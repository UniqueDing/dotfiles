{ config, pkgs, ... }:

{
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true; # so that gtk works properly
    extraPackages = with pkgs; [
      swaylock
      swayidle
      wl-clipboard
      mako # notification daemon
      waybar
      wlsunset
      convertall
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
  };

  networking.networkmanager = {
    enable = true;
    plugins  = with pkgs; [
      networkmanager-openvpn
    ];
  };
  services.blueman.enable=true;
}
