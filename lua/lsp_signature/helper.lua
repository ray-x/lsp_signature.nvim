local helper = {}
local api = vim.api
local fn = vim.fn

-- local lua_magic = [[^$()%.[]*+-?]]

local special_chars = { '%', '*', '[', ']', '^', '$', '(', ')', '.', '+', '-', '?', '"' }

local contains = vim.tbl_contains
-- local lsp_trigger_chars = {}

local vim_version = vim.version().major * 100 + vim.version().minor * 10 + vim.version().patch

local function is_special(ch)
  return contains(special_chars, ch)
end

local function fs_write(path, data)
  local uv = vim.uv or vim.loop

  -- Open the file in append mode
  uv.fs_open(path, 'a', tonumber('644', 8), function(open_err, fd)
    if open_err then
      -- Handle error in opening file
      print('Error opening file: ' .. open_err)
      return
    end

    -- Write data to the file
    uv.fs_write(fd, data, -1, function(write_err)
      if write_err then
        -- Handle error in writing to file
        print('Error writing to file: ' .. write_err)
      end

      -- Close the file descriptor
      uv.fs_close(fd, function(close_err)
        if close_err then
          -- Handle error in closing file
          print('Error closing file: ' .. close_err)
        end
      end)
    end)
  end)
end

helper.log = function(...)
  if _LSP_SIG_CFG.debug ~= true and _LSP_SIG_CFG.verbose ~= true then
    return
  end

  local arg = { ... }
  local log_path = _LSP_SIG_CFG.log_path or nil
  local str = '󰘫 '

  if _LSP_SIG_CFG.verbose == true then
    local info = debug.getinfo(2, 'Sl')
    local lineinfo = info.short_src .. ':' .. info.currentline
    str = str .. lineinfo
  end
  for i, v in ipairs(arg) do
    if type(v) == 'table' then
      str = str .. ' |' .. tostring(i) .. ': ' .. vim.inspect(v) .. '\n'
    else
      str = str .. ' |' .. tostring(i) .. ': ' .. tostring(v)
    end
  end
  if #str > 4 then
    if log_path ~= nil and #log_path > 3 then
      fs_write(log_path, str .. '\n')
    else
      print(str .. '\n')
    end
  end
end

local log = helper.log

local function replace_special(word)
  for _, value in pairs(special_chars) do
    local fd = '%' .. value
    local as_loc = word:find(fd)
    while as_loc do
      word = word:sub(1, as_loc - 1) .. '%' .. value .. word:sub(as_loc + 1, -1)
      as_loc = word:find(fd, as_loc + 2)
    end
  end
  return word
end

helper.replace_special = replace_special

