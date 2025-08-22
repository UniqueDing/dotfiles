{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    wlroots
    libjson
    json_c
    pcre2
    pango
    cairo
    cmake
    pkg-config
    meson
    wayland
    wayland-scanner
    wayland-protocols
    egl-wayland
    wayland-utils
    libinput
    libxkbcommon
    pixman
    seatd
    xorg.libxcb
    xwayland
  ];
}
