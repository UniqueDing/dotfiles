{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
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
    todo-txt-cli
    proxychains-ng
    file
    zip
    unzip
    nettools
  ];

  programs.zsh = {
    enable = true;
    # enableAutosuggestions = true;
    # enableSyntaxHighlighting = true;
    initExtra = ''
        source $HOME/.config/zsh/init.zsh
    '';
  };

  # home.file = {
  #   ".config/zsh".source = ../zsh;
  #   ".zshrc".source = ../zshrc;
  #   ".config/lf".source = ../lf;
  #   ".vimrc".source = ../vimrc;
  # };
  home.activation.linkDotfiles = config.lib.dag.entryAfter ["writeBoundary"]
  ''
    ln -sfn /opt/dotfiles/homemanager/uniqueding/ranger $HOME/.config/ranger
    ln -sfn /opt/dotfiles/homemanager/uniqueding/zsh $HOME/.config/zsh
    # ln -sfn /opt/dotfiles/homemanager/uniqueding/zshrc $HOME/.zshrc
    ln -sfn /opt/dotfiles/homemanager/uniqueding/vimrc $HOME/.vimrc
    ln -sfn /opt/dotfiles/homemanager/uniqueding/fcitx5/config $HOME/.config/fcitx5
    ln -sfn /opt/dotfiles/homemanager/uniqueding/fcitx5/share $HOME/.local/share/fcitx5
    ln -sfn /opt/dotfiles/homemanager/uniqueding/nvim $HOME/.config/nvim
    ln -sfn /opt/dotfiles/homemanager/uniqueding/hypr $HOME/.config/hypr
    ln -sfn /opt/dotfiles/homemanager/uniqueding/eww $HOME/.config/eww
    ln -sfn /opt/dotfiles/homemanager/uniqueding/squeekboard $HOME/.local/share/squeekboard
  '';
}
