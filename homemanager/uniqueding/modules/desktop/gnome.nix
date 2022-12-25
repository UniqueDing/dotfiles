{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    #adwaita-icon-theme
    baobab
    #caribou
    #dconf-editor
    empathy
    epiphany
    evince
    evolution-data-server
    #gdm
    #gnome.gnome3-backgrounds
    #gnome.gnome-bluetooth
    #gnome.gnome-bluetooth_1_0
    gnome.gnome-color-manager
    gnome.gnome-contacts
    gnome.gnome-control-center
    gnome.gnome-calculator
    gnome.gnome-common
    gnome.gnome-dictionary
    gnome.gnome-disk-utility
    gnome.gnome-font-viewer
    gnome.gnome-keyring
    libgnome-keyring
    gnome.gnome-initial-setup
    gnome.gnome-online-miners
    gnome.gnome-remote-desktop
    gnome.gnome-session
    gnome.gnome-session-ctl
    gnome.gnome-shell
    gnome.gnome-shell-extensions
    gnome.gnome-screenshot
    gnome.gnome-settings-daemon
    # Using 3.38 to match Mutter used in Pantheon
    #gnome.gnome-settings-daemon338
    gnome.gnome-software
    gnome.gnome-system-monitor
    gnome.gnome-terminal
    gnome.gnome-themes-extra
    gnome.gnome-user-share
    gnome.gucharmap
    gnome.gvfs
    gnome.eog
    gnome.mutter
  ];
}
