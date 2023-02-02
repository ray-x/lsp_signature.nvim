local eq = assert.are.same
local busted = require('plenary/busted')
local result = {
  activeParameter = 0,
  activeSignature = 0,
  signatures = {
    {
      documentation = 'Date returns the Time corresponding to\n\tyyyy-mm-dd hh:mm:ss + nsec nanoseconds\nin the appropriate zone for that time in the given location.\n\nThe month, day, hour, min, sec, and nsec values may be outside\ntheir usual ranges and will be normalized during the conversion.\nFor example, October 32 converts to November 1.\n\nA daylight savings time transition skips or repeats times.\nFor example, in the United States, March 13, 2011 2:15am never occurred,\nwhile November 6, 2011 1:15am occurred twice. In such cases, the\nchoice of time zone, and therefore the time, is not well-defined.\nDate returns a time that is correct in one of the two zones involved\nin the transition, but it does not guarantee which.\n\nDate panics if loc is nil.\n',
      label = 'Date(year int, month time.Month, day int, hour int, min int, sec int, nsec int, loc *time.Location) time.Time',
      parameters = {
        { label = 'year int' },
        { label = 'month time.Month' },
        { label = 'day int' },
        { label = 'hour int' },
        { label = 'min int' },
        { label = 'sec int' },
        { label = 'nsec int' },
        { label = 'loc *time.Location' },
      },
    },
  },
}

local result_ccls = {
  activeParameter = 0,
  activeSignature = 0,
  signatures = {
    { documentation = 'no args s1', label = 'func() -> int', parameters = {} },
    {
      documentation = 'one int arg s2',
      label = 'func(int a) -> int',
      parameters = { { label = { 5, 10 } } },
    },
    {
      documentation = 'one ref arg s3',
      label = 'func(int &a) -> int',
      parameters = { { label = { 5, 11 } } },
    },
    {
      documentation = 'on pointer s3',
      label = 'func(int *a) -> int',
      parameters = { { label = { 5, 11 } } },
    },
    {
      documentation = 'two args s4',
      label = 'func(int a, int b) -> int',
      parameters = { { label = { 5, 10 } }, { label = { 12, 17 } } },
    },
    {
      documentation = 'three args',
      label = 'func(int a, int b, int c) -> int',
      parameters = { { label = { 5, 10 } }, { label = { 12, 17 } }, { label = { 19, 24 } } },
    },
  },
}

local result_csharp = {
  activeParameter = 2,
  activeSignature = 1,
  signatures = {
    {
      documentation = '',
      label = 'bool EditorGUI.PropertyField(Rect position, SerializedProperty property)',
      parameters = {
        { documentation = '', label = 'Rect position' },
        { documentation = '', label = 'SerializedProperty property' },
      },
    },
    {
      documentation = '\n      <summary>\n        <para>Use this to make a field for a SerializedProperty in the Editor.</para>\n      </summary>\n      <param name="position">Rectangle on the screen to use for the property field.</param>\n      <param name="property">The SerializedProperty to make a field for.</param>\n      <param name="label">Optional label to use. If not specified the label of the property itself is used. Use GUIContent.none to not display a label at all.</param>\n      <param name="includeChildren">If true the property including children is drawn; otherwise only the control itself (such as only a foldout but nothing below it).</param>\n      <returns>\n        <para>True if the property has children and is expanded and includeChildren was set to false; otherwise false.</para>\n      </returns>\n    ',
      label = 'bool EditorGUI.PropertyField(Rect position, SerializedProperty property, bool includeChildren)',
      parameters = {
        {
          documentation = 'Rectangle on the screen to use for the property field.',
          label = 'Rect position',
        },
        {
          documentation = 'The SerializedProperty to make a field for.',
          label = 'SerializedProperty property',
        },
        {
          documentation = 'If true the property including children is drawn; otherwise only the control itself (such as only a foldout but nothing below it).',
          label = 'bool includeChildren',
        },
      },
    },
    {
      documentation = '',
      label = 'bool EditorGUI.PropertyField(Rect position, SerializedProperty property, GUIContent label)',
      parameters = {
        { documentation = '', label = 'Rect position' },
        { documentation = '', label = 'SerializedProperty property' },
        { documentation = '', label = 'GUIContent label' },
      },
    },
    {
      documentation = '\n      <summary>\n        <para>Use this to make a field for a SerializedProperty in the Editor.</para>\n      </summary>\n      <param name="position">Rectangle on the screen to use for the property field.</param>\n      <param name="property">The SerializedProperty to make a field for.</param>\n      <param name="label">Optional label to use. If not specified the label of the property itself is used. Use GUIContent.none to not display a label at all.</param>\n      <param name="includeChildren">If true the property including children is drawn; otherwise only the control itself (such as only a foldout but nothing below it).</param>\n      <returns>\n        <para>True if the property has children and is expanded and includeChildren was set to false; otherwise false.</para>\n      </returns>\n    ',
      label = 'bool EditorGUI.PropertyField(Rect position, SerializedProperty property, GUIContent label, bool includeChildren)',
      parameters = {
        {
          documentation = 'Rectangle on the screen to use for the property field.',
          label = 'Rect position',
        },
        {
          documentation = 'The SerializedProperty to make a field for.',
          label = 'SerializedProperty property',
        },
        {
          documentation = 'Optional label to use. If not specified the label of the property itself is used. Use GUIContent.none to not display a label at all.',
          label = 'GUIContent label',
        },
        {
          documentation = 'If true the property including children is drawn; otherwise only the control itself (such as only a foldout but nothing below it).',
          label = 'bool includeChildren',
        },
      },
    },
  },
}