local function findwholeword(input, word)
  word = replace_special(word)

  local e
  local l, _ = string.find(input, '%(') -- All languages I know, func parameter start with (
  l = l or 1
  l, e = string.find(input, '%f[%a]' .. word .. '%f[%A]', l)

  if l == nil then
    -- fall back it %f[%a] fail for int32 etc
    return string.find(input, word)
  end
  return l, e
end

helper.fallback = function(trigger_chars)
  local r = api.nvim_win_get_cursor(0)
  local line = api.nvim_get_current_line()
  line = line:sub(1, r[2])
  local activeParameter = 0
  if not vim.tbl_contains(trigger_chars, '(') then
    log('incorrect trigger', trigger_chars)
    return
  end

  for i = #line, 1, -1 do
    local c = line:sub(i, i)
    if vim.tbl_contains(trigger_chars, c) then
      if c == '(' then
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
      vim.list_extend(tbl1, { value })
    end
  end
  return tbl1
end

helper.ft2md = function(ft)
  local m = {
    javascriptreact = 'javascript',
    typescriptreact = 'typescript',
    ['javascript.jsx'] = 'javascript',
    ['typescript.tsx'] = 'typescript',
  }
  local f = m[ft]
  if f ~= nil then
    return f
  else
    return ft
  end
end

--  location of active parameter
-- return result, next parameter, start of next parameter, end of next parameter
helper.match_parameter = function(result, config)
  -- log("match para ", result, config)
  local signatures = result.signatures

  if #signatures == 0 then -- no parameter
    log('no sig')
    return result, '', 0, 0
  end

  local activeSignature = result.activeSignature or 0
  activeSignature = activeSignature + 1
  local signature = signatures[activeSignature]

  if signature == nil or signature.parameters == nil then -- no parameter
    log('no sig')
    return result, '', 0, 0
  end

  local activeParameter = signature.activeParameter or result.activeParameter

  if activeParameter == nil or activeParameter < 0 then
    log('incorrect signature response?', result, config)
    activeParameter = helper.fallback(config.triggered_chars or { '(', ',' })
  end

  if signature.parameters == nil then
    log('incorrect signature response, missing signature.parameters', result)
    return result, '', 0, 0
  end

  if activeParameter == nil then
    log('incorrect signature response, failed to detect activeParameter', result)
    return result, '', 0, 0
  end

  if activeParameter > #signature.parameters then
    activeParameter = 0
  end

  local nextParameter = signature.parameters[activeParameter + 1]
  log('sig Par', activeParameter, nextParameter, 'label:', signature.label)

  if nextParameter == nil then
    log('no next param')
    return result, '', 0, 0
  end

  local label = signature.label
  local nexp = ''
  local s, e

  if type(nextParameter.label) == 'table' then -- label = {2, 4} c style
    local range = nextParameter.label
    nexp = label:sub(range[1] + 1, range[2])
    s = range[1] + 1
    e = range[2]
    signature.label = label
    -- log("range s, e", s, e)
  else
    if type(nextParameter.label) == 'string' then -- label = 'par1 int'
      -- log("range str ", label, nextParameter.label)
      local i, j = findwholeword(label, nextParameter.label)
      if i ~= nil then
        signature.label = label
      end
      nexp = nextParameter.label
      s = i
      e = j
    else
      log('incorrect label type', type(nextParameter.label))
    end
  end
  if nextParameter.documentation and #nextParameter.documentation > 0 then
    nexp = nexp .. ': ' .. nextParameter.documentation
  end

  -- test markdown hl
  -- signature.label = "```lua\n"..signature.label.."\n```"
  log('match next pos:', nexp, s, e)
  return result, nexp, s, e
end

helper.check_trigger_char = function(line_to_cursor, trigger_characters)
  if trigger_characters == nil then
    return false, #line_to_cursor
  end
  local no_ws_line_to_cursor = string.gsub(line_to_cursor, '%s+', '')
  -- log("newline: ", #line_to_cursor, line_to_cursor)
  if #no_ws_line_to_cursor < 1 then
    log('newline, lets try signature based on setup')
    return _LSP_SIG_CFG.always_trigger, #line_to_cursor
  end

  local includes = ''
  local excludes = [[^]]

  for _, ch in pairs(trigger_characters) do
    if is_special(ch) then
      includes = includes .. '%' .. ch
      excludes = excludes .. '%' .. ch
    else
      includes = includes .. ch
      excludes = excludes .. ch
    end
  end

  if vim.tbl_contains(trigger_characters, '(') then
    excludes = excludes .. '%)'
  end

  local pat = string.format('[%s][%s]*$', includes, excludes)
  log(pat, includes, excludes)

  -- with a this bit of logic we're gonna search for the nearest trigger
  -- character this improves requesting of signature help since some lsps only
  -- provide the signature help on the trigger character.
  -- if vim.tbl_contains(trigger_characters, "(") then
  -- we're gonna assume in this language that function arg are warpped with ()
  -- 1. find last triggered_chars
  -- TODO: populate this regex with trigger_character
  local last_trigger_char_index = line_to_cursor:find(pat)
  if last_trigger_char_index ~= nil then
    -- check if last character is a closing character
    local last_trigger_char = line_to_cursor:sub(last_trigger_char_index, last_trigger_char_index)
    -- log('last trigger char', last_trigger_char, last_trigger_char_index)
    -- when the last character is not a closing character, use the line
    -- until this trigger character to request the signature help.
    -- when the last character is a closing character, use the full line
    -- for example when the line is: "list(); new_var = " we don't want to trigger on the )
    if last_trigger_char ~= ')' then
      local line_to_last_trigger = line_to_cursor:sub(1, last_trigger_char_index)
      -- seems gopls does not handle this well, mightbe other language too
      if last_trigger_char == '(' and vim.tbl_contains({ 'go' }, vim.bo.filetype) then
        return true, #line_to_last_trigger - 1
      end
      return true, #line_to_last_trigger
    else
      return true, #line_to_cursor
    end
  end

  -- when there is no trigger character, still trigger if always_trigger is set
  -- and let the lsp decide if there should be a signature useful in
  -- multi-line function calls.
  return _LSP_SIG_CFG.always_trigger, #line_to_cursor
end

helper.check_closer_char = function(line_to_cursor, trigger_chars)
  if trigger_chars == nil then
    return false
  end

  local current_char = string.sub(line_to_cursor, #line_to_cursor, #line_to_cursor)
  if current_char == ')' and vim.tbl_contains(trigger_chars, '(') then
    return true
  end
  return false
end

helper.is_new_line = function()
  local line = api.nvim_get_current_line()
  local r = api.nvim_win_get_cursor(0)
  local line_to_cursor = line:sub(1, r[2])
  line_to_cursor = string.gsub(line_to_cursor, '%s+', '')
  if #line_to_cursor < 1 then
    log('newline')
    return true
  end
  return false
end

helper.close_float_win = function(close_float_win)
  close_float_win = close_float_win or false
  if _LSP_SIG_CFG.winnr and api.nvim_win_is_valid(_LSP_SIG_CFG.winnr) and close_float_win then
    log('closing winnr', _LSP_SIG_CFG.winnr)
    api.nvim_win_close(_LSP_SIG_CFG.winnr, true)
    _LSP_SIG_CFG.winnr = nil
  end
end

helper.cleanup = function(close_float_win)
  -- vim.schedule(function()
  -- log(debug.traceback())

  _LSP_SIG_VT_NS = _LSP_SIG_VT_NS or vim.api.nvim_create_namespace('lsp_signature_vt')
  log('cleanup vt', _LSP_SIG_VT_NS)
  api.nvim_buf_clear_namespace(0, _LSP_SIG_VT_NS, 0, -1)
  close_float_win = close_float_win or false
  if _LSP_SIG_CFG.ns and _LSP_SIG_CFG.bufnr and api.nvim_buf_is_valid(_LSP_SIG_CFG.bufnr) then
    log('bufnr, ns', _LSP_SIG_CFG.bufnr, _LSP_SIG_CFG.ns)
    api.nvim_buf_clear_namespace(_LSP_SIG_CFG.bufnr, _LSP_SIG_CFG.ns, 0, -1)
  end
  _LSP_SIG_CFG.markid = nil
  _LSP_SIG_CFG.ns = nil
  local winnr = _LSP_SIG_CFG.winnr
  if winnr and winnr ~= 0 and api.nvim_win_is_valid(winnr) and close_float_win then
    log('closing winnr', _LSP_SIG_CFG.winnr)
    api.nvim_win_close(_LSP_SIG_CFG.winnr, true)
    _LSP_SIG_CFG.winnr = nil
    _LSP_SIG_CFG.bufnr = nil
  end
  -- end)
end

helper.cleanup_async = function(close_float_win, delay, force)
  -- log(debug.traceback())
  vim.validate({ delay = { delay, 'number' } })
  vim.defer_fn(function()
    local mode = api.nvim_get_mode().mode
    if not force and (mode == 'i' or mode == 's') then
      log('async cleanup insert leave ignored')
      -- still in insert mode debounce
      return
    end
    log('async cleanup: ', mode)
    helper.cleanup(close_float_win)
  end, delay)
end

local function get_border_height(opts)
  local border_height = { none = 0, single = 2, double = 2, rounded = 2, solid = 2, shadow = 1 }
  local border = opts.border
  local height = 0
  if border == nil then
    return
  end

  if type(border) == 'string' then
    height = border_height[border]
  else
    local function _border_height(id)
      id = (id - 1) % #border + 1
      if type(border[id]) == 'table' then
        -- border specified as a table of <character, highlight group>
        return #border[id][1] > 0 and 1 or 0
      elseif type(border[id]) == 'string' then
        -- border specified as a list of border characters
        return #border[id] > 0 and 1 or 0
      end
    end
    height = height + _border_height(2) -- top
    height = height + _border_height(6) -- bottom
  end

  return height
end

helper.cal_pos = function(contents, opts)
  local lnum = fn.line('.') - fn.line('w0') + 1

  local lines_above = fn.winline() - 1
  local lines_below = fn.winheight(0) - fn.winline() -- not counting current
  -- wont fit if move floating above current line
  if not _LSP_SIG_CFG.floating_window_above_cur_line or lnum <= 2 then
    return {}, 2
  end
  local util = vim.lsp.util
  contents = vim.split(table.concat(contents, '\n'), '\n', { trimempty = true })
  -- there are 2 cases:
  -- 1. contents[1] = "```{language_id}", and contents[#contents] = "```", the code fences will be removed
  --    and return language_id
  -- 2. in other cases, no lines will be removed, and return "markdown"
  local filetype = helper.try_trim_markdown_code_blocks(contents)
  log(vim.inspect(contents))

  local width, height = util._make_floating_popup_size(contents, opts)
  -- if the filetype returned is "markdown", and contents contains code fences, the height should minus 2,
  -- because the code fences won't be display
  local code_block_flag = contents[1]:match('^```')
  if filetype == 'markdown' and code_block_flag ~= nil then
    height = height - 2
  end
  local float_option = util.make_floating_popup_options(width, height, opts)

  -- log('popup size:', width, height, float_option)
  local off_y = 0
  local max_height = float_option.height or _LSP_SIG_CFG.max_height
  local border_height = get_border_height(float_option)
  -- shift win above current line
  if float_option.anchor == 'NW' or float_option.anchor == 'NE' then
    -- note: the floating widnows will be under current line
    if lines_above >= float_option.height + border_height + 1 then
      off_y = -(float_option.height + border_height + 1)
      max_height =
        math.min(max_height, math.max(lines_above - border_height - 1, border_height + 1))
    else
      -- below
      max_height =
        math.min(max_height, math.max(lines_below - border_height - 1, border_height + 1))
    end
  else
    -- above
    max_height = math.min(max_height, math.max(lines_above - border_height - 1, border_height + 1))
  end

  log(off_y, lines_above, max_height)
  if not float_option.height or float_option.height < 1 then
    float_option.height = 1
  end
  float_option.max_height = max_height
  return float_option, off_y, contents, max_height
end

function helper.cal_woff(line_to_cursor, label)
  local woff = line_to_cursor:find('%([^%(]*$')
  local sig_woff = label:find('%([^%(]*$')
  if woff and sig_woff then
    local function_name = label:sub(1, sig_woff - 1)

    -- run this again for some language have multiple `()`
    local sig_woff2 = function_name:find('%([^%(]*$')
    if sig_woff2 then
      function_name = label:sub(1, sig_woff2 - 1)
    end
    local f = function_name
    f = '.*' .. replace_special(f)
    local function_on_line = line_to_cursor:match(f)
    if function_on_line then
      woff = #line_to_cursor - #function_on_line + #function_name
    else
      woff = (sig_woff2 or sig_woff) + (#line_to_cursor - woff)
    end
    woff = -woff
  else
    log('invalid trigger pos? ', line_to_cursor)
    woff = -1 * math.min(3, #line_to_cursor)
  end
  return woff
end

function helper.truncate_doc(lines, num_sigs)
  local doc_num = 2 + _LSP_SIG_CFG.doc_lines -- 3: markdown code signature
  local vmode = api.nvim_get_mode().mode
  -- truncate doc if in insert/replace mode
  if
    vmode == 'i'
    or vmode == 'ic'
    or vmode == 'v'
    or vmode == 's'
    or vmode == 'S'
    or vmode == 'R'
    or vmode == 'Rc'
    or vmode == 'Rx'
  then
    -- truncate the doc?
    -- log(#lines, doc_num, num_sigs)
    if #lines > doc_num + num_sigs then -- for markdown doc start with ```text and end with ```
      local last = lines[#lines]
      lines = vim.list_slice(lines, 1, doc_num + num_sigs)
      if last == '```' then
        table.insert(lines, '```')
      end
      log('lines truncate', lines)
    end
  end

  lines = helper.trim_empty_lines(lines)

  -- remove trailing space
  for i, line in ipairs(lines) do
    -- if line:match("\n") then
    --   log("***** \n exists", line)
    -- end
    -- log(line)
    lines[i] = line:gsub('%s+$', ''):gsub('\r', ' '):gsub('\n', ' ')
  end

  -- log(lines)
  return lines
end

function helper.update_config(config)
  local double = { '╔', '═', '╗', '║', '╝', '═', '╚', '║' }
  local rounded = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' }
  local rand = math.random(1, 1000)
  local id = string.format('%d', rand)
  config.max_height = math.max(_LSP_SIG_CFG.max_height, 1)
  if config.max_height <= 3 then
    config.separator = false
  end
  config.max_width = math.max(_LSP_SIG_CFG.max_width, 40)

  config.focus_id = 'lsp_signature' .. id
  config.stylize_markdown = true
  if config.border == 'double' then
    config.border = double
  end
  if config.border == 'rounded' then
    config.border = rounded
  end
  if _LSP_SIG_CFG.wrap then
    config.wrap_at = config.max_width
    config.wrap = true
  end
  return config
end

function helper.check_lsp_cap(clients, line_to_cursor)
  local triggered = false
  local signature_cap = false
  local hover_cap = false

  local total_lsp = 0

  local triggered_chars = {}
  local trigger_position = nil

  local tbl_combine = helper.tbl_combine
  for _, value in pairs(clients) do
    if value ~= nil then
      local sig_provider = value.server_capabilities.signatureHelpProvider
      local rslv_cap = value.server_capabilities
      if vim_version <= 70 then
        vim.notify('LSP: lsp-signature requires neovim 0.7.1 or later', vim.log.levels.WARN)
        return
      end
      if fn.empty(sig_provider) == 0 then
        signature_cap = true
        total_lsp = total_lsp + 1

        local h = rslv_cap.hoverProvider
        if h == true or (h ~= nil and h ~= {}) then
          hover_cap = true
        end

        if sig_provider ~= nil then
          log(sig_provider, line_to_cursor)
          if sig_provider.triggerCharacters ~= nil then
            triggered_chars = sig_provider.triggerCharacters
          end
          if sig_provider.retriggerCharacters ~= nil then
            vim.list_extend(triggered_chars, sig_provider.retriggerCharacters)
            table.sort(triggered_chars)
            triggered_chars = fn.uniq(triggered_chars)
          end
          if _LSP_SIG_CFG.extra_trigger_chars ~= nil then
            triggered_chars = tbl_combine(triggered_chars, _LSP_SIG_CFG.extra_trigger_chars)
          end
        end

        if triggered == false then
          triggered, trigger_position = helper.check_trigger_char(line_to_cursor, triggered_chars)
        end
      end
    end
  end
  if hover_cap == false then
    log('hover not supported')
  end

  if total_lsp > 1 then
    log('multiple lsp with signatureHelp enabled')
  end
  log('lsp cap & trigger pos: ', signature_cap, triggered, trigger_position)

  return signature_cap, triggered, trigger_position, triggered_chars
end

helper.highlight_parameter = function(s, l)
  _LSP_SIG_CFG.ns = api.nvim_create_namespace('lsp_signature_hi_parameter')
  local hi = _LSP_SIG_CFG.hi_parameter
  log('extmark', _LSP_SIG_CFG.bufnr, s, l, #_LSP_SIG_CFG.padding, hi)
  if s and l and s > 0 then
    if _LSP_SIG_CFG.padding == '' then
      s = s - 1
    else
      s = s - 1 + #_LSP_SIG_CFG.padding
      l = l + #_LSP_SIG_CFG.padding
    end
    local line = 0

    if vim.fn.has('nvim-0.10') == 1 then
      local lines = vim.api.nvim_buf_get_lines(_LSP_SIG_CFG.bufnr, 0, 3, false)
      if lines[1]:find([[```]]) then -- it is strange that the first line is not signatures, it is ```language_id
        -- open_floating_preview changed display ```language_id
        log(
          'Check: first line is ```language_id, it may not be behavior of release version of nvim'
        )
        log('first two lines: ', lines)
        line = 1
      end
    end
    if line == 1 then
      -- scroll to top
      pcall(vim.api.nvim_win_set_cursor, _LSP_SIG_CFG.winnr, { 2, 0 })
    end
    if _LSP_SIG_CFG.bufnr and api.nvim_buf_is_valid(_LSP_SIG_CFG.bufnr) then
      log('extmark', _LSP_SIG_CFG.bufnr, s, l, #_LSP_SIG_CFG.padding)
      _LSP_SIG_CFG.markid = api.nvim_buf_set_extmark(
        _LSP_SIG_CFG.bufnr,
        _LSP_SIG_CFG.ns,
        line,
        s,
        { end_line = line, end_col = l, hl_group = hi, strict = false }
      )

      log('extmark_id', _LSP_SIG_CFG.markid)
    end
  else
    log('failed get highlight parameter', s, l)
  end
end

helper.set_keymaps = function(winnr, bufnr)
  if _LSP_SIG_CFG.keymaps then
    local maps = _LSP_SIG_CFG.keymaps
    if type(_LSP_SIG_CFG.keymaps) == 'function' then
      maps = _LSP_SIG_CFG.keymaps(bufnr)
    end
    if maps and type(maps) == 'table' then
      for _, map in ipairs(maps) do
        vim.keymap.set('i', map.lhs, map.rhs, { buffer = bufnr })
      end
    end
  end
  vim.keymap.set('i', '<M-d>', '<C-o><C-d>', { buffer = bufnr })
  vim.keymap.set('i', '<M-u>', '<C-o><C-u>', { buffer = bufnr })
end

helper.remove_doc = function(result)
  for i = 1, #result.signatures do
    log(result.signatures[i])
    if result.signatures[i] and result.signatures[i].documentation then
      if result.signatures[i].documentation.value then
        result.signatures[i].documentation.value = nil
      else
        result.signatures[i].documentation = nil
      end
    end
  end
end

helper.get_doc = function(result)
  for i = 1, #result.signatures do
    if result.signatures[i] and result.signatures[i].documentation then
      if result.signatures[i].documentation.value then
        return result.signatures[i].documentation.value
      else
        return result.signatures[i].documentation
      end
    end
  end
end

helper.completion_visible = function()
  local hascmp, cmp = pcall(require, 'cmp')
  if hascmp then
    -- reduce timeout from cmp's hardcoded 1000ms:
    -- https://github.com/ray-x/lsp_signature.nvim/issues/288
    cmp.core.filter:sync(42)
    return cmp.core.view:visible() or fn.pumvisible() == 1
  end

  return fn.pumvisible() ~= 0
end

local function jump_to_win(wr)
  if wr and api.nvim_win_is_valid(wr) then
    return api.nvim_set_current_win(wr)
  end
end

helper.change_focus = function()
  helper.log('move focus', _LSP_SIG_CFG.winnr, _LSP_SIG_CFG.mainwin)
  local winnr = api.nvim_get_current_win()
  if winnr == _LSP_SIG_CFG.winnr then --need to change back to main
    return jump_to_win(_LSP_SIG_CFG.mainwin)
  else -- jump to floating
    _LSP_SIG_CFG.mainwin = winnr --need to change back to main
    winnr = _LSP_SIG_CFG.winnr
    if winnr and winnr ~= 0 and api.nvim_win_is_valid(winnr) then
      return jump_to_win(winnr)
    end
  end

  -- vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(_LSP_SIG_CFG.move_cursor_key, true, true, true), "i", true)
end

-- from vim.lsp.util deprecated function
helper.trim_empty_lines = function(lines)
  local new_list = {}
  for _, str in ipairs(lines) do
    if str ~= '' and str then
      table.insert(new_list, str)
    end
  end
  return new_list
end

helper.get_mardown_syntax = function(lines)
  local language_id = lines[1]:match('^```(.*)')
  if language_id then
    return language_id
  end
  return 'markdown'
end

function helper.try_trim_markdown_code_blocks(lines)
  local language_id = lines[1]:match('^```(.*)')
  if language_id then
    local has_inner_code_fence = false
    for i = 2, (#lines - 1) do
      local line = lines[i]
      if line:sub(1, 3) == '```' then
        has_inner_code_fence = true
        break
      end
    end
    -- No inner code fences + starting with code fence = hooray.
    if not has_inner_code_fence then
      table.remove(lines, 1)
      table.remove(lines)
      return language_id
    end
  end
  return 'markdown'
end

local validate = vim.validate
local default_border = {
  { '', 'NormalFloat' },
  { '', 'NormalFloat' },
  { '', 'NormalFloat' },
  { ' ', 'NormalFloat' },
  { '', 'NormalFloat' },
  { '', 'NormalFloat' },
  { '', 'NormalFloat' },
  { ' ', 'NormalFloat' },
}

--- Creates a table with sensible default options for a floating window. The
--- table can be passed to |nvim_open_win()|.
---
---@param width (integer) window width (in character cells)
---@param height (integer) window height (in character cells)
---@param opts (table, optional)
---        - offset_x (integer) offset to add to `col`
---        - offset_y (integer) offset to add to `row`
---        - border (string or table) override `border`
---        - focusable (string or table) override `focusable`
---        - zindex (string or table) override `zindex`, defaults to 50
---        - relative ("mouse"|"cursor") defaults to "cursor"
---        - noautocmd (boolean) defaults to "false"

---@returns (table) Options
function helper.make_floating_popup_options(width, height, opts)
  validate({
    opts = { opts, 't', true },
  })
  opts = opts or {}
  validate({
    ['opts.offset_x'] = { opts.offset_x, 'n', true },
    ['opts.offset_y'] = { opts.offset_y, 'n', true },
  })

  local anchor = ''
  local row, col

  local lines_above = opts.relative == 'mouse' and vim.fn.getmousepos().line - 1
    or vim.fn.winline() - 1
  local lines_below = vim.fn.winheight(0) - lines_above

  if lines_above < lines_below then
    anchor = anchor .. 'N'
    height = math.min(lines_below, height)
    row = 1
  else
    anchor = anchor .. 'S'
    height = math.min(lines_above, height)
    row = 0
  end

  local wincol = opts.relative == 'mouse' and vim.fn.getmousepos().column or vim.fn.wincol()

  if wincol + width + (opts.offset_x or 0) <= api.nvim_get_option('columns') then
    anchor = anchor .. 'W'
    col = 0
  else
    anchor = anchor .. 'E'
    col = 1
  end

  local title = (opts.border and opts.title) and opts.title or nil
  local title_pos

  if title then
    title_pos = opts.title_pos or 'center'
  end
  if opts.noautocmd == nil then
    opts.noautocmd = false
  end

  return {
    anchor = anchor,
    col = col + (opts.offset_x or 0),
    height = height,
    focusable = opts.focusable,
    relative = opts.relative == 'mouse' and 'mouse' or 'cursor',
    row = row + (opts.offset_y or 0),
    style = 'minimal',
    width = width,
    border = opts.border or default_border,
    zindex = opts.zindex or 50,
    title = title,
    title_pos = title_pos,
    noautocmd = opts.noautocmd,
  }
end

function helper.get_clients(opts)
  if vim.lsp.get_clients then
    return vim.lsp.get_clients(opts)
  else
    return vim.lsp.get_active_clients(opts)
  end
end

return helper
