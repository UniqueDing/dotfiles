return {
  "yetone/avante.nvim",
  opts = {
    provider = "opencode",
    acp_providers = {
      ["opencode"] = {
        command = "opencode",
        args = { "acp", "--model", "gpt/gpt-5.1-codex" }
      }
    },
    windows = {
      width = 40
    }
  },
}
