local M = {}
local state = require("skxxtz-git.state")
local ui = require("skxxtz-git.ui")
local highlights = require("skxxtz-git.highlights")
local keymaps = require("skxxtz-git.keymaps")

function M.setup(user_config)
    -- merge user config into defaults
    state.config = vim.tbl_deep_extend("force", state.config, user_config or {})
    highlights.setup()
end

function M.open()
    local buf = vim.api.nvim_create_buf(false, true)
    local b_opts = {
        buftype = "nofile",
        bufhidden = "hide",
        modifiable = false,
        swapfile = false,
    }
    ui.set_opts(buf, b_opts, false)
    state.buf = buf

    vim.cmd("botright 10split")

    local win = vim.api.nvim_get_current_win()
    local w_opts = {
        number = false,
        relativenumber = false,
        winfixheight = true,
        wrap = false,
        spell = false,
        fillchars = "eob: ",
        foldenable = false,
        foldcolumn = "0",
        statuscolumn = "",
        cursorline = false,
    }
    ui.set_opts(win, w_opts, true)
    state.win = win

    vim.api.nvim_buf_set_name(buf, "Skxxtz-Git")
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_set_option_value("winfixbuf", true, { win = win })

    -- Auto close diff window
    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(state.win),
        callback = function()
            ui.close_diff()

            if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
                vim.api.nvim_buf_delete(state.buf, { force = true })
            end

            state.win = nil
            state.buf = nil
        end,
        once = true
    })

    -- Auto load diff
    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = buf,
        callback = function()
            ui.debounced_diff()
        end
    })

    keymaps.set(buf)

    ui.async_refresh()
end

vim.api.nvim_create_user_command("SkxxtzGit", function()
    M.open()
end, {
    nargs = 0,
    desc = "Opens skxxtz git"
})

return M
