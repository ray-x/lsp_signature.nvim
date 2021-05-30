local helper = {}

local log = function(...)
  local arg = {...}
  print(_LSP_SIG_CFG.log_path)
  local log_path = _LSP_SIG_CFG.log_path or nil
  if _LSP_SIG_CFG.debug == true then
    print("debug")
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
end
helper.log = log
helper.match_parameter = function(result)
  local signatures = result.signatures
  if #signatures == 0 then -- no parameter
    return result, ""
  end

  local signature = signatures[1]

  local activeParameter = result.activeParameter
  if result.activeParameter == nil then
    activeParameter = signature.activeParameter
  end
  if activeParameter == nil or activeParameter < 0 then
    log("incorrect signature response?", signatures)
    return result, ""
  end

  if signature.parameters == nil then
    return result, ""
  end
  -- no arguments or only 1 arguments, the active arguments will not shown
  -- disable return as it is useful for virtual hint
  -- maybe use a flag?
  -- if #signature.parameters < 2 or activeParameter + 1 > #signature.parameters then
  --   return result, ""
  -- end

  local nextParameter = signature.parameters[activeParameter + 1]

  if nextParameter == nil then
    return result, ""
  end
  local dec_pre = _LSP_SIG_CFG.decorator[1]
  local dec_after = _LSP_SIG_CFG.decorator[2]
  local label = signature.label
  local nexp = ""
  if type(nextParameter.label) == "table" then -- label = {2, 4} c style
    local range = nextParameter.label
    nexp = label:sub(range[1] + 1, range[2])
    label = label:sub(1, range[1]) .. dec_pre .. label:sub(range[1] + 1, range[2]) .. dec_after
                .. label:sub(range[2] + 1, #label + 1)

    signature.label = label
  else
    if type(nextParameter.label) == "string" then -- label = 'par1 int'
      local i, j = label:find(nextParameter.label, 1, true)
      if i ~= nil then
        label = label:sub(1, i - 1) .. dec_pre .. label:sub(i, j) .. dec_after
                    .. label:sub(j + 1, #label + 1)
        signature.label = label
      end
      nexp = nextParameter.label
    end
  end

  -- test markdown hl
  -- signature.label = "```lua\n"..signature.label.."\n```"
  -- log("match:", result, nexp)
  return result, nexp
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

return helper
