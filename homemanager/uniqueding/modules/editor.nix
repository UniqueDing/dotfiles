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
    lua
    nodejs
    chromium
    translate-shell
  ];

  # home.activation.linkDotfiles = config.lib.dag.entryAfter ["writeBoundary"]
  # ''
  #   ln -sfn /opt/dotfiles/homemanager/uniqueding/nvim $HOME/.config/nvim
  # '';
}
