return {
    'adam-coates/todoist.nvim',
    lazy = false,
    module = false,  -- Don't try to load as a module
    rocks = nil,     -- Explicitly disable LuaRocks for this plugin
    config = function()
        require('todoist').setup()
    end
}
