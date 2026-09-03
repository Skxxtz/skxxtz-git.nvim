local M = {}
local state = require("skxxtz-git.state")
local git = require("skxxtz-git.git")
local ui = require("skxxtz-git.ui")

function M.set(buf)
    if not buf or not vim.api.nvim_buf_is_valid(buf) then 
        vim.notify("Failed to set keymaps to nil buffer.", vim.log.levels.ERROR, {})
    end
    -- git add command
    vim.keymap.set("n", state.config.keymaps.stage, function ()
        local file = git.get_file_under_cursor()

        git.stage_file(file, function ()
            ui.async_refresh()
            ui.show_diff_at_cursor()
        end)
    end, { buffer = buf, desc = "Runs 'git add <file>' for file under cursor"})

    -- git restore command
    vim.keymap.set("n", state.config.keymaps.unstage, function ()
        local file = git.get_file_under_cursor()

        git.unstage_file(file, function ()
            ui.async_refresh(ui.show_diff_at_cursor)
        end)
    end, { buffer = buf, desc = "Runs 'git restore --staged <file>' for file under cursor"})

    -- git stage all
    vim.keymap.set("n", state.config.keymaps.stage_all, function ()
        git.stage_all(function ()
            ui.async_refresh()
            ui.close_diff()
        end)
    end, { buffer = buf, desc = "Runs 'git add .'"})

    -- git unstage all
    vim.keymap.set("n", state.config.keymaps.unstage_all, function ()
        git.unstage_all(function ()
            ui.async_refresh()
            ui.close_diff()
        end)
    end, { buffer = buf, desc = "Runs 'git restore --staged .'"})

    -- git push
    vim.keymap.set("n", state.config.keymaps.push, function ()
        ui.start_spinner("Pushing to Remote")
        git.push(function (error)
            if not error then
                ui.stop_spinner("✔ Pushed", 2000)
                ui.async_refresh(ui.show_diff_at_cursor)
            else
                ui.stop_spinner("Error", 2000)
                ui.show_message(error)
            end
        end)
    end, { buffer = buf, desc = "Push local commits" })

    --commit
    vim.keymap.set("n", state.config.keymaps.commit, function()
        -- temporary buffer for the commit message
        local commit_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("filetype", "gitcommit", { buf = commit_buf })
        vim.api.nvim_buf_set_name(commit_buf, "Commit Message:")

        -- open commit buffer
        local original_win = state.win
        vim.api.nvim_set_option_value("winfixbuf", false, {win = original_win})
        vim.api.nvim_win_set_buf(original_win, commit_buf)
        vim.api.nvim_set_option_value("winfixbuf", true, {win = original_win})

        vim.cmd("startinsert")

        -- keymap to commit
        vim.keymap.set("n", state.config.keymaps.confirm_commit, function()
            local lines = vim.api.nvim_buf_get_lines(commit_buf, 0, -1, false)
            local message = table.concat(lines, "\n")

            if message:match("%S") then
                git.commit(message, function()
                    -- Go back to the TUI buffer and refresh
                    if vim.api.nvim_win_is_valid(original_win) then
                        vim.api.nvim_set_option_value("winfixbuf", false, {win = original_win})
                        vim.api.nvim_win_set_buf(original_win, state.buf)
                        vim.api.nvim_set_option_value("winfixbuf", true, {win = original_win})
                        ui.async_refresh()
                    end
                end)
            else
                vim.notify("Commit cancelled: Empty message", vim.log.levels.WARN)
                vim.api.nvim_win_set_buf(original_win, state.buf)
            end
        end, { buffer = commit_buf, desc = "Confirm Commit" })

        -- keymap to cancel
        vim.keymap.set("n", "<esc>", function()
            vim.api.nvim_set_option_value("winfixbuf", false, {win = original_win})
            vim.api.nvim_win_set_buf(original_win, state.buf)
            vim.api.nvim_set_option_value("winfixbuf", true, {win = original_win})
        end, { buffer = commit_buf, desc = "Cancel Commit" })

    end, { buffer = buf, desc = "Open commit buffer" })

    vim.keymap.set("n", state.config.keymaps.branch, function ()
        ui.branch_view()
    end, { buffer = buf, desc = "Open branch buffer" })


    vim.keymap.set("n", state.config.keymaps.close, function()
        if state.win and vim.api.nvim_win_is_valid(state.win) then
            vim.api.nvim_win_close(state.win, true)
        end
    end, { buffer = buf, desc = "Close window" })
end

return M
