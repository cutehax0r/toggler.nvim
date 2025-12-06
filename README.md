# Toggler

A Neovim UI for toggling features on and off. Manage multiple feature toggles in one place without saving state between sessions.

![IOU a UI Demo](./docs/demo.gif)

(See [Motivation](#motivation) for more context on why this plugin exists.)

## Installation
The minimum viable configuration looks something like this:

### Lazy.nvim

```lua
{
  "cutehax0r/toggler.nvim",
  dependencies = {
    "folke/snacks.nvim"
  },
  command = {
    "Toggler"
  },
  config = function()
    require('toggler').setup({
      features = {
        -- Define your features here
        {
          name = "Spelling",
          description = "Show red underline for spelling errors",
          get = function() return vim.wo.spell end,
          set = ":set spell!",
        },
      }
    })
  end,
}
```

After installation, use `:Toggler` to open the picker window.

## Usage

### GUI

The picker window provides an interactive interface for toggling features:

```
:Toggler picker     " open the picker window
:Toggler            " same as above
```

**Keyboard shortcuts in the picker:**
- Fuzzy search: type to filter features by name or description
- Navigate: `<C-n>` (next) / `<C-p>` (previous)
- Select one: press `<enter>` to toggle the selected feature
- Select multiple: press `<tab>` to mark features, then `<enter>` to toggle all marked features at once
- Close: `<esc>`

### Command Line

Use the CLI for scripting or direct feature toggling:

```vim
:Toggler get <name>                " show current state of a feature
:Toggler set <name> <state>        " set a feature to a specific state
:Toggler toggle <name>             " toggle a feature on/off
```

**State values:** `true`, `false`, `on`, `off`, `enabled`, `disabled`

**Examples:**

```vim
:Toggler get Spelling              " notify: Spelling is enabled
:Toggler set Spelling false        " disable Spelling
:Toggler toggle Spelling           " toggle Spelling
:Toggler set "Multi Word Name" on  " quotes needed for multi-word feature names
```

Tab completion is available for feature names.

## Configuration

Toggler is configured via `require('toggler').setup(opts)` with the following structure:

### Features

The `features` table is an array of feature definitions. Each feature must have:

- **`name`** (string): Short identifier for the feature (used in CLI commands). Must be unique.
- **`get`** (function): Returns a boolean indicating current state (`true` = enabled, `false` = disabled).
- **`set`** (string | function): How to toggle the feature. Can be one of:
  - **Vim command string** (e.g., `":set spell!"`) - executed as a command
  - **Keystroke sequence** (e.g., `"<C-w>n"`, `"tt"`) - sent to Neovim as key input
  - **Lua function** (e.g., `function(state) vim.diagnostic.enable(state) end`) - receives the target boolean state

Optional fields:
- **`description`** (string): User-friendly description. Used for fuzzy search and display.
- **`icons`** (table): Per-feature icon overrides
  - **`icons.enabled`** (string): Icon when feature is enabled (overrides global default)
  - **`icons.disabled`** (string): Icon when feature is disabled (overrides global default)

### Window

The `window` table configures the picker UI. Options are passed directly to [snacks.nvim's picker](https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/config.lua#L69).

Common customizations:
- `title`: Window title (default: `"Toggle Distractions"`)
- `layout`: Layout preset (default: `{ preset = "vscode" }`)
- `prompt`: Prompt string (default: `"❯ "`)
- `auto_close`: Close window after toggling (default: `true`)
- `enter`: Focus the window on open (default: `true`)
- `preview`: Preview pane setting (default: `"none"`)

See [snacks.picker config](https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/config.lua#L69) for all available options.

### Icons

Global icon defaults for all features:

```lua
icons = {
  enabled = "[x]",   " icon when feature is enabled
  disabled = "[ ]",  " icon when feature is disabled
}
```

Per-feature icons (in a feature's `icons` table) override these defaults.

### Highlights

Customize the appearance of the picker with highlight groups. Each highlight can link to an existing group or define custom styling:

```lua
highlights = {
  TogglerPickerIconOn = { link = "DiagnosticOk" },
  TogglerPickerNameOn = { link = "Normal", bold = true },
  TogglerPickerDescriptionOn = { link = "Comment" },
  
  TogglerPickerIconOff = { link = "DiagnosticError" },
  TogglerPickerNameOff = { link = "Normal" },
  TogglerPickerDescriptionOff = { link = "Comment" },
  
  TogglerPickerIconOnSelected = { link = "Search" },
  TogglerPickerNameOnSelected = { link = "Search", bold = true },
  TogglerPickerDescriptionOnSelected = { link = "Search" },
  
  TogglerPickerIconOffSelected = { link = "Search" },
  TogglerPickerNameOffSelected = { link = "Search", bold = true },
  TogglerPickerDescriptionOffSelected = { link = "Search" },
}
```

See [nvim_set_hl()](https://neovim.io/doc/user/api.html#nvim_set_hl()) for available highlight attributes (e.g., `fg`, `bg`, `bold`, `italic`, `underline`, etc.).

## Example Configurations

### Basic Examples
These are some examples of feature configuration. They should be placed inside of the `config`
function's call to `setup()`
```lua
  opts = {
   features = {
     --- examples are assumed to be placed in here
  }
}
```

**Minimum viable feature**
```lua
{
  name = "Lines",
  get = function() return vim.wo.number end,
  set = ":set number!",
}

```

**Maximum viable feature**
```lua
{
    name = "Lines",
    description = "Line numbers on the left side of a window",
    icons = {
        enabled = "",
        disabled = "",
    },
    get = function()
        return vim.wo.number
    end,
    set = function(state)
        vim.wo.number = state
    end,
}
```

**Toggle spelling (Vim command):**
```lua
{
  name = "Spelling",
  description = "Show red underline for spelling errors",
  get = function() return vim.wo.spell end,
  set = ":set spell!",
}
```

**Toggle diagnostics (Lua function):**
```lua
{
  name = "Diagnostics",
  description = "Show inline diagnostics",
  get = function() return vim.diagnostic.is_enabled() end,
  set = function(state) vim.diagnostic.enable(state) end,
}
```

**Toggle quickfix (Keystrokes):**
```lua
{
  name = "Quickfix",
  description = "Toggle quickfix window",
  get = function()
    -- Returns true if quickfix list is not empty
    return #vim.fn.getqflist() > 0
  end,
  set = "<C-q>",  -- Assumes <C-q> is bound to toggle quickfix (e.g., with vim-unimpaired)
}
```

### Advanced Pattern: Extracting Hidden State

Use `debug.getupvalue()` to access internal state from plugins that don't expose a public API:

```lua
{
  name = "Context VT (Tree-sitter)",
  description = "Scope closing tree-sitter context",
  get = function()
    local _, value = debug.getupvalue(require("nvim_context_vt").toggle_context, 1)
    return value.enabled
  end,
  set = ":NvimContextVtToggle",
}
```

It's fragile (depends on the plugin's internal implementation) but useful when a plugin doesn't provide a proper way to query state.

### Multi-Feature Batch Toggling

A key advantage of Toggler is toggling multiple features at once. For example, disable an autocomplete plugin and enable GitHub Copilot simultaneously to prevent competing completions:

```lua
local function toggle_completion_sources(state)
  -- Toggle blink.cmp off
  require("blink.cmp").setup({ enabled = state })
  
  -- Toggle GitHub Copilot on (inverse)
  if state then
    vim.cmd("Copilot disable")
  else
    vim.cmd("Copilot enable")
  end
end

return {
  name = "Completion Mode",
  description = "Toggle between blink.cmp and GitHub Copilot",
  get = function() return vim.b.cmp_enabled ~= false end,
  set = toggle_completion_sources,
}
```

With the GUI, you can mark both "Completion Mode" and other features, then toggle everything with one keystroke.

## Motivation

I have many Neovim settings that add visual clutter: spelling error underlines, completion popups, virtual text markers, inline diagnostics. Most of the time I want these features enabled, but sometimes I need a distraction-free view for focused work.

The problem:
- Remembering all the command names is tedious (`:set spell!`, `:set signcolumn=no`, `:Copilot disable`, `:NvimContextVtToggle`, etc.)
- Typing each command individually is slow, especially when toggling 5+ settings
- Creating keybindings for all combinations quickly becomes unwieldy

### Comparison with snacks.toggle

[snacks.toggle](https://github.com/folke/snacks.nvim/blob/main/lua/snacks/toggle.lua) (from snacks.nvim) is excellent for individually toggled features with keybindings. Use it when you want quick keystroke-based toggles.

Toggler is designed for **grouped, interactive toggling**:
- One UI to manage all feature toggles that aren't worthy of having their own better keybind
- Batch toggle multiple features at once (e.g., turn off blink.cmp AND enable GitHub Copilot simultaneously)
- Fuzzy-searchable interface for quickly finding available toggles
- A command-line UI to provide a nice wrapper around features or groups of features

Both tools are useful; choose based on your workflow:

See the [snacks.toggle docs](https://github.com/folke/snacks.nvim/blob/main/lua/snacks/toggle.lua) to compare in detail.

## Dependencies

- **[folke/snacks.nvim](https://github.com/folke/snacks.nvim)** - Provides the picker UI used by Toggler
