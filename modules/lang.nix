{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    cargo
    clang
    clang-tools
    cmake
    gcc
    gdb
    go
    jdk
    lua
    luajit
    lua5_1
    ninja
    nodejs
    pkg-config
    rustup
    rustc
    racket
    nodePackages.npm
    python3Full
    python39Packages.pip
    pythonFull
  ];
}
