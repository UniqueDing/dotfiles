{ config, pkgs, ...}:

{
  environment.systemPackages = with pkgs; [
    stdenv
    gnumake
    coreutils-full
    gcc
    bash
    wlroots
    binutils
    cmake
    pkg-config
    meson
    wayland
    wayland-scanner
    wayland-protocols
    wayland-utils
    wlr-protocols
    egl-wayland
    xwayland
    vulkan-tools
    vulkan-loader
    vulkan-headers
    pixman
    libseat
    libxkbcommon
    libinput
    llvm
    libdrm
    libglvnd
    libffi
    libffiBoot
    ninja
    mesa
    weston
  ];

}
