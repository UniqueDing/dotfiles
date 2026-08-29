use std::time::Duration;

use kanata_controller::{
    linux_sni::{KanataTray, TrayCommand},
    model::{ControllerState, Operation, ServiceStatus},
    service::{ServiceControl, SystemdControl},
};
use ksni::TrayMethods;
use tokio::{sync::mpsc, time};

const MAX_ERROR_CHARS: usize = 512;

#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let (commands, mut receiver) = mpsc::channel::<TrayCommand>(1);
    let (shutdown, mut shutdown_receiver) = mpsc::unbounded_channel();
    let handle = KanataTray::new(ControllerState::new(), commands, shutdown)
        .spawn()
        .await?;
    let control = SystemdControl::new();
    let mut poll = time::interval(Duration::from_secs(2));

    loop {
        tokio::select! {
            _ = poll.tick() => refresh_status(&handle, control).await,
            shutdown = shutdown_receiver.recv() => {
                let _ = shutdown;
                handle.shutdown().await;
                return Ok(());
            }
            command = receiver.recv() => match command {
                None => {
                    handle.shutdown().await;
                    return Ok(());
                }
                Some(command) => run_operation(&handle, control, command).await,
            },
        }
    }
}

async fn refresh_status(handle: &ksni::Handle<KanataTray>, control: SystemdControl) {
    let result = control.status().await.map_err(bound_error);
    handle
        .update(|tray| match result {
            Ok(status) => {
                tray.state.status = status;
                tray.state.last_error = None;
            }
            Err(error) => {
                tray.state.status = ServiceStatus::Unknown;
                tray.state.last_error = Some(error);
            }
        })
        .await;
}

async fn run_operation(
    handle: &ksni::Handle<KanataTray>,
    control: SystemdControl,
    command: TrayCommand,
) {
    let operation = match command {
        TrayCommand::Start => Operation::Start,
        TrayCommand::Stop => Operation::Stop,
        TrayCommand::Restart => Operation::Restart,
        TrayCommand::Quit => return,
    };
    let operation_error = control.execute(operation).await.err().map(bound_error);
    let status_result = control.status().await.map_err(bound_error);

    handle
        .update(|tray| {
            tray.state.operation_in_flight = None;
            match status_result {
                Ok(status) => {
                    tray.state.status = status;
                    tray.state.last_error = operation_error;
                }
                Err(status_error) => {
                    tray.state.status = ServiceStatus::Unknown;
                    tray.state.last_error = Some(match operation_error {
                        Some(operation_error) => format!("{operation_error}；{status_error}"),
                        None => status_error,
                    });
                }
            }
        })
        .await;
}

fn bound_error(error: String) -> String {
    error.chars().take(MAX_ERROR_CHARS).collect()
}
