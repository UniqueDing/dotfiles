use std::fmt;

use tokio::sync::mpsc::{error::TrySendError, Sender, UnboundedSender};

use crate::{
    model::{ControllerState, Operation, ServiceStatus},
    presentation::MenuState,
};

const ICON_SIZES: &[i32] = &[16, 22, 32, 48, 64];
const RUNNING: [u8; 3] = [0x16, 0xa3, 0x4a];
const TRANSITIONING: [u8; 3] = [0xd9, 0x77, 0x06];
const STOPPED: [u8; 3] = [0x6b, 0x72, 0x80];
const ERROR: [u8; 3] = [0xdc, 0x26, 0x26];
const WHITE: [u8; 3] = [0xff, 0xff, 0xff];

/// Rasterize the vector artwork in `assets/kanata-controller.svg` into the
/// ARGB32 pixmaps required by the StatusNotifierItem protocol. Multiple sizes
/// allow each host to select its own tray scale without icon-theme lookup.
fn icon_pixmaps(state: &ControllerState) -> Vec<ksni::Icon> {
    let background = icon_background(state);
    ICON_SIZES
        .iter()
        .copied()
        .map(|size| render_icon(size, background))
        .collect()
}

fn icon_background(state: &ControllerState) -> [u8; 3] {
    if state.last_error.is_some() {
        return ERROR;
    }

    match state.status {
        ServiceStatus::Running => RUNNING,
        ServiceStatus::Starting | ServiceStatus::Stopping => TRANSITIONING,
        ServiceStatus::Stopped => STOPPED,
        ServiceStatus::Failed | ServiceStatus::Unknown => ERROR,
    }
}

fn render_icon(size: i32, background: [u8; 3]) -> ksni::Icon {
    let mut data = Vec::with_capacity((size * size * 4) as usize);
    for y in 0..size {
        for x in 0..size {
            let mut background_coverage = 0;
            let mut k_coverage = 0;
            for sample_y in 0..4 {
                for sample_x in 0..4 {
                    let x = (x as f32 + (sample_x as f32 + 0.5) / 4.0) * 64.0 / size as f32;
                    let y = (y as f32 + (sample_y as f32 + 0.5) / 4.0) * 64.0 / size as f32;
                    background_coverage += usize::from(in_rounded_rectangle(x, y));
                    k_coverage += usize::from(in_k(x, y));
                }
            }

            let color = blend(background, WHITE, k_coverage, 16);
            let alpha = (background_coverage * 0xff / 16) as u8;
            data.extend_from_slice(&[alpha, color[0], color[1], color[2]]);
        }
    }
    ksni::Icon {
        width: size,
        height: size,
        data,
    }
}

fn in_rounded_rectangle(x: f32, y: f32) -> bool {
    const LEFT: f32 = 2.0;
    const TOP: f32 = 2.0;
    const RIGHT: f32 = 62.0;
    const BOTTOM: f32 = 62.0;
    const RADIUS: f32 = 10.0;

    if !(LEFT <= x && x < RIGHT && TOP <= y && y < BOTTOM) {
        return false;
    }

    let nearest_x = x.clamp(LEFT + RADIUS, RIGHT - RADIUS);
    let nearest_y = y.clamp(TOP + RADIUS, BOTTOM - RADIUS);
    let dx = x - nearest_x;
    let dy = y - nearest_y;
    dx * dx + dy * dy <= RADIUS * RADIUS
}

fn in_k(x: f32, y: f32) -> bool {
    // The points follow the white K path in the SVG artwork, clockwise.
    const K: &[(f32, f32)] = &[
        (18.0, 15.0),
        (26.0, 15.0),
        (26.0, 27.0),
        (38.0, 15.0),
        (50.0, 15.0),
        (34.0, 31.0),
        (50.0, 49.0),
        (38.0, 49.0),
        (26.0, 36.0),
        (26.0, 49.0),
        (18.0, 49.0),
    ];

    let mut inside = false;
    for index in 0..K.len() {
        let (x1, y1) = K[index];
        let (x2, y2) = K[(index + 1) % K.len()];
        if (y1 > y) != (y2 > y) && x < (x2 - x1) * (y - y1) / (y2 - y1) + x1 {
            inside = !inside;
        }
    }
    inside
}

