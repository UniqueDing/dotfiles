# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/0527bbf4-d633-41d0-8199-bcf418765c6e";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/F3CC-F7AC";
      fsType = "vfat";
    };

  fileSystems."/srv/diska" =
    { device = "/dev/disk/by-uuid/f6cf9993-786e-46c8-8ba6-3c6debbd27ff";
      fsType = "ext4";
    };

  fileSystems."/srv/diskb" =
    { device = "/dev/disk/by-uuid/8388db88-6089-4bad-9fad-229c81f4e371";
      fsType = "ext4";
    };

  fileSystems."/srv/diskc" =
    { device = "/dev/disk/by-uuid/1d80f4f1-252b-4f0b-92fb-abe11239bb21";
      fsType = "ext4";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/cc7f6dca-4e6b-48ae-b2d3-a00bd644e955"; }
    ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp4s0.useDHCP = lib.mkDefault true;

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # high-resolution display
  hardware.video.hidpi.enable = lib.mkDefault true;
}
