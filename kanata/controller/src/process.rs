use std::{process::Stdio, time::Duration};

use tokio::{
    io::{AsyncRead, AsyncReadExt},
    process::Command,
    time,
};

pub(crate) const MAX_OUTPUT_BYTES: usize = 4 * 1024;
pub(crate) const COMMAND_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CommandSpec {
    pub program: &'static str,
    pub args: Vec<String>,
}

impl CommandSpec {
    pub fn new<const N: usize>(program: &'static str, args: [&str; N]) -> Self {
        Self {
            program,
            args: args.into_iter().map(str::to_owned).collect(),
        }
    }
}

#[derive(Debug, Eq, PartialEq)]
pub(crate) struct CommandOutput {
    pub(crate) stdout: Vec<u8>,
    pub(crate) stderr: Vec<u8>,
}

#[derive(Debug, Eq, PartialEq)]
pub(crate) enum CommandError {
    Spawn(String),
    Timeout,
    Wait(String),
    Read(String),
    Exit {
        code: Option<i32>,
        stdout: Vec<u8>,
        stderr: Vec<u8>,
    },
}

pub(crate) async fn run_bounded(spec: &CommandSpec) -> Result<CommandOutput, CommandError> {
    run_with_timeout(spec, COMMAND_TIMEOUT).await
}

async fn run_with_timeout(
    spec: &CommandSpec,
    timeout: Duration,
) -> Result<CommandOutput, CommandError> {
    let mut child = Command::new(spec.program)
        .args(&spec.args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true)
        .spawn()
        .map_err(|error| CommandError::Spawn(error.to_string()))?;
    let stdout = child.stdout.take().expect("stdout is piped");
    let stderr = child.stderr.take().expect("stderr is piped");
    let stdout_reader = tokio::spawn(read_bounded(stdout));
    let stderr_reader = tokio::spawn(read_bounded(stderr));
    let status = match time::timeout(timeout, child.wait()).await {
        Ok(result) => result.map_err(|error| CommandError::Wait(error.to_string()))?,
        Err(_) => {
            child
                .kill()
                .await
                .map_err(|error| CommandError::Wait(error.to_string()))?;
            child
                .wait()
                .await
                .map_err(|error| CommandError::Wait(error.to_string()))?;
            return Err(CommandError::Timeout);
        }
    };
    let stdout = stdout_reader
        .await
        .map_err(|error| CommandError::Read(error.to_string()))??;
    let stderr = stderr_reader
        .await
        .map_err(|error| CommandError::Read(error.to_string()))??;
    if status.success() {
        Ok(CommandOutput { stdout, stderr })
    } else {
        Err(CommandError::Exit {
            code: status.code(),
            stdout,
            stderr,
        })
    }
}

async fn read_bounded<R: AsyncRead + Unpin>(mut reader: R) -> Result<Vec<u8>, CommandError> {
    let mut output = Vec::new();
    let mut buffer = [0_u8; 1024];
    loop {
        let read = reader
            .read(&mut buffer)
            .await
            .map_err(|error| CommandError::Read(error.to_string()))?;
        if read == 0 {
            return Ok(output);
        }
        let remaining = MAX_OUTPUT_BYTES.saturating_sub(output.len());
        output.extend_from_slice(&buffer[..read.min(remaining)]);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn successful_command_collects_both_streams() {
        let spec = CommandSpec::new("/bin/sh", ["-c", "printf out; printf err >&2"]);
        let output = run_bounded(&spec).await.unwrap();
        assert_eq!(output.stdout, b"out");
        assert_eq!(output.stderr, b"err");
    }

    #[tokio::test]
    async fn nonzero_exit_preserves_bounded_stderr() {
        let spec = CommandSpec::new("/bin/sh", ["-c", "printf denied >&2; exit 7"]);
        let CommandError::Exit { code, stderr, .. } = run_bounded(&spec).await.unwrap_err() else {
            panic!("expected nonzero exit");
        };
        assert_eq!(code, Some(7));
        assert_eq!(stderr, b"denied");
    }

    #[tokio::test]
    async fn timeout_kills_the_child() {
        let spec = CommandSpec::new("/bin/sh", ["-c", "sleep 1"]);
        assert_eq!(
            run_with_timeout(&spec, Duration::from_millis(10)).await,
            Err(CommandError::Timeout)
        );
    }
}
