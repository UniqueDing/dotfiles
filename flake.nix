{
  description = "My Home Manager Configuration";

  inputs = {
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs @ { flake-utils, home-manager, nix-darwin, nixpkgs, ... }:
    flake-utils.lib.eachDefaultSystemPassThrough (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        username = "uniqueding";
        homeDirectory = "/home/uniqueding";
        stateVersion = "26.05";
        localConfig =
          if builtins.pathExists ./local.nix then import ./local.nix else { };
        dotfilesPath = localConfig.dotfilesPath or "${homeDirectory}/dotfiles";
        confPath = "${dotfilesPath}/conf";
      in {
        homeConfigurations.light = home-manager.lib.homeManagerConfiguration {
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
    ) // {
      darwinConfigurations.uniqueding-mbp = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit inputs; };
        modules = [
          home-manager.darwinModules.home-manager
          ({ lib, ... }:
            let
              localConfig =
                if builtins.pathExists ./local.nix then import ./local.nix else { };
              configuredDotfilesPath = localConfig.dotfilesPath or "/Users/uniqueding/dotfiles";
              dotfilesPath =
                if lib.hasPrefix "/Users/" configuredDotfilesPath
                then configuredDotfilesPath
                else "/Users/uniqueding/dotfiles";
              confPath = "${dotfilesPath}/conf";
            in
            {
              system.primaryUser = "uniqueding";
              system.stateVersion = 6;
              users.users.uniqueding.home = "/Users/uniqueding";

              # Zim owns completion initialization from the user configuration.
              programs.zsh.enableGlobalCompInit = false;

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit confPath; };
              home-manager.users.uniqueding = {
                home.username = "uniqueding";
                home.homeDirectory = "/Users/uniqueding";
                home.stateVersion = "26.05";

                imports = [
                  ./modules/editor.nix
                  ./modules/tools.nix
                  ./modules/shell.nix
                  ./modules/filemanager.nix
                  ./modules/lang.nix
                ];
              };
            })
        ];
      };
    };
}
