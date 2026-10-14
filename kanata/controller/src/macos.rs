use std::{sync::mpsc, thread, time::Duration};

use tao::{
    event::{Event, StartCause},
    event_loop::{ControlFlow, EventLoopBuilder, EventLoopProxy},
    platform::macos::{ActivationPolicy, EventLoopExtMacOS},
};
use tray_icon::{
    menu::{Menu, MenuEvent, MenuItem, PredefinedMenuItem},
    Icon, TrayIconBuilder,
};

use crate::{
    engine::ControllerEngine,
    macos_control::MacControl,
    model::{ControllerState, Operation},
    presentation::MenuState,
};

const POLL_INTERVAL: Duration = Duration::from_secs(2);
const TRAY_ICON_SIZE: u32 = 32;
const TRAY_ICON_SVG: &[u8] = include_bytes!("../assets/kanata-controller.svg");

#[derive(Clone, Copy)]
enum WorkerCommand {
    Start,
    Stop,
    Restart,
    OpenConfig,
}

enum UserEvent {
    State(ControllerState),
    Command(WorkerCommand),
}

struct MenuItems {
    detail: MenuItem,
    start: MenuItem,
    stop: MenuItem,
    restart: MenuItem,
    open_config: MenuItem,
}

struct ControllerUi {
    _tray: tray_icon::TrayIcon,
    items: MenuItems,
    commands: mpsc::Sender<WorkerCommand>,
    state: ControllerState,
}

pub fn run() -> Result<(), Box<dyn std::error::Error>> {
    let mut event_loop = EventLoopBuilder::<UserEvent>::with_user_event().build();
    event_loop.set_activation_policy(ActivationPolicy::Accessory);
    event_loop.set_activate_ignoring_other_apps(false);
    let proxy = event_loop.create_proxy();
    let mut ui = None;
    event_loop.run(move |event, _target, control_flow| {
        *control_flow = ControlFlow::Wait;
        match event {
            Event::NewEvents(StartCause::Init) if ui.is_none() => {
                let (menu, items) = build_menu();
                let tray = match TrayIconBuilder::new()
                    .with_menu(Box::new(menu))
                    .with_tooltip("Kanata")
                    .with_icon(template_icon())
                    .build()
                {
                    Ok(tray) => tray,
                    Err(error) => {
                        eprintln!("Unable to create tray icon: {error}");
                        *control_flow = ControlFlow::Exit;
                        return;
                    }
                };
                install_menu_handler(proxy.clone(), &items);

                let (commands, receiver) = mpsc::channel();
                spawn_worker(proxy.clone(), receiver);

                let state = ControllerState::new();
                update_menu(&items, &state);
                ui = Some(ControllerUi {
                    _tray: tray,
                    items,
                    commands,
                    state,
                });
            }
            Event::UserEvent(event) => {
                let Some(ui) = ui.as_mut() else {
                    return;
                };
                match event {
                    UserEvent::State(next_state) => {
                        ui.state = next_state;
                        update_menu(&ui.items, &ui.state);
                    }
                    UserEvent::Command(command) => {
                        if let Some(operation) = operation(command) {
                            if ui.state.operation_in_flight.is_some() {
                                return;
                            }
                            ui.state.operation_in_flight = Some(operation);
                            update_menu(&ui.items, &ui.state);
                        }
                        if ui.commands.send(command).is_err() {
                            ui.state.last_error = Some("Unable to send menu command".into());
                            ui.state.operation_in_flight = None;
                            update_menu(&ui.items, &ui.state);
                        }
                    }
                }
            }
            _ => {}
        }
    })
}

fn build_menu() -> (Menu, MenuItems) {
    let menu = Menu::new();
    let detail = MenuItem::new("Kanata — checking status", false, None);
    let start = MenuItem::new("Start", false, None);
    let stop = MenuItem::new("Stop", false, None);
    let restart = MenuItem::new("Restart", false, None);
    let open_config = MenuItem::new("Open Config", true, None);
    menu.append_items(&[
        &detail,
        &start,
        &stop,
        &restart,
        &PredefinedMenuItem::separator(),
        &open_config,
    ])
    .expect("menu construction cannot fail");
    (
        menu,
        MenuItems {
            detail,
            start,
            stop,
            restart,
            open_config,
        },
    )
}

