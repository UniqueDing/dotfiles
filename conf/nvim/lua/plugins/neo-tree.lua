return {
  "nvim-neo-tree/neo-tree.nvim",
  cmd = "Neotree",
  keys = {
    { "<leader>e", "<cmd>Neotree filesystem toggle left<cr>", desc = "Explorer NeoTree" },
  },
  opts = {
    window = {
      position = "left",
      mappings = {
        ["i"] = function(state)
          local node = state.tree:get_node()
          if node and node.type == "directory" and not node:is_expanded() then
            require("neo-tree.sources.filesystem.commands").open(state)
          end
        end,
        ["o"] = "open",
        ["h"] = "close_node",
        ["n"] = "",
        ["e"] = "",
        ["/"] = "",
        ["<bs>"] = "toggle_hidden",
        ["H"] = "navigate_up",
        ["f"] = "fuzzy_finder",
        ["<space>"] = "none",
        ["Y"] = {
          function(state)
            local node = state.tree:get_node()
            local path = node:get_id()
            vim.fn.setreg("+", path, "c")
          end,
          desc = "Copy Path to Clipboard",
        },
        ["O"] = {
          function(state)
            require("lazy.util").open(state.tree:get_node().path, { system = true })
          end,
          desc = "Open with System Application",
        },
        ["P"] = { "toggle_preview", config = { use_float = false } },
      },
    },
  },
}
