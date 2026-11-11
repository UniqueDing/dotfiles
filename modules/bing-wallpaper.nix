{ config, lib, pkgs, ... }:

let
  cfg = config.programs.bing-wallpaper;
  package = pkgs.writeShellScriptBin "bing-wallpaper" ''
    export PATH="$PATH:/usr/bin:/bin"
    export SSL_CERT_FILE="''${SSL_CERT_FILE:-${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt}"
    exec ${pkgs.python3}/bin/python3 ${../scripts/bing-wallpaper.py} \
      --market ${lib.escapeShellArg cfg.market} --keep ${toString cfg.keep} "$@"
  '';
  logs = "${config.xdg.stateHome}/bing-wallpaper";
in
{
  options.programs.bing-wallpaper = {
    enable = lib.mkEnableOption "the background-only Bing wallpaper command";
    automatic = lib.mkEnableOption "login and hourly wallpaper checks";
    market = lib.mkOption {
      type = lib.types.str;
      default = "en-US";
      description = "Bing market used to select the daily UHD image.";
    };
    keep = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
      description = "Number of cached images to retain after a successful update.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ package ];

    systemd.user.services.bing-wallpaper = lib.mkIf (cfg.automatic && pkgs.stdenv.hostPlatform.isLinux) {
      Unit = {
        Description = "Update Bing daily wallpaper";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${package}/bin/bing-wallpaper";
        TimeoutStartSec = 240;
        UMask = "0077";
      };
    };

    systemd.user.timers.bing-wallpaper = lib.mkIf (cfg.automatic && pkgs.stdenv.hostPlatform.isLinux) {
      Unit.Description = "Check Bing wallpaper after login and hourly";
      Timer = {
        OnStartupSec = "1min";
        OnUnitActiveSec = "1h";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    home.activation.bingWallpaperLogs = lib.mkIf (cfg.automatic && pkgs.stdenv.hostPlatform.isDarwin)
      (lib.hm.dag.entryBefore [ "setupLaunchAgents" ] ''
        run ${pkgs.coreutils}/bin/mkdir -p -m 700 -- ${lib.escapeShellArg logs}
      '');

    launchd.agents.bing-wallpaper = lib.mkIf (cfg.automatic && pkgs.stdenv.hostPlatform.isDarwin) {
      enable = true;
      config = {
        Label = "org.nix-community.home.bing-wallpaper";
        ProgramArguments = [ "${package}/bin/bing-wallpaper" ];
        RunAtLoad = true;
        StartInterval = 3600;
        LimitLoadToSessionType = "Aqua";
        ProcessType = "Background";
        StandardOutPath = "${logs}/stdout.log";
        StandardErrorPath = "${logs}/stderr.log";
      };
    };
  };
}
