{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # cargo
    # clang
    # clang-tools
    cmake
    gcc
    gdb
    go
    jdk
    # lua
    # luajit
    # lua5_1
    ninja
    nodejs
    pkg-config
    rustup
    # rustc
    racket
    python313
    python313Packages.pip
    protobuf
    flutter
    chromium
    android-tools
    sdkmanager
  ];
}
