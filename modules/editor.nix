{ config, pkgs, confPath, ... }:

{
  #nixpkgs.overlays = [
  #  (import (builtins.fetchTarball {
  #    url = https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz;
  #  }))
  #];

  home.packages = with pkgs; [
 #   neovim-nightly
    neovim
    tree-sitter
    rustup
    go
    gcc
    lua
    nodejs
    bun
    # chromium
    translate-shell
    opencode
    codegraph
    skills
  ];

  systemd.user.services.opencode-web = {
    Unit = {
      Description = "OpenCode Web";
      Documentation = "https://opencode.ai/";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.opencode}/bin/opencode web --hostname 0.0.0.0 --port 4096";
      Restart = "on-failure";
      RestartSec = "5";
      Environment = [
        "PATH=${pkgs.opencode}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin"
      ];
    };
  };

  xdg.configFile.nvim.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/nvim";
}
