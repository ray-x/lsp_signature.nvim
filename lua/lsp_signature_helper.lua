local helper = {}

local log = function(...)
  if _LSP_SIG_CFG.debug ~= true then
    return
  end
  local arg = {...}
  -- print(_LSP_SIG_CFG.log_path)
  local log_path = _LSP_SIG_CFG.log_path or nil
  local str = "שׁ "
  for i, v in ipairs(arg) do
    if type(v) == "table" then
      str = str .. " |" .. tostring(i) .. ": " .. vim.inspect(v) .. "\n"
    else
      str = str .. " |" .. tostring(i) .. ": " .. tostring(v)
    end
  end
  if #str > 2 then
    if log_path ~= nil and #log_path > 3 then
      local f = io.open(log_path, "a+")
      io.output(f)
      io.write(str .. "\n")
      io.close(f)
    else
      print(str .. "\n")
    end
  end
end
helper.log = log

local function findwholeword(input, word)
  local special_chars = {"%", "*", "[", "]", "^", "$", "(", ")", ".", "+", "-", "?"}
  for _, value in pairs(special_chars) do
    local fd = "%" .. value
    local as_loc = word:find(fd)
    if as_loc then
      word = word:sub(1, as_loc - 1) .. "%" .. value .. word:sub(as_loc + 1, -1)
    end
  end

  local l, e = string.find(input, '%(') -- All languages I know, func parameter start with (
  l = l or 1
  l, e = string.find(input, "%f[%a]" .. word .. "%f[%A]", l)

  if l == nil then
    -- fall back it %f[%a] fail for int32 etc
    return string.find(input, word)
  end
  return l, e
end

helper.fallback = function(trigger_chars)
  local r = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  line = line:sub(1, r[2])
  local activeParameter = 0
  if not vim.tbl_contains(trigger_chars, "(") then
    log("incorrect trigger", trigger_chars)
    return
  end

  for i = #line, 1, -1 do
    local c = line:sub(i, i)
    if vim.tbl_contains(trigger_chars, c) then
      if c == "(" then
        return activeParameter
      end
      activeParameter = activeParameter + 1
    end
  end
  return 0
end

helper.tbl_combine = function(tbl1, tbl2)
  for _, value in pairs(tbl2) do
    if not vim.tbl_contains(tbl1, value) then
      vim.list_extend(tbl1, {value})
    end
  end
  return tbl1
end

--  location of active parameter
helper.match_parameter = function(result, config)
  local signatures = result.signatures

  if #signatures == 0 then -- no parameter
    log("no sig")
    return result, "", 0, 0
  end

  local activeSignature = result.activeSignature or 0
  activeSignature = activeSignature + 1
  local signature = signatures[activeSignature]

  if signature.parameters == nil then -- no parameter
    log("no sig")
    return result, "", 0, 0
  end

  local activeParameter = signature.active_parameter

  if result.activeParameter ~= nil and result.activeParameter < #signature.parameters then
    activeParameter = result.activeParameter
  else
    activeParameter = 0
  end

  if signature.activeParameter ~= nil then
    activeParameter = signature.activeParameter
  end

  if activeParameter == nil or activeParameter < 0 then
    log("incorrect signature response?", result, config)
    activeParameter = helper.fallback(config.triggered_chars)
  end
  if signature.parameters == nil then
    log("incorrect signature response?", result)
    return result, "", 0, 0
  end

  local nextParameter = signature.parameters[activeParameter + 1]

  if nextParameter == nil then
    log("no next param")
    return result, "", 0, 0
  end
  -- local dec_pre = _LSP_SIG_CFG.decorator[1]
  -- local dec_after = _LSP_SIG_CFG.decorator[2]
  local label = signature.label
  local nexp = ""
  local s, e
  if type(nextParameter.label) == "table" then -- label = {2, 4} c style
    local range = nextParameter.label
    nexp = label:sub(range[1] + 1, range[2])
    -- label = label:sub(1, range[1]) .. dec_pre .. label:sub(range[1] + 1, range[2]) .. dec_after
    --             .. label:sub(range[2] + 1, #label + 1)
    s = range[1] + 1
    e = range[2]
    signature.label = label
    -- log("range s, e", s, e)
  else
    if type(nextParameter.label) == "string" then -- label = 'par1 int'
      -- log("range str ", label, nextParameter.label)
      local i, j = findwholeword(label, nextParameter.label)
      -- local i, j = label:find(nextParameter.label, 1, true)
      if i ~= nil then
        -- label = label:sub(1, i - 1) .. dec_pre .. label:sub(i, j) .. dec_after
        --             .. label:sub(j + 1, #label + 1)
        signature.label = label
      end
      nexp = nextParameter.label
      s = i
      e = j
    else
      log("incorrect label type", type(nextParameter.label))
    end
  end

  -- test markdown hl
  -- signature.label = "```lua\n"..signature.label.."\n```"
  -- log("match:", result, nexp, s, e)
  return result, nexp, s, e
end

helper.check_trigger_char = function(line_to_cursor, trigger_character)
  if trigger_character == nil then
    return false, #line_to_cursor
  end
  local no_ws_line_to_cursor = string.gsub(line_to_cursor, "%s+", "")
  -- log("newline: ", #line_to_cursor, line_to_cursor)
  if #no_ws_line_to_cursor < 1 then
    log("newline, lets try signature")
    return true, #line_to_cursor
  end

  -- with a this bit of logic we're gonna search for the nearest trigger
  -- character this improves requesting of signature help since some lsps only
  -- provide the signature help on the trigger character.
  if vim.tbl_contains(trigger_character, "(") then
    -- we're gonna assume in this language that function arg are warpped with ()
    -- 1. find last triggered_chars
    -- TODO: populate this regex with trigger_character
    local last_trigger_char_index = line_to_cursor:find('[%(,%)][^%(,%)]*$')
    if last_trigger_char_index ~= nil then
      -- check if last character is a closing character
      local last_trigger_char = line_to_cursor:sub(last_trigger_char_index, last_trigger_char_index)
      if last_trigger_char ~= ')' then
        -- when the last character is a closing character, use the full line
        -- for example when the line is: "list(); new_var = " we don't want to trigger on the )
        local line_to_last_trigger = line_to_cursor:sub(1, last_trigger_char_index)
        return true, #line_to_last_trigger
      else
        -- when the last character is not a closing character, use the line
        -- until this trigger character to request the signature help.
        return true, #line_to_cursor
      end
    else
      -- when there is no trigger character, still trigger and let the lsp
      -- decide if there should be a signature useful in multi-line function
      -- calls.
      return true, #line_to_cursor
    end
  end

  for _, ch in ipairs(trigger_character) do
    local current_char = string.sub(line_to_cursor, #line_to_cursor - #ch + 1, #line_to_cursor)
    if current_char == ch then
      return true, #line_to_cursor
    end
    local prev_char = current_char
    local prev_prev_char = current_char
    if #line_to_cursor > #ch + 1 then
      prev_char = string.sub(line_to_cursor, #line_to_cursor - #ch, #line_to_cursor - #ch)
    end
    if current_char == " " then
      if prev_char == ch then
        return true, #line_to_cursor
      end
    end
    -- this works for select mode after completion confirmed
    if prev_char == ch then -- this case fun_name(a_
      return true, #line_to_cursor
    end

    if #line_to_cursor > #ch + 2 then -- this case fun_name(a, b_
      prev_prev_char = string.sub(line_to_cursor, #line_to_cursor - #ch - 1,
                                  #line_to_cursor - #ch - 1)
    end
    -- log(prev_prev_char, prev_char, current_char)
    if prev_char == " " and prev_prev_char == ch then
      return true, #line_to_cursor
    end
  end
  return false, #line_to_cursor
end

helper.check_closer_char = function(line_to_cursor, trigger_chars)
  if trigger_chars == nil then
    return false
  end

  local current_char = string.sub(line_to_cursor, #line_to_cursor, #line_to_cursor)
  if current_char == ")" and vim.tbl_contains(trigger_chars, "(") then
    return true
  end
  return false
end

helper.is_new_line = function()
  local new_line = false
  local line = vim.api.nvim_get_current_line()
  local r = vim.api.nvim_win_get_cursor(0)
  local line_to_cursor = line:sub(1, r[2])
  line_to_cursor = string.gsub(line_to_cursor, "%s+", "")
  if #line_to_cursor < 1 then
    log("newline")
    return true
  end
  return false
end

helper.close_float_win = function(close_float_win)
  close_float_win = close_float_win or false
  if _LSP_SIG_CFG.winnr and vim.api.nvim_win_is_valid(_LSP_SIG_CFG.winnr) and close_float_win then
    log("closing winnr", _LSP_SIG_CFG.winnr)
    vim.api.nvim_win_close(_LSP_SIG_CFG.winnr, true)
    _LSP_SIG_CFG.winnr = nil
  end
end

helper.cleanup = function(close_float_win)
  close_float_win = close_float_win or false
  if _LSP_SIG_CFG.ns and _LSP_SIG_CFG.bufnr and vim.api.nvim_buf_is_valid(_LSP_SIG_CFG.bufnr) then
    log("bufnr, ns", _LSP_SIG_CFG.bufnr, _LSP_SIG_CFG.ns)
    vim.api.nvim_buf_clear_namespace(_LSP_SIG_CFG.bufnr, _LSP_SIG_CFG.ns, 0, -1)
  end
  _LSP_SIG_CFG.markid = nil
  _LSP_SIG_CFG.ns = nil

  if _LSP_SIG_CFG.winnr and vim.api.nvim_win_is_valid(_LSP_SIG_CFG.winnr) and close_float_win then
    log("closing winnr", _LSP_SIG_CFG.winnr)
    vim.api.nvim_win_close(_LSP_SIG_CFG.winnr, true)
    _LSP_SIG_CFG.winnr = nil
  end
  if _LSP_SIG_CFG.bufnr and not vim.api.nvim_buf_is_valid(_LSP_SIG_CFG.bufnr) then
    _LSP_SIG_CFG.bufnr = nil
  end

end

helper.cal_pos = function(contents, opts)
  if not _LSP_SIG_CFG.floating_window_above_first then
    return {}, 0
  end
  local util = vim.lsp.util
  local width, height = util._make_floating_popup_size(contents, opts)
  local float_option = util.make_floating_popup_options(width, height, opts)
  helper.log("pos", width, height, float_option)
  local off_y = 0
  if float_option.anchor == 'NW' then
    -- note: the floating widnows will be under current line
    local lines_above = vim.fn.winline() - 1
    local lines_below = vim.fn.winheight(0) - lines_above
    if lines_above > float_option.height + 3 then -- border
      off_y = -(float_option.height + 3)
    end
  end
  return float_option, off_y

end

local nvim_0_6
function helper.nvim_0_6()
  if nvim_0_6 ~= nil then
    return nvim_0_6
  end
  if debug.getinfo(vim.lsp.handlers.signature_help).nparams == 4 then
    nvim_0_6 = true
  else
    nvim_0_6 = false
  end
  return nvim_0_6
end

function helper.mk_handler(fn)
  return function(...)
    local config_or_client_id = select(4, ...)
    local is_new = helper.nvim_0_6()
    if is_new then
      fn(...)
    else
      local err = select(1, ...)
      local method = select(2, ...)
      local result = select(3, ...)
      local client_id = select(4, ...)
      local bufnr = select(5, ...)
      local config = select(6, ...)
      fn(err, result, {method = method, client_id = client_id, bufnr = bufnr}, config)
    end
  end
end

return helper
