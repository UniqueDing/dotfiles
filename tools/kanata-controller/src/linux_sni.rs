use std::fmt;

use tokio::sync::mpsc::{error::TrySendError, Sender, UnboundedSender};

use crate::{
    model::{ControllerState, Operation, ServiceStatus},
    tray::MenuState,
};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TrayCommand {
    Start,
    Stop,
    Restart,
    Quit,
}

impl fmt::Display for TrayCommand {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::Start => "start",
            Self::Stop => "stop",
            Self::Restart => "restart",
            Self::Quit => "quit",
        })
    }
}

pub struct KanataTray {
    pub state: ControllerState,
    pub commands: Sender<TrayCommand>,
    pub shutdown: UnboundedSender<()>,
}

impl KanataTray {
    pub fn new(
        state: ControllerState,
        commands: Sender<TrayCommand>,
        shutdown: UnboundedSender<()>,
    ) -> Self {
        Self {
            state,
            commands,
            shutdown,
        }
    }

    pub fn request_operation(&mut self, operation: Operation, command: TrayCommand) -> bool {
        if self.state.operation_in_flight.is_some() {
            return false;
        }
        self.state.operation_in_flight = Some(operation);
        match self.commands.try_send(command) {
            Ok(()) => true,
            Err(TrySendError::Full(_)) => {
                self.state.operation_in_flight = None;
                self.state.last_error = Some("操作队列繁忙".into());
                false
            }
            Err(TrySendError::Closed(_)) => {
                self.state.operation_in_flight = None;
                self.state.last_error = Some("无法发送托盘命令".into());
                false
            }
        }
    }
}

impl ksni::Tray for KanataTray {
    fn id(&self) -> String {
        "kanata-controller".into()
    }

    fn title(&self) -> String {
        MenuState::from(&self.state).title
    }

    fn icon_name(&self) -> String {
        "input-keyboard".into()
    }

    fn tool_tip(&self) -> ksni::ToolTip {
        let menu = MenuState::from(&self.state);
        ksni::ToolTip {
            title: menu.title,
            description: menu.detail,
            icon_name: "input-keyboard".into(),
            icon_pixmap: Vec::new(),
        }
    }

    fn status(&self) -> ksni::Status {
        if self.state.status == ServiceStatus::Failed || self.state.last_error.is_some() {
            ksni::Status::NeedsAttention
        } else {
            ksni::Status::Active
        }
    }

    fn watcher_offline(&self, reason: ksni::OfflineReason) -> bool {
        eprintln!("StatusNotifierWatcher offline: {reason:?}");
        true
    }

    fn menu(&self) -> Vec<ksni::MenuItem<Self>> {
        let menu = MenuState::from(&self.state);

        vec![
            ksni::menu::StandardItem {
                label: menu.detail,
                enabled: false,
                ..Default::default()
            }
            .into(),
            ksni::menu::StandardItem {
                label: "启动".into(),
                enabled: menu.start_enabled,
                activate: Box::new(|tray: &mut Self| {
                    tray.request_operation(Operation::Start, TrayCommand::Start);
                }),
                ..Default::default()
            }
            .into(),
            ksni::menu::StandardItem {
                label: "停止".into(),
                enabled: menu.stop_enabled,
                activate: Box::new(|tray: &mut Self| {
                    tray.request_operation(Operation::Stop, TrayCommand::Stop);
                }),
                ..Default::default()
            }
            .into(),
            ksni::menu::StandardItem {
                label: "重启".into(),
                enabled: menu.restart_enabled,
                activate: Box::new(|tray: &mut Self| {
                    tray.request_operation(Operation::Restart, TrayCommand::Restart);
                }),
                ..Default::default()
            }
            .into(),
            ksni::menu::MenuItem::Separator,
            ksni::menu::StandardItem {
                label: "退出".into(),
                activate: Box::new(|tray: &mut Self| {
                    let _ = tray.shutdown.send(());
                }),
                ..Default::default()
            }
            .into(),
        ]
    }
}
