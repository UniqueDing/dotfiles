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
      hostName = "uniqueding-nas";
      nameservers = ["8.8.8.8" "114,114,114,114"];
      defaultGateway = "192.168.31.1";
      interfaces = {
        enp1s0 = {
          ipv4.addresses = [{ address = "192.168.31.5";  prefixLength = 24;}];
        };
        enp4s0 = {
          ipv4.addresses = [{ address = "192.168.2.1";  prefixLength = 24;}];
          ipv6.addresses = [{ address = "fd00::1"; prefixLength = 64; }];
        };
      };
      nat.enable = false;
      firewall.enable = false;
      nftables = {
        enable = false;
        ruleset = ''
          table inet filter {
            # enable flow offloading for better throughput
            flowtable f {
              hook ingress priority 0;
              devices = { enp1s0, enp4s0 };
            }

            chain output {
              type filter hook output priority 100; policy accept;
            }

            chain input {
              type filter hook input priority filter; policy accept;

              # Allow trusted networks to access the router
              iifname {
                "enp1s0",
              } counter accept

              iifname {
                "enp4s0",
              } counter accept

              # Allow returning traffic from wan and drop everthing else
              iifname "enp1s0" ct state { established, related } counter accept
              # iifname "ppp0" drop
            }
            chain forward {
              type filter hook forward priority filter; policy accept;

              # enable flow offloading for better throughput
              ip protocol { tcp, udp } flow offload @f

              # Allow trusted network WAN access
              iifname {
                  "enp4s0",
              } oifname {
                  "enp1s0",
              } counter accept comment "Allow trusted LAN to WAN"

              # Allow established WAN to return
              iifname {
                  "enp1s0",
              } oifname {
                  "enp4s0",
              } ct state established,related counter accept comment "Allow established back to LANs"
            }
          }
          table ip nat {
            chain prerouting {
              type nat hook output priority filter; policy accept;
            }

            # Setup NAT masquerading on the ppp0 interface
            chain postrouting {
              type nat hook postrouting priority filter; policy accept;
              oifname "enp1s0" masquerade
            }
          }
      '';
      };
  };

  boot.kernel.sysctl = {
     "net.ipv4.conf.all.forwarding" = 1;
     "net.ipv6.conf.all.forwarding" = 1;
  };

}

