---
name: computer-use-atspi
description: Use only for explicitly requested Linux desktop GUI tasks through the computeruse AT-SPI MCP; not for general coding, browsing, or shell tasks.
---

# Linux AT-SPI 应用控件操作

仅在用户明确要求操作 Linux 桌面应用时使用 `computeruse` MCP。工具访问可能读取应用控件中的敏感文本；每次调用都需要用户逐次批准。不要把关闭截图描述成不会读取敏感信息。

## 操作步骤

1. 从用户任务中确定唯一目标应用；若目标不明确，先询问，不要枚举或读取所有应用。
2. 每轮操作先调用 `computeruse_get_app_state`，默认使用 `include_screenshot: false`。用户明确要求截图操作时，允许通过 MCP 截取已确认的目标窗口；只读取任务所需的画面和控件信息。
3. 操作前核对控件的当前标识、状态和支持动作。优先使用稳定的 `element_identifier`；索引可能过期，操作前重新检查。
4. 仅在用户已明确授权相应可见结果后操作。优先使用控件支持的明确原生动作（例如 click、toggle 或 press），不要依赖默认主动作。用户明确要求截图点击时，允许通过 MCP 聚焦已确认的目标窗口并进行坐标点击；点击前核对最新截图、窗口边界和坐标缩放，操作后验证结果。不得聚焦或操作无关应用。
5. 仅对已确认是可编辑字段且目标值明确的控件调用 `computeruse_set_value`。若任务未说明应保留或替换的现有内容，先询问。
6. 若状态、目标或动作与预期不符，停止并报告；不要盲目重试。

## 禁止绕行

- 不通过 shell、`xdotool`、`pyautogui` 或其他 MCP 之外的方式注入鼠标或键盘输入。仅允许上述用户已授权的 MCP 原生动作、目标窗口聚焦和截图坐标点击；键盘模拟不因本条变更而自动获得授权。
- 不用 shell、脚本或其他工具绕过 MCP 权限；不调用未列明的工具或未核实的动作。
- 不假设 MCP 权限会过滤 `perform_action` 的动作参数。审批和本说明不是服务器级沙箱；应用执行操作也可能自行改变焦点。
- 若 MCP 不可用或报告缺少桌面会话，不猜测显示编号或授权文件，不伪造会话环境；停止并说明问题。
