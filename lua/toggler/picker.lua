--- Picker module for toggler.nvim
--- Integrates with Snacks.nvim to provide a fuzzy-searchable picker UI for toggling configured
--- features on and off. Longer term this should be one way of covering display with a custom window
--- and Mini.nvim and Telescope as options too. I just don't want to write those right now and I
--- don't want to figure out a nice generic interface to abstract all that stuff behind.
---
--- This handles:
--- 1. verifying basic sanity of each of the config.features[]. validate_feature should probably be
---    moved over to the config module but I'm delaying that until I write a second picker support
---    that it can be generic.
--- 2. converting the config.features[].feature into a string that can be displayed by the picker
--- 3. wires up the 'confirm' function.  If I  moved that into the config multiple picker support
---    would be easier.
--- 3. wires up the 'highlight' function so that when you're fuzzy searching for things in snacks
---    you can see what matched. This is probably unique to each picker so it belongs here, but it
---    would be easier if it was pulled from config.
---
--- I'll make refactoring choices later. This is already way more work than I signed up for. I just
--- wanted to make my little UI toggle window something a friend could use and now there's like 10x
--- more code than I started with.
local config = require("toggler.config")
local commands = require("toggler.commands")

local M = {}

--- @type boolean
M.enabled = false

--- @type table?
M.snacks = nil

--- Validates that a feature has required methods and fields
--- @package
--- @param feature table the feature to validate
--- @return boolean, string? true if valid, or false and error message if invalid
local function validate_feature(feature)
  if not feature.name or type(feature.name) ~= "string" then
    return false, "Feature missing required 'name' field (must be a string)"
  end

  if not feature.get or type(feature.get) ~= "function" then
    return false, string.format("Feature '%s' missing required 'get' function", feature.name)
  end

  -- Test that feature.get is actually callable
  local ok, result = pcall(feature.get)
  if not ok then
    return false, string.format("Feature '%s' get function throws error: %s", feature.name, tostring(result))
  end

  if not feature.set then
    return false, string.format("Feature '%s' missing required 'set' field", feature.name)
  end

  local set_type = type(feature.set)
  if set_type ~= "string" and set_type ~= "function" then
    return false, string.format("Feature '%s' set must be a string or function, got %s", feature.name, set_type)
  end

  return true
end

--- @class TogglerDisplayFeature display version of a TogglerFeature for the picker UI
--- @field name string feature name displayed in the picker (from TogglerFeature.name)
--- @field description string feature description displayed in the picker (from TogglerFeature.description)
--- @field get fun():boolean function that returns current enabled state of the feature (from TogglerFeature.get)
--- @field set string|fun(state:boolean):nil action to toggle the feature when selected (from TogglerFeature.set)
--- @field icon string visual icon displayed next to the feature in the picker (reflects current status)
--- @field idx integer index of the feature in the features array
--- @field text string display text shown in the picker for this item
--- @see TogglerFeature for the source feature configuration
--- @see TogglerOptions for the overall configuration structure

--- Builds display entries for the picker from configured features
--- kill goto -- like it's cool to use it just to piss people off but maybe nesting everything in a
--- big "else" block is nicer? Without a 'next' or 'continue' method in lua there's no a nice
--- non-goto way of doing this.
--- @package
--- @return TogglerDisplayFeature[]
local function build_command_picker_entries()
  local items = {}
  for idx, feature in ipairs(config.options.features) do
    local valid, err = validate_feature(feature)
    if not valid then
      vim.notify(string.format("Toggler: Invalid feature configuration: %s", err), vim.log.levels.ERROR)
      goto continue
    end

    -- Determine current state and get appropriate icon
    local is_enabled = feature.get() == true
    local feature_icons = feature.icons or {}
    local icon = ""
    if is_enabled then
      icon = feature_icons.enabled or config.options.icons.enabled
    else
      icon = feature_icons.disabled or config.options.icons.disabled
    end

    local item = {
      idx = idx,
      name = feature.name,
      description = feature.description or "",
      icon = icon,
      is_enabled = is_enabled,
      text = string.format("%s  %s %s", icon, feature.name, feature.description or ""),
      get = feature.get,
      set = feature.set,
    }
    table.insert(items, item)
    ::continue::
  end
  return items
end

--- Runs the actual 'toggling' when you choose an item. This is an snacks.picker.Action.spec
--- Supports multi-select: toggles all selected items, or the current item if nothing is selected.
--- @package
---@diagnostic disable-next-line: unused-local
local confirm = function(picker, item)
  return picker:norm(function()
    picker:close()
    local selected_items = picker:selected({ fallback = true })
    for _, selected_item in ipairs(selected_items) do
      commands.execute_feature_action(selected_item, not selected_item.get())
    end
  end)
end

--- formats the item's text Applies highlight groups to each element (icon, name, description)
--- based on state and selection
--- @package
--- @param item table the item being formatted
--- @param picker table the picker instance to check selection state
--- @return table formatted segments with highlight groups
local format = function(item, picker)
  -- Determine if this item is selected
  local is_selected = false
  if picker and picker.selected then
    local selected_items = picker:selected()
    for _, selected_item in ipairs(selected_items) do
      if selected_item.idx == item.idx then
        is_selected = true
        break
      end
    end
  end

  -- Determine state suffix (On/Off)
  local state = item.is_enabled and "On" or "Off"
  local selected_suffix = is_selected and "Selected" or ""

  -- Build highlight group names
  local icon_hl = "TogglerPickerIcon" .. state .. selected_suffix
  local name_hl = "TogglerPickerName" .. state .. selected_suffix
  local desc_hl = "TogglerPickerDescription" .. state .. selected_suffix

  -- Build the formatted segments
  local segments = {
    { item.icon, icon_hl },
    { "  ", nil },
    { item.name, name_hl },
  }

  -- Add description if it exists
  if item.description and item.description ~= "" then
    table.insert(segments, { " ", nil })
    table.insert(segments, { item.description, desc_hl })
  end

  return segments
end

--- Opens the Snacks picker UI for toggling features Displays
--- @return nil
function M.picker()
   local window_options = vim.tbl_deep_extend("force", {}, config.options.window)
   window_options.items = build_command_picker_entries()
   window_options.confirm = confirm
   window_options.format = format
   Snacks.picker(window_options)
end

return M
