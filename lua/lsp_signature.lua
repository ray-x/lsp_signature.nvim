local vim = vim -- suppress warning
local api = vim.api
local M = {}
_VT_NS = api.nvim_create_namespace("lsp_signature")
local helper = require "lsp_signature_helper"
local match_parameter = helper.match_parameter
local check_trigger_char = helper.check_trigger_char
local check_closer_char = helper.check_closer_char

local manager = {
  insertChar = false, -- flag for InsertCharPre event, turn off imediately when performing completion
  insertLeave = false, -- flag for InsertLeave, prevent every completion if true
  changedTick = 0, -- handle changeTick
  confirmedCompletion = false -- flag for manual confirmation of completion
}

_LSP_SIG_CFG = {
  bind = true, -- This is mandatory, otherwise border config won't get registered.
  -- if you want to use lspsaga, please set it to false
  doc_lines = 10, -- how many lines to show in doc, set to 0 if you only want the signature
  max_height = 12, -- max height of signature floating_window
  max_width = 120, -- max_width of signature floating_window

  floating_window = true, -- show hint in a floating window
  fix_pos = true, -- fix floating_window position
  hint_enable = true, -- virtual hint
  hint_prefix = "🐼 ",
  hint_scheme = "String",
  hi_parameter = "Search",
  handler_opts = {border = "single"},
  use_lspsaga = false,
  debug = false,
  extra_trigger_chars = {} -- Array of extra characters that will trigger signature completion, e.g., {"(", ","}
  -- decorator = {"`", "`"} -- set to nil if using guihua.lua
}

local double = {"╔", "═", "╗", "║", "╝", "═", "╚", "║"}
local single = {"╭", "─", "╮", "│", "╯", "─", "╰", "│"}

local log = helper.log

function manager.init()
  manager.insertLeave = false
  manager.insertChar = false
  manager.confirmedCompletion = false
end

