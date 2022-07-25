{ config, pkgs, ... }:

{
  home.username = "uniqueding";
  home.homeDirectory = "/home/uniqueding";

  home.stateVersion = "22.05";
  #programs.home-manager.enable = true;

  home.file.".config/fcitx5".source = ./fcitx5;
  home.file.".config/foot".source = ./foot;

  imports = [
    ./modules/editor.nix
    ./modules/tools.nix
    ./modules/app.nix
    ./modules/ime.nix
    ./modules/font.nix
    ./modules/gapp.nix
    ./modules/sway.nix
  ];
}
