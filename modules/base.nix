{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    cron
    vim
    networkmanager
    blueman
    wget
    file
    zip
    unzip
    nettools
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
}
