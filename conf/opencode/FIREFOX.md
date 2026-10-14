# Firefox MCP

首次使用、MCP 安装、更新和新机器迁移说明统一维护在 `scripts/opencode.sh`：

```sh
bash build.sh opencode help
```

`bash build.sh opencode update` 先更新记录中的外部 Skills，再更新 npm MCP 并同步版本号；不会启动 Firefox、复制登录态或修改启用状态。

资料：[Mozilla Firefox DevTools MCP](https://github.com/mozilla/firefox-devtools-mcp#connect-to-existing-firefox) · [OpenCode V2 MCP](https://opencode.ai/v2/docs/mcp-servers)
