{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    cron
    vim
    networkmanager
    blueman
    wget
    man
    curl
  ];

  networking.networkmanager = {
    enable = true;
    plugins  = with pkgs; [
      networkmanager-openvpn
    ];
  };

  services.blueman.enable = true;

  services.logind.lidSwitch = "ignore";
  services.logind.extraConfig = ''
    HandlePowerKey=suspend
    HandleRebootKey=suspend
    HandleSuspendKey=suspend
    HandleHibernateKey=suspend
  '';

  sound.mediaKeys.enable = true;
}
