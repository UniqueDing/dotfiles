{ config, pkgs, ... }:

{
  home.username = "uniqueding";
  home.homeDirectory = "/home/uniqueding";

  home.stateVersion = "22.05";
  programs.home-manager.enable = true;

  imports = [
    ./modules/editor.nix
    ./modules/tools.nix
    ./modules/app.nix
    ./modules/ime.nix
    ./modules/font.nix
    ./modules/gapp.nix
    # ./modules/sway.nix
    ./modules/hyprland.nix
    ./modules/lang.nix
  ];
}
