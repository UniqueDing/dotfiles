{ config, pkgs, ... }:

{
  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures = {
      base = true;
      gtk = true;
    };
    xwayland = true;
    extraSessionCommands = ''
      export XDG_SESSION_TYPE=wayland
      export XDG_CURRENT_DESKTOP=sway
      export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
      export QT_AUTO_SCREEN_SCALE_FACTOR=0
      export QT_SCALE_FACTOR=1
      export GDK_SCALE=1
      export GDK_DPI_SCALE=1
      export MOZ_ENABLE_WAYLAND=1
      export _JAVA_AWT_WM_NONREPARENTING=1
    '';
  };

  home.packages = with pkgs; [
    #(pkgs.callPackage ./nwg-dock.nix { })
      swaylock-effects
      swayidle
      wl-clipboard
      mako # notification daemon
      waybar
      wlsunset
      imagemagick
      grim
      brightnessctl
      # playctl
      pulseaudio
      swaybg
      slurp
      wlogout
      wofi
      wob
      wtype
      wmctrl
      squeekboard
      networkmanagerapplet
      openvpn
      networkmanager-openvpn
      pavucontrol
      materia-theme
      material-icons
      material-design-icons
      qogir-theme
      qogir-icon-theme
      gnome3.adwaita-icon-theme
      glib # gsettings
  ];

  home.file = {
    ".config/sway".source = ../sway;
    ".config/waybar".source = ../waybar;
    ".config/.wlogout".source = ../wlogout;
    ".local/share/.squeekboard".source = ../squeekboard;
    ".config/mako".source = ../mako;
  };
}
