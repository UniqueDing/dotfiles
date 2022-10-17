{ config, pkgs, ... }:

{
  i18n.inputMethod.enabled = "fcitx5";
  i18n.inputMethod.fcitx5.addons = with pkgs; [
    fcitx5-configtool
    fcitx5-chinese-addons
    fcitx5-mozc
    fcitx5-lua
  ];

  home.file.".config/fcitx5".source = ../fcitx5;
}
