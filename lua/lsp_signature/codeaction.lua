local M = {}

local lsp = vim.lsp
local util = vim.lsp.util

local helper = require('lsp_signature.helper')
local log = helper.log

-- can be other languages?, e.g. C/python/javascript ?
function M.get_fill_struct_codeaction(callback)
  local bufnr = vim.api.nvim_get_current_buf()

  local found_action = nil

  local client
  local clients = lsp.get_clients({ bufnr = bufnr })
  if not clients then
    log('No client found for', bufnr)
    return
  end
  for _, c in ipairs(clients) do
    if c.name == 'gopls' then
      client = c
      break
    end
  end
  if not client then
    return
  end
  M.encoding = client.offset_encoding

  local params = vim.lsp.util.make_range_params(0, M.encoding)
  local function on_codeact_result(err, result, cactx, _)
    if err or not result then
      log('Error:', err, cactx)
      return
    end
    -- Look for "Fill <structName>" in this server's result
    for _, action in ipairs(result) do
      -- if action.title:match('^Fill ') then
      if action.kind == 'refactor.rewrite.fillStruct' then
        found_action = action
        break
      end
    end
    if found_action then
      log('Found fill-struct code action:', found_action, cactx, bufnr)
      local client_id = cactx.client_id
      local c = lsp.get_client_by_id(client_id)
      c.request('codeAction/resolve', found_action, function(errca, resolved_action, rectx, config)
        if errca then
          log('Error:', errca)
          return
        end
        log('codeAction/resolve', resolved_action, rectx, config)
        callback(resolved_action, rectx)
      end, cactx.bufnr)
    end
  end

  -- Send requests to all LSP clients attached to this buffer
  client.request('textDocument/codeAction', params, on_codeact_result, bufnr)
end

--- Parse a "Fill <struct>" code action (WorkspaceEdit) to extract unfilled fields.
---@param action table The code action from get_fill_struct_code_action_async
---@return table fields A list of { name="Bar", default_value="0", raw_line="Bar: 0," }
function M.parse_fill_struct_edit(action)
  if not action or not action.edit or not action.edit.documentChanges then
    log('No changes in code action')
    return {}
  end

  local fields = {}
  for i, edits in pairs(action.edit.documentChanges) do
    log('Parsing edits for', i, edits.edits)
    for _, edit in ipairs(edits.edits) do
      local text = edit.newText or ''
      local lines = vim.split(text, '\n')
      for _, line in ipairs(lines) do
        local trimmed = line:match('^%s*(.-)%s*$')
        -- e.g. "Bar: 0," or "FooBar: \"\","
        local name, val = trimmed:match('^(%w+)%s*:%s*(.-),?$')
        if name and val then
          table.insert(fields, {
            name = name, -- e.g. "Bar"
            default_value = val, -- e.g. "0" or "\"\""
            raw_line = line, -- the entire line for reference
          })
        end
      end
    end
  end
  log(fields)
  return fields
end

