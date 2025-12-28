return {
  {
    "nvim-mini/mini.ai",
    event = "VeryLazy",
    opts = function()
      return {
        mappings = {
          -- Main textobject prefixes
          around = 'a',
          inside = 'l',

          -- Next/last variants
          around_next = 'an',
          inside_next = 'ln',
          around_last = 'al',
          inside_last = 'll',
        },
      }
    end,
  },
}
