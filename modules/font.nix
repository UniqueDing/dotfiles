{ config, pkgs, ... }:

{
fonts.fonts = with pkgs; [
  noto-fonts
  noto-fonts-cjk
  noto-fonts-emoji
  liberation_ttf
  fira-code
  fira-code-symbols
  source-han-sans
  wqy_zenhei
  wqy_microhei
  hack-font
  (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" "Hack" ]; })
];


}
