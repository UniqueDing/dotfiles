{ config, pkgs, ... }:

{
    services.samba-wsdd.enable = true; # make shares visible for windows 10 clients
    # networking.firewall.allowedTCPPorts = [
    #   5357 # wsdd
    # ];
    # networking.firewall.allowedUDPPorts = [
    #   3702 # wsdd
    # ];
    services.samba = {
      enable = true;
      securityType = "user";
      extraConfig = ''
        workgroup = nas
        server string = nas
        netbios name = nas
        security = user
        use sendfile = yes
        max protocol = smb2
        # note: localhost is the ipv6 localhost ::1
        hosts allow = 192.168.31. 192.168.100. 127.0.0.1 localhost
        hosts deny = 0.0.0.0/0
        guest account = nobody
        map to guest = bad user
      '';
      shares = {
        main = {
          path = "/srv/diska/main";
          browseable = "yes";
          writable = "yes";
          "valid user" = "uniqueding";
          "read only" = "no";
          "guest ok" = "no";
          "create mask" = "0644";
          "directory mask" = "0755";
        };
      };
    };
}

