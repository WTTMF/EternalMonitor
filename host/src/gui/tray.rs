//! Windows tray lifetime and actions. Callbacks wake eframe even while its window is hidden.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use eframe::egui::{self, ViewportCommand};
use tray_icon::menu::{Menu, MenuEvent, MenuItem};
use tray_icon::{MouseButton, TrayIcon, TrayIconBuilder, TrayIconEvent};

pub(super) struct SystemTray {
    _icon: TrayIcon,
    exiting: Arc<AtomicBool>,
}

impl SystemTray {
    pub(super) fn new(ctx: &egui::Context) -> Result<Self, Box<dyn std::error::Error>> {
        let menu = Menu::new();
        let open = MenuItem::with_id("open", "打开主界面", true, None);
        let quit = MenuItem::with_id("quit", "退出 EternalMonitor", true, None);
        menu.append_items(&[&open, &quit])?;
        let image = eframe::icon_data::from_png_bytes(include_bytes!("../../assets/icon_256.png"))?;
        let icon = TrayIconBuilder::new()
            .with_tooltip("EternalMonitor · 双击打开，右键退出")
            .with_menu(Box::new(menu))
            .with_menu_on_left_click(false)
            .with_icon(tray_icon::Icon::from_rgba(
                image.rgba,
                image.width,
                image.height,
            )?)
            .build()?;

        let exiting = Arc::new(AtomicBool::new(false));
        let open_id = open.id().clone();
        let quit_id = quit.id().clone();
        let menu_ctx = ctx.clone();
        let menu_exiting = exiting.clone();
        MenuEvent::set_event_handler(Some(move |event: MenuEvent| {
            if event.id == open_id {
                open_window(&menu_ctx);
            } else if event.id == quit_id {
                request_exit(&menu_ctx, &menu_exiting);
            }
        }));
        let tray_ctx = ctx.clone();
        TrayIconEvent::set_event_handler(Some(move |event| {
            if matches!(
                event,
                TrayIconEvent::DoubleClick {
                    button: MouseButton::Left,
                    ..
                }
            ) {
                open_window(&tray_ctx);
            }
        }));
        tracing::info!("System tray initialized");
        Ok(Self {
            _icon: icon,
            exiting,
        })
    }

    pub(super) fn handle_close(&self, ctx: &egui::Context) {
        close_to_tray(ctx, &self.exiting);
    }
}

pub(super) fn open_window(ctx: &egui::Context) {
    ctx.send_viewport_cmd(ViewportCommand::Visible(true));
    ctx.send_viewport_cmd(ViewportCommand::Minimized(false));
    ctx.send_viewport_cmd(ViewportCommand::Focus);
    ctx.request_repaint();
}

fn request_exit(ctx: &egui::Context, exiting: &AtomicBool) {
    exiting.store(true, Ordering::SeqCst);
    ctx.send_viewport_cmd(ViewportCommand::Close);
    ctx.request_repaint();
}

fn close_to_tray(ctx: &egui::Context, exiting: &AtomicBool) {
    if ctx.input(|input| input.viewport().close_requested()) && !exiting.load(Ordering::SeqCst) {
        ctx.send_viewport_cmd(ViewportCommand::CancelClose);
        // Minimized also tells eframe to skip GPU rendering while hidden.
        ctx.send_viewport_cmd(ViewportCommand::Minimized(true));
        ctx.send_viewport_cmd(ViewportCommand::Visible(false));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn hidden_input(close: bool) -> egui::RawInput {
        let mut input = egui::RawInput::default();
        let viewport = input.viewports.get_mut(&egui::ViewportId::ROOT).unwrap();
        viewport.minimized = Some(true);
        if close {
            viewport.events.push(egui::ViewportEvent::Close);
        }
        input
    }

    #[test]
    fn closing_window_hides_to_tray_without_exiting() {
        let ctx = egui::Context::default();
        let exiting = AtomicBool::new(false);
        let output = ctx.run_logic(&hidden_input(true), |ctx| close_to_tray(ctx, &exiting));
        let commands = &output.viewport_commands[&egui::ViewportId::ROOT];
        assert!(commands.contains(&ViewportCommand::CancelClose));
        assert!(commands.contains(&ViewportCommand::Visible(false)));
        assert!(commands.contains(&ViewportCommand::Minimized(true)));
        assert!(!commands.contains(&ViewportCommand::Close));
    }

    #[test]
    fn tray_open_restores_window_without_a_ui_frame() {
        let ctx = egui::Context::default();
        open_window(&ctx);
        let output = ctx.run_logic(&hidden_input(false), |_| {});
        let commands = &output.viewport_commands[&egui::ViewportId::ROOT];
        assert!(commands.contains(&ViewportCommand::Visible(true)));
        assert!(commands.contains(&ViewportCommand::Minimized(false)));
        assert!(commands.contains(&ViewportCommand::Focus));
    }

    #[test]
    fn tray_exit_is_not_cancelled_by_close_to_tray() {
        let ctx = egui::Context::default();
        let exiting = AtomicBool::new(false);
        request_exit(&ctx, &exiting);
        let output = ctx.run_logic(&hidden_input(true), |ctx| close_to_tray(ctx, &exiting));
        let commands = &output.viewport_commands[&egui::ViewportId::ROOT];
        assert!(commands.contains(&ViewportCommand::Close));
        assert!(!commands.contains(&ViewportCommand::CancelClose));
        assert!(!commands.contains(&ViewportCommand::Visible(false)));
    }
}
