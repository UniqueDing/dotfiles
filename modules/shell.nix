{ config, pkgs, lib, confPath, ... }:

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

  home.activation.shellLink = lib.mkAfter ''
    ln -sfn ${confPath}/zshrc   $HOME/.zshrc
    ln -sfn ${confPath}/zsh      $HOME/.config/zsh
    ln -sfn ${confPath}/starship $HOME/.config/starship
    ln -sfn ${confPath}/tmux     $HOME/.config/tmux
  '';
}