function M.get_field_completions(callback, ctx)
  local gopls = vim.lsp.get_clients({
    name = 'gopls',
  })
  if not gopls then
    return
  end
  local params = util.make_position_params(0, gopls[1].offset_encoding)

  local field_map = {}
  local remaining_clients = 0
  local client_id = ctx.client_id
  local client = lsp.get_client_by_id(client_id)

  local function on_result(err, result, cpctx, _)
    if err then
      log('Error:', err)
      return
    end
    log(#result.items, cpctx)
    remaining_clients = remaining_clients - 1
    if not err and result then
      local items = result.items or result
      for _, item in ipairs(items) do
        if item.kind == 5 then -- 5 => "Field"
          log('Field:', item.label, item.detail, item.documentation)
          field_map[item.label] = item
        end
      end
    end
    log('Field map:', field_map)
    callback(field_map, cpctx)
  end

  client.request('textDocument/completion', params, on_result, ctx.bufnr)
end

function M.collect_unfilled_fields_info(final_cb)
  -- Step 1: get fill-struct code action
  M.get_fill_struct_codeaction(function(action, ctx)
    if not action then
      -- No fill-struct available here
      log('No fill-struct code action available')
      final_cb({})
      return
    end

    -- Step 2: parse out the unfilled fields
    local unfilled = M.parse_fill_struct_edit(action)
    if vim.tbl_isempty(unfilled) then
      log('No unfilled fields found')
      final_cb({})
      return
    end

    -- Step 3: fetch completion items for detailed info
    M.get_field_completions(function(field_map, cctx)
      local result = {}
      for _, fieldData in ipairs(unfilled) do
        local name = fieldData.name
        local compItem = field_map[name]
        if compItem then
          table.insert(result, {
            name = name,
            default_value = fieldData.default_value,
            type = compItem.detail or '',
            doc = (compItem.documentation and compItem.documentation.value) or '',
          })
        else
          -- If no completion item found, store minimal info
          table.insert(result, {
            name = name,
            default_value = fieldData.default_value,
          })
        end
      end
      log(result)

      -- Step 4: final callback
      final_cb(result, cctx)
    end, ctx)
  end)
end

--- Example function to demonstrate usage: logs unfilled fields to :messages.
function M.show_unfilled_fields()
  M.collect_unfilled_fields_info(function(fields_info, ctx)
    log('Unfilled fields:', fields_info, ctx)
    if vim.tbl_isempty(fields_info) then
      vim.notify('No unfilled fields or no code action here.', vim.log.levels.INFO)
      return
    end

    -- vim.notify('Unfilled fields in struct:', vim.log.levels.INFO)
    log('Unfilled fields:', fields_info)
    local contents = {}
    local line_length = 40
    for _, f in ipairs(fields_info) do
      -- if f.type and f.name then -- if f.type empty means the field had already filled
      local msg
      if f.type then
        msg =
          string.format('- %s (type: %s, default: %s)', f.name, f.type, f.default_value or 'nil')
      else
        msg = string.format('- ~~%s (default: %s)~~', f.name, f.default_value or 'nil')
      end
      line_length = math.max(line_length, #msg)
      -- if f.doc then
      --   msg = msg .. ' // ' .. f.doc
      -- end
      contents[#contents + 1] = msg
      -- end
    end
    M.show_unfilled_fields_floating(contents, {
      width = math.min(line_length + 5, 80),
      height = #contents,
      row = 1,
      col = 1,
    })
  end)
end

-- display contents in a floating window
function M.show_unfilled_fields_floating(lines, cfg)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'lsp_signature', { buf = bufnr })

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
  local win_id = vim.lsp.util.open_floating_preview(lines, 'markdown', {
    relative = 'cursor',
    width = cfg.width or 40,
    height = cfg.height or #lines,
    row = cfg.row or 1,
    col = cfg.col or 1,
  })

  -- the floating should be auto-closed when cursor moves
  vim.api.nvim_buf_attach(bufnr, false, {
    on_detach = function()
      vim.api.nvim_win_close(win_id, true)
    end,
  })

  return bufnr, win_id
end

local function debounce(func, wait)
  local timer_id = nil
  return function(...)
    if timer_id ~= nil then
      vim.loop.timer_stop(timer_id)
    end
    local args = { ... }
    timer_id = vim.loop.new_timer()
    vim.loop.timer_start(timer_id, wait, 0, function()
      vim.schedule(function()
        func(unpack(args))
      end)
    end)
  end
end

-- trigger show_unfilled_fields when there is a `{` before current cursor or
-- it is all spaces before cursor
function M.setup(cfg)
  local ms = cfg.show_struct_debounce_time or 500
  local augroup = vim.api.nvim_create_augroup('Signature_fillfields', {
    clear = false,
  })
  vim.api.nvim_create_autocmd({ 'InsertCharPre', 'CursorMovedI', 'CursorHold', 'CursorHoldI' }, {
    -- check if the character before the cursor is `{` or it is all spaces
    group = augroup,
    callback = debounce(function(arg)
      -- log(arg)
      local line = vim.fn.getline('.')
      local col = vim.fn.col
      if line:sub(1, col('.') - 1):match('%s*{%s*') or line:sub(1, col('.')):match('^%s*$') then
        M.show_unfilled_fields(arg.buf)
      end
    end, ms), -- debounce 500ms
  })
end

return M
