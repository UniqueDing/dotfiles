{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    msr-tools
  ];

  systemd.services.turnoff-bd-prochot = {
    enable = true;
    description = "turnoff BD PROCHOT";
    unitConfig = {
    };
    serviceConfig = {
      ExecStart = "${pkgs.msr-tools}/bin/wrmsr 0x1FC value";
      Restart = "on-failure";
      Type = "oneshot";
    };
    wantedBy = [ "multi-user.target" ];
  };
}