local function virtual_hint(hint)
  if hint == nil or hint == "" then
    return
  end
  local r = vim.api.nvim_win_get_cursor(0)
  local line = api.nvim_get_current_line()
  local line_to_cursor = line:sub(1, r[2])
  local cur_line = r[1] - 1
  local show_at = cur_line - 1 -- show at above line
  local lines_above = vim.fn.winline() - 1
  local lines_below = vim.fn.winheight(0) - lines_above
  if lines_above > lines_below then
    show_at = cur_line + 1 -- same line
  end
  local pl
  if _LSP_SIG_CFG.floating_window == false then
    local prev_line, next_line
    if cur_line > 0 then
      prev_line = vim.api.nvim_buf_get_lines(0, cur_line - 1, cur_line, false)[1]
    end
    next_line = vim.api.nvim_buf_get_lines(0, cur_line + 1, cur_line + 2, false)[1]
    -- log(prev_line, next_line, r)
    if prev_line and #prev_line < r[2] + 2 then
      show_at = cur_line - 1
      pl = prev_line
    elseif next_line and #next_line < r[2] + 2 then
      show_at = cur_line + 1
      pl = next_line
    else
      show_at = cur_line
    end
  end

  if cur_line == 0 then
    show_at = 0
  end
  -- get show at line
  if not pl then
    pl = vim.api.nvim_buf_get_lines(0, show_at, show_at + 1, false)[1]
  end
  if pl == nil then
    show_at = cur_line -- no lines below
  end

  -- log("virtual text: ", cur_line, show_at)
  pl = pl or ""
  local pad = ""
  if show_at ~= cur_line and #line_to_cursor > #pl + 1 then
    pad = string.rep(" ", #line_to_cursor - #pl)
  end

  vim.api.nvim_buf_clear_namespace(0, _VT_NS, 0, -1)
  if r ~= nil then
    vim.api.nvim_buf_set_virtual_text(0, _VT_NS, show_at, {
      {pad .. _LSP_SIG_CFG.hint_prefix .. hint, _LSP_SIG_CFG.hint_scheme}
    }, {})
  end
end

local close_events = {"CursorMoved", "CursorMovedI", "BufHidden", "InsertCharPre"}

-- ----------------------
-- --  signature help  --
-- ----------------------
local function signature_handler(err, method, result, client_id, bufnr, config)
  log("sig result", result, config)
  if err ~= nil then
    print(err)
  end
  if config.check_client_handlers then
    local client = vim.lsp.get_client_by_id(client_id)
    local handler = client and client.handlers["textDocument/signatureHelp"]
    if handler then
      log(" using 3rd handler")
      handler(err, method, result, client_id, bufnr, config)
      return
    end
  end
  if not (result and result.signatures and result.signatures[1]) then
    log("no result?", result)
    return
  end
  local _, hint, s, l = match_parameter(result, config)
  local force_redraw = false
  if #result.signatures > 1 then
    force_redraw = true
  end
  if _LSP_SIG_CFG.floating_window == true or not config.trigger_from_lsp_sig then
    local ft = vim.api.nvim_buf_get_option(bufnr, "ft")
    local lines = vim.lsp.util.convert_signature_help_to_markdown_lines(result, ft)

    if lines == nil then
        return
    end

    local offset = 3
    if #result.signatures > 1 and result.activeSignature ~= nil then
      for index, sig in ipairs(result.signatures) do
        if index ~= result.activeSignature + 1 then
          table.insert(lines, offset, sig.label)
          offset = offset + 1
        end
      end
    end
    local label = result.signatures[1].label
    -- log("label:", label, result.activeSignature, result.activeParameter,
    --    #result.signatures[1].parameters)
    local woff
    if config.triggered_chars and vim.tbl_contains(config.triggered_chars, '(') then
      woff = label:find('(', 1, true)
      if woff then
        woff = -woff
      else
        woff = -3
      end
    end

    local doc_num = 3 + _LSP_SIG_CFG.doc_lines
    if doc_num < 3 then
      doc_num = 3
    end
    if vim.fn.mode() == 'i' or vim.fn.mode() == 'ic' then
      -- truncate the doc?
      if lines ~= nil then
        if #lines > doc_num + 1 then
          if doc_num == 0 then
            lines = vim.list_slice(lines, 1, offset + 1)
          else
            lines = vim.list_slice(lines, 1, doc_num + offset + 1)
          end
        end
      end
    end

    if vim.tbl_isempty(lines) then
      return
    end

    if config.check_pumvisible and vim.fn.pumvisible() ~= 0 then
      return
    end

    lines = vim.lsp.util.trim_empty_lines(lines)
    if config.trigger_from_lsp_sig == true and _LSP_SIG_CFG.preview == "guihua" then
      vim.lsp.util.try_trim_markdown_code_blocks(lines)
      -- This is a TODO
      error("guihua text view not supported yet")
    end

    local rand = math.random(1, 1000)
    local id = string.format("%d", rand)

    local syntax = vim.lsp.util.try_trim_markdown_code_blocks(lines)

    config.max_height = math.max(_LSP_SIG_CFG.max_height, 1)
    if config.max_height <= 3 then
      config.separator = false
    end
    config.max_width = math.max(_LSP_SIG_CFG.max_width, 60)

    config.focus_id = method .. "lsp_signature" .. id
    config.stylize_markdown = true
    if config.border == "double" then
      config.border = double
    end
    if config.border == "single" then
      config.border = single
    end
    config.offset_x = woff

    config.close_events = {'BufHidden', 'InsertLeavePre'}
    if not _LSP_SIG_CFG.fix_pos then
      config.close_events = close_events
    end
    if not config.trigger_from_lsp_sig then
      config.close_events = close_events
    end
    if force_redraw then
      config.close_events = close_events
    end
    config.zindex = 1000 -- TODO: does it work?
    -- fix pos case
    if _LSP_SIG_CFG.fix_pos and _LSP_SIG_CFG.bufnr and _LSP_SIG_CFG.winnr then
      if api.nvim_win_is_valid(_LSP_SIG_CFG.winnr) then
        -- check last parameter and update hilight
        if _LSP_SIG_CFG.ns then
          log("bufnr, ns", _LSP_SIG_CFG.bufnr, _LSP_SIG_CFG.ns)
          api.nvim_buf_clear_namespace(_LSP_SIG_CFG.bufnr, _LSP_SIG_CFG.ns, 0, -1)
        end
        _LSP_SIG_CFG.markid = nil
        _LSP_SIG_CFG.ns = nil
      else
        log("sig_cfg bufnr, winnr not valid", _LSP_SIG_CFG.bufnr, _LSP_SIG_CFG.winnr)
        -- vim.api.nvim_win_close(_LSP_SIG_CFG.winnr, true)
        _LSP_SIG_CFG.bufnr, _LSP_SIG_CFG.winnr = vim.lsp.util.open_floating_preview(lines, syntax,
                                                                                    config)

      end
    else
      _LSP_SIG_CFG.bufnr, _LSP_SIG_CFG.winnr = vim.lsp.util.open_floating_preview(lines, syntax,
                                                                                  config)
    end
    local sig = result.signatures
    -- log("sig", result)
    -- if it is last parameter, close windows after cursor moved
    if sig and sig[1].parameters == nil or result.activeParameter == nil or result.activeParameter
        + 1 == #sig[1].parameters then
      log("last para", close_events)
      vim.lsp.util.close_preview_autocmd(close_events, _LSP_SIG_CFG.winnr)
      -- elseif _LSP_SIG_CFG.fix_pos then
      --   log("should not close")
      --   -- vim.lsp.util.close_preview_autocmd(ce, _LSP_SIG_CFG.winnr)
    end
    -- Not sure why this not working
    -- api.nvim_command("autocmd User SigComplete".." <buffer> ++once lua pcall(vim.api.nvim_win_close, "..winnr..", true)")
    _LSP_SIG_CFG.ns = vim.api.nvim_create_namespace('lsp_signature_hi_parameter')
    local hi = _LSP_SIG_CFG.hi_parameter
    if s and l and s > 0 then
      _LSP_SIG_CFG.markid = vim.api.nvim_buf_set_extmark(_LSP_SIG_CFG.bufnr, _LSP_SIG_CFG.ns, 0,
                                                         s - 1,
                                                         {end_line = 0, end_col = l, hl_group = hi})
    else
      print("failed get highlight parameter", s, l)
    end

  end

  if _LSP_SIG_CFG.hint_enable == true and config.trigger_from_lsp_sig then
    virtual_hint(hint)
  end
end

local signature = function()
  local pos = api.nvim_win_get_cursor(0)
  local line = api.nvim_get_current_line()
  local line_to_cursor = line:sub(1, pos[2])
  local clients = vim.lsp.buf_get_clients(0)
  if clients == nil or clients == {} then
    return
  end

  local triggered = false
  local signature_cap = false
  local hover_cap = false

  local total_lsp = 0

  local triggered_chars = {}
  for _, value in pairs(clients) do
    if value == nil then
      goto continue
    end
    if value.resolved_capabilities.signature_help == true
        or value.server_capabilities.signatureHelpProvider ~= nil then
      signature_cap = true
      total_lsp = total_lsp + 1
    else
      goto continue
    end

    local h = value.resolved_capabilities.hover

    if h == true or (h ~= nil and h ~= {}) then
      hover_cap = true
    end

    if value.server_capabilities.signatureHelpProvider ~= nil then
      if value.server_capabilities.signatureHelpProvider.triggerCharacters ~= nil then
        triggered_chars = value.server_capabilities.signatureHelpProvider.triggerCharacters
      end
      if value.server_capabilities.signatureHelpProvider.retriggerCharacters ~= nil then
        vim.list_extend(triggered_chars,
                        value.server_capabilities.signatureHelpProvider.retriggerCharacters)
      end
      if _LSP_SIG_CFG.extra_trigger_chars ~= nil then
        vim.list_extend(triggered_chars, _LSP_SIG_CFG.extra_trigger_chars)
      end
    elseif value.resolved_capabilities ~= nil
        and value.resolved_capabilities.signature_help_trigger_characters ~= nil then
      triggered_chars = value.server_capabilities.signature_help_trigger_characters
    elseif value.resolved_capabilities and value.resolved_capabilities.signatureHelpProvider
        and value.resolved_capabilities.signatureHelpProvider.triggerCharacters then
      triggered_chars = value.server_capabilities.signatureHelpProvider.triggerCharacters
    end
    if triggered == false then
      triggered = check_trigger_char(line_to_cursor, triggered_chars)
    end
    ::continue::
  end

  if hover_cap == false then
    log("hover not supported")
  end

  if total_lsp > 1 then
    log("you have multiple lsp with signatureHelp enabled")
  end
  if signature_cap == false then
    return
  end

  if triggered then
    if _LSP_SIG_CFG.use_lspsaga then
      local ok, saga = pcall(require, "lspsaga.signaturehelp")
      if ok then
        saga.signature_help()
        return
      else
        print("Check your config, lspsaga not configured correctly")
      end
    end
    -- overwrite signature help here to disable "no signature help" message
    local params = vim.lsp.util.make_position_params()
    -- Try using the already binded one, otherwise use it without custom config.
    -- LuaFormatter off
    vim.lsp.buf_request(0, "textDocument/signatureHelp", params,
                        vim.lsp.with(vim.lsp.handlers["textDocument/signatureHelp"] or signature_handler, {
                          check_pumvisible = true,
                          check_client_handlers = true,
                          trigger_from_lsp_sig = true,
                          line_to_cursor = line_to_cursor,
                          triggered_chars = triggered_chars
                        }))
    -- LuaFormatter on
  else
    -- check if we should close the signature
    if _LSP_SIG_CFG.winnr and _LSP_SIG_CFG.winnr > 0
        and check_closer_char(line_to_cursor, trigger_chars) then
      vim.api.nvim_win_close(_LSP_SIG_CFG.winnr, true)
      _LSP_SIG_CFG.winnr = nil
      _LSP_SIG_CFG.startx = nil
    end
  end
end

M.signature = signature

function M.on_InsertCharPre()
  manager.insertChar = true
end

function M.on_InsertLeave()
  manager.insertLeave = true
end

function M.on_InsertEnter()
  local timer = vim.loop.new_timer()
  -- setup variable
  manager.init()

  timer:start(100, 100, vim.schedule_wrap(function()
    local l_changedTick = api.nvim_buf_get_changedtick(0)
    -- closing timer if leaving insert mode
    if l_changedTick ~= manager.changedTick then
      manager.changedTick = l_changedTick
      signature()
    end
    if manager.insertLeave == true and timer:is_closing() == false then
      timer:stop()
      timer:close()
      vim.api.nvim_buf_clear_namespace(0, _VT_NS, 0, -1)
    end
  end))
end

-- handle completion confirmation and dismiss hover popup
-- Note: this function may not work, depends on if complete plugin add parents or not
function M.on_CompleteDone()
  -- need auto brackets to make things work
  -- signature()
  -- cleanup virtual hint
  vim.api.nvim_buf_clear_namespace(0, _VT_NS, 0, -1)
end

M.on_attach = function(cfg)
  api.nvim_command("augroup Signature")
  api.nvim_command("autocmd! * <buffer>")
  api.nvim_command("autocmd InsertEnter <buffer> lua require'lsp_signature'.on_InsertEnter()")
  api.nvim_command("autocmd InsertLeave <buffer> lua require'lsp_signature'.on_InsertLeave()")
  api.nvim_command("autocmd InsertCharPre <buffer> lua require'lsp_signature'.on_InsertCharPre()")
  api.nvim_command("autocmd CompleteDone <buffer> lua require'lsp_signature'.on_CompleteDone()")
  api.nvim_command("augroup end")

  if type(cfg) == "table" then
    _LSP_SIG_CFG = vim.tbl_extend("keep", cfg, _LSP_SIG_CFG)
  end

  vim.cmd([[hi default FloatBorder guifg = #777777]])
  if _LSP_SIG_CFG.bind then
    vim.lsp.handlers["textDocument/signatureHelp"] =
        vim.lsp.with(signature_handler, _LSP_SIG_CFG.handler_opts)
  end
end

return M
