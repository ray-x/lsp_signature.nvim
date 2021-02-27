# lsp_signature.nvim

This nvim plugin are made for completion plugin which does not support signature help.
Need neovim-0.5+ and enable nvim-lsp.

Part of the code was ported from [completion-nvim](https://github.com/nvim-lua/completion-nvim), which does have lots of cool features.

![lsp_signature_help.gif](https://github.com/ray-x/files/blob/master/img/sigature.gif?raw=true "signature")

# Install:

```vim
dein#add('ray-x/lsp_signature.nvim')


Plug 'ray-x/lsp_signature.nvim'
```

And in your init.lua

```lua
require'lsp_signature'.on_attach()
```
