local M = {}
local state = require("skxxtz-git.state")

M.registry = {}

-- spec = {
--   create   = function(...) -> buf   -- build/reuse a buffer, return it
--   keymaps  = function(buf, ...)     -- optional, buffer-local maps for this view
--   on_leave = function(buf)          -- optional, cleanup when navigating away
--   sticky   = true|false             -- if true, <esc> closes the window instead of going back to status
-- }
function M.register(name, spec)
    M.registry[name] = spec
end

function M.switch(name, ...)
    local spec = M.registry[name]
    if not spec then
        vim.notify("skxxtz-git: unknown view '" .. name .. "'", vim.log.levels.ERROR)
        return
    end

    local win = state.win
    if not win or not vim.api.nvim_win_is_valid(win) then return end

    -- let the outgoing view clean up (e.g. status view closes its diff float)
    local prev = state.current_view and M.registry[state.current_view]
    if prev and prev.on_leave then
        prev.on_leave(state.view_buf)
    end

    local buf = spec.create(...)
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

    vim.api.nvim_set_option_value("winfixbuf", false, { win = win })
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_set_option_value("winfixbuf", true, { win = win })

    state.current_view = name
    state.view_buf = buf

    if spec.keymaps then
        spec.keymaps(buf, ...)
    end

    if not spec.sticky then
        vim.keymap.set("n", state.config.keymaps.close, function()
            M.switch("status")
        end, { buffer = buf, desc = "Back to status" })
    end
end

return M
