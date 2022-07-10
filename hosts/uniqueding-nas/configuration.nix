# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  #networking.interfaces.enp1s0.useDHCP = true;
  networking = {
      interfaces.enp1s0 = {
        ipv4.address = "192.168.1.5";
        prefixLength = 24;
      }
      interfaces.enp4s0 = {
        ipv4.address = "192.168.2.1";
        prefixLength = 24;
        ipv6.address = "fd00::1";
        useDHCP = true;
      }
  }

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

}

