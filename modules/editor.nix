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

  systemd.user.services.opencode-telegram-bot = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "OpenCode Telegram Bot";
      After = [ "opencode-serve.service" ];
      BindsTo = [ "opencode-serve.service" ];
      PartOf = [ "opencode-serve.service" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      WorkingDirectory = builtins.dirOf confPath;
      UMask = "0077";
      Environment = [
        "PATH=${config.home.homeDirectory}/.opencode/bin:${config.home.profileDirectory}/bin:/usr/bin:/bin"
      ];
      ExecStart = "${pkgs.zsh}/bin/zsh -f -c 'set -a; source \"${config.xdg.configHome}/zsh/env.local.zsh\" && source \"${config.xdg.configHome}/opencode-telegram-bot/env.$$(hostname -s).zsh\" && exec \"${pkgs.nodejs_24}/bin/node\" \"${config.xdg.dataHome}/opencode-telegram-bot/runtime-0.26.4/node_modules/@grinev/opencode-telegram-bot/dist/cli.js\"'";
      Restart = "on-failure";
      RestartSec = "5";
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

  launchd.agents.opencode-telegram-bot = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      Label = "opencode-telegram-bot";
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 5;
      WorkingDirectory = builtins.dirOf confPath;
      EnvironmentVariables.PATH = "${config.home.homeDirectory}/.opencode/bin:${config.home.profileDirectory}/bin:/usr/bin:/bin";
      ProgramArguments = [
        "${pkgs.zsh}/bin/zsh"
        "-f"
        "-c"
        "set -a; source \"${config.xdg.configHome}/zsh/env.local.zsh\" && source \"${config.xdg.configHome}/opencode-telegram-bot/env.$(hostname -s).zsh\" && exec \"${pkgs.nodejs_24}/bin/node\" \"${config.xdg.dataHome}/opencode-telegram-bot/runtime-0.26.4/node_modules/@grinev/opencode-telegram-bot/dist/cli.js\""
      ];
    };
  };

  xdg.configFile.nvim.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/nvim";
  xdg.configFile.opencode.source = config.lib.file.mkOutOfStoreSymlink "${confPath}/opencode";
}
