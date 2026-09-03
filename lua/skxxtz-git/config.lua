local M = {}

M.defaults = {
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

return M
