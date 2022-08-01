{
  description = "UniqueDing's nixos dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = github:NixOS/nixos-hardware/master;

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/NUR";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixos-hardware,
    home-manager,
    nur,
    neovim-nightly-overlay,
    ...
  }: {

    nixosConfigurations.uniqueding-vm = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      system = "x86_64-linux";
      modules = [
        {
          nixpkgs.overlays = [
            nur.overlay
            neovim-nightly-overlay.overlay
          ];
          networking.hostName = "uniqueding-vm";
        }

        ./hosts/uniqueding-vm/hardware-configuration.nix

        ./modules/configuration.nix
        ./modules/base.nix
        ./modules/lib.nix
        ./modules/lang.nix
        ./modules/interception.nix
        ./modules/sway.nix
        ./modules/vm.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.uniqueding = import ./homemanager/uniqueding/home-sway-light.nix;
        }
      ];
    };
    nixosConfigurations.uniqueding-pad = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      system = "x86_64-linux";
      modules = [
        {
          nixpkgs.overlays = [
            nur.overlay
            neovim-nightly-overlay.overlay
          ];
          networking.hostName = "uniqueding-pad";
        }

        ./hosts/uniqueding-pad/hardware-configuration.nix
        ./hosts/uniqueding-pad/surface/default.nix
        ./hosts/uniqueding-pad/wrmsr.nix

        ./modules/configuration.nix
        ./modules/base.nix
        ./modules/lib.nix
        ./modules/lang.nix
        ./modules/interception.nix
        ./modules/n2n.nix
        ./modules/virtualbox.nix
        ./modules/sway.nix
        ./modules/waydroid.nix
        ./modules/build-wlroots.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.uniqueding = import ./homemanager/uniqueding/home-sway.nix;
        }
      ];
    };
    nixosConfigurations.uniqueding-nas = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      system = "x86_64-linux";
      modules = [
        {
          networking.hostName = "uniqueding-nas";
        }

        ./hosts/uniqueding-nas/hardware-configuration.nix
        ./hosts/uniqueding-nas/network.nix
        ./hosts/uniqueding-nas/mount-bind.nix
        ./hosts/uniqueding-nas/samba.nix
        ./hosts/uniqueding-nas/container.nix

        ./modules/configuration.nix
        ./modules/base.nix
        ./modules/lib.nix
        ./modules/nas.nix
        ./modules/podman.nix
        ./modules/n2n.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.uniqueding = import ./homemanager/uniqueding/home.nix;
        }
      ];
    };
  };
}
