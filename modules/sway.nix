{ config, pkgs, ... }:

{
  programs.sway.enable = true;
 # programs.sway = {
 #   enable = true;
 #   wrapperFeatures.gtk = true; # so that gtk works properly
 #   extraPackages = with pkgs; [
 #     swaylock
 #     swayidle
 #     wl-clipboard
 #     mako # notification daemon
 #     glib
 #     waybar
 #     wlsunset
 #     imagemagick
 #     grim
 #     brightnessctl
 #     # playctl
 #     swaybg
 #     slurp
 #     wlogout
 #     wofi
 #     wob
 #     wtype
 #     wmctrl
 #     networkmanagerapplet
 #     blueman
 #     pavucontrol
 #     materia-theme
 #     material-icons
 #     material-design-icons
 #     qogir-theme
 #     qogir-icon-theme
 #   ];
 # };
 #
 # services.blueman.enable=true;
}
