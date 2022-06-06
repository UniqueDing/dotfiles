local gl = require('galaxyline')
local gls = gl.section
local extension = require('galaxyline.providers.extensions')

-- This is Denstiny write
-- My home page https://github.com/denstiny

gl.short_line_list = {
    'LuaTree',
    'vista',
    'floaterm',
    'dbui',
    'startify',
    'term',
    'nerdtree',
    'fugitive',
    'fugitiveblame',
    'plug'
}

VistaPlugin = extension.vista_nearest

local colors = {
    -- bg = '#282c34',
    -- line_bg = '#7D0AB2',
    fg = '#8FBCBB',
    NameColor = '#5B4B70',
    fg_green = '#65a380',
    cocColor = '#1592A5',
    yellow = '#fabd2f',
    cyan = '#008080',
    darkblue = '#081633',
    green = '#AB47BC',
    orange = '#FF8800',
    purple = '#5d4d7a',
    magenta = '#c678dd',
    blue = '#51afef';
    red = '#ec5f67'
}


local function trailing_whitespace()
    local trail = vim.fn.search("\\s$", "nw")
    if trail ~= 0 then
        return ' '
    else
        return nil
    end
end

TrailingWhiteSpace = trailing_whitespace

local function has_file_type()
    local f_type = vim.bo.filetype
    if not f_type or f_type == '' then
        return false
    end
    return true
end

local buffer_not_empty = function()
  if vim.fn.empty(vim.fn.expand('%:t')) ~= 1 then
    return true
  end
  return false
end

gls.left[2] = {
  ViMode = {
    provider = function()
      -- auto change color according the vim mode
      local alias = {
          n = '▋ ',
          i = '▋ ',
          c = '▋ ',
          V = '▋ ',
          [''] = '▋ ',
          v ='▋ ',
          ['r?'] = '▋ ',
          rm = '▋ ',
          R  = '▋ ',
          Rv = '▋ ',
          s  = '▋ ',
          S  = '▋ ',
          ['r']  = '▋ ',
          [''] = '▋ ',
          t  = '▋ ',
          ['!']  = '▋ ',
      }
      local mode_color = {
          n = colors.green,
          i = colors.blue,
          v=colors.magenta,
          [''] = colors.blue,
          V=colors.blue,
          no = colors.magenta,
          s = colors.orange,
          S=colors.orange,
          [''] = colors.orange,
          ic = colors.yellow,
          cv = colors.red,
          ce=colors.red,
          ['r?'] = colors.cyan,
          ['!']  = colors.green,
          t = colors.green,
          c  = colors.purple,
          r  = colors.red,
          rm = colors.red,
          R  = colors.yellow,
          Rv = colors.magenta,
      }
      local vim_mode = vim.fn.mode()
      vim.api.nvim_command('hi GalaxyViMode guifg='..mode_color[vim_mode])
      return alias[vim_mode] .. ' '
    end,
    highlight = {colors.red,colors.line_bg,'bold'},
  },
}

gls.left[3] = {
	BOOLNS = {
    provider = function()
		end,
		separator = '',
    condition = buffer_not_empty,
    separator_highlight = {colors.NameColor,colors.bg}
	}
}

gls.left[5] = {
  ShowLspClient = {
    provider = 'GetLspClient',
    condition = function ()
      local tbl = {['dashboard'] = true,['']=true}
      if tbl[vim.bo.filetype] then
        return false
      end
      return true
    end,
    separator = ' ',
    separator_highlight = {colors.NameColor,colors.bg},
    highlight = {colors.fg,colors.NameColor,'bold'}
  }
}

gls.left[6] = {
  GitIcon = {
    provider = function() return ' ' end,
    condition = require('galaxyline.providers.vcs').check_git_workspace,
    highlight = {colors.orange,colors.line_bg},
  }
}
gls.left[7] = {
  GitBranch = {
    provider = 'GitBranch',
    condition = require('galaxyline.providers.vcs').check_git_workspace,
    separator = ' ',
    highlight = {colors.line_bg,'bold'},
  }
}

gls.left[8] = {
    vista_nearest = {
        provider = VistaPlugin,
    }
}

local checkwidth = function()
  local squeeze_width  = vim.fn.winwidth(0) / 2
  if squeeze_width > 40 then
    return true
  end
  return false
end


gls.right[1] = {
  DiagnosticError = {
    provider = 'DiagnosticError',
    icon = '   ',
    highlight = {colors.red,colors.bg}
  }
}

gls.right[2] = {
  DiagnosticWarn = {
    provider = 'DiagnosticWarn',
    icon = '   ',
    highlight = {colors.yellow,colors.bg},
  }
}
gls.right[3] = {
  DiffAdd = {
    provider = 'DiffAdd',
    condition = checkwidth,
    icon = ' ',
    highlight = {colors.green,colors.line_bg},
  }
}
gls.right[4] = {
  DiffModified = {
    provider = 'DiffModified',
    condition = checkwidth,
    icon = ' ',
    highlight = {colors.orange,colors.line_bg},
  }
}
gls.right[5] = {
  DiffRemove = {
    provider = 'DiffRemove',
    condition = checkwidth,
    icon = '  ',
    highlight = {colors.red,colors.line_bg},
  }
}
gls.right[6] = {
    TrailingWhiteSpace = {
     provider = TrailingWhiteSpace,
     icon = '   ',
     highlight = {colors.yellow,colors.bg},
    }
}
--
-- gls.right[2] = {
--     Space = {
--         provider = function () return ' ' end
--     }
-- }

gls.right[7] = {
  FileSize = {
    provider = 'FileSize',
    condition = buffer_not_empty,
    highlight = {colors.cocColor,colors.line_bg}
  }
}

gls.right[8] = {
  LineInfo = {
    provider = 'LineColumn',
    highlight = {colors.fg,colors.line_bg},
  },
}
gls.right[9] = {
    ScrollBar = {
        provider = 'ScrollBar',
        -- separator = ' ● ',
        -- separator_highlight = {colors.blue,colors.line_bg},
        highlight = {colors.yellow,colors.bg},
    }
}

gls.short_line_left[2] = {
	BOOLNS = {
    provider = function()
		end,
		separator = '',
    condition = buffer_not_empty,
    separator_highlight = {colors.NameColor,colors.bg}
	}
}

gls.short_line_left[3] = {
  BufferType = {
    provider = 'FileTypeName',
    separator = '',
    condition = has_file_type,
    separator_highlight = {colors.purple,colors.bg},
    highlight = {colors.fg,colors.purple}
  }
}
