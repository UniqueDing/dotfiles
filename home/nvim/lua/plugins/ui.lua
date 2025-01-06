return {
  "akinsho/bufferline.nvim",
  keys = {
    { "<S-h>", false },
    { "<S-l>", false },
    { "[b", false },
    { "]b", false },
    { "<A-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
    { "<A-i>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
    { "<A-q>", "<cmd>bdelete<cr>", desc = "Close Buffer"},
  },
}
