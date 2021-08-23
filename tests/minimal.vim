set rtp +=.
set rtp +=../plenary.nvim/


runtime! plugin/plenary.vim


set noswapfile
set nobackup

filetype indent off
set nowritebackup
set noautoindent
set nocindent
set nosmartindent
set indentexpr=


lua << EOF
_G.test_rename = true
_G.test_close = true
require("plenary/busted")
require("lsp_signature").setup()
EOF
