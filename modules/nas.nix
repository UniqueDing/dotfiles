{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    mdadm
  ];
}
