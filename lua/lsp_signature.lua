local vim = vim -- suppress warning
local api = vim.api
local M = {}

local helper = require "lsp_signature_helper"

local match_parameter = helper.match_parameter
local check_trigger_char = helper.check_trigger_char

local manager = {
  insertChar = false, -- flag for InsertCharPre event, turn off imediately when performing completion
  insertLeave = false, -- flag for InsertLeave, prevent every completion if true
  changedTick = 0, -- handle changeTick
  confirmedCompletion = false -- flag for manual confirmation of completion
}
function manager.init()
  manager.insertLeave = false
  manager.insertChar = false
  manager.confirmedCompletion = false
end

-- ----------------------
-- --  signature help  --
-- ----------------------
local signature = function()
  local pos = api.nvim_win_get_cursor(0)
  local line = api.nvim_get_current_line()
  local line_to_cursor = line:sub(1, pos[2])
  if vim.lsp.buf_get_clients() == nil then
    return
  end

  local triggered
  local signature_cap = false
  local hover_cap = false

  local triggered_chars = {}
  for _, value in pairs(vim.lsp.buf_get_clients(0)) do
    if value == nil then
      goto continue
    end
    if value.resolved_capabilities.signature_help == true or value.server_capabilities.signatureHelpProvider ~= nil then
      signature_cap = true
    else
      goto continue
    end

    if value.resolved_capabilities.hover == true then
      hover_cap = true
    end

    if
      value.server_capabilities.signatureHelpProvider ~= nil and
        value.server_capabilities.signatureHelpProvider.triggerCharacters ~= nil
     then
      triggered_chars = value.server_capabilities.signatureHelpProvider.triggerCharacters
    elseif value.resolved_capabilities ~= nil and value.resolved_capabilities.signature_help_trigger_characters ~= nil then
      triggered_chars = value.server_capabilities.signature_help_trigger_characters
    end
    triggered = check_trigger_char(line_to_cursor, triggered_chars)
    ::continue::
  end

  if signature_cap == false or hover_cap == false then
    return
  end

  if triggered then
    -- overwrite signature help here to disable "no signature help" message
    local params = vim.lsp.util.make_position_params()
    vim.lsp.buf_request(
      0,
      "textDocument/signatureHelp",
      params,
      function(err, method, result, client_id)
        local client = vim.lsp.get_client_by_id(client_id)
        local handler = client and client.handlers["textDocument/signatureHelp"]
        if handler then
          handler(err, method, result, client_id)
          return
        end
        if not (result and result.signatures and result.signatures[1]) then
          return
        end
        match_parameter(result)
        -- print(vim.inspect(result))
        local lines = vim.lsp.util.convert_signature_help_to_markdown_lines(result)
        if vim.tbl_isempty(lines) then
          return
        end
        --
        -- local bufnr, _ =
        vim.lsp.util.focusable_preview(
          method .. "lsp_signature",
          function()
            -- TODO show popup when signatures is empty?
            lines = vim.lsp.util.trim_empty_lines(lines)
            return lines, vim.lsp.util.try_trim_markdown_code_blocks(lines)
          end
        )
        -- vim.api.nvim_buf_set_var(bufnr, "lsp_floating", true)
      end
    )
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

  timer:start(
    100,
    200,
    vim.schedule_wrap(
      function()
        local l_changedTick = api.nvim_buf_get_changedtick(0)
        -- closing timer if leaving insert mode
        if l_changedTick ~= manager.changedTick then
          manager.changedTick = l_changedTick
          signature()
        end
        if manager.insertLeave == true and timer:is_closing() == false then
          timer:stop()
          timer:close()
        end
      end
    )
  )
end

-- handle completion confirmation and dismiss hover popup
-- Note: this function may not work, depends on if complete plugin add parents or not
function M.on_CompleteDone()
  -- need auto brackets to make things work
  -- signature()
end

local function signature_handler(err, method, result, _, bufnr, config)
  -- log(result)
  if not (result and result.signatures and result.signatures[1]) then
    return
  end
  match_parameter(result)
  local lines = vim.lsp.util.convert_signature_help_to_markdown_lines(result)
  if vim.tbl_isempty(lines) then
    return
  end
  vim.lsp.util.focusable_preview(
    method .. "lsp_signature",
    function()
      lines = vim.lsp.util.trim_empty_lines(lines)
      return lines, vim.lsp.util.try_trim_markdown_code_blocks(lines)
    end
  )
end

M.on_attach = function(cfg)
  api.nvim_command("augroup Signature")
  api.nvim_command("autocmd! * <buffer>")
  api.nvim_command("autocmd InsertEnter <buffer> lua require'lsp_signature'.on_InsertEnter()")
  api.nvim_command("autocmd InsertLeave <buffer> lua require'lsp_signature'.on_InsertLeave()")
  api.nvim_command("autocmd InsertCharPre <buffer> lua require'lsp_signature'.on_InsertCharPre()")
  -- api.nvim_command("autocmd CompleteDone * lua require'lsp_signature'.on_CompleteDone()")
  api.nvim_command("augroup end")
  cfg = cfg or {bind = true}
  if cfg.bind then
    vim.lsp.handlers["textDocument/signatureHelp"] = signature_handler
  end
end

return M
