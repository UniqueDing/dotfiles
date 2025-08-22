{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    zoxide
    tealdeer
    fzf
    jq
    starship
    tmux
    try
    zsh
    nushell
    fish
    glances
  ];

  systemd.user.services.glances_server = {
    Unit = {
        Description = "Glance server";
    };
    Install = {
        WantedBy = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.glances}/bin/glances -w --disable-webui --disable-plugins all --enable-plugins cpu,gpu,network,sensors,mem,network,fs";
      Restart = "always";
      RestartSec = "10";
    };
  };

  home.file.".config/zsh" = { source = ../conf/zsh; };
  home.file.".zshrc" = { source = ../conf/zshrc; };
  home.file.".config/starship" = { source = ../conf/starship; };
  home.file.".config/tmux" = { source = ../conf/tmux; };
}
