return {
  "jackMort/ChatGPT.nvim",
  event = "VeryLazy",
  keys = {
    {
      "<leader>ae",
      "<cmd>ChatGPTEditWithInstruction<cr>",
      mode = { "n", "v" },
      desc = "ChatGPT Edit with instruction",
    },
    {
      "<leader>ag",
      "<cmd>ChatGPTRun grammar_correction<cr>",
      mode = { "n", "v" },
      desc = "ChatGPTRun Grammar Correction",
    },
    { "<leader>at", "<cmd>ChatGPTRun translate<cr>", mode = { "n", "v" }, desc = "ChatGPTRun Translate" },
    { "<leader>ak", "<cmd>ChatGPTRun keywords<cr>", mode = { "n", "v" }, desc = "ChatGPTRun Keywords" },
    { "<leader>ad", "<cmd>ChatGPTRun docstring<cr>", mode = { "n", "v" }, desc = "ChatGPTRun Docstring" },
    { "<leader>aa", "<cmd>ChatGPTRun add_tests<cr>", mode = { "n", "v" }, desc = "ChatGPTRun Add Tests" },
    { "<leader>ao", "<cmd>ChatGPTRun optimize_code<cr>", mode = { "n", "v" }, desc = "ChatGPTRun Optimize Code" },
    { "<leader>as", "<cmd>ChatGPTRun summarize<cr>", mode = { "n", "v" }, desc = "ChatGPTRun Summarize" },
    { "<leader>af", "<cmd>ChatGPTRun fix_bugs<cr>", mode = { "n", "v" }, desc = "ChatGPTRun Fix Bug" },
    { "<leader>ax", "<cmd>ChatGPTRun explain_code<cr>", mode = { "n", "v" }, desc = "ChatGPTRun Explain Code" },
    { "<leader>ar", "<cmd>ChatGPTRun roxygen_edit<cr>", mode = { "n", "v" }, desc = "ChatGPTRun Roxygen Edit" },
    {
      "<leader>al",
      "<cmd>ChatGPTRun code_readability_analysis<cr>",
      mode = { "n", "v" },
      desc = "ChatGPTRun Readability Analysis",
    },
  },
  config = function()
    local home = vim.fn.expand("$HOME")
    local host_cmd = "sed -n 1p " .. home .. "/.config/chat.api"
    local key_cmd = "sed -n 2p " .. home .. "/.config/chat.api"
    require("chatgpt").setup({
      api_host_cmd = host_cmd,
      api_key_cmd = key_cmd,
      openai_params = {
        model = "gpt-4o-mini",
        max_tokens = 4095,
      },
    })
  end,
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-lua/plenary.nvim",
    "folke/trouble.nvim", -- optional
    "nvim-telescope/telescope.nvim",
  },
}
