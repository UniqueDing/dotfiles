{ config, lib, pkgs, confPath, ... }:

{

  home.packages = with pkgs; [
    neovim
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
      PassEnvironment = "SSH_AUTH_SOCK";
      UnsetEnvironment = "OPENCODE_SERVER_PASSWORD";
      ExecStartPre = "${pkgs.openssh}/bin/ssh-add -l";
      ExecStart = "${pkgs.zsh}/bin/zsh -f -c 'set -a; source \"${config.xdg.configHome}/zsh/env.local.zsh\" && unset OPENCODE_SERVER_PASSWORD && exec \"${config.home.homeDirectory}/.opencode/bin/opencode\" serve --hostname 0.0.0.0 --port 4096'";
      Restart = "on-failure";
      RestartSec = "5";
      Environment = [
        "PATH=${config.home.homeDirectory}/.opencode/bin:${config.home.profileDirectory}/bin:${pkgs.opencode}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      ];
    };
  };

  launchd.agents.opencode-serve = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      Label = "opencode-serve";
      ProgramArguments = [
        "${pkgs.zsh}/bin/zsh"
        "-f"
        "-c"
        "set -a; source \"${config.xdg.configHome}/zsh/env.local.zsh\" && unset OPENCODE_SERVER_PASSWORD && export PATH=\"${config.home.homeDirectory}/.opencode/bin:${config.home.profileDirectory}/bin:$PATH\" && exec \"${config.home.homeDirectory}/.opencode/bin/opencode\" serve --hostname 0.0.0.0 --port 4096"
      ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  xdg.configFile.nvim.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/nvim";
  xdg.configFile.opencode.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/opencode";
}
