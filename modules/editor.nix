{ config, lib, pkgs, confPath, ... }:

{
  #nixpkgs.overlays = [
  #  (import (builtins.fetchTarball {
  #    url = https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz;
  #  }))
  #];

  home.packages = with pkgs; [
 #   neovim-nightly
    neovim
    # chromium
    translate-shell
    opencode
    codegraph
    skills
  ];

  systemd.user.services.opencode-serve = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "OpenCode Serve";
      Documentation = "https://opencode.ai/";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.opencode}/bin/opencode serve --hostname 0.0.0.0 --port 4096";
      Restart = "on-failure";
      RestartSec = "5";
      Environment = [
        "PATH=${config.home.profileDirectory}/bin:${pkgs.opencode}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      ];
    };
  };

  launchd.agents.opencode-web = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      Label = "dev.uniqueding.opencode-web";
      ProgramArguments = [
        "${pkgs.opencode}/bin/opencode"
        "web"
        "--hostname"
        "0.0.0.0"
        "--port"
        "4096"
      ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  xdg.configFile.nvim.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/nvim";
  xdg.configFile.opencode.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/opencode";
}