local result_pyright = {
  activeParameter = 5,
  activeSignature = 0,
  cfgActiveSignature = 0,
  signatures = {
    {
      activeParameter = 0,
      label = '(*values: object, sep: str | None = ..., end: str | None = ..., file: SupportsWrite[str] | None = ..., flush: Literal[False] = ...) -> None',
      parameters = {
        {
          label = { 1, 16 },
        },
        {
          label = { 18, 39 },
        },
        {
          label = { 41, 62 },
        },
        {
          label = { 64, 101 },
        },
        {
          label = { 103, 130 },
        },
      },
    },
    {
      activeParameter = 0,
      label = '(*values: object, sep: str | None = ..., end: str | None = ..., file: _SupportsWriteAndFlush[str] | None = ..., flush: bool) -> None',
      parameters = {
        {
          label = { 1, 16 },
        },
        {
          label = { 18, 39 },
        },
        {
          label = { 41, 62 },
        },
        {
          label = { 64, 110 },
        },
        {
          label = { 112, 123 },
        },
      },
    },
  },
}

describe('busted should run ', function()
  it(' should start test', function()
    vim.cmd([[packadd lsp_signature.nvim]])
    local status = require('plenary.reload').reload_module('lsp_signature.nvim')
    eq(status, nil)
    local signature = require('lsp_signature')
    signature.setup({ debug = true, verbose = true })
  end)
end)

