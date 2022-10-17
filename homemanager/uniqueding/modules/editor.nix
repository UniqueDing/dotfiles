{ config, pkgs, ... }:

{
  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url = https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz;
    }))
  ];

  home.packages = with pkgs; [
    neovim-nightly
    gcc
    nodejs
    tabnine
  ];

  home.file = {
    ".config/nvim".source = ../nvim;
  };
}
