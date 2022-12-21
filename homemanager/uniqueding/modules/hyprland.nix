{ config, pkgs, inputs, ... }: let
  flake-compat = builtins.fetchTarball "https://github.com/edolstra/flake-compat/archive/master.tar.gz";
  hyprland = (import flake-compat {
    src = builtins.fetchTarball "https://github.com/hyprwm/Hyprland/archive/master.tar.gz";
  }).defaultNix;
in {
  imports = [
    hyprland.homeManagerModules.default
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = ''
        source = ~/.config/hypr/hyprland-core.conf
    '';
  };

  programs.zsh.enable = true;
  programs.zsh.envExtra = ''
    export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
    export QT_AUTO_SCREEN_SCALE_FACTOR="0"
    export QT_SCALE_FACTOR="2"
    export GDK_SCALE="2"
    export GDK_DPI_SCALE="2"
    export GIO_EXTRA_MODULES="${pkgs.dconf.lib}/lib/gio/modules"
  '';
  # home.sessionVariables = {
  #   XDG_SESSION_TYPE = "wayland";
  #   XDG_CURRENT_DESKTOP = "Hyprland";
  #   QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
  #   QT_AUTO_SCREEN_SCALE_FACTOR = "0";
  #   QT_SCALE_FACTOR = "1";
  #   GDK_SCALE = "1";
  #   GDK_DPI_SCALE = "1";
  #   MOZ_ENABLE_WAYLAND = "1";
  #   _JAVA_AWT_WM_NONREPARENTING = "1";
  #   UNIQUEDING = "1";
  #   GIO_EXTRA_MODULES = "${pkgs.dconf.lib}/lib/gio/modules";
  #   GIO_EXTRA_MODULES_A = "1";
  # };

  home.packages = with pkgs; [
    hyprpaper
    fuzzel
    eww-wayland
    socat
    dconf
    lua
    swaylock-effects
    swayidle
    wl-clipboard
    mako # notification daemon
    waybar
    wlsunset
    imagemagick
    grim
    brightnessctl
    pulseaudio
    swaybg
    slurp
    wlogout
    wofi
    wob
    wtype
    wmctrl
    squeekboard
    pavucontrol
    materia-theme
    material-icons
    material-design-icons
    qogir-theme
    qogir-icon-theme
    gnome.adwaita-icon-theme
    glib # gsettings
    kanshi
  ];

  # home.activation.linkDotfiles = config.lib.dag.entryAfter ["writeBoundary"]
  # ''
  #  ln -sfn /opt/dotfiles/homemanager/uniqueding/hypr $HOME/.config/hypr
  #  ln -sfn /opt/dotfiles/homemanager/uniqueding/eww $HOME/.config/eww
  # '';
  home.file = {
    ".config/mako".source = ../mako;
  };
}
