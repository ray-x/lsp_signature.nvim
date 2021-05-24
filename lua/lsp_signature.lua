local vim = vim -- suppress warning
local api = vim.api
local M = {}
_VT_NS = api.nvim_create_namespace("lsp_signature")
local helper = require "lsp_signature_helper"

local match_parameter = helper.match_parameter
local check_trigger_char = helper.check_trigger_char

local manager = {
  insertChar = false, -- flag for InsertCharPre event, turn off imediately when performing completion
  insertLeave = false, -- flag for InsertLeave, prevent every completion if true
  changedTick = 0, -- handle changeTick
  confirmedCompletion = false -- flag for manual confirmation of completion
}

_LSP_SIG_CFG = {
  bind = true, -- This is mandatory, otherwise border config won't get registered.
  -- if you want to use lspsaga, please set it to false
  doc_lines = 2, -- how many lines to show in doc, set to 0 if you only want the signature
  hint_enable = true, -- virtual hint
  hint_prefix = "🐼 ",
  hint_scheme = "String",
  handler_opts = {border = "shadow"},
  use_lspsaga = false,
  debug = false,
  decorator = {"`", "`"} -- set to nil if using guihua.lua
}

local function log(...)
  local arg = {...}
  if _LSP_SIG_CFG.debug == true then
    local str = "שׁ "
    for i, v in ipairs(arg) do
      if type(v) == "table" then
        str = str .. " |" .. tostring(i) .. ": " .. vim.inspect(v) .. "\n"
      else
        str = str .. " |" .. tostring(i) .. ": " .. tostring(v)
      end
    end
    if #str > 2 then
      if M.log_path ~= nil and #M.log_path > 3 then
        local f = io.open(M.log_path, "a+")
        io.output(f)
        io.write(str)
        io.close(f)
      else
        print(str .. "\n")
      end
    end
  end
end

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
  local r = vim.api.nvim_win_get_cursor(0)
  local cur_line = r[1] - 1
  local show_at = cur_line - 1 -- show above
  local lines_above = vim.fn.winline() - 1
  local lines_below = vim.fn.winheight(0) - lines_above
  if lines_above > lines_below then
    show_at = cur_line + 1 -- same line
  end
  if cur_line == 0 then
    show_at = 0
  end

  -- get previous line
  local pl = vim.api.nvim_buf_get_lines(0, show_at, show_at + 1, false)[1]
  if pl == nil then
    show_at = cur_line -- no lines below
  end
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

-- ----------------------
-- --  signature help  --
-- ----------------------
local function signature_handler(err, method, result, client_id, bufnr, config)
  -- log(result)
  if config.check_client_handlers then
    local client = vim.lsp.get_client_by_id(client_id)
    local handler = client and client.handlers["textDocument/signatureHelp"]
    if handler then
      handler(err, method, result, client_id, bufnr, config)
      return
    end
  end
  if not (result and result.signatures and result.signatures[1]) then
    return
  end
  local _, hint = match_parameter(result)
  local lines = vim.lsp.util.convert_signature_help_to_markdown_lines(result)
  local doc_num = _LSP_SIG_CFG.doc_lines or 12
  if vim.fn.mode() == 'i' or vim.fn.mode() == 'ic' then
    -- truncate the doc?
    if #lines > doc_num + 1 then
      if doc_num == 0 then
        lines = vim.list_slice(lines, 1, 1)
      else
        lines = vim.list_slice(lines, 1, doc_num + 1)
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
    lines = vim.lsp.util.trim_empty_lines(lines)
    vim.lsp.util.try_trim_markdown_code_blocks(lines)
  else
    local rand = math.random(1, 1000)
    local id = string.format("%d", rand)
    vim.lsp.util.focusable_preview(method .. "lsp_signature" .. id, function()
      lines = vim.lsp.util.trim_empty_lines(lines)
      return lines, vim.lsp.util.try_trim_markdown_code_blocks(lines), config
    end)
  end
  if _LSP_SIG_CFG.hint_enable == true then
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

  local triggered_chars = {}
  local total_lsp = 0
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

    if value.server_capabilities.signatureHelpProvider ~= nil
        and value.server_capabilities.signatureHelpProvider.triggerCharacters ~= nil then
      triggered_chars = value.server_capabilities.signatureHelpProvider.triggerCharacters
    elseif value.resolved_capabilities ~= nil
        and value.resolved_capabilities.signature_help_trigger_characters ~= nil then
      triggered_chars = value.server_capabilities.signature_help_trigger_characters
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
                          trigger_from_lsp_sig = true
                        }))
    -- LuaFormatter on
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

local function config(opts)
  opts = opts or {}
  if next(opts) == nil then
    return
  end
  _LSP_SIG_CFG = vim.tbl_extend("keep", opts, _LSP_SIG_CFG)
end

M.on_attach = function(cfg)
  api.nvim_command("augroup Signature")
  api.nvim_command("autocmd! * <buffer>")
  api.nvim_command("autocmd InsertEnter <buffer> lua require'lsp_signature'.on_InsertEnter()")
  api.nvim_command("autocmd InsertLeave <buffer> lua require'lsp_signature'.on_InsertLeave()")
  api.nvim_command("autocmd InsertCharPre <buffer> lua require'lsp_signature'.on_InsertCharPre()")
  api.nvim_command("autocmd CompleteDone <buffer> lua require'lsp_signature'.on_CompleteDone()")
  api.nvim_command("augroup end")
  config(cfg)
  cfg = cfg or _LSP_SIG_CFG
  if cfg.bind then
    vim.lsp.handlers["textDocument/signatureHelp"] =
        vim.lsp.with(signature_handler, _LSP_SIG_CFG.handler_opts)
  end
end

return M
