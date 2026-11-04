class ClashPartyLinux < Formula
  desc "Graphical Mihomo proxy client for Linux desktops"
  homepage "https://clashparty.org/"
  license "GPL-3.0-only"

  on_linux do
    on_intel do
      url "https://github.com/mihomo-party-org/clash-party/releases/download/v2.0.4/clash-party-linux-2.0.4-amd64.deb",
          using: :nounzip
      sha256 "33f3b75a8c0ed91c09499c0b9f2e0eb755e5ae13f69d6ffabab713fbb9bbf3a4"
    end

    on_arm do
      url "https://github.com/mihomo-party-org/clash-party/releases/download/v2.0.4/clash-party-linux-2.0.4-arm64.deb",
          using: :nounzip
      sha256 "cc1f38075a2c4d223d80f679699b7004279e63efa12828e0e18026578731452c"
    end
  end

  depends_on "binutils" => :build
  depends_on "xz" => :build
  depends_on :linux

  # Preserve upstream Electron resources.
  skip_clean "libexec"

  def install
    system "ar", "x", cached_download
    system "tar", "xf", "data.tar.xz"
    app = buildpath/"opt/clash-party"

    linkage = Utils.safe_popen_read("/usr/bin/ldd", app/"mihomo-party")
    missing = linkage.lines.grep(/not found/)
    odie "Install the host desktop libraries listed by ldd first:\n#{missing.join}" if missing.any?

    libexec.install app
    app = libexec/"clash-party"
    app.find do |path|
      path.chmod(path.stat.mode & 0o777) if path.file? && !path.symlink?
    end

    (bin/"clash-party-linux").write <<~SH
      #!/bin/sh
      exec "#{opt_libexec}/clash-party/mihomo-party" --disable-setuid-sandbox "$@"
    SH

    icon = "share/icons/hicolor/512x512/apps/clash-party-linux.png"
    (prefix/"share/icons/hicolor/512x512/apps").install "usr/share/icons/hicolor/512x512/apps/mihomo-party.png" => "clash-party-linux.png"
    desktop = buildpath/"usr/share/applications/mihomo-party.desktop"
    inreplace desktop do |file|
      file.gsub! "Name=Clash Party\n", "Name=Clash Party (Homebrew)\n"
      file.gsub! "Exec=/opt/clash-party/mihomo-party %U", "Exec=#{opt_bin}/clash-party-linux %U"
      file.gsub! "Icon=mihomo-party", "Icon=#{opt_prefix}/#{icon}"
      # Leave existing URI handlers unchanged.
      file.gsub!(/^MimeType=.*\n/, "")
    end
    (share/"applications").install desktop => "clash-party-linux.desktop"
  end

  def caveats
    <<~EOS
      Exit any existing instance before running clash-party-linux; ~/.config/mihomo-party is shared.
      Uses host desktop libraries and the user-namespace sandbox, without setuid bits.
      No TUN privileges, services or URI defaults are configured.
      Run `bash build.sh brew install` for the desktop menu entry.
    EOS
  end
end
