{ config, pkgs, ... }:

{
  virtualisation.vmware.guest.enable = true;
  virtualisation.virtualbox.guest.enable = true;
}
