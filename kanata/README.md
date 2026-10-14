# Kanata

本目录保存 Kanata 配置和各平台服务模板。修改这里的配置后，先检查，再安装。安装仅管理本脚本当前受管的 Kanata/controller，以及 macOS 明确列出的 VirtualHID Daemon；不会迁移或操作旧 Kmonad、其他 remapper 或旧服务。

## 日常操作

在 dotfiles 仓库根目录打开 Bash（Linux/macOS 终端，或 Windows Git Bash），日常检查和服务控制统一使用以下六个动作：

```sh
bash kanata/kanata.sh check
bash kanata/kanata.sh install
bash kanata/kanata.sh start
bash kanata/kanata.sh status
bash kanata/kanata.sh restart
bash kanata/kanata.sh stop
```

`kanata/kanata.sh` 是日常入口；`install` 委派给同目录的 `kanata/kanata-install.sh`，其他操作只检查或控制服务，不准备或安装软件。安装器只通过 source guard 读取日常入口中的少量无副作用共享 helper，不会触发入口 main 或形成循环。旧路径下不保留兼容脚本。`build.sh kanata [linux|macos|windows]` 仍是构建入口，可选 target 仅限当前运行的同一平台；它会先执行通用初始化并写入仓库根目录 `local.nix`。

- `check` 使用现有 Kanata 检查配置，不准备软件、不下载、不部署、不管理服务，也不会启动 Kanata。若本机没有可用 Kanata，先按平台说明安装/准备它。
- `install` 先准备平台软件，再检查二进制、配置、模板、固定目标和当前受管服务状态；前置检查通过后，只停止/卸载需要刷新的当前受管作业，部署并启用/注册服务定义，然后启动它们。macOS Kanata/controller launchd 作业只要仍 loaded（无论当前是否忙碌）就会在刷新文件前卸载；随后安装器刷新并验证 VirtualHID Daemon，成功后才启动 Kanata/controller。Windows 当前任务若处于 queued/running 会结束并确认已停止后才写入。安装会启动或重启当前受管组件，不触碰其他 remapper；运行时可能需要包管理器或系统服务权限。
- `start`、`stop`、`restart`、`status` 只控制/查询当前受管服务，不准备或安装软件。查询失败是错误，不要将其当成“未安装”或“未运行”。Linux/macOS 的系统服务操作通常需要相应权限；不要改用 root 运行 Kanata 本身。
- 新机器首次部署运行 `install` 即会准备、部署并启动当前受管组件。配置更新常见流程为 `check` → `install`；安装会自行停止当前正在运行的受管组件、部署后再启动，即使安装前组件已停止也会启动。安装后若又手动停止组件，之后可用 `start` 启动。

软件准备阶段可能已通过包管理器写入/更新包管理器拥有的软件（包括 Arch `/usr/bin/kanata` 或 Homebrew Kanata）；之后若部署前检查失败，脚本管理的配置/controller/service 目标及服务操作不变，但包管理器改动不会回滚。停止当前服务或开始部署后的失败可能留下停止或部分部署状态；安装器不会自动回滚、重启旧版本或恢复服务状态。macOS VHID Daemon 一旦更新并启动，即使后续 Kanata/controller 阶段失败也不会回滚。单文件替换使用同目录临时文件和原子重命名，并保留首份 `.pre-kanata.bak`，但这不是完整事务保证。需要恢复时，先明确停止受管服务，再检查备份和目标文件；只有在确认恢复目标并取得相应授权后，才手动恢复。不要删除本目录中的历史资料来“清理”安装。

## 配置

- 修改 `kanata/config/` 下对应平台的 `kanata-*.kbd`，以及它引用的 `kanata-common.kbd`。Linux 配置包含公共配置；其他平台也应按各自配置文件维护。
- 先运行 `check`。它检查配置语法，不会模拟键盘、不验证系统输入设备权限，也不保证运行时服务一定能打开设备。
- 仓库中的文件是**源配置**；`install` 部署的是系统使用的副本。改完源文件后需重新安装，单独编辑已部署副本会在之后部署时被覆盖。
- 当前配置不需要 shell 命令定义。若以后增加此类功能，应先确认配置语法和安全影响，再部署。

## 平台准备

### Linux

