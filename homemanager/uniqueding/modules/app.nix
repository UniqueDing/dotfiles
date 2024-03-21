{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    firefox
    chromium
    syncthing
    imv
    emacs
    alacritty
    v2raya
    wezterm
  ];

  systemd.user.services.syncthing = {
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
}
