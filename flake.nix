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
        ./modules/lib.nix
        ./modules/lang.nix
        ./modules/font.nix
        ./modules/sway.nix
        ./modules/tools.nix
        ./modules/app.nix
        ./modules/ime.nix
        ./modules/interception.nix
        ./modules/vm.nix
        ./modules/gapp.nix

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
