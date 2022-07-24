{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    n2n
  ];

  systemd.services.edge = {
    enable = true;
    description = "start edge";
    unitConfig = {
      Type = "simple";
    };
    serviceConfig = {
      ExecStart = "${pkgs.n2n}/bin/edge /etc/n2n/edge.conf -f";
      Restart = "on-abnormal";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
