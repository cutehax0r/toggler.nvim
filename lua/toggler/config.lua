--- Configuration module for Toggler. We provide some minimal defaults but you're really supposed to
--- set this up yourself.
---
--- * `TogglerFeature` class defines a single 'menu item' that you can toggle on or off. These are
---   defined in config.opts.features[].
---
--- * `Window` is passed almost unmodified to Snacks.picker so if you want to customize the display
---   or keys you should look there. snacks.Picker class is what you want to check for options.
---
--- * `Icons` are there just to look pretty. While you can't disable them, you could set empty
---   strings. That would screw up the indenting but I'm lazy and don't want to fix that right now.
--- 
--- * `Highlights` are there to customize the display of the window. They're linked to existing
---    highlights by default because I don't think it really matters that much.
local M = {}

--- @class TogglerFeature definition of UI feature to toggle on/off
--- @field name string short name of the feature (used with CLI `toggle` and `status`)
--- @field description? string user-friendly description of the feature being toggled
--- @field get fun():boolean function that returns true/false for whether the feature is currently enabled
--- @field set string|fun(state:boolean):nil how to toggle the feature. Can be:
---   - Vim command string starting with `:` (e.g., ":set spell!")
---   - Key sequence string without prefix (e.g., "<C-w>n" for key chords)
---   - Lua function that receives the target state (boolean) and performs the action
--- @field icon? string an icon for the selector item. Defaults to a checkbox that toggles based on status
--- @field icons? table optional per-feature icons that override global icons
--- @field icons.enabled? string icon to display when this feature is enabled (overrides global)
--- @field icons.disabled? string icon to display when this feature is disabled (overrides global)
--- @see TogglerDisplayFeature for the display version of this feature
--- @see TogglerOptions for the options structure
--- @class TogglerHighlightConfig table of highlight definitions for nvim_set_hl()
--- See: https://neovim.io/doc/user/api.html#nvim_set_hl()
--- Each key is a highlight group name, and the value is a table of highlight attributes
--- (e.g., link, bold, italic, fg, bg, ctermfg, ctermbg, etc.)
---
--- @class TogglerOptions configuration options for the toggler
--- @field features TogglerFeature[] list of features to toggle
--- @field window? table snacks.picker window configuration
--- @field icons? table icon strings for feature states
--- @field icons.enabled? string icon to display when feature is enabled (default: "[x]")
--- @field icons.disabled? string icon to display when feature is disabled (default: "[ ]")
--- @field highlights? TogglerHighlightConfig table of highlight group definitions for nvim_set_hl()
--- @see TogglerFeature for individual feature configuration

--- Default configuration for toggler
--- Provides sensible defaults that are merged with user-supplied options during setup()
--- @type TogglerOptions
M.defaults = {
  --- @type TogglerFeature[]
  features = {
    --- This is a minimal example of declaring a feature that can be toggled.
    --- By default it'll use a custom icon that appears as a 'checkbox' that is checked
    --- when enabled and unchecked when not enabled.
    {
      name = "Spelling",
      description = "Show a red underline for spelling errors.",
      get = function() return vim.wo.spell end,
      set = ":set spell!",
    },
  },
  --- this is a snacks.picker.config
  --- https://github.com/folke/snacks.nvim/blob/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/picker/config/defaults.lua#L69
  --- `format`, `items`, and `confirm` will be overriden.
  window = {
    title = "Toggle Distractions",
    layout = { preset = "vscode", },
    prompt = "❯ ",
    auto_close = true,
    enter = true,
    preview = "none",
  },
  icons = {
    enabled = "[x]",
    disabled = "[ ]",
  },
  highlights = {
    TogglerPickerIconOn = { link = "DiagnosticOk" },
    TogglerPickerNameOn = { link = "Normal", bold = true },
    TogglerPickerDescriptionOn = { link = "Comment" },
    TogglerPickerIconOff = { link = "DiagnosticError" },
    TogglerPickerNameOff = { link = "Normal", bold = true },
    TogglerPickerDescriptionOff = { link = "Comment" },
    TogglerPickerIconOnSelected = { link = "Search" },
    TogglerPickerNameOnSelected = { link = "Search", bold = true },
    TogglerPickerDescriptionOnSelected = { link = "Search" },
    TogglerPickerIconOffSelected = { link = "Search" },
    TogglerPickerNameOffSelected = { link = "Search", bold = true },
    TogglerPickerDescriptionOffSelected = { link = "Search" },
  },
}

--- Merged configuration for toggler
--- This is the result of merging M.defaults with user-supplied options via setup()
--- Populated during setup() and used at runtime by the picker
--- @type TogglerOptions
M.options = {
  features = {},
  window = {},
  icons = {},
  highlights = {},
}

--- Applies highlight group definitions to Neovim
--- @package
--- @param highlights table table of highlight group definitions
--- @return nil
local function setup_highlights(highlights)
  for group_name, group_config in pairs(highlights or {}) do
    vim.api.nvim_set_hl(0, group_name, group_config)
  end
end

--- @param options? TogglerOptions user configuration to merge with defaults
--- @return nil
function M.setup(options)
  options = options or {}
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, options)
  setup_highlights(M.options.highlights)
end

return M
