{ config, pkgs, ... }:

{
  home.username = "uniqueding";
  home.homeDirectory = "/home/uniqueding";

  home.stateVersion = "22.05";
  #programs.home-manager.enable = true;

  imports = [
    ./modules/editor.nix
    ./modules/tools.nix
  ];
}
