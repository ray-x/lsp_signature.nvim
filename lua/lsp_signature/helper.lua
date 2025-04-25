local helper = {}
local api = vim.api
local fn = vim.fn
local validate = vim.validate
local has_nvim11 = vim.fn.has('nvim-0.11') == 1

if not has_nvim11 then
  -- for nvim 0.10 or earlier validate has changed
  validate = function(...) end
end

-- local lua_magic = [[^$()%.[]*+-?]]

local special_chars = { '%', '*', '[', ']', '^', '$', '(', ')', '.', '+', '-', '?', '"' }

local contains = vim.tbl_contains

local vim_version = vim.version().major * 100 + vim.version().minor * 10 + vim.version().patch

local function is_special(ch)
  return contains(special_chars, ch)
end

helper.cursor_hold = function(enabled, bufnr)
  if not _LSP_SIG_CFG.cursorhold_update then
    return
  end

  local augroup = api.nvim_create_augroup('Signature', { clear = false })
  if enabled then
    api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
      group = augroup,
      buffer = bufnr,
      callback = function()
        require('lsp_signature').on_UpdateSignature()
      end,
      desc = 'signature on cursor hold',
    })
    api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
      group = augroup,
      buffer = bufnr,
      callback = function()
        require('lsp_signature').check_signature_should_close()
      end,
      desc = 'signature on cursor hold',
    })
  end
  if not enabled then
    api.nvim_clear_autocmds({
      buffer = bufnr,
      group = augroup,
      event = { 'CursorHold', 'CursorHoldI' },
    })
  end
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

-- location of active parameter
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
  -- this is to follow when the documentation is a table like {kind= xxx, value= zzz}
  elseif type(nextParameter.documentation) == 'table' and nextParameter.documentation.value then
    nexp = nexp .. ': ' .. nextParameter.documentation.value
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
  validate('delay', delay, 'number')
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

-- copy neovim internal/private functions accorss as they can be removed without notice

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

local function border_error(border)
  error(
    string.format(
      'invalid floating preview border: %s. :help vim.api.nvim_open_win()',
      vim.inspect(border)
    ),
    2
  )
end
local border_size = {
  none = { 0, 0 },
  single = { 2, 2 },
  double = { 2, 2 },
  rounded = { 2, 2 },
  solid = { 2, 2 },
  shadow = { 1, 1 },
}

--- Check the border given by opts or the default border for the additional
--- size it adds to a float.
--- @param opts? {border:string|(string|[string,string])[]}
--- @return integer height
--- @return integer width
local function get_border_size(opts)
  local border = opts and opts.border or default_border

  if type(border) == 'string' then
    if not border_size[border] then
      border_error(border)
    end
    local r = border_size[border]
    return r[1], r[2]
  end

  if 8 % #border ~= 0 then
    border_error(border)
  end

  --- @param id integer
  --- @return string
  local function elem(id)
    id = (id - 1) % #border + 1
    local e = border[id]
    if type(e) == 'table' then
      -- border specified as a table of <character, highlight group>
      return e[1]
    elseif type(e) == 'string' then
      -- border specified as a list of border characters
      return e
    end
    --- @diagnostic disable-next-line:missing-return
    border_error(border)
  end

  --- @param e string
  local function border_height(e)
    return #e > 0 and 1 or 0
  end

  local top, bottom = elem(2), elem(6)
  local height = border_height(top) + border_height(bottom)

  local right, left = elem(4), elem(8)
  local width = vim.fn.strdisplaywidth(right) + vim.fn.strdisplaywidth(left)

  return height, width
end

-- note: this is a neovim internal function from lsp/util.lua

