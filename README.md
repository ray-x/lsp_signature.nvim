# lsp_signature.nvim

This nvim plugin are made for completion plugin which does not support signature help.
Need neovim-0.5+ and nvim-lsp support.

![lsp_signature_help.gif](/img/sigature.gif?raw=true "signature")

# Install:

```vim
dein#add('ray-x/lsp_signature.nvim')
```

And in your init.lua

```lua
require'lsp_signature'.on_attach()
```
