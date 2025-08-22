{ config, pkgs, ... }:

{
  virtualisation.vmware.guest.enable = true;
  virtualisation.virtualbox.guest.enable = true;
  environment.sessionVariables = rec {
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
