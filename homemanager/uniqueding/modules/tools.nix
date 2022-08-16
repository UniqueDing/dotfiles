{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    zsh
    psmisc
    atool
    dos2unix
    tree
    fd
    lsd
    bat
    ranger
    lf
    ripgrep
    diff-so-fancy
    httpie
    htop
    glances
    lazygit
    lazydocker
    lsb-release
    zoxide
    tealdeer
    fzf
    gdu
    duf
    neo-cowsay
    lolcat
    neofetch
    asciiquarium
    cmatrix
    jq
    pciutils
    joshuto
    bottom
    diskonaut
    gping
    termscp
    gitui
  ];

  home.file = {
    ".config/zsh".source = ../zsh;
    ".zshrc".source = ../zshrc;
    ".config/lf".source = ../lf;
    ".vimrc".source = ../vimrc;
  };
 # home.activation.linkDotfiles = config.lib.dag.entryAfter ["writeBoundary"]
 # ''
 #   ln -sf /opt/dotfiles/homemanager/uniqueding/ranger $HOME/.config/ranger
 # '';
}
