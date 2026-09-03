local config = require("skxxtz-git.config")

local M = {
    ui_buf = nil,
    ui_win = nil,
    diff_buf = nil,
    diff_win = nil,
    timer = vim.uv.new_timer(),
    title_locked = false,
    current_view = nil,
    view_buf = nil,
}

M.config = config.defaults

function M.default_buffer_is_valid()
    local win_ok = M.win and vim.api.nvim_win_is_valid(M.win)
    local buf_ok = M.buf and vim.api.nvim_buf_is_valid(M.buf)
    return win_ok and buf_ok
end

return M