fn install_menu_handler(proxy: EventLoopProxy<UserEvent>, items: &MenuItems) {
    let start = items.start.id().clone();
    let stop = items.stop.id().clone();
    let restart = items.restart.id().clone();
    let open_config = items.open_config.id().clone();
    MenuEvent::set_event_handler(Some(move |event: MenuEvent| {
        let event = if event.id == start {
            UserEvent::Command(WorkerCommand::Start)
        } else if event.id == stop {
            UserEvent::Command(WorkerCommand::Stop)
        } else if event.id == restart {
            UserEvent::Command(WorkerCommand::Restart)
        } else if event.id == open_config {
            UserEvent::Command(WorkerCommand::OpenConfig)
        } else {
            return;
        };
        if proxy.send_event(event).is_err() {
            eprintln!("kanata-controller: menu event proxy failed");
        }
    }));
}

fn update_menu(items: &MenuItems, state: &ControllerState) {
    let menu = MenuState::from(state);
    let detail = if menu.detail.is_empty() {
        menu.title
    } else {
        format!("{} — {}", menu.title, menu.detail)
    };
    items.detail.set_text(detail);
    items.start.set_enabled(menu.start_enabled);
    items.stop.set_enabled(menu.stop_enabled);
    items.restart.set_enabled(menu.restart_enabled);
}

fn operation(command: WorkerCommand) -> Option<Operation> {
    match command {
        WorkerCommand::Start => Some(Operation::Start),
        WorkerCommand::Stop => Some(Operation::Stop),
        WorkerCommand::Restart => Some(Operation::Restart),
        WorkerCommand::OpenConfig => None,
    }
}

fn spawn_worker(proxy: EventLoopProxy<UserEvent>, receiver: mpsc::Receiver<WorkerCommand>) {
    thread::spawn(move || {
        eprintln!("kanata-controller: worker started");
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("Tokio runtime creation failed");
        runtime.block_on(async move {
            let mut engine = ControllerEngine::new(MacControl::new());
            loop {
                let command = receiver.recv_timeout(POLL_INTERVAL).ok();
                match command {
                    Some(command) => match operation(command) {
                        Some(operation) => {
                            engine.begin(operation);
                            if engine.execute(operation).await.last_error.is_some() {
                                eprintln!("kanata-controller: {operation} helper call failed");
                            }
                        }
                        None => {
                            if let Err(error) = MacControl::new().open_config().await {
                                eprintln!("kanata-controller: open-config command failed");
                                engine.set_error(error);
                            }
                        }
                    },
                    None => {
                        engine.refresh(true).await;
                    }
                }
                if proxy
                    .send_event(UserEvent::State(engine.state().clone()))
                    .is_err()
                {
                    eprintln!("kanata-controller: worker state proxy failed");
                    break;
                }
            }
        });
    });
}

fn template_icon() -> Icon {
    let (rgba, width, height) = rasterize_tray_icon();
    Icon::from_rgba(rgba, width, height).expect("embedded SVG raster dimensions are valid")
}

fn rasterize_tray_icon() -> (Vec<u8>, u32, u32) {
    let tree = resvg::usvg::Tree::from_data(TRAY_ICON_SVG, &resvg::usvg::Options::default())
        .expect("embedded tray SVG must be valid");
    let mut pixmap = resvg::tiny_skia::Pixmap::new(TRAY_ICON_SIZE, TRAY_ICON_SIZE)
        .expect("static tray icon dimensions must be non-zero");
    let size = tree.size();
    let scale = TRAY_ICON_SIZE as f32 / size.width();
    resvg::render(
        &tree,
        resvg::tiny_skia::Transform::from_scale(scale, scale),
        &mut pixmap.as_mut(),
    );
    (pixmap.data().to_vec(), TRAY_ICON_SIZE, TRAY_ICON_SIZE)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn embedded_svg_raster_has_expected_dimensions_and_visible_pixels() {
        let (rgba, width, height) = rasterize_tray_icon();

        assert_eq!((width, height), (TRAY_ICON_SIZE, TRAY_ICON_SIZE));
        assert_eq!(rgba.len(), (width * height * 4) as usize);
        assert!(rgba.chunks_exact(4).any(|pixel| pixel[3] != 0));
    }
}
