use std::future::Future;

use crate::{
    model::{Operation, ServiceStatus},
    process::{run_bounded, CommandError, CommandSpec},
};

pub(crate) const CONTROL_HELPER: &str = "/usr/local/libexec/kanata-control";
pub(crate) const SUDO_PATH: &str = "/usr/bin/sudo";
pub(crate) const OPEN_PATH: &str = "/usr/bin/open";
#[derive(Clone, Copy, Debug, Default)]
pub(crate) struct MacControl;

impl MacControl {
    pub(crate) fn new() -> Self {
        Self
    }

    pub(crate) fn command_for(&self, operation: Operation) -> CommandSpec {
        let operation = match operation {
            Operation::Start => "start",
            Operation::Stop => "stop",
            Operation::Restart => "restart",
        };
        CommandSpec::new(SUDO_PATH, ["-n", CONTROL_HELPER, operation])
    }

    pub(crate) fn status_command(&self) -> CommandSpec {
        CommandSpec::new(SUDO_PATH, ["-n", CONTROL_HELPER, "status"])
    }

    pub(crate) async fn open_config(&self) -> Result<(), String> {
        let home = std::env::var_os("HOME").ok_or_else(|| "HOME is not set".to_owned())?;
        let config = std::path::PathBuf::from(home)
            .join(".config")
            .join("kanata")
            .join("kanata.kbd");
        self.run(CommandSpec {
            program: OPEN_PATH,
            args: vec![config.to_string_lossy().into_owned()],
        })
        .await
        .map(|_| ())
    }

    async fn run(&self, spec: CommandSpec) -> Result<Vec<u8>, String> {
        run_bounded(&spec)
            .await
            .map(|output| output.stdout)
            .map_err(macos_control_error)
    }
}

impl crate::service::ServiceControl for MacControl {
    #[allow(clippy::manual_async_fn)]
    fn status(&self) -> impl Future<Output = Result<ServiceStatus, String>> + Send {
        async move {
            let output = self.run(self.status_command()).await?;
            Ok(parse_helper_status(&output))
        }
    }

    #[allow(clippy::manual_async_fn)]
    fn execute(&self, operation: Operation) -> impl Future<Output = Result<(), String>> + Send {
        async move { self.run(self.command_for(operation)).await.map(|_| ()) }
    }
}

fn control_error(stderr: &[u8]) -> String {
    let error = String::from_utf8_lossy(stderr).trim().to_owned();
    let lower = error.to_ascii_lowercase();
    if lower.contains("a password is required")
        || lower.contains("no tty present")
        || lower.contains("not allowed to run sudo")
    {
        "Authorization unavailable: configure NOPASSWD for kanata-control".into()
    } else if error.is_empty() {
        "kanata-control command failed".into()
    } else {
        error.chars().take(512).collect()
    }
}

fn macos_control_error(error: CommandError) -> String {
    match error {
        CommandError::Exit { stderr, .. } => control_error(&stderr),
        CommandError::Timeout => "kanata-control command timed out".into(),
        CommandError::Spawn(error) | CommandError::Wait(error) | CommandError::Read(error) => {
            error.chars().take(512).collect()
        }
    }
}

/// Parse only explicit launchctl state and pid fields. In particular, do not
/// inspect `last exit code`: a running job commonly reports `never exited`.
pub(crate) fn parse_helper_status(output: &[u8]) -> ServiceStatus {
    let text = String::from_utf8_lossy(output);
    let mut state = None;
    let mut has_positive_pid = false;

    for line in text.lines() {
        let line = line.trim();
        if let Some(value) = line.strip_prefix("state =") {
            state = Some(value.trim());
        } else if let Some(value) = line.strip_prefix("pid =") {
            has_positive_pid = value.trim().parse::<u64>().is_ok_and(|pid| pid > 0);
        }
    }

    if matches!(state, Some("running")) || has_positive_pid {
        ServiceStatus::Running
    } else if matches!(
        state,
        Some(
            "stopped"
                | "waiting"
                | "exited"
                | "throttled"
                | "terminated"
                | "crashed"
                | "spawn scheduled"
        )
    ) {
        ServiceStatus::Stopped
    } else {
        ServiceStatus::Unknown
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn helper_commands_are_fixed_sudo_invocations() {
        let control = MacControl::new();
        assert_eq!(
            control.status_command(),
            CommandSpec::new(SUDO_PATH, ["-n", CONTROL_HELPER, "status"])
        );
        assert_eq!(
            control.command_for(Operation::Restart),
            CommandSpec::new(SUDO_PATH, ["-n", CONTROL_HELPER, "restart"])
        );
    }

    #[test]
    fn running_launchctl_output_ignores_never_exited_text() {
        assert_eq!(
            parse_helper_status(
                b"system/dev.kanata.kanata = {\n\tstate = running\n\tpid = 8485\n\tlast exit code = (never exited)\n}"
            ),
            ServiceStatus::Running
        );
    }

    #[test]
    fn stopped_launchctl_state_is_stopped() {
        assert_eq!(
            parse_helper_status(b"\tstate = spawn scheduled\n\tlast exit code = 1"),
            ServiceStatus::Stopped
        );
    }

    #[test]
    fn arbitrary_text_is_unknown() {
        assert_eq!(
            parse_helper_status(b"all systems nominal; never exited"),
            ServiceStatus::Unknown
        );
    }
}