---@private
--- Computes size of float needed to show contents (with optional wrapping)
---
---@param contents string[] of lines to show in window
---@param opts? vim.lsp.util.open_floating_preview.Opts
---@return integer width size of float
---@return integer height size of float
local function make_floating_popup_size(contents, opts)
  validate('contents', contents, 'table')
  validate('opts', opts, 'table', true)
  opts = opts or {}

  local width = opts.width
  local height = opts.height
  local wrap_at = opts.wrap_at
  local max_width = opts.max_width
  local max_height = opts.max_height
  local line_widths = {} --- @type table<integer,integer>

  if not width then
    width = 0
    for i, line in ipairs(contents) do
      -- TODO(ashkan) use nvim_strdisplaywidth if/when that is introduced.
      line_widths[i] = vim.fn.strdisplaywidth(line:gsub('%z', '\n'))
      width = math.max(line_widths[i], width)
    end
  end

  local _, border_width = get_border_size(opts)
  local screen_width = api.nvim_win_get_width(0)
  width = math.min(width, screen_width)

  -- make sure borders are always inside the screen
  width = math.min(width, screen_width - border_width)

  -- Make sure that the width is large enough to fit the title.
  local title_length = 0
  local chunks = type(opts.title) == 'string' and { { opts.title } } or opts.title or {}
  for _, chunk in
    ipairs(chunks --[=[@as [string, string][]]=])
  do
    title_length = title_length + vim.fn.strdisplaywidth(chunk[1])
  end

  width = math.max(width, title_length)

  if wrap_at then
    wrap_at = math.min(wrap_at, width)
  end

  if max_width then
    width = math.min(width, max_width)
    wrap_at = math.min(wrap_at or max_width, max_width)
  end

  if not height then
    height = #contents
    if wrap_at and width >= wrap_at then
      height = 0
      if vim.tbl_isempty(line_widths) then
        for _, line in ipairs(contents) do
          local line_width = vim.fn.strdisplaywidth(line:gsub('%z', '\n'))
          height = height + math.max(1, math.ceil(line_width / wrap_at))
        end
      else
        for i = 1, #contents do
          height = height + math.max(1, math.ceil(line_widths[i] / wrap_at))
        end
      end
    end
  end
  if max_height then
    height = math.min(height, max_height)
  end

  return width, height
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

  local width, height = make_floating_popup_size(contents, opts)
  log('popup size:', width, height, opts)
  -- if the filetype returned is "markdown", and contents contains code fences, the height should minus 2, note,
  -- for latests nvim with conceal level 2 there is no need to `-2`
  -- because the code fences won't be display
  local code_block_flag = contents[1]:match('^```')
  if filetype == 'markdown' and code_block_flag ~= nil then
    height = height - 2
  end
  local float_option = util.make_floating_popup_options(width, height, opts)

  log('popup size:', width, height, opts, float_option)
  local off_y = 0
  local max_height = float_option.height or _LSP_SIG_CFG.max_height
  local border_height = get_border_height(float_option)
  -- shift win above current line
  if float_option.anchor == 'NW' or float_option.anchor == 'NE' then
    -- note: the floating windows will be under current line
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

  log(off_y, lines_above, max_height, width)
  if not float_option.height or float_option.height < 1 then
    float_option.height = 1
  end
  float_option.max_height = max_height
  float_option.width = width
  float_option.height = math.min(height, max_height)
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
  if type(_LSP_SIG_CFG.max_width) == 'number' then
    config.max_width = math.max(_LSP_SIG_CFG.max_width, 60)
  end
  if type(_LSP_SIG_CFG.max_width) == 'function' then
    config.max_width = _LSP_SIG_CFG.max_width()
  end

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
        if h == true or fn.empty(h) == 0 then
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

---@param extra_params table extends the position parameters
---@return table|(fun(client: vim.lsp.Client, bufnr: integer): table) final parameters
helper.make_position_params = function(extra_params)
  if vim.fn.has('nvim-0.11') == 0 then
    local params = vim.lsp.util.make_position_params()
    if extra_params then
      params = vim.tbl_deep_extend('force', params, extra_params)
    end
    return params
  end
  ---@param client vim.lsp.Client
  return function(client, _)
    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
    if extra_params then
      params = vim.tbl_deep_extend('force', params, extra_params)
    end
    return params
  end
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

    local lines = vim.api.nvim_buf_get_lines(_LSP_SIG_CFG.bufnr, 0, 3, false)
    if lines[1]:find([[```]]) then -- it is strange that the first line is not signatures, it is ```language_id
      -- open_floating_preview changed display ```language_id
      log('first line is ```language_id')
      log('first two lines: ', lines)
      line = 1
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
        vim.keymap.set('i', map[1], map[2], { buffer = bufnr })
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
    -- issues #288
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

function helper.get_clients(opts)
  if vim.lsp.get_clients then
    return vim.lsp.get_clients(opts)
  else
    vim.notify('unsupported neovim version, please update to nvim 0.10')
  end
end

function helper.lsp_with(handler, override_config)
  return function(err, result, ctx, config)
    return handler(err, result, ctx, vim.tbl_deep_extend('force', config or {}, override_config))
  end
end
return helper
