--- The command line interface to Toggler is defined here. For these examples `foo` is the `name` of
--- some feature you've configured when you setup the plugin. The command line interface supports:
---
--- * `:Toggler get foo` to return the status of the `foo` feature. True = on, false = off.
---
--- * `:Toggler set foo on` forces the `foo` feature on. You can also use `off` to force it off. For
--- convenience it also supports true/false and enabled/disabled. Maybe that isn't worth the
--- complexity?
---
--- * `:Toggler toggle foo` turns on foo if it's off and turns off foo if it's on.
---
--- * `:Toggler picker` displays the snacks picker so you can use a graphical interface to toggle
--- things.
---
--- If the `name` of the feature is multiple words then quote it. Tab completion is supported. 

local config = require("toggler.config")

local M = {}

--- The sub-commands that are currently supported for `:Toggler`.
--- @type string[]
local SUBCOMMANDS = { "get", "set", "toggle", "picker", }

--- These exist so that you can run `:Toggler set Foo on` or `Toggler set foo true` without needing
--- to remember to pass exactly the right thing as the status string.
---
--- Maybe this is too much and I should just force the use of true/false everywhere.
--- @type table<string, boolean>
local STATE_MAP = {
  on = true,
  enabled = true,
  ["true"] = true,
  off = false,
  disabled = false,
  ["false"] = false,
}

--- You're expected to define features in the configuration when setting up the plugin. When
--- toggling/getting/setting a feature by name we need to look the feature up from in
--- config.features[]. If the feature is not defined/found then We'll pass back nil and let the user
--- know that the feature isn't found by error notification.
---
--- That error would indicate that there's probably a typo in the name in the configuration or in
--- the command line call they made.
--- @package
--- @param feature_name string the `name` attribute from the features definition in configuration
--- @return TogglerFeature|nil # The full feature from configuration or nil if not found
local function get_feature_or_error(feature_name)
  -- is there some sort of vim.tbl_* method to find a feature by function?
  for _, feature in ipairs(config.options.features) do
    if feature.name == feature_name then
      return feature
    end
  end
  vim.notify(string.format("Feature not found: %s", feature_name), vim.log.levels.ERROR)
  return nil
end

--- Executes a feature's set action. This can be a lua function or a string that contains either a
--- Neovim command line declaration, or just some keystrokes to play back.
--- Errors are caught and reported via vim.notify() so that down-stream doesn't need to trap and
--- alert when they happen.
--- @param feature TogglerFeature the feature from config
--- @param state boolean the desired state. caller must use STATE_MAP to map user input to boolean
--- @return nil
function M.execute_feature_action(feature, state)
  if type(feature.set) == "string" then
    if feature.set:find("^:") then
      ---@diagnostic disable-next-line: param-type-mismatch
      local ok, err = pcall(vim.cmd, feature.set:sub(2))
      if not ok then
        vim.notify(string.format("Failed to execute command '%s': %s", feature.set:sub(2), tostring(err)),
          vim.log.levels.ERROR)
      end
    else
      local ok, err = pcall(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        local keystrokes = vim.api.nvim_replace_termcodes(feature.set, true, true, true)
        vim.api.nvim_input(keystrokes)
      end)
      if not ok then
        vim.notify(string.format("Failed to execute keystrokes '%s': %s", feature.set, tostring(err)),
          vim.log.levels.ERROR)
      end
    end
  else
    ---@diagnostic disable-next-line: param-type-mismatch
    local ok, err = pcall(feature.set, state)
    if not ok then
      vim.notify(string.format("Failed to execute feature setter: %s", tostring(err)), vim.log.levels.ERROR)
    end
  end
end
--- @class ParsedCommand command entered in command mode parsed into something 'nice'
--- @field command string|nil The command that was run `:foo bar baz` has command = foo
--- @field subcommand string|nil one of the SUBCOMMANDS
--- @field feature_name string|nil the name of a feature as defined in config.feature[].name
--- @field status string|nil the desired target status as entered by the user
--- Parses the full command line string into structured components. E.g. `:Toggler set "some feature" on`
--- returns {command="Toggler", subcommand="set", feature_name="some feature", status="on"}
--- Missing components will be nil.

--- Simple approach: split on spaces (first part is command), then parse args respecting quotes.
--- @param cmdline string The full command line string (e.g., `:Toggler set foo on`)
--- @return ParsedCommand
local function parse_command(cmdline)
  -- Split by spaces to get command and args string
  local parts = vim.split(cmdline, "%s+", { trimempty = true })

  -- First part is the command with colon (e.g., `:Toggler`), extract just the name. This is extra.
  local command = parts[1] and parts[1]:match("^:(.*)$") or nil

  -- Reconstruct the arg_string (everything after the command) to parse quoted strings properly
  local arg_string = ""
  if #parts > 1 then
    arg_string = table.concat(parts, " ", 2)
  end

  -- Parse the arguments handling basic quoting. It's a half-assed state machine and not really a
  -- parser but it'll work well enough if you don't make features with names that include escaped or
  -- nested quotes.  Read arg_string char-by-char, if we're getting letters then append them to the
  -- current word. If we get a space then append the current word to the args stack.  If we see a
  -- quote then allow 'current word' to keep building even if we hit a space. Keep going until we
  -- see the same quote that started the whole capture to begin with. It's naive so escaped quote,
  -- nested quote, unmatched quotes, and god knows what else can break this.
  local args = {}
  local current = ""
  local in_quotes = false
  local quote_char = nil

  for i = 1, #arg_string do
    local char = arg_string:sub(i, i)
    if (char == '"' or char == "'") and not in_quotes then
      in_quotes = true
      quote_char = char
    elseif char == quote_char and in_quotes then
      in_quotes = false
      quote_char = nil
    elseif char == " " and not in_quotes then
      if current ~= "" then
        table.insert(args, current)
        current = ""
      end
    else
      current = current .. char
    end
  end

  if current ~= "" then
    table.insert(args, current)
  end

  --- @type ParsedCommand
  return {
    command = command,
    subcommand = args[1],
    feature_name = args[2],
    status = args[3],
  }
