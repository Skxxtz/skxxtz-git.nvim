local M = {}

function M.register()
    local view = require("skxxtz-git.view")
    local state = require("skxxtz-git.state")
    local ui = require("skxxtz-git.ui")

    view.register("status", {
        sticky = true,
        create = function()
            ui.async_refresh()
            return state.buf
        end,
        on_leave = function()
            ui.close_diff()
        end,
    })
end

return M
