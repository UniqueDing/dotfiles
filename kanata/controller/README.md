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
