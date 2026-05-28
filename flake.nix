{
  description = "My Home Manager Configuration";

  inputs = {
    home-manager.url = "github:nix-community/home-manager";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { flake-utils, home-manager, nixpkgs, ... }:
    flake-utils.lib.eachDefaultSystemPassThrough (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        username = "uniqueding";
        homeDirectory = "/home/uniqueding";
        stateVersion = "25.11";
        localConfig =
          if builtins.pathExists ./local.nix then import ./local.nix else { };
        dotfilesPath = localConfig.dotfilesPath or "${homeDirectory}/dotfiles";
        confPath = "${dotfilesPath}/conf";
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
          extraSpecialArgs = {
            inherit confPath;
          };
        };
      }
    );
}
