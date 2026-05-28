{ config, pkgs, confPath, ... }:

{
  home.packages = with pkgs; [
    yazi
    bat
    # ranger
    # lf
    # joshuto
    fzf
    file
    jq
    poppler
    fd
    ripgrep
    zoxide
    lsd
    eza
    ouch
    trash-cli
    chafa
    ueberzugpp
  ];

  xdg.configFile.yazi.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/yazi";
}
