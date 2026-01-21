{ config, pkgs, lib, confPath, ... }:

{
  #nixpkgs.overlays = [
  #  (import (builtins.fetchTarball {
  #    url = https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz;
  #  }))
  #];

  home.packages = with pkgs; [
 #   neovim-nightly
    neovim
    tree-sitter
    rustup
    go
    gcc
    lua
    nodejs
    # chromium
    translate-shell
    opencode
  ];

  home.activation.editorLink = lib.mkAfter ''
    ln -sfn ${confPath}/nvim $HOME/.config/nvim
  '';
}