安装器使用 systemd system unit 运行 Kanata，服务以指定普通用户身份启动（不是 root），并通过服务定义配置 `input`、`uinput` 补充组。托盘控制器另由用户级 systemd 服务运行，因此安装和控制需有已登录的 systemd 用户管理器。安装/启动前确认这两个组、所需的输入设备和 udev 权限规则可用；不必仅为服务运行而把所有交互式进程也加入这些组。不同发行版的设备准备方式可能不同。不要用更换 glibc 或混装系统库的方式解决兼容问题。

Arch Linux 使用发行版仓库版本的 Kanata，不受其他 Linux 固定 v1.12.0 限制。`install` 在已有 `yay` 时运行 `yay -S --needed --noconfirm kanata`，否则运行 `sudo pacman --needed --noconfirm -S kanata`；systemd unit 和 `check` 直接使用包管理器安装的 `/usr/bin/kanata`，不复制到 `/usr/local` 管理路径。保留现有 host-architecture 自动选择和 `arch` alias；Arch `check` 应优先选 `/usr/bin/kanata`，避免误用残留的旧 `/usr/local/bin/kanata`。Arch 还可通过 pacman 准备实际缺少的 `base-devel`、`git`、`curl`、`unzip`、`binutils`；只有 `cargo`/`rustc` 不可用时才准备 `rust`，避免与 rustup 工具链冲突。

其他 Linux 发行版仍仅使用固定版本 v1.12.0：仅复用版本符合且实际可运行的已有 Kanata，否则获取该版本匹配架构的官方预编译包并核对 SHA-256。预编译文件必须通过实际运行检查后才进行 parse-only 配置检查；校验失败立即停止，不以源码构建绕过。无匹配包、下载不可用或运行库不兼容时，使用同一 v1.12.0 tag 源码，以普通用户身份显式指定适配本机架构的 GNU/Linux target 并控制继承的 Cargo target 设置，执行默认功能的 `cargo build --locked --release`，再验证构建产物可运行且配置可解析。源码构建使用本机原生 GNU/Linux target，不使用 Nix wrapper/runtime、musl 或额外 `libudev` / `pkg-config` 依赖。Linux controller 继续以普通用户通过 Cargo 使用仓库源码构建。其他发行版缺少工具链时会提示准备步骤，不自动调用其包管理器。不要用更换 glibc 或混装系统库解决兼容问题。

如需手动检查非 Arch Linux 的 Kanata v1.12.0 同一源码构建路线，先准备该版本源码，再执行：

```sh
cargo build --locked --release --manifest-path <Kanata源码目录>/Cargo.toml
```

此手动命令适用于正常的本机 GNU/Linux Cargo target；确保 Cargo 环境或配置没有将 target 改为 musl，或引入 Nix runtime/wrapper。构建使用默认功能及与目标系统兼容的本机工具链和系统库。常见 Debian/Ubuntu C 工具链包为 `build-essential`；源码获取、下载及验证还会用到 `git`、`curl`、`unzip`、`binutils` 等工具。Rust stable 工具链需另行准备。发行版包名和安装方式请查本机发行版文档。

### macOS

安装器通过已存在的 Homebrew 执行 `brew install kanata libiconv`，并以本机 Cargo 构建 controller。Kanata 直接使用 `$(brew --prefix kanata)/bin/kanata` 作为 LaunchDaemon 的 `ProgramArguments`，不复制到独立的 `/usr/local/libexec/kanata`，不覆盖 Intel Homebrew 的 `/usr/local/bin/kanata` symlink，也不自动删除历史遗留的独立副本。Homebrew 不存在时须先自行安装；若本机 Rust/Cargo 或 Apple Command Line Tools 缺失，安装器会提示准备步骤，不自动安装工具链。如需手动构建本仓库的 controller，可执行：

```sh
cargo build --release --manifest-path kanata/controller/Cargo.toml
```

