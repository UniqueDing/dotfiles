use std::future::Future;

use crate::model::{Operation, ServiceStatus};

#[cfg(target_os = "linux")]
use crate::process::{run_bounded, CommandError, CommandOutput, CommandSpec};

#[cfg(target_os = "linux")]
pub(crate) const SYSTEMD_UNIT: &str = "kanata.service";
#[cfg(target_os = "linux")]
const SYSTEMCTL_PATH: &str = "/usr/bin/systemctl";
pub(crate) trait ServiceControl {
    fn status(&self) -> impl Future<Output = Result<ServiceStatus, String>> + Send;
    fn execute(&self, operation: Operation) -> impl Future<Output = Result<(), String>> + Send;
}

#[derive(Clone, Copy, Debug, Default)]
#[cfg(target_os = "linux")]
pub(crate) struct SystemdControl;

#[cfg(target_os = "linux")]
impl SystemdControl {
    pub(crate) fn new() -> Self {
        Self
    }

    pub(crate) fn command_for(&self, operation: Operation) -> CommandSpec {
        let verb = match operation {
            Operation::Start => "start",
            Operation::Stop => "stop",
            Operation::Restart => "restart",
        };
        CommandSpec::new(SYSTEMCTL_PATH, [verb, SYSTEMD_UNIT])
    }

    pub(crate) fn status_command(&self) -> CommandSpec {
        CommandSpec::new(
            SYSTEMCTL_PATH,
            ["show", SYSTEMD_UNIT, "--property=ActiveState", "--value"],
        )
    }

    async fn run(&self, spec: CommandSpec) -> Result<CommandOutput, String> {
        run_bounded(&spec).await.map_err(systemd_error)
    }
}

#[cfg(target_os = "linux")]
impl ServiceControl for SystemdControl {
    async fn status(&self) -> Result<ServiceStatus, String> {
        let output = self.run(self.status_command()).await?;
        Ok(parse_active_state(&output.stdout))
    }

    async fn execute(&self, operation: Operation) -> Result<(), String> {
        self.run(self.command_for(operation)).await.map(|_| ())
    }
}

#[cfg(target_os = "linux")]
fn bounded_stderr(stderr: &[u8]) -> String {
    let error = String::from_utf8_lossy(stderr).trim().to_owned();
    if error.is_empty() {
        "systemctl command failed".into()
    } else {
        error
    }
}

#[cfg(target_os = "linux")]
fn systemd_error(error: CommandError) -> String {
    match error {
        CommandError::Exit { stderr, .. } => bounded_stderr(&stderr),
        CommandError::Timeout => "systemctl command timed out".into(),
        CommandError::Spawn(error) | CommandError::Wait(error) | CommandError::Read(error) => {
            error.chars().take(512).collect()
        }
    }
}

#[cfg_attr(not(target_os = "linux"), allow(dead_code))]
pub(crate) fn parse_active_state(output: &[u8]) -> ServiceStatus {
    match String::from_utf8_lossy(output).trim() {
        "active" => ServiceStatus::Running,
        "activating" => ServiceStatus::Starting,
        "inactive" => ServiceStatus::Stopped,
        "deactivating" => ServiceStatus::Stopping,
        "failed" => ServiceStatus::Failed,
        _ => ServiceStatus::Unknown,
    }
}

#[cfg(all(test, target_os = "linux"))]
mod tests {
    use super::*;

    #[test]
    fn systemd_commands_are_fixed_to_kanata_unit() {
        let control = SystemdControl::new();
        assert_eq!(
            control.command_for(Operation::Restart),
            CommandSpec::new(SYSTEMCTL_PATH, ["restart", SYSTEMD_UNIT])
        );
        assert_eq!(
            control.status_command(),
            CommandSpec::new(
                SYSTEMCTL_PATH,
                ["show", SYSTEMD_UNIT, "--property=ActiveState", "--value"]
            )
        );
    }
}

#[cfg(test)]
mod parser_tests {
    use super::*;

    #[test]
    fn systemd_active_state_parser_maps_known_values() {
        assert_eq!(parse_active_state(b"active\n"), ServiceStatus::Running);
        assert_eq!(parse_active_state(b"activating\n"), ServiceStatus::Starting);
        assert_eq!(parse_active_state(b"inactive\n"), ServiceStatus::Stopped);
        assert_eq!(
            parse_active_state(b"deactivating\n"),
            ServiceStatus::Stopping
        );
        assert_eq!(parse_active_state(b"failed\n"), ServiceStatus::Failed);
        assert_eq!(parse_active_state(b"unknown\n"), ServiceStatus::Unknown);
    }
}
