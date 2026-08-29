use crate::model::{ControllerState, ServiceStatus};

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MenuState {
    pub title: String,
    pub start_enabled: bool,
    pub stop_enabled: bool,
    pub restart_enabled: bool,
    pub detail: String,
}

impl From<&ControllerState> for MenuState {
    fn from(state: &ControllerState) -> Self {
        let (title, detail, start_enabled, stop_enabled, restart_enabled) = match state.status {
            ServiceStatus::Running => (
                "Kanata — 运行中",
                "kanata.service 正在运行",
                false,
                true,
                true,
            ),
            ServiceStatus::Starting => (
                "Kanata — 启动中",
                "kanata.service 正在启动",
                false,
                false,
                false,
            ),
            ServiceStatus::Stopped => (
                "Kanata — 已停止",
                "kanata.service 未运行",
                true,
                false,
                false,
            ),
            ServiceStatus::Stopping => (
                "Kanata — 停止中",
                "kanata.service 正在停止",
                false,
                false,
                false,
            ),
            ServiceStatus::Failed => ("Kanata — 失败", "kanata.service 失败", true, false, false),
            ServiceStatus::Unknown => (
                "Kanata — 未知",
                "kanata.service 状态未知",
                true,
                false,
                false,
            ),
        };

        let actions_enabled = state.operation_in_flight.is_none();

        let detail = match &state.last_error {
            Some(error) => format!("{detail}：{error}"),
            None => detail.into(),
        };

        Self {
            title: title.into(),
            start_enabled: actions_enabled && start_enabled,
            stop_enabled: actions_enabled && stop_enabled,
            restart_enabled: actions_enabled && restart_enabled,
            detail,
        }
    }
}
