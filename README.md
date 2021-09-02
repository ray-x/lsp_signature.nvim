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

https://user-images.githubusercontent.com/1681295/122633027-a7879400-d119-11eb-95ff-d06e6aeeb0b2.mov

##### Lua
![lua](https://user-images.githubusercontent.com/1681295/109505092-5b73fd80-7af0-11eb-9ec7-15b297c6e3be.png?raw=true "lua")

#### The plugin also re-write the builtin lsp signature allow the parameter highlight
<img width="1230" alt="signature_with_virtual_hint" src="https://user-images.githubusercontent.com/1681295/122689853-11628380-d269-11eb-994f-65974fb1312d.png">


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

# Attach the plugin

In your init.lua

Call on_attach() when the LSP client attaches to a buffer

e.g. gopls:

```lua
local golang_setup = {
  on_attach = function(client, bufnr)
    ...
    require "lsp_signature".on_attach()  -- Note: add in lsp client on-attach
    ...
  end,
  ...
}

require'lspconfig'.gopls.setup(golang_setup)

```


Alternatively, use setup function

```vim
require "lsp_signature".setup()
```


## Configure

### Floating window borders

If you have a recent enough build of Neovim, you can configure borders in the signature help
floating window(Thanks [@Gabriel Sanches](https://github.com/gbrlsnchs) for the PR):

```lua
local example_setup = {
  on_attach = function(client, bufnr)
    ...
    require "lsp_signature".on_attach({
      bind = true, -- This is mandatory, otherwise border config won't get registered.
      handler_opts = {
        border = "single"
      }
    }, bufnr)
    ...
  end,
  ...
}
```

Or:

```lua
  require'lspconfig'.gopls.setup()
  require "lsp_signature".setup({
    bind = true, -- This is mandatory, otherwise border config won't get registered.
    handler_opts = {
      border = "single"
    }
  })

```

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
  fix_pos = false,  -- set to true, the floating window will not auto-close until finish all parameters
  hint_enable = true, -- virtual hint enable
  hint_prefix = "🐼 ",  -- Panda for parameter
  hint_scheme = "String",
  use_lspsaga = false,  -- set to true if you want to use lspsaga popup
  hi_parameter = "Search", -- how your parameter will be highlight
  max_height = 12, -- max height of signature floating_window, if content is more than max_height, you can scroll down
                   -- to view the hiding contents
  max_width = 120, -- max_width of signature floating_window, line will be wrapped if exceed max_width
  transpancy = 10, -- set this value if you want the floating windows to be transpant (100 fully transpant), nil to disable(default)
  handler_opts = {
    border = "shadow"   -- double, single, shadow, none
  },

  trigger_on_newline = false, -- set to true if you need multiple line parameter, sometime show signature on new line can be confusing, set it to false for #58
  extra_trigger_chars = {}, -- Array of extra characters that will trigger signature completion, e.g., {"(", ","}
  -- deprecate !!
  -- decorator = {"`", "`"}  -- this is no longer needed as nvim give me a handler and it allow me to highlight active parameter in floating_window
  zindex = 200, -- by default it will be on top of all floating windows, set to 50 send it to bottom
  debug = false, -- set to true to enable debug logging
  log_path = "debug_log_file_path", -- debug log path

  padding = '', -- character to pad on left and right of signature can be ' ', or '|'  etc

  shadow_blend = 36, -- if you using shadow as border use this set the opacity
  shadow_guibg = 'Black', -- if you using shadow as border use this set the color e.g. 'Green' or '#121315'
  toggle_key = nil -- toggle signature on and off in insert mode,  e.g. toggle_key = '<M-x>'
}

require'lsp_signature'.on_attach(cfg, bufnr) -- no need to specify bufnr if you don't use toggle_key
```
Note: navigator.lua no longer support auto setup for lsp_signature as the setup options is getting more complicated now

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