end

--- This function is here to provide nice autocompletion when you're using the command line. It gets
--- wired up in the `enable()` function. Completions are determined by parsing the full command
--- line and determining which argument position we're at.
--- @param argLead string the leading portion of the argument being completed (unused)
--- @param cmdline string the entire command line that's been typed
--- @param cursorPos number the cursor position in the command line (unused)
--- @return string[] list of completion candidates
--- @diagnostic disable-next-line: unused-local
function M.complete_toggler(argLead, cmdline, cursorPos)
  local cmd_parts = parse_command(cmdline)

  -- Complete subcommands if we haven't typed one yet
  if not cmd_parts.subcommand then
    return SUBCOMMANDS
  end

  -- Complete feature names for commands that require them
  if (cmd_parts.subcommand == "get" or cmd_parts.subcommand == "set" or cmd_parts.subcommand == "toggle") then
    if not cmd_parts.feature_name then
      local feature_names = {}
      for _, feature in ipairs(config.options.features) do
        -- Wrap feature names with spaces in quotes for proper parsing
        if feature.name:match("%s") then
          table.insert(feature_names, string.format('"%s"', feature.name))
        else
          table.insert(feature_names, feature.name)
        end
      end
      return feature_names
    end
  end

  -- Complete state values for the `set` command
  if cmd_parts.subcommand == "set" and cmd_parts.feature_name and not cmd_parts.status then
    return vim.tbl_keys(STATE_MAP)
  end

  return {}
end

--- This what gets called when you run `:Toggler...` It parses the command line string using the
--- parse_command() function to convert it into structured components. It verifies that those
--- components are sane and then runs the appropriate action. While each of the 'subcommands'
--- could be broken out into smaller functions that gets kind of spaghetti for something this
--- simple. The best way to understand this function is to start by imagining somebody ran
--- `:Toggler set "Some feature" on`. This walks through the command word-by-word figuring out
--- what to do as it goes and then doing it.
--- @param opts table command options from nvim_create_user_command.
--- @param picker_callback function callback to show picker.
--- @see Picker.picker()
--- @return nil
function M.command_handler(opts, picker_callback)
  local command = parse_command("Toggler " .. opts.args)

  --- Check to see that we're working with a valid subcommand. If not, just bail out.
  --- Nil is valid it maps to picker as a default action
  if not vim.list_contains(SUBCOMMANDS, command.subcommand) and command.subcommand ~= nil then
    vim.notify(string.format("Unknown subcommand: %s. Use: %s", command.subcommand, table.concat(SUBCOMMANDS, ", ")), vim.log.levels.ERROR)
    return
  end

  --- Picker and callback don't take any args so we can ignore everything after the subcommand
  if not command.subcommand or command.subcommand == "picker" then
    picker_callback()
    return
  end

  --- we're dealing with sub commands that take arguments. All of them require a name of a feature
  --- to act on so we look that up once here. Looking up the feature handles error messages if one
  --- hasn't been defined.
  if not command.feature_name then
    vim.notify("Toggler " .. command.subcommand .. " requires a feature name", vim.log.levels.ERROR)
    return
  end
  -- there's probably a vim.tbl_* function that can do this for me. vim.tbl_contains({t}, {value}, {opts})
  -- with predicate = true in opts and search for command.feature_name, config.opts.features with a
  -- function.
  local feature = get_feature_or_error(command.feature_name)
  if not feature then
    return
  end

  --- Toggle and Get don't require a state so if we have the feature name we're ready to go now
  if command.subcommand == "toggle" then
    local current_state = feature.get()
    M.execute_feature_action(feature, not current_state)
    return
  elseif command.subcommand == "get" then
    local current_status = feature.get() and "enabled" or "disabled"
    vim.notify(string.format("%s is %s", command.feature_name, current_status))
    return
  end

  --- Set requires that you pass a desired state so look that up. Error if not present or invalid,
  --- otherwise we do the thing.  `subcommand == "set"` is implied by now but I'm being explicit.
  local target_state = STATE_MAP[command.status]
  if target_state == nil or command.subcommand ~= "set" then
    vim.notify("Toggler " .. command.subcommand .. " requires a desired status (" .. vim.iter(vim.tbl_keys(STATE_MAP)):join(', ') .. ")", vim.log.levels.ERROR)
  else
    M.execute_feature_action(feature, target_state)
  end
end

return M
