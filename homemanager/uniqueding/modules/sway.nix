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
      networkmanager
      networkmanagerapplet
      blueman
      pavucontrol
      materia-theme
      material-icons
      material-design-icons
      qogir-theme
      qogir-icon-theme
  ];
  services.blueman.enable=true;
}
