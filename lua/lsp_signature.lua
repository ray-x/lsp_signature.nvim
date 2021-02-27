
local vim = vim
local api = vim.api
local M = {}

manager = {
  insertChar          = false,  -- flag for InsertCharPre event, turn off imediately when performing completion
  insertLeave         = false,  -- flag for InsertLeave, prevent every completion if true
  changedTick         = 0,      -- handle changeTick
  confirmedCompletion = false,  -- flag for manual confirmation of completion
}
function manager.init()
  manager.insertLeave         = false
  manager.insertChar          = false
  manager.confirmedCompletion = false
end


local check_trigger_char = function(line_to_cursor, trigger_character)
  if trigger_character == nil then return false end
  for _, ch in ipairs(trigger_character) do
    local current_char = string.sub(line_to_cursor, #line_to_cursor-#ch+1, #line_to_cursor)
    if current_char == ch then
      return true
    end
  end
  return false
end

----------------------
--  signature help  --
----------------------
local signature = function()
  local pos = api.nvim_win_get_cursor(0)
  local line = api.nvim_get_current_line()
  local line_to_cursor = line:sub(1, pos[2])
  if vim.lsp.buf_get_clients() == nil then return end

  local triggered
  for _, value in pairs(vim.lsp.buf_get_clients(0)) do
    if value.resolved_capabilities.signature_help == false or
      value.server_capabilities.signatureHelpProvider == nil then
      return
    end

    if value.resolved_capabilities.hover == false then return end
      triggered = check_trigger_char(line_to_cursor,
        value.server_capabilities.signatureHelpProvider.triggerCharacters)
  end

  if triggered then
    -- overwrite signature help here to disable "no signature help" message
    local params = vim.lsp.util.make_position_params()
    vim.lsp.buf_request(0, 'textDocument/signatureHelp', params, function(err, method, result, client_id)
      local client = vim.lsp.get_client_by_id(client_id)
      local handler = client and client.handlers['textDocument/signatureHelp']
      if handler then
          handler(err, method, result, client_id)
          return
      end
      if not (result and result.signatures and result.signatures[1]) then
        return
      end
      local lines = vim.lsp.util.convert_signature_help_to_markdown_lines(result)
      if vim.tbl_isempty(lines) then
        return
      end
      local bufnr, _ = vim.lsp.util.focusable_preview(method, function()
        -- TODO show popup when signatures is empty?
        lines = vim.lsp.util.trim_empty_lines(lines)
        return lines, vim.lsp.util.try_trim_markdown_code_blocks(lines)
      end)
      -- setup a variable for floating window, fix #223
      vim.api.nvim_buf_set_var(bufnr, "lsp_floating", true)
    end)
  end
end

M.signature=signature


function M.on_InsertCharPre()
  manager.insertChar = true
end

function M.on_InsertLeave()
  manager.insertLeave = true
end

function M.confirmCompletion(completed_item)
  print("confirm completion ...")
  manager.confirmedCompletion = true
end

function M.on_InsertEnter()
  -- if enable == nil or enable == 0 then
  --   return
  -- end
  local timer = vim.loop.new_timer()
  -- setup variable
  manager.init()

  timer:start(100, 200, vim.schedule_wrap(function()
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
  end))
end

-- handle completion confirmation and dismiss hover popup
function M.on_CompleteDone()
  if manager.confirmedCompletion then
    manager.confirmedCompletion = false
    signature()
  end
end


M.on_attach = function(option)
  api.nvim_command("augroup Signature")
    print("register events ")
    api.nvim_command("autocmd! * <buffer>")
    api.nvim_command("autocmd InsertEnter <buffer> lua require'lsp_signature'.on_InsertEnter()")
    api.nvim_command("autocmd InsertLeave <buffer> lua require'lsp_signature'.on_InsertLeave()")
    api.nvim_command("autocmd InsertCharPre <buffer> lua require'lsp_signature'.on_InsertCharPre()")
    api.nvim_command("autocmd CompleteDone <buffer> lua require'lsp_signature'.on_CompleteDone()")
  api.nvim_command("augroup end")
end

return M