fn blend(background: [u8; 3], foreground: [u8; 3], coverage: usize, samples: usize) -> [u8; 3] {
    std::array::from_fn(|channel| {
        ((background[channel] as usize * (samples - coverage)
            + foreground[channel] as usize * coverage)
            / samples) as u8
    })
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TrayCommand {
    Start,
    Stop,
    Restart,
}

impl fmt::Display for TrayCommand {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::Start => "start",
            Self::Stop => "stop",
            Self::Restart => "restart",
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
                self.state.last_error = Some("Operation queue is busy".into());
                false
            }
            Err(TrySendError::Closed(_)) => {
                self.state.operation_in_flight = None;
                self.state.last_error = Some("Unable to send tray command".into());
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
        String::new()
    }

    fn icon_pixmap(&self) -> Vec<ksni::Icon> {
        icon_pixmaps(&self.state)
    }

    fn tool_tip(&self) -> ksni::ToolTip {
        let menu = MenuState::from(&self.state);
        ksni::ToolTip {
            title: menu.title,
            description: menu.detail,
            icon_name: String::new(),
            icon_pixmap: icon_pixmaps(&self.state),
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
                label: "Start".into(),
                enabled: menu.start_enabled,
                activate: Box::new(|tray: &mut Self| {
                    tray.request_operation(Operation::Start, TrayCommand::Start);
                }),
                ..Default::default()
            }
            .into(),
            ksni::menu::StandardItem {
                label: "Stop".into(),
                enabled: menu.stop_enabled,
                activate: Box::new(|tray: &mut Self| {
                    tray.request_operation(Operation::Stop, TrayCommand::Stop);
                }),
                ..Default::default()
            }
            .into(),
            ksni::menu::StandardItem {
                label: "Restart".into(),
                enabled: menu.restart_enabled,
                activate: Box::new(|tray: &mut Self| {
                    tray.request_operation(Operation::Restart, TrayCommand::Restart);
                }),
                ..Default::default()
            }
            .into(),
            ksni::menu::MenuItem::Separator,
            ksni::menu::StandardItem {
                label: "Quit".into(),
                activate: Box::new(|tray: &mut Self| {
                    let _ = tray.shutdown.send(());
                }),
                ..Default::default()
            }
            .into(),
        ]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn embedded_icons_are_argb_pixmaps_at_all_supported_sizes() {
        let icons = icon_pixmaps(&ControllerState {
            status: ServiceStatus::Running,
            operation_in_flight: None,
            last_error: None,
        });
        assert_eq!(icons.len(), ICON_SIZES.len());
        for icon in icons {
            assert_eq!(icon.data.len(), (icon.width * icon.height * 4) as usize);
            assert!(icon.data.chunks_exact(4).any(|pixel| pixel[0] == 0));
            assert!(icon.data.chunks_exact(4).any(|pixel| pixel[0] == 0xff));
        }
    }

    #[test]
    fn status_maps_to_the_semantic_background_palette() {
        let cases = [
            (ServiceStatus::Running, RUNNING),
            (ServiceStatus::Starting, TRANSITIONING),
            (ServiceStatus::Stopping, TRANSITIONING),
            (ServiceStatus::Stopped, STOPPED),
            (ServiceStatus::Failed, ERROR),
            (ServiceStatus::Unknown, ERROR),
        ];

        for (status, color) in cases {
            let state = ControllerState {
                status,
                operation_in_flight: None,
                last_error: None,
            };
            assert_eq!(icon_background(&state), color, "{status:?}");
        }

        let state = ControllerState {
            status: ServiceStatus::Running,
            operation_in_flight: None,
            last_error: Some("operation failed".into()),
        };
        assert_eq!(icon_background(&state), ERROR);
    }

    #[test]
    fn pixmaps_use_the_state_background_and_centered_white_k() {
        let icon = render_icon(64, RUNNING);
        assert_eq!(&icon.data[0..4], &[0, RUNNING[0], RUNNING[1], RUNNING[2]]);
        let center = ((32 * 64 + 22) * 4) as usize;
        assert_eq!(
            &icon.data[center..center + 4],
            &[0xff, WHITE[0], WHITE[1], WHITE[2]]
        );
        let background = ((8 * 64 + 8) * 4) as usize;
        assert_eq!(
            &icon.data[background..background + 4],
            &[0xff, RUNNING[0], RUNNING[1], RUNNING[2]]
        );

        let error_icon = render_icon(64, ERROR);
        assert_eq!(
            &error_icon.data[background..background + 4],
            &[0xff, ERROR[0], ERROR[1], ERROR[2]]
        );
    }
}
