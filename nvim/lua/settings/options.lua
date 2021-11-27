options = {
    nu = true;
    relativenumber = true;
    showcmd = true;
    wildmenu = true;
    hlsearch = true;
    incsearch = true;
    expandtab = true;
    smarttab = true;
    tabstop = 4;
    shiftwidth = 4;
    scrolloff = 4;
    cmdheight = 2;
    hidden = true;
    fileencodings = "utf-8,ucs-bom,gb18030,gbk,gb2312";
    fileformats = unix;
    ignorecase = true;
    smartcase = true;
}

for o,v in pairs(options) do
    vim.opt[o] = v
end
