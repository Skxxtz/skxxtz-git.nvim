local M = {
    ui_buf = nil,
    ui_win = nil,
    diff_buf = nil,
    diff_win = nil,
    diff_file = nil,
    timer = vim.uv.new_timer()
}

M.config = {
    keymaps = {
        stage = "a",
        unstage = "u",
        stage_all = "<C-a>",
        unstage_all = "<C-u>",
        commit = "<C-c>",
        push = "p",
        close = "<esc>",
        confirm_commit = "<C-CR>",
        branch = "b",
    }
}

function M.default_buffer_is_valid()
    local win_ok = M.win and vim.api.nvim_win_is_valid(M.win)
    local buf_ok = M.buf and vim.api.nvim_buf_is_valid(M.buf)
    return win_ok and buf_ok
end

return M
