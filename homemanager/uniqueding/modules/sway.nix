{ config, pkgs, ... }:

{
  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures = { gtk = true; };
  };

  home.packages = with pkgs; [
      swaylock
      swayidle
      wl-clipboard
      mako # notification daemon
      waybar
      wlsunset
      imagemagick
      grim
      brightnessctl
      # playctl
      swaybg
      slurp
      wlogout
      wofi
      wob
      wtype
      wmctrl
      networkmanagerapplet
      pavucontrol
      materia-theme
      material-icons
      material-design-icons
      qogir-theme
      qogir-icon-theme
  ];

  home.file = {
    ".config/sway".source = ../sway;
    ".config/waybar".source = ../waybar;
    ".config/.wlogout".source = ../wlogout;
    ".local/share/.squeekboard".source = ../squeekboard;
    ".config/mako".source = ../mako;
  };
}
