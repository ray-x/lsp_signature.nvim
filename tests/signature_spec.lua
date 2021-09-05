local eq = assert.are.same

local busted = require("plenary/busted")
-- local cur_dir = vim.fn.expand("%:p:h")
describe("should show signature ", function()
  _LSP_SIG_CFG.debug = false
  _LSP_SIG_CFG.floating_window = true

  local status = require("plenary.reload").reload_module("lsp_signature.nvim")
  local result = {
    activeParameter = 0,
    activeSignature = 0,
    signatures = {
      {
        documentation = "Date returns the Time corresponding to\n\tyyyy-mm-dd hh:mm:ss + nsec nanoseconds\nin the appropriate zone for that time in the given location.\n\nThe month, day, hour, min, sec, and nsec values may be outside\ntheir usual ranges and will be normalized during the conversion.\nFor example, October 32 converts to November 1.\n\nA daylight savings time transition skips or repeats times.\nFor example, in the United States, March 13, 2011 2:15am never occurred,\nwhile November 6, 2011 1:15am occurred twice. In such cases, the\nchoice of time zone, and therefore the time, is not well-defined.\nDate returns a time that is correct in one of the two zones involved\nin the transition, but it does not guarantee which.\n\nDate panics if loc is nil.\n",
        label = "Date(year int, month time.Month, day int, hour int, min int, sec int, nsec int, loc *time.Location) time.Time",
        parameters = {
          {label = "year int"}, {label = "month time.Month"}, {label = "day int"},
          {label = "hour int"}, {label = "min int"}, {label = "sec int"}, {label = "nsec int"},
          {label = "loc *time.Location"}
        }
      }
    }
  }

  local cfg = {
    check_pumvisible = true,
    check_client_handlers = true,
    trigger_from_lsp_sig = true,
    line_to_cursor = "\ttime.Date(2020, ",
    triggered_chars = {'(', ','}
  }

  local signature = require "lsp_signature"
  signature.setup {debug = true, verbose = true}
  _LSP_SIG_CFG.debug = true
  _LSP_SIG_CFG.verbose = true
  local nvim_6 = true
  if debug.getinfo(vim.lsp.handlers.signature_help).nparams > 4 then
    nvim_6 = false
  end
  it("should show signature Date golang", function()
    local ctx = {method = "textDocument/signatureHelp", client_id = 1, buffnr = 0}
    -- local lines, s, l = signature.signature_handler(nil, result, ctx, cfg)
    local lines, s, l

    if nvim_6 then
      lines, s, l = signature.signature_handler(nil, result, ctx, cfg)
    else
      lines, s, l = signature.signature_handler(nil, "", result, 1, 1, cfg)
    end
    print("lines", vim.inspect(lines))
    eq(
        "Date(year int, month time.Month, day int, hour int, min int, sec int, nsec int, loc *time.Location) time.Time",
        lines[2])
    eq(5, s) -- match `year int`
    eq(13, l)
  end)
  it("should show fn add", function()

    _LSP_SIG_CFG.debug = false
    _LSP_SIG_CFG.floating_window = true

    result = {
      activeParameter = 0,
      signatures = {
        {
          active_parameter = 0,
          label = "fn add(left: i32, right: i32) -> i32",
          parameters = {{label = {7, 16}}, {label = {18, 28}}}
        }
      }
    }

    cfg = {
      check_pumvisible = true,
      check_client_handlers = true,
      trigger_from_lsp_sig = true,
      line_to_cursor = "    add(1, ",
      triggered_chars = {'(', ','}
    }

    local ctx = {method = "textDocument/signatureHelp", client_id = 1, buffnr = 0}
    if nvim_6 then
      lines, s, l = signature.signature_handler(nil, result, ctx, cfg)
    else
      lines, s, l = signature.signature_handler(nil, "", result, 1, 1, cfg)
    end

    eq("fn add(left: i32, right: i32) -> i32", lines[1])
    eq(7, s) -- match `year int`
    eq(16, l)
  end)

  it("should show signature with new line", function()
    _LSP_SIG_CFG.debug = false
    _LSP_SIG_CFG.floating_window = true

    result = {
      activeParameter = 1,
      activeSignature = 0,
      signatures = {
        {
          documentation = "HandleFunc registers a new route with a matcher for the URL path.\nSee Route.Path() and Route.HandlerFunc().\n",
          label = "HandleFunc(path string, f func(http.ResponseWriter,\n\t*http.Request)) *mux.Route",
          parameters = {
            {label = "path string"}, {label = "f func(http.ResponseWriter,\n\t*http.Request)"}
          }
        }
      }
    }

    cfg = {
      check_pumvisible = true,
      check_client_handlers = true,
      trigger_from_lsp_sig = true,
      line_to_cursor = [[\t HandleFunc(" / ", ]],
      triggered_chars = {'(', ','}
    }

    local ctx = {method = "textDocument/signatureHelp", client_id = 1, buffnr = 0}

    if nvim_6 then
      lines, s, l = signature.signature_handler(nil, result, ctx, cfg)
    else
      lines, s, l = signature.signature_handler(nil, "", result, 1, 1, cfg)
    end

    eq("HandleFunc(path string, f func(http.ResponseWriter,  *http.Request)) *mux.Route", lines[2])
  end)

end)
