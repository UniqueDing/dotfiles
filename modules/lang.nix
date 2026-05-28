{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # cargo
    # clang
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
    uv
    python313
    python313Packages.pip
    protobuf
    flutter
    # chromium
    android-tools
    sdkmanager
    godot
    dotnet-sdk

    ## lsp
    nixd
    clang-tools
    cmake-language-server
    # rust-analyzer
    gopls
    python3Packages.python-lsp-server
    vtsls
    vue-language-server
    jdt-language-server
    typescript-language-server
    yaml-language-server
    taplo
    lemminx
    sqls
    postgres-language-server
    buf
    bash-language-server
    docker-language-server
    systemd-language-server
    marksman
    lua-language-server
  ];
}
