# kanata-controller

## Safety boundary

- Linux uses fixed `/usr/bin/systemctl` commands for `kanata.service`.
- macOS uses only fixed `sudo -n /usr/local/libexec/kanata-control` operations.
- The tray application is never root.

## macOS verification

```sh
LIBICONV_PREFIX="$(/opt/homebrew/bin/brew --prefix libiconv)"
RUSTFLAGS="-C link-arg=-L${LIBICONV_PREFIX}/lib" cargo fmt --check
RUSTFLAGS="-C link-arg=-L${LIBICONV_PREFIX}/lib" cargo clippy --all-targets -- -D warnings
RUSTFLAGS="-C link-arg=-L${LIBICONV_PREFIX}/lib" cargo test
```

The macOS Quit menu item is intentionally absent because the controller is a
LaunchAgent kept alive by launchd.

## Linux verification

```sh
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
```

Linux tray and systemd runtime behavior requires native Linux or Linux CI
verification; macOS builds do not validate that runtime.

## Linux and macOS CI release packages

`.github/workflows/kanata-controller-linux.yml` checks formatting, runs Clippy and
tests, and builds two native targets using Rust 1.97.1:

- `x86_64-unknown-linux-gnu` on Ubuntu 22.04. The packaging check rejects Nix-store
  dependencies, nonstandard loaders, embedded RPATH/RUNPATH, and requirements
  newer than glibc 2.35 (Deepin 25 has glibc 2.38).
- `aarch64-apple-darwin` on Apple Silicon `macos-14`, using the Apple SDK without
  Homebrew runtime libraries. The deployment target is macOS 11.0. Checks reject
  Intel/universal binaries, non-system dylibs, Nix/Homebrew library paths and
  LC_RPATH. The executable is ad-hoc signed and its signature is verified.

Intel Macs are not built. Ad-hoc signing is not Developer ID signing or Apple
notarization; Gatekeeper can still require an explicit user decision for a
downloaded executable. The workflow never changes Gatekeeper settings.

Relevant pushes to `master`, pull requests, and manual workflow runs upload a
14-day Actions artifact. A pushed tag matching the package version, currently
`kanata-controller-v0.1.0`, additionally publishes a GitHub Release containing:

- `kanata-controller-0.1.0-x86_64-unknown-linux-gnu.tar.gz`
- `kanata-controller-0.1.0-aarch64-apple-darwin.tar.gz`
- `SHA256SUMS`

The archive contains the executable and this README. Verify it with
`sha256sum --check SHA256SUMS` before installation. Release tags must exactly match
`Cargo.toml`; existing releases are never overwritten. Only the release job has
repository write permission, and PRs cannot publish releases. Both platform jobs
must pass before publication; their individual checksums are checked before
generating the combined Release checksum file.

The workflow does not install services, change permissions, or replace the local
controller. A Homebrew binary formula can consume the Release archive once it
has actually been published. Passing CI does not establish native tray behavior,
Linux D-Bus/systemd/polkit integration, or macOS launchd/sudo-helper integration
on a desktop session.
