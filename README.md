# lsp_signature.nvim

This nvim plugin are made for completion plugin which does not support signature help.
Need neovim-0.5+ and enable nvim-lsp.

Part of the code was ported from [completion-nvim](https://github.com/nvim-lua/completion-nvim), which does have lots of cool features.

![lsp_signature_help.gif](https://github.com/ray-x/files/blob/master/img/sigature.gif?raw=true "signature")
![lua](https://user-images.githubusercontent.com/1681295/109505092-5b73fd80-7af0-11eb-9ec7-15b297c6e3be.png?raw=true "lua")

# Install:

```vim
" dein
dein#add('ray-x/lsp_signature.nvim')

" plug
Plug 'ray-x/lsp_signature.nvim'

" Packer
use {
  "ray-x/lsp_signature.nvim",
}
```

And in your init.lua

```lua
require'lsp_signature'.on_attach()
```

Some users reported the plugin not working for packer(which has nice lazy-loading feature). If the plugin does not work, you can attach the function in the lsp client on_attach. e.g.

```lua
local golang_setup = {
  on_attach = function(client, bufnr)
    if lsp_status ~= nil then
      lsp_status.on_attach(client, bufnr)
    end
    require "lsp_signature".on_attach()  -- Note: add in lsp client on-attach
    diagnostic_map(bufnr),
    ...
  end,
  ...
}
```
