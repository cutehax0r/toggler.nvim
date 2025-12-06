--- Provides setup() function to initialize the plugin with configuration
--- and enable the Snacks picker UI for toggling features
---
--- The interesting configuration documentation is over in config.lua.
--- If you're just curious 'how does it work' then commands.lua is where you can find the cli
--- and if you'd like to support either a custom window or add support for telescope/mini pickers
--- then take a look at picker.lua for inspiration
local M = {}

local picker = require("toggler.picker")
local commands = require("toggler.commands")

--- Initializes toggler with the provided configuration options
--- @see TogglerOptions for available configuration options
--- @see TogglerFeature for individual feature configuration
--- @param opts? TogglerOptions user configuration, merged with defaults
--- @return nil
function M.setup(opts)
   -- with the nvim 12 default loader, maybe this should change. We should just wire up the vim
  -- user command. Change that to do the setup on first invocation? It's convenient to setup called
  -- at vim boot during development but we might save 0.3ms of launch time by delaying the requires
  -- etc. until the first time the command is invoked. Right now Lazy is covering the delay.
   require("toggler.config").setup(opts)
   M.enable()
end

--- Initializes the Toggler user command Attempts to load and cache the Snacks plugin dependency
--- even though that should really be handled by the plugin manager. I'm paranoid I guess
--- @return nil
function M.enable()
   -- maybe too defensive? It covers the case of forgetting the dependency when loading
   local ok, snacks = pcall(require, "snacks")
   if ok then
     picker.snacks = snacks
   else
     vim.notify("toggler.picker requires Snacks. https://github.com/folke/snacks.nvim ")
     return
   end
   vim.api.nvim_create_user_command("Toggler", function(opts)
     commands.command_handler(opts, picker.picker)
   end, {
     nargs = "*",
     complete = commands.complete_toggler,
   })
   picker.enabled = true
end

return M
