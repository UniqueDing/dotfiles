use std::fmt;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ServiceStatus {
    Running,
    Starting,
    Stopped,
    Stopping,
    Failed,
    Unknown,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Operation {
    Start,
    Stop,
    Restart,
}

impl fmt::Display for Operation {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::Start => "start",
            Self::Stop => "stop",
            Self::Restart => "restart",
        })
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ControllerState {
    pub status: ServiceStatus,
    pub operation_in_flight: Option<Operation>,
    pub last_error: Option<String>,
}

impl ControllerState {
    pub fn new() -> Self {
        Self {
            status: ServiceStatus::Unknown,
            operation_in_flight: None,
            last_error: None,
        }
    }
}

impl Default for ControllerState {
    fn default() -> Self {
        Self::new()
    }
}
