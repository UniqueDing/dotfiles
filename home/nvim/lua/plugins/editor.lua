return {
  "nvim-telescope/telescope.nvim",
  keys = {
    { "<leader>gc", false },
    { "<leader>gs", false },
    { "<leader>fm", "<cmd>Telescope git_commits<CR>", desc = "Commits" },
    { "<leader>fu", "<cmd>Telescope git_status<CR>", desc = "Status" },
  },
  {
    "FabianWirth/search.nvim",
    lazy = true,
    dependencies = { "nvim-telescope/telescope.nvim" },
    keys = {
      {
        "<A-f>",
        function()
          require("search").open({ collection = "pattern" })
        end,
        desc = "Open search",
      },
    },
    config = function()
      local builtin = require("telescope.builtin")
      local extensions = require("telescope").extensions

      require("search").setup({
        collections = {
          -- Search using filenames
          file = {
            initial_tab = 1,
            tabs = {
              {
                name = "Files",
                tele_func = function(opts)
                  opts = opts or {}
                  if vim.fn.isdirectory(".git") == 1 then
                    builtin.git_files(opts)
                  else
                    builtin.find_files(opts)
                  end
                end,
              },
              {
                name = "Frecency",
                tele_func = function()
                  extensions.frecency.frecency()
                end,
              },
              {
                name = "Oldfiles",
                tele_func = function()
                  builtin.oldfiles()
                end,
              },
              {
                name = "Buffers",
                tele_func = function()
                  builtin.buffers()
                end,
              },
            },
          },
          -- Search using patterns
          pattern = {
            initial_tab = 1,
            tabs = {
              {
                name = "Word under cursor",
                tele_func = function(opts)
                  opts = opts or {}
                  builtin.grep_string(opts)
                end,
              },
              {
                name = "Word in project",
                tele_func = function()
                  extensions.live_grep_args.live_grep_args()
                end,
              },
            },
          },
          -- Search Git objects (branches, commits)
          git = {
            initial_tab = 1,
            tabs = {
              {
                name = "Branches",
                tele_func = function()
                  builtin.git_branches()
                end,
              },
              {
                name = "Commits",
                tele_func = function()
                  builtin.git_commits()
                end,
              },
              {
                name = "Commit content",
                tele_func = function()
                  extensions.advanced_git_search.search_log_content()
                end,
              },
              {
                name = "Diff current file with commit",
                tele_func = function()
                  extensions.advanced_git_search.diff_commit_file()
                end,
              },
            },
          },
          -- Retrieve dossiers
          dossier = {
            initial_tab = 1,
            tabs = {
              {
                name = "Sessions",
                tele_func = function()
                  extensions.persisted.persisted()
                end,
              },
              {
                name = "Projects",
                tele_func = function()
                  extensions.projects.projects({})
                end,
              },
              {
                name = "Zoxide",
                tele_func = function()
                  extensions.zoxide.list()
                end,
              },
            },
          },
          -- Miscellaneous
          misc = {
            initial_tab = 1,
            tabs = {
              {
                name = "Colorschemes",
                tele_func = function()
                  builtin.colorscheme({ enable_preview = true })
                end,
              },
              {
                name = "Notify",
                tele_func = function()
                  extensions.notify.notify()
                end,
              },
              {
                name = "Undo History",
                tele_func = function()
                  extensions.undo.undo()
                end,
              },
            },
          },
        },
      })
    end,
  },
}
