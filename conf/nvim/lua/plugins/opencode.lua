return {
  "sudo-tee/opencode.nvim",
  opts = function()
    local port = vim.env.OPENCODE_PORT
    if port and port:match("^%d+$") then
      return { server = { url = "http://127.0.0.1", port = tonumber(port) } }
    end
    return {}
  end,
  dependencies = {
    {
      "MeanderingProgrammer/render-markdown.nvim",
      ft = function(_, filetypes)
        if not vim.tbl_contains(filetypes, "opencode_output") then
          table.insert(filetypes, "opencode_output")
        end
      end,
      opts = function(_, opts)
        opts.file_types = opts.file_types or { "markdown" }
        if not vim.tbl_contains(opts.file_types, "opencode_output") then
          table.insert(opts.file_types, "opencode_output")
        end
      end,
    },
  },
}
