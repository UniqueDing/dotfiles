class KanataController < Formula
  desc "Tray controller for the repository-managed Kanata service"
  homepage "https://github.com/UniqueDing/dotfiles/tree/master/kanata/controller"
  license "MIT"

  on_linux do
    depends_on arch: :x86_64
    url "https://github.com/UniqueDing/dotfiles/releases/download/kanata-controller-v0.1.0/kanata-controller-0.1.0-x86_64-unknown-linux-gnu.tar.gz"
    sha256 "cefdf240107f6c11b0c9ef4f05e8ac7f85b159f5c88c30c39027dd21149a3e1f"
  end

  on_macos do
    depends_on arch: :arm64
    url "https://github.com/UniqueDing/dotfiles/releases/download/kanata-controller-v0.1.0/kanata-controller-0.1.0-aarch64-apple-darwin.tar.gz"
    sha256 "699cbff61beef3dade53639bc0000ef2c1fa66ebc14f6cda15039ab03e315ffc"
  end

  resource "license" do
    url "https://github.com/UniqueDing/dotfiles/releases/download/kanata-controller-v0.1.0/LICENSE", using: :nounzip
    sha256 "0fac0276be8f49fa54ec9625970e05eb4ac6af51946c2ab00ec62d3a21cc72af"
  end

  # Keep the macOS ad-hoc signature intact.
  skip_clean "bin/kanata-controller"

  def install
    bin.install "kanata-controller"
    pkgshare.install "README.md"
    resource("license").stage { prefix.install "LICENSE" }
  end

  def caveats
    <<~EOS
      Installs the executable only; services and authorization remain unchanged.
      After desktop verification, point your service to #{opt_bin}/kanata-controller.
      macOS: ad-hoc signed, not Developer ID signed or notarized.
    EOS
  end
end
