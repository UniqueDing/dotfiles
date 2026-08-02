{ config, lib, pkgs, confPath, ... }:

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

  systemd.user.services.glances_server = lib.mkIf pkgs.stdenv.isLinux {
      Unit = {
          Description = "Glance server";
      };
      Install = {
          WantedBy = [ "default.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.glances}/bin/glances -w --disable-webui --disable-plugins all --enable-plugins cpu,gpu,network,sensors,mem,fs";
        Restart = "always";
        RestartSec = "10";
      };
  };

  launchd.agents.glances = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      Label = "dev.uniqueding.glances";
      ProgramArguments = [
        "${pkgs.glances}/bin/glances"
        "-w"
        "--disable-webui"
        "--disable-plugins"
        "all"
        "--enable-plugins"
        "cpu,gpu,network,sensors,mem,fs"
      ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  home.file.".zshrc".source = config.lib.file.mkOutOfStoreSymlink "${confPath}/zshrc";
  xdg.configFile.zsh.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/zsh";
  xdg.configFile.starship.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/starship";
  xdg.configFile.tmux.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/tmux";
}
