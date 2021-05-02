local helper = {}

helper.match_parameter = function(result)
  local signatures = result.signatures
  if #signatures < 1 then
    return result, ""
  end

  local signature = signatures[1]
  local activeParameter = result.activeParameter or signature.activeParameter
  if activeParameter == nil or activeParameter < 0 then
    return result, ""
  end

  if signature.parameters == nil then
    return result, ""
  end
  -- no arguments or only 1 arguments, the active arguments will not shown
  if #signature.parameters < 2 or activeParameter + 1 > #signature.parameters then
    return result, ""
  end

  local nextParameter = signature.parameters[activeParameter + 1]

  if nextParameter == nil then
    return result, ""
  end
  local dec_pre = _LSP_SIG_CFG.decorator[1] or "***"
  local dec_after = _LSP_SIG_CFG.decorator[2] or "***"
  local label = signature.label
  local nexp = ""
  if type(nextParameter.label) == "table" then -- label = {2, 4} c style
    local range = nextParameter.label
    label =
      label:sub(1, range[1]) ..
      dec_pre .. label:sub(range[1] + 1, range[2]) .. dec_after .. label:sub(range[2] + 1, #label + 1)
    signature.label = label
    nexp = label:sub(range[1] + 1, range[2])
  else
    if type(nextParameter.label) == "string" then -- label = 'par1 int'
      local i, j = label:find(nextParameter.label, 1, true)
      if i ~= nil then
        label = label:sub(1, i - 1) .. dec_pre .. label:sub(i, j) .. dec_after .. label:sub(j + 1, #label + 1)
        signature.label = label
      end
      nexp = nextParameter.label
    end
  end

  -- test markdown hl
  -- signature.label = "```lua\n"..signature.label.."\n```"

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
