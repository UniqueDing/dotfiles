# OpenCode Skills

`conf/skills/.skill-lock.json` 是由 Git 管理的 Skills 来源记录。当前机器的
`~/.agents/.skill-lock.json` 是指向仓库该记录的软链接。

在新机器上运行 `bash build.sh opencode`，会通过 `uv` 安装 `code-review-graph`，从 dotfiles
记录读取技能，并通过 Skills CLI 安装缺失的全局技能，再准备本机 MCP 依赖。首次使用、更新和迁移说明见 `bash build.sh opencode help`。
脚本只读取仓库记录；由 CLI 管理其全局记录，不会在新机器部署锁文件软链接，
也不保证自动把新机器上的记录同步回 Git。若要让后续 CLI 记录变更自动写入仓库，需另行安排锁文件软链接。
此安装方式不承诺恢复某个精确提交版本。

本地维护的 `codemap`、`computer-use-atspi`、`qual-commit-message` 和 `qual-gerrit-review`
由 dotfiles/Git 管理，不应交给 `skills update` 重新安装。标记为本地 `Source` 不代表可自动跟随上游更新。

OpenCode V2 会读取全局 `~/.config/opencode/skills`，也兼容读取 `~/.agents/skills`；
前者优先，避免放置同名副本遮住 CLI 管理的技能。

## CLI 命令

- 查看全局技能：`skills list --global`
- 查找技能：`skills find <keyword>`
- 更新已记录的外部技能：`skills update --global brainstorming systematic-debugging`
- 更新 dotfiles 来源记录里的 GitHub 技能和 npm MCP：`bash build.sh opencode update`；不会批量更新本地自定义技能。
- 安装新外部技能：`skills add <owner/repo> --global --agent opencode --skill <name>`

安装前检查同名技能，避免覆盖本地内容。不要使用 `--all` 或 `--yes` 做大范围操作，也不要自行接管来源未知的技能。
所需工具为 Bash、`jq`、Skills CLI 和 `uv`。
