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
    return false
  end
  line_to_cursor = string.gsub(line_to_cursor, "%s+", "")
  -- log("newline: ", #line_to_cursor, line_to_cursor)
  if #line_to_cursor < 1 then
    log("newline, lets try signature")
    return _LSP_SIG_CFG.trigger_on_newline
  end
  for _, ch in ipairs(trigger_character) do
    local current_char = string.sub(line_to_cursor, #line_to_cursor - #ch + 1, #line_to_cursor)
    if current_char == ch then
      return true
    end
    local prev_char = current_char
    local prev_prev_char = current_char
    if #line_to_cursor > #ch + 1 then
      prev_char = string.sub(line_to_cursor, #line_to_cursor - #ch, #line_to_cursor - #ch)
    end
    if current_char == " " then
      if prev_char == ch then
        return true
      end
    end
    -- this works for select mode after completion confirmed
    if prev_char == ch then -- this case fun_name(a_
      return true
    end

    if #line_to_cursor > #ch + 2 then -- this case fun_name(a, b_
      prev_prev_char = string.sub(line_to_cursor, #line_to_cursor - #ch - 1,
                                  #line_to_cursor - #ch - 1)
    end
    log(prev_prev_char, prev_char, current_char)
    if prev_char == " " and prev_prev_char == ch then
      return true
    end
  end
  return false
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

return helper
