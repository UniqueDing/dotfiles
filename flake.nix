{
  description = "My Home Manager Configuration";

  inputs = {
    home-manager.url = "github:nix-community/home-manager";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, home-manager, nixpkgs, ... }@inputs:
    flake-utils.lib.eachDefaultSystemPassThrough (system:
      let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        username = "uniqueding";
        homeDirectory = "/home/uniqueding";
        stateVersion = "25.11";
        confPath = "/home/uniqueding/dotfiles/conf";
      in {
        homeConfigurations.docker = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
              home.stateVersion = stateVersion;

              imports = [
                ./modules/editor.nix
                ./modules/tools.nix
                ./modules/shell.nix
                ./modules/filemanager.nix
                ./modules/lang.nix
              ];
            }
          ];
          extraSpecialArgs = {
            inherit confPath;
          };
        };
        homeConfigurations.app = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
              home.stateVersion = stateVersion;

              imports = [
                ./modules/editor.nix
                ./modules/tools.nix
                ./modules/shell.nix
                ./modules/filemanager.nix
                ./modules/lang.nix
                ./modules/app.nix
              ];
            }
          ];
        };
      }
    );
}
