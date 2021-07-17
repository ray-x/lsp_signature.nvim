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

  l, e = string.find(input, "%f[%a]" .. word .. "%f[%A]")

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

  local activeParameter = result.activeParameter or signature.active_parameter
                              or signature.activeParameter

  if activeParameter == nil or activeParameter < 0 then
    log("incorrect signature response?", result, config)
    activeParameter = helper.fallback(config.triggered_chars)
  end
  if signature.parameters == nil then
    log("incorrect signature response?", result)
    return result, "", 0, 0
  end

  -- no arguments or only 1 arguments, the active arguments will not shown
  -- disable return as it is useful for virtual hint
  -- maybe use a flag?
  -- if #signature.parameters < 2 or activeParameter + 1 > #signature.parameters then
  --   return result, ""
  -- end

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
  for _, ch in ipairs(trigger_character) do
    local current_char = string.sub(line_to_cursor, #line_to_cursor - #ch + 1, #line_to_cursor)
    if current_char == ch then
      return true
    end
    if current_char == " " and #line_to_cursor > #ch + 1 then
      local pre_char = string.sub(line_to_cursor, #line_to_cursor - #ch, #line_to_cursor - 1)
      if pre_char == ch then
        return true
      end
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

return helper