Karabiner VirtualHID Driver 软件及所需 DriverKit 批准仍须由用户预先安装/批准；本安装器不安装驱动或授予授权。vendor daemon executable 必须存在并通过签名检查，但 daemon job 在运行安装前不必处于运行状态：`install` 会在停止当前 Kanata/controller 后，若 daemon job 已加载则 `bootout` 并确认已卸载；原子刷新 plist 后，按精确匹配的 vendor 进程发送有限 `TERM`，再 enable/bootstrap/kickstart daemon。安装器会验证 daemon 已运行且 socket 目录中存在真实的 UNIX `*.sock` 才继续启动 Kanata/controller。还须在“系统设置”中授予所需的输入监控和辅助功能权限；不要尝试绕过系统授权。`start`、`stop`、`restart`、`status` 不会管理 VHID daemon。

受管 VHID job 使用 label `org.pqrs.Karabiner-VirtualHIDDevice-Daemon` 和模板 `kanata/services/macos/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist`（`KeepAlive=true`），部署至 `/Library/LaunchDaemons/org.pqrs.Karabiner-VirtualHIDDevice-Daemon.plist`。安装前会用 `codesign --verify` 检查既有 vendor executable，并确认 identifier 为 `org.pqrs.Karabiner-VirtualHIDDevice-Daemon`、Team ID 为 `G43BCU2T37`；查询或 `ps -axo pid=,comm=` 进程枚举错误会中止。daemon plist 刷新后只向完整 vendor 命令路径精确匹配的进程发送 `TERM`，最多等待 10 秒，不向其他进程发信号，也不升级为 `KILL`。随后 enable/bootstrap/kickstart，并在有界等待内确认 launchd 报告运行且 socket 目录 `/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server` 下存在真实 UNIX socket 文件（该路径是目录，不是 socket 文件本身）。若 VHID 更新成功后 Kanata/controller 阶段失败，已更新的 VHID 保持原状，不自动回滚；错误应指出失败阶段。

### Windows

在 Windows Git Bash 中使用本仓库时，`install` 优先复用当前唯一且可运行的 Kanata GUI；仅在缺少或不可运行时才要求已存在的 WinGet 执行 `winget install --id jtroo.kanata_gui`，之后重新唯一发现并检查版本。已有可用 GUI 时不要求 WinGet，也不因重复安装而强制升级。WinGet 不会 bootstrap。允许当前用户的 Kanata 数据目录尚不存在。安装会注册并运行当前用户的提升权限登录计划任务，需以管理员身份运行 Git Bash；任务状态 `0`（unknown）会拒绝写入，queued/running 任务须结束并在有界等待内确认停止后再修改目标，超时则拒绝写入。它不是 Linux/macOS 那种托盘控制器；配置检查不需要管理员权限。

## 故障排查

1. 先运行 `bash kanata/kanata.sh check` 检查配置；首次部署或更新则运行 `bash kanata/kanata.sh install`，它会准备软件、在部署前验证配置，并在安装完成后启动当前受管组件。
2. `status` 查询当前受管服务；若查询本身失败，请按错误排查，不要当作服务未运行。`start` 或 `restart` 报错时，先阅读完整错误，再检查二进制版本/可执行性、配置路径及平台设备和隐私权限。
3. Linux 检查用户的 `input`/`uinput` 权限、udev 规则及用户级 systemd 管理器；macOS 检查 Karabiner 驱动及系统隐私授权；Windows 检查计划任务权限及 Kanata GUI 的 WinGet 安装。
4. 安装器只管理当前固定的 Kanata/controller 服务，以及 macOS 明确列出的 VirtualHID Daemon；不迁移、停止或删除旧 Kmonad/其他 remapper，也不自动清理旧文件。

## 维护者验证

在仓库根目录运行 Bash 语法检查和隔离安装器测试：

```sh
for script in \
  kanata/kanata.sh \
  kanata/kanata-install.sh \
  kanata/tests/kanata_installer_test.sh \
  build.sh
do
  bash -n "$script" || exit
done
bash kanata/tests/kanata_installer_test.sh
```

测试应使用隔离临时目录（例如 `/tmp/opencode` 下的 fixture），并 mock 软件准备命令；不得实际安装软件、运行包管理器、提权、修改服务/任务/权限、启动键盘接管或操作硬件。以上是验证命令，不代表它们已在当前改动上运行或通过；平台真实效果还需在相应系统上单独授权验证。

## 上游资料

- [Kanata 项目与发布](https://github.com/jtroo/kanata)
- [Kanata 文档目录](https://github.com/jtroo/kanata/tree/main/docs)
