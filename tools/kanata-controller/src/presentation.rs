use crate::model::{ControllerState, ServiceStatus};

#[derive(Clone, Debug, Eq, PartialEq)]
pub(crate) struct MenuState {
    pub(crate) title: String,
    pub(crate) start_enabled: bool,
    pub(crate) stop_enabled: bool,
    pub(crate) restart_enabled: bool,
    pub(crate) detail: String,
}

impl From<&ControllerState> for MenuState {
    fn from(state: &ControllerState) -> Self {
        let (title, start_enabled, stop_enabled, restart_enabled) = match state.status {
            ServiceStatus::Running => ("Running", false, true, true),
            ServiceStatus::Starting => ("Starting", false, false, false),
            ServiceStatus::Stopped => ("Stopped", true, false, false),
            ServiceStatus::Stopping => ("Stopping", false, false, false),
            ServiceStatus::Failed => ("Failed", true, false, false),
            ServiceStatus::Unknown => ("Unknown", true, false, false),
        };

        let actions_enabled = state.operation_in_flight.is_none();
        let detail = state.last_error.clone().unwrap_or_default();

        Self {
            title: title.into(),
            start_enabled: actions_enabled && start_enabled,
            stop_enabled: actions_enabled && stop_enabled,
            restart_enabled: actions_enabled && restart_enabled,
            detail,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::Operation;

    #[test]
    fn running_state_is_platform_neutral_and_enables_stop_restart() {
        let state = ControllerState {
            status: ServiceStatus::Running,
            operation_in_flight: None,
            last_error: None,
        };

        let menu = MenuState::from(&state);

        assert_eq!(menu.title, "Running");
        assert_eq!(menu.detail, "");
        assert!(!menu.start_enabled);
        assert!(menu.stop_enabled);
        assert!(menu.restart_enabled);
        assert!(!menu.detail.contains("kanata.service"));
    }

    #[test]
    fn in_flight_operation_disables_actions_without_hiding_error() {
        let state = ControllerState {
            status: ServiceStatus::Stopped,
            operation_in_flight: Some(Operation::Start),
            last_error: Some("helper failed".into()),
        };

        let menu = MenuState::from(&state);

        assert!(!menu.start_enabled);
        assert!(!menu.stop_enabled);
        assert!(!menu.restart_enabled);
        assert_eq!(menu.detail, "helper failed");
    }
}
