{ config, pkgs, ... }:

{
  services.interception-tools = {
    enable = true;
    udevmonConfig = ''
  - JOB: "${pkgs.interception-tools}/bin/intercept -g $DEVNODE | ${pkgs.interception-tools-plugins.caps2esc}/bin/caps2esc -m 1 | ${pkgs.interception-tools}/bin/uinput -d $DEVNODE"
    DEVICE:
      EVENTS:
        EV_KEY: [KEY_CAPSLOCK, KEY_ESC]
  '';
    plugins = with pkgs; [
      interception-tools-plugins.caps2esc
    ];
  };
}
