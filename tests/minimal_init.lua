local plenary_path = "/home/eazy/.local/share/nvim/lazy/plenary.nvim"
local current_dir = vim.fn.getcwd()

vim.opt.rtp:append(plenary_path)
vim.opt.rtp:append(current_dir)

vim.cmd("runtime! plugin/plenary.vim")
