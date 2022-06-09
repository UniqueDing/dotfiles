#!/usr/bin/env bash

set -xe

NIXADDR=172.16.55.128
NIXPORT=22
NIXBLOCKDEVICE=sda
NIXUSER=uniqueding
NIXHOST=uniqueding-vm

_init()
{
	ssh -p$NIXPORT root@$NIXADDR << EOF
		parted /dev/$NIXBLOCKDEVICE -- mklabel gpt
		parted /dev/$NIXBLOCKDEVICE -- mkpart primary 512MiB -8GiB
		parted /dev/$NIXBLOCKDEVICE -- mkpart primary linux-swap -8GiB 100\%
		parted /dev/$NIXBLOCKDEVICE -- mkpart ESP fat32 1MiB 512MiB
		parted /dev/$NIXBLOCKDEVICE -- set 3 esp on
		mkfs.ext4 -L nixos /dev/${NIXBLOCKDEVICE}1
		mkswap -L swap /dev/${NIXBLOCKDEVICE}2
		mkfs.fat -F 32 -n boot /dev/${NIXBLOCKDEVICE}3
		mount /dev/disk/by-label/nixos /mnt
		mkdir -p /mnt/boot
        mkdir -p /mnt/opt
		mount /dev/disk/by-label/boot /mnt/boot
		nixos-generate-config --root /mnt
		sed --in-place '/system\.stateVersion = .*/a \
  nix.package = pkgs.nixUnstable;\n \
  nix.extraOptions = \"experimental-features = nix-command flakes\";\n \
  services.openssh.enable = true;\n \
  services.openssh.passwordAuthentication = true;\n \
  services.openssh.permitRootLogin = \"yes\";\n \
  users.users.root.initialPassword = \"root\";\n \
' /mnt/etc/nixos/configuration.nix
		nixos-install --no-root-passwd
		reboot
EOF
}

_start()
{
	NIXUSER=root
	echo $NIXUSER
	_cp
	_switch
}

_cp()
{
	ssh -p$NIXPORT $NIXUSER@$NIXADDR << EOF
        sudo mkdir -p /opt/dotfiles
EOF
	scp -r -P$NIXPORT * $NIXUSER@$NIXADDR:/opt/dotfiles
	ssh -p$NIXPORT $NIXUSER@$NIXADDR << EOF
        sudo mkdir -p /opt/dotfiles/hosts/$NIXHOST
        sudo cp /etc/nixos/hardware-configuration.nix /opt/dotfiles/hosts/$NIXHOST/
EOF
}

_switch()
{
	ssh -p$NIXPORT $NIXUSER@$NIXADDR << EOF
		sudo NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild switch --flake "/opt/dotfiles#$NIXHOST"
        sudo chown -R uniqueding:users /opt/dotfiles
EOF
}

if [[ $1 == "init" ]];then
	$(_init)
elif [[ $1 == "start" ]];then
	$(_start)
elif [[ $1 == "cp" ]];then
	$(_cp)
elif [[ $1 == "switch" ]];then
	$(_switch)
fi
