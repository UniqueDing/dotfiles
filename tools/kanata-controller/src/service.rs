use std::{future::Future, process::Stdio, time::Duration};

use tokio::{
    io::{AsyncRead, AsyncReadExt},
    process::Command,
    time,
};

use crate::model::{Operation, ServiceStatus};

pub const SYSTEMD_UNIT: &str = "kanata.service";
const SYSTEMCTL_PATH: &str = "/usr/bin/systemctl";
const MAX_OUTPUT_BYTES: usize = 4 * 1024;
const COMMAND_TIMEOUT: Duration = Duration::from_secs(10);

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

pub trait ServiceControl {
    fn status(&self) -> impl Future<Output = Result<ServiceStatus, String>> + Send;
    fn execute(&self, operation: Operation) -> impl Future<Output = Result<(), String>> + Send;
}

#[derive(Clone, Copy, Debug, Default)]
pub struct SystemdControl;

impl SystemdControl {
    pub fn new() -> Self {
        Self
    }

    pub fn command_for(&self, operation: Operation) -> CommandSpec {
        let verb = match operation {
            Operation::Start => "start",
            Operation::Stop => "stop",
            Operation::Restart => "restart",
        };
        CommandSpec::new(SYSTEMCTL_PATH, [verb, SYSTEMD_UNIT])
    }

    pub fn status_command(&self) -> CommandSpec {
        CommandSpec::new(
            SYSTEMCTL_PATH,
            ["show", SYSTEMD_UNIT, "--property=ActiveState", "--value"],
        )
    }

    async fn run(&self, spec: CommandSpec) -> Result<CommandOutput, String> {
        let mut child = Command::new(spec.program)
            .args(&spec.args)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .kill_on_drop(true)
            .spawn()
            .map_err(|error| error.to_string())?;
        let stdout = child.stdout.take().expect("stdout is piped");
        let stderr = child.stderr.take().expect("stderr is piped");
        let stdout_reader = tokio::spawn(read_bounded(stdout));
        let stderr_reader = tokio::spawn(read_bounded(stderr));

        let status = match time::timeout(COMMAND_TIMEOUT, child.wait()).await {
            Ok(result) => result.map_err(|error| error.to_string())?,
            Err(_) => {
                child.kill().await.map_err(|error| error.to_string())?;
                child.wait().await.map_err(|error| error.to_string())?
            }
        };
        let stdout = stdout_reader.await.map_err(|error| error.to_string())?;
        let stderr = stderr_reader.await.map_err(|error| error.to_string())?;

        if status.success() {
            Ok(CommandOutput { stdout })
        } else {
            Err(bounded_stderr(&stderr))
        }
    }
}

impl ServiceControl for SystemdControl {
    async fn status(&self) -> Result<ServiceStatus, String> {
        let output = self.run(self.status_command()).await?;
        Ok(parse_active_state(&output.stdout))
    }

    async fn execute(&self, operation: Operation) -> Result<(), String> {
        self.run(self.command_for(operation)).await.map(|_| ())
    }
}

struct CommandOutput {
    stdout: Vec<u8>,
}

async fn read_bounded<R: AsyncRead + Unpin>(mut reader: R) -> Vec<u8> {
    let mut output = Vec::new();
    let mut buffer = [0_u8; 1024];
    loop {
        let read = match reader.read(&mut buffer).await {
            Ok(0) | Err(_) => break,
            Ok(read) => read,
        };
        let remaining = MAX_OUTPUT_BYTES.saturating_sub(output.len());
        output.extend_from_slice(&buffer[..read.min(remaining)]);
    }
    output
}

fn bounded_stderr(stderr: &[u8]) -> String {
    let error = String::from_utf8_lossy(stderr).trim().to_owned();
    if error.is_empty() {
        "systemctl command failed".into()
    } else {
        error
    }
}

pub fn parse_active_state(output: &[u8]) -> ServiceStatus {
    match String::from_utf8_lossy(output).trim() {
        "active" => ServiceStatus::Running,
        "activating" => ServiceStatus::Starting,
        "inactive" => ServiceStatus::Stopped,
        "deactivating" => ServiceStatus::Stopping,
        "failed" => ServiceStatus::Failed,
        _ => ServiceStatus::Unknown,
    }
}
