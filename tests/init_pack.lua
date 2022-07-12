-- init.lua
vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=/tmp/nvim/site]])

local package_root = "/tmp/nvim/site/pack"
local install_path = package_root .. "/packer/start/packer.nvim"

local function load_plugins()
  require("packer").startup({
    function(use)
      use({ "wbthomason/packer.nvim" })
      use({
        "neovim/nvim-lspconfig",
        config = function()
          require("lspconfig").gopls.setup({})
        end,
      })
      use({ "ray-x/lsp_signature.nvim" })
    end,
    config = {
      package_root = package_root,
      compile_path = install_path .. "/plugin/packer_compiled.lua",
    },
  })
end

if vim.fn.isdirectory(install_path) == 0 then
  vim.fn.system({
    "git",
    "clone",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  })
  load_plugins()
  require("packer").sync()
else
  load_plugins()
end

vim.cmd("colorscheme murphy")

vim.cmd("syntax on")
require("lspconfig").tsserver.setup({})
require("lsp_signature").setup({})
