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
      blueman
      pavucontrol
      materia-theme
      material-icons
      material-design-icons
      qogir-theme
      qogir-icon-theme
    ];
  };

  services.blueman.enable=true;

  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
}
