brew "xray"
brew "frpc"
brew "kanata"
brew "uniqueding/dotfiles/clash-party-linux", trusted: true if OS.linux?
if (OS.linux? && Hardware::CPU.intel?) || (OS.mac? && Hardware::CPU.arm?)
  brew "uniqueding/dotfiles/kanata-controller", trusted: true
end
