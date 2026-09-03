local M = {}

M.defaults = {
    keymaps = {
        back = "<esc>",
        status = {
            stage = "a",
            unstage = "u",
            stage_all = "<C-a>",
            unstage_all = "<C-u>",
            commit = "<C-c>",
            branch = "b",
            push = "p",
            close = "<esc>",
        },
        commit = {
            confirm = "<C-CR>",
        },
        branch = {
            switch = "<CR>",
            delete = "dd",
            create = "o",
            rename = "r",
        },
    },
}

function M.validate(cfg)
    for view_name, maps in pairs(cfg.keymaps) do
        if type(maps) == "table" then
            for action, key in pairs(maps) do
                if key ~= false and type(key) ~= "string" and type(key) ~= "table" then
                    vim.notify(string.format(
                        "skxxtz-git: invalid keymap for %s.%s (expected string, table, or false)",
                        view_name, action), vim.log.levels.WARN)
                end
            end
        elseif maps ~= false and type(maps) ~= "string" and type(maps) ~= "table" then
            vim.notify(string.format(
                "skxxtz-git: invalid keymap '%s' (expected string, table, or false)",
                view_name), vim.log.levels.WARN)
        end
    end
end

return M
