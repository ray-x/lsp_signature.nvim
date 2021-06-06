# lsp_signature.nvim

Show function signature when you type

- This nvim plugin is made for completion plugins that do not support signature help.
  Need neovim-0.5+ and enable nvim-lsp.

- Part of the code was ported from [completion-nvim](https://github.com/nvim-lua/completion-nvim), which does have lots of cool features.

- Fully asynchronous lsp buf request.

- Virtual text available


Note: decorator = {"\`", "\`"} setup is deprecate

##### Golang with markdown
Highlight with "Search"
![signature2](https://user-images.githubusercontent.com/1681295/120245954-2d9a8280-c2b2-11eb-9fe9-f32f64a13512.gif)
##### Lua
![lua](https://user-images.githubusercontent.com/1681295/109505092-5b73fd80-7af0-11eb-9ec7-15b297c6e3be.png?raw=true "lua")

#### The plugin also re-write the builtin lsp signature allow the parameter highlight

![show_signature](https://github.com/ray-x/files/blob/master/img/navigator/show_signnature.gif?raw=true "show_signature")

#### Using virtual text to show the next parameter

![virtual_hint](https://github.com/ray-x/files/blob/master/img/signature/virtual_text.jpg?raw=true "show_virtual_text")

#### Virtual text only mode

(from @fdioguardi)

<img width="600" alt="virtual_text_only" src="https://user-images.githubusercontent.com/1681295/120172944-e3c88280-c246-11eb-95a6-40a0bbc1df9c.png">


#### Multiple signatures

In case some of the languages allow function overload, the plugin will show all available signatures

<img width="600" alt="multiple_signature" src="https://user-images.githubusercontent.com/1681295/120487194-17e3a500-c3f9-11eb-9561-82b3854694c5.png">
<img width="600" alt="signature2" src="https://user-images.githubusercontent.com/1681295/120487380-43ff2600-c3f9-11eb-9684-f6e7a1f8e170.png">

#### Scroll in side signature window

If max_height is set in the config and content exceed max_height, you can scroll up and down in signature window
to view the hiding content.


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

## Configure

### Floating window borders

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

### Full configuration

```lua

 cfg = {
  bind = true, -- This is mandatory, otherwise border config won't get registered.
               -- If you want to hook lspsaga or other signature handler, pls set to false
  doc_lines = 2, -- will show two lines of comment/doc(if there are more than two lines in doc, will be truncated);
                 -- set to 0 if you DO NOT want any API comments be shown
                 -- This setting only take effect in insert mode, it does not affect signature help in normal
                 -- mode, 10 by default

  floating_window = true, -- show hint in a floating window, set to false for virtual text only mode
  hint_enable = true, -- virtual hint enable
  hint_prefix = "🐼 ",  -- Panda for parameter
  hint_scheme = "String",
  use_lspsaga = false,  -- set to true if you want to use lspsaga popup
  hi_parameter = "Search", -- how your parameter will be highlight
  max_height = 12, -- max height of signature floating_window, if content is more than max_height, you can scroll down
                   -- to view the hiding contents
  max_width = 120, -- max_width of signature floating_window, line will be wrapped if exceed max_width
  handler_opts = {
    border = "shadow"   -- double, single, shadow, none
  },
  extra_trigger_chars = {} -- Array of extra characters that will trigger signature completion, e.g., {"(", ","}
  -- deprecate !!
  -- decorator = {"`", "`"}  -- this is no longer needed as nvim give me a handler and it allow me to highlight active parameter in floating_window

}

require'lsp_signature'.on_attach(cfg)
```

If you are using [navigator.lua](https://github.com/ray-x/navigator.lua), it will hook lsp_signature for you.

### Q&A:

Q: What is the default colorscheme in screenshot:

A: [aurora](https://github.com/ray-x/aurora)


Q: I can not see border after enable border = "single"

A: Try another colorscheme (e.g. colorscheme aurora, or colorscheme luna). If issue persists, please submit an issue


Q: It is not working 😡

A: Here is some trouble shooting: https://github.com/ray-x/lsp_signature.nvim/issues/1


Q:I do not like the pop window background highlight, how to change it?

A: Redefine your `NormalFloat` and `FloatBorder`, esp if your colorscheme dose not define it.


Q: How to change parameter highlight

A: By default, the highlight is using "Search" defined in your colorscheme, you can either override "Search" or
define, e.g. use `IncSearch`  on_attach({ hi_parameter = "IncSearch"})

Q: I can not see 🐼 in virtual text

A: It is emoji, not nerdfont. Please check how to enable emoji for your terminal.