-- local cur_dir = vim.fn.expand("%:p:h")
describe('should show signature ', function()
  local busted = require('plenary/busted')
  local signature = require('lsp_signature')
  signature.setup({ debug = true, verbose = true })
  _LSP_SIG_CFG.debug = true
  _LSP_SIG_CFG.verbose = true
  _LSP_SIG_CFG.floating_window = true
  --_LSP_SIG_CFG.log_path = "" -- set so the debug info will out put to console

  local status = require('plenary.reload').reload_module('lsp_signature.nvim')

  local cfg = {
    check_completion_visible = true,
    check_client_handlers = true,
    trigger_from_lsp_sig = true,
    line_to_cursor = '\ttime.Date(2020, ',
    triggered_chars = { '(', ',' },
  }

  local signature = require('lsp_signature')
  signature.setup({ debug = true, verbose = true })
  _LSP_SIG_CFG.debug = true
  _LSP_SIG_CFG.verbose = true
  -- _LSP_SIG_CFG.log_path = ""
  local nvim_6 = true
  if debug.getinfo(vim.lsp.handlers.signature_help).nparams > 4 then
    nvim_6 = false
  end

  local match_parameter = require('lsp_signature.helper').match_parameter
  it('match should get signature pos', function()
    local result1 = vim.deepcopy(result)
    local _, nextp, s, e = match_parameter(result1, cfg)
    eq('year int', nextp)
    eq(6, s)
    eq(13, e)
  end)

  it('match should get signature pos 3', function()
    local result1 = vim.deepcopy(result)
    result1.activeParameter = 2
    local _, nextp, s, e = match_parameter(result1, cfg)
    eq('day int', nextp)
    eq(34, s)
    eq(40, e)
  end)

  it('match should get signature for ccls multi ', function()
    local result1 = vim.deepcopy(result_ccls)
    result1.activeParameter = 1
    result1.activeSignature = 4
    local _, nextp, s, e = match_parameter(result1, cfg)
    eq('int b', nextp)
    eq(13, s)
    eq(17, e)
  end)

  it('match should get signature for pyright multi parameters with doc ', function()
    local busted = require('plenary/busted')
    local signature = require('lsp_signature')
    signature.setup({ debug = true, verbose = true })
    _LSP_SIG_CFG.debug = true
    _LSP_SIG_CFG.verbose = true
    _LSP_SIG_CFG.floating_window = true
    --_LSP_SIG_CFG.log_path = "" -- set so the debug info will out put to console

    local result1 = vim.deepcopy(result_pyright)
    local lines, label, s, e = match_parameter(result1, cfg)
    print('lines', vim.inspect(lines))
    eq('*values: object', label)
    eq(2, s)
    eq(16, e)
  end)

  it('match should get signature for csharp multi parameters with doc ', function()
    local busted = require('plenary/busted')
    local signature = require('lsp_signature')
    signature.setup({ debug = true, verbose = true })
    _LSP_SIG_CFG.debug = true
    _LSP_SIG_CFG.verbose = true
    _LSP_SIG_CFG.floating_window = true
    --_LSP_SIG_CFG.log_path = "" -- set so the debug info will out put to console

    local result1 = vim.deepcopy(result_csharp)
    local lines, label, s, e = match_parameter(result1, cfg)
    -- print("lines", vim.inspect(lines))
    eq(
      'bool includeChildren: If true the property including children is drawn; otherwise only the control itself (such as only a foldout but nothing below it).',
      label
    )
    eq(74, s)
    eq(93, e)
  end)

  it('should show signature Date golang', function()
    local ctx = {
      method = 'textDocument/signatureHelp',
      client_id = 1,
      bufnr = vim.api.nvim_get_current_buf(),
    }
    -- local lines, s, l = signature.signature_handler(nil, result, ctx, cfg)
    local lines, s, l

    local cfg1 = {
      check_completion_visible = true,
      check_client_handlers = true,
      trigger_from_lsp_sig = true,
      line_to_cursor = '\ttime.Date(1999, 12, 31',
      triggered_chars = { '(', ',' },
    }
    _LSP_SIG_CFG.log_path = '' -- set so the debug info will out put to console
    if nvim_6 then
      lines, s, l = signature.signature_handler(nil, result, ctx, cfg1)
    else
      lines, s, l = signature.signature_handler(nil, '', result, 1, 1, cfg1)
    end
    -- print("lines", vim.inspect(lines))
    eq(
      'Date(year int, month time.Month, day int, hour int, min int, sec int, nsec int, loc *time.Location) time.Time',
      lines[2]
    )
    eq(6, s) -- match `year int`
    eq(13, l)
  end)

  it('should ignore signature for other buffers', function()
    local ctx = {
      method = 'textDocument/signatureHelp',
      client_id = 1,
      bufnr = vim.api.nvim_get_current_buf() + 1,
    }
    local handler_result

    local cfg1 = {
      check_completion_visible = true,
      check_client_handlers = true,
      trigger_from_lsp_sig = true,
      line_to_cursor = '\ttime.Date(1999, 12, 31',
      triggered_chars = { '(', ',' },
    }
    _LSP_SIG_CFG.log_path = '' -- set so the debug info will out put to console
    if nvim_6 then
      handler_result = signature.signature_handler(nil, result, ctx, cfg1)
    else
      handler_result = signature.signature_handler(nil, '', result, 1, 1, cfg1)
    end
    eq(nil, handler_result)
  end)

  it('should show multi signature csharp', function()
    local cfg_cs = {
      check_completion_visible = true,
      check_client_handlers = true,
      trigger_from_lsp_sig = true,
      line_to_cursor = '\tEditorGUI.PropertyField(Rect, Seri',
      triggered_chars = { '(', ',' },
    }
    local ctx = {
      method = 'textDocument/signatureHelp',
      client_id = 1,
      bufnr = vim.api.nvim_get_current_buf(),
    }
    -- local lines, s, l = signature.signature_handler(nil, result, ctx, cfg)
    local lines, s, l

    local result_cs = vim.deepcopy(result_csharp)
    -- print(vim.inspect(result_cs))
    if nvim_6 then
      lines, s, l = signature.signature_handler(nil, result_cs, ctx, cfg_cs)
    else
      lines, s, l = signature.signature_handler(nil, '', result_cs, 1, 1, cfg_cs)
    end

    print('csharp lines', vim.inspect(lines), s, l)
    -- line 1 can be ```
    eq(
      'bool EditorGUI.PropertyField(Rect position, SerializedProperty property, bool includeChildren)',
      lines[2]
    )
    eq(74, s) -- match `year int`
    eq(93, l)
  end)

  it('should show fn add', function()
    _LSP_SIG_CFG.debug = false
    _LSP_SIG_CFG.floating_window = true

    result = {
      activeParameter = 0,
      signatures = {
        {
          active_parameter = 0,
          label = 'fn add(left: i32, right: i32) -> i32',
          parameters = { { label = { 7, 16 } }, { label = { 18, 28 } } },
        },
      },
    }

    cfg = {
      check_completion_visible = true,
      check_client_handlers = true,
      trigger_from_lsp_sig = true,
      line_to_cursor = '    add(1, ',
      triggered_chars = { '(', ',' },
    }

    local ctx = {
      method = 'textDocument/signatureHelp',
      client_id = 1,
      bufnr = vim.api.nvim_get_current_buf(),
    }

    local lines, s, l
    if nvim_6 then
      lines, s, l = signature.signature_handler(nil, result, ctx, cfg)
    else
      lines, s, l = signature.signature_handler(nil, '', result, 1, 1, cfg)
    end

    eq('fn add(left: i32, right: i32) -> i32', lines[1])
    eq(8, s) -- match `left: i32`
    eq(16, l)
  end)

  it('should show signature with new line', function()
    _LSP_SIG_CFG.debug = false
    _LSP_SIG_CFG.floating_window = true

    result = {
      activeParameter = 1,
      activeSignature = 0,
      signatures = {
        {
          documentation = 'HandleFunc registers a new route with a matcher for the URL path.\nSee Route.Path() and Route.HandlerFunc().\n',
          label = 'HandleFunc(path string, f func(http.ResponseWriter,\n\t*http.Request)) *mux.Route',
          parameters = {
            { label = 'path string' },
            { label = 'f func(http.ResponseWriter,\n\t*http.Request)' },
          },
        },
      },
    }

    cfg = {
      check_completion_visible = true,
      check_client_handlers = true,
      trigger_from_lsp_sig = true,
      line_to_cursor = [[\t HandleFunc(" / ", ]],
      triggered_chars = { '(', ',' },
    }

    local ctx = {
      method = 'textDocument/signatureHelp',
      client_id = 1,
      bufnr = vim.api.nvim_get_current_buf(),
    }
    local lines, s, l
    if nvim_6 then
      lines, s, l = signature.signature_handler(nil, result, ctx, cfg)
    else
      lines, s, l = signature.signature_handler(nil, '', result, 1, 1, cfg)
    end

    eq('HandleFunc(path string, f func(http.ResponseWriter,  *http.Request)) *mux.Route', lines[2])
  end)
end)
