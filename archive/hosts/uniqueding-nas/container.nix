{ config, pkgs, ... }:

{
  systemd.services.podman-nginx = {
    enable = true;
    description = "start nginx";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start nginx";
      ExecStop = "${pkgs.podman}/bin/podman stop nginx";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-adguard = {
    enable = true;
    description = "start adguard";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start adguard";
      ExecStop = "${pkgs.podman}/bin/podman stop adguard";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-blog = {
    enable = true;
    description = "start blog";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start blog";
      ExecStop = "${pkgs.podman}/bin/podman stop blog";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-filebrowser = {
    enable = true;
    description = "start filebrowser";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start filebrowser";
      ExecStop = "${pkgs.podman}/bin/podman stop filebrowser";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-photoview = {
    enable = true;
    description = "start photoview";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start photoview & ${pkgs.podman}/bin/podman start photoview-db";
      ExecStop = "${pkgs.podman}/bin/podman stop photoview & ${pkgs.podman}/bin/podman stop photoview-db";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-jellyfin = {
    enable = true;
    description = "start jellyfin";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start jellyfin";
      ExecStop = "${pkgs.podman}/bin/podman stop jellyfin";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-talebook = {
    enable = true;
    description = "start talebook";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start talebook";
      ExecStop = "${pkgs.podman}/bin/podman stop talebook";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-navidrome = {
    enable = true;
    description = "start navidrome";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start navidrome";
      ExecStop = "${pkgs.podman}/bin/podman stop navidrome";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-gitea = {
    enable = true;
    description = "start gitea";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start gitea";
      ExecStop = "${pkgs.podman}/bin/podman stop gitea";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-ariang = {
    enable = true;
    description = "start ariang";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start ariang";
      ExecStop = "${pkgs.podman}/bin/podman stop ariang";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-awtrix = {
    enable = true;
    description = "start awtrix";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start awtrix";
      ExecStop = "${pkgs.podman}/bin/podman stop awtrix";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-awtrix-server = {
    enable = true;
    description = "start awtrix-server";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start awtrix-server";
      ExecStop = "${pkgs.podman}/bin/podman stop awtrix-server";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-bitwarden = {
    enable = true;
    description = "start bitwarden";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start bitwarden";
      ExecStop = "${pkgs.podman}/bin/podman stop bitwarden";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-mailpile = {
    enable = true;
    description = "start mailpile";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start mailpile";
      ExecStop = "${pkgs.podman}/bin/podman stop mailpile";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-syncthing = {
    enable = true;
    description = "start syncthing";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start syncthing";
      ExecStop = "${pkgs.podman}/bin/podman stop syncthing";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.podman-v2raya = {
    enable = true;
    description = "start v2raya";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.podman}/bin/podman start v2raya";
      ExecStop = "${pkgs.podman}/bin/podman stop v2raya";
      Restart = "on-failure";
      Type = "forking";
    };
    wantedBy = [ "multi-user.target" ];
  };
}

