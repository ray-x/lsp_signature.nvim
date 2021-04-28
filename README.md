# lsp_signature.nvim

This nvim plugin are made for completion plugin which does not support signature help.
Need neovim-0.5+ and enable nvim-lsp.

Part of the code was ported from [completion-nvim](https://github.com/nvim-lua/completion-nvim), which does have lots of cool features.

In order to highlight the parameters that are typing, I am using "\`" to force highlight in markdown. So the hint will look
like :

```go
myfunc(`parameter1 int`, parameter2 int)
```

This does not mean parameter1 is a string type.
You can argue that using _parameter1_ or **parameter1**. But those are hard to tell as the font rendering in terminal are
not as good as web browser

![lsp_signature_help.gif](https://github.com/ray-x/files/blob/master/img/signature/sigature.gif?raw=true "signature")

![lua](https://user-images.githubusercontent.com/1681295/109505092-5b73fd80-7af0-11eb-9ec7-15b297c6e3be.png?raw=true "lua")

The plugin also re-write the builtin lsp sigature allow the parameter highlight
![show_signature](https://github.com/ray-x/files/blob/master/img/navigator/show_signnature.gif?raw=true "show_signature")

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

Some users reported the plugin not working for packer(which has a nice lazy-loading feature). If the plugin does not work, you can attach the function in the lsp client on_attach. e.g.

```lua
local golang_setup = {
  on_attach = function(client, bufnr)
    ...
    require "lsp_signature".on_attach()  -- Note: add in lsp client on-attach
    ...
  end,
  ...
}
```

## Floating window borders

If you have a recent enough build of Neovim, you can configure borders in the signature help
floating window:

```lua
local example_setup = {
  on_attach = function(client, bufnr)
    ...
    require "lsp_signature".on_attach({
      bind = true, -- This is mandatory, otherwise border config won't get registered.
      handler_opts = {
        border = "single"
      }
    })
    ...
  end,
  ...
}
```

Thanks [@Gabriel Sanches](https://github.com/gbrlsnchs) for the PR
![lsp_signature_border](https://github.com/ray-x/files/blob/master/img/signature/signature_boarder.jpg?raw=true "signature")

If you are using [navigator.lua](https://github.com/ray-x/navigator.lua). navigator will setup lsp_signature for you.
