use crate::{
    model::{ControllerState, Operation, ServiceStatus},
    service::ServiceControl,
};

const MAX_ERROR_CHARS: usize = 512;

pub(crate) struct ControllerEngine<C> {
    control: C,
    state: ControllerState,
}

impl<C: ServiceControl> ControllerEngine<C> {
    pub(crate) fn new(control: C) -> Self {
        Self {
            control,
            state: ControllerState::new(),
        }
    }

    pub(crate) fn state(&self) -> &ControllerState {
        &self.state
    }

    pub(crate) fn begin(&mut self, operation: Operation) -> &ControllerState {
        self.state.operation_in_flight = Some(operation);
        &self.state
    }

    pub(crate) fn set_error(&mut self, error: String) -> &ControllerState {
        self.state.last_error = Some(bound_error(error));
        &self.state
    }

    pub(crate) async fn execute(&mut self, operation: Operation) -> &ControllerState {
        self.state.last_error = self.control.execute(operation).await.err().map(bound_error);
        self.state.operation_in_flight = None;
        self.refresh(false).await
    }

    pub(crate) async fn refresh(&mut self, clear_error: bool) -> &ControllerState {
        match self.control.status().await {
            Ok(status) => {
                self.state.status = status;
                if clear_error {
                    self.state.last_error = None;
                }
            }
            Err(error) => {
                self.state.status = ServiceStatus::Unknown;
                self.state.last_error = Some(bound_error(error));
            }
        }
        &self.state
    }
}

fn bound_error(error: String) -> String {
    error.chars().take(MAX_ERROR_CHARS).collect()
}

#[cfg(test)]
mod tests {
    use std::{collections::VecDeque, future::Future, sync::Mutex};

    use super::*;

    struct FakeControl {
        statuses: Mutex<VecDeque<Result<ServiceStatus, String>>>,
        operations: Mutex<VecDeque<Result<(), String>>>,
    }

    impl FakeControl {
        fn new(
            statuses: impl IntoIterator<Item = Result<ServiceStatus, String>>,
            operations: impl IntoIterator<Item = Result<(), String>>,
        ) -> Self {
            Self {
                statuses: Mutex::new(statuses.into_iter().collect()),
                operations: Mutex::new(operations.into_iter().collect()),
            }
        }
    }

    impl ServiceControl for FakeControl {
        fn status(&self) -> impl Future<Output = Result<ServiceStatus, String>> + Send {
            std::future::ready(
                self.statuses
                    .lock()
                    .expect("test status lock")
                    .pop_front()
                    .expect("test status result"),
            )
        }

        fn execute(
            &self,
            _operation: Operation,
        ) -> impl Future<Output = Result<(), String>> + Send {
            std::future::ready(
                self.operations
                    .lock()
                    .expect("test operation lock")
                    .pop_front()
                    .expect("test operation result"),
            )
        }
    }

    #[tokio::test]
    async fn failed_operation_then_successful_refresh_preserves_operation_error() {
        let control = FakeControl::new(
            [Ok(ServiceStatus::Running)],
            [Err("permission denied".into())],
        );
        let mut engine = ControllerEngine::new(control);

        engine.begin(Operation::Restart);
        assert_eq!(engine.state().operation_in_flight, Some(Operation::Restart));

        engine.execute(Operation::Restart).await;
        assert_eq!(engine.state().status, ServiceStatus::Running);
        assert_eq!(engine.state().operation_in_flight, None);
        assert_eq!(
            engine.state().last_error.as_deref(),
            Some("permission denied")
        );
    }

    #[tokio::test]
    async fn periodic_successful_refresh_clears_old_error() {
        let mut engine = ControllerEngine::new(FakeControl::new([Ok(ServiceStatus::Stopped)], []));
        engine.state.last_error = Some("old error".into());

        engine.refresh(true).await;
        assert_eq!(engine.state().status, ServiceStatus::Stopped);
        assert_eq!(engine.state().last_error, None);
    }

    #[tokio::test]
    async fn status_error_sets_unknown_and_bounds_error() {
        let mut engine = ControllerEngine::new(FakeControl::new([Err("x".repeat(1024))], []));

        engine.refresh(true).await;
        assert_eq!(engine.state().status, ServiceStatus::Unknown);
        assert_eq!(
            engine.state().last_error.as_ref().unwrap().chars().count(),
            512
        );
    }
}
