{ config, lib, pkgs, confPath, ... }:

{
  home.packages = with pkgs; [
    # psmisc # Linux-only utility.
    atool
    bc
    bitwarden-cli
    gh
    dos2unix
    tree
    vivid
    bat
    diff-so-fancy
    delta
    httpie
    htop
    glances
    syncthing
    git
    lazygit
    lazydocker
    lazysql
    # lsb-release # Linux Standard Base metadata.
    zoxide
    tealdeer
    fzf
    gdu
    duf
    neo-cowsay
    lolcat
    fastfetch
    asciiquarium
    cmatrix
    jq
    pciutils
    bottom
    less
    # diskonaut
    gping
    # termscp
    gitui
    todo-txt-cli
    proxychains-ng
    zip
    unzip
    nettools
    # try # Linux-only utility.
    pay-respects
    curl
    wget
    # traceroute # Provided by the host system where available.
    netcat
  ];

  systemd.user.services.syncthing = lib.mkIf pkgs.stdenv.isLinux {
      Unit = {
          Description = "Syncthing - Open Source Continuous File Synchronization";
      };
      Install = {
          WantedBy = [ "default.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.syncthing}/bin/syncthing";
        Restart = "always";
        RestartSec = "10";
      };
  };

  launchd.agents.syncthing = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      Label = "syncthing";
      ProgramArguments = [ "${pkgs.syncthing}/bin/syncthing" ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  home.file.".gitconfig".source = config.lib.file.mkOutOfStoreSymlink "${confPath}/gitconfig";
  xdg.configFile.lazygit.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/lazygit";
  xdg.configFile.bat.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/bat";
  xdg.configFile.tealdeer.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/tealdeer";
  xdg.configFile.eza.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/eza";
}
