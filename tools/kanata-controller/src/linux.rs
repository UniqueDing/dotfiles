use std::time::Duration;

use ksni::TrayMethods;
use tokio::{sync::mpsc, time};

use crate::{
    engine::ControllerEngine,
    linux_sni::{KanataTray, TrayCommand},
    model::{ControllerState, Operation},
    service::{ServiceControl, SystemdControl},
};

const MAX_ERROR_CHARS: usize = 512;

pub async fn run() -> Result<(), Box<dyn std::error::Error>> {
    let (commands, mut receiver) = mpsc::channel::<TrayCommand>(1);
    let (shutdown, mut shutdown_receiver) = mpsc::unbounded_channel();
    let handle = KanataTray::new(ControllerState::new(), commands, shutdown)
        .spawn()
        .await?;
    let mut engine = ControllerEngine::new(SystemdControl::new());
    let mut poll = time::interval(Duration::from_secs(2));

    loop {
        tokio::select! {
            _ = poll.tick() => refresh_status(&handle, &mut engine).await,
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
                Some(command) => run_operation(&handle, &mut engine, command).await,
            },
        }
    }
}

async fn refresh_status(
    handle: &ksni::Handle<KanataTray>,
    engine: &mut ControllerEngine<SystemdControl>,
) {
    let state = engine.refresh(true).await.clone();
    handle.update(|tray| tray.state = state).await;
}

async fn run_operation(
    handle: &ksni::Handle<KanataTray>,
    engine: &mut ControllerEngine<SystemdControl>,
    command: TrayCommand,
) {
    let operation = match command {
        TrayCommand::Start => Operation::Start,
        TrayCommand::Stop => Operation::Stop,
        TrayCommand::Restart => Operation::Restart,
    };
    let state = engine.begin(operation).clone();
    handle.update(|tray| tray.state = state).await;
    let state = engine.execute(operation).await.clone();

    handle.update(|tray| tray.state = state).await;
}
