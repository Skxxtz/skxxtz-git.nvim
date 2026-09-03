local M = {}

function M.register()
    local view = require("skxxtz-git.view")
    local state = require("skxxtz-git.state")
    local ui = require("skxxtz-git.ui")
    local git = require("skxxtz-git.git")

    view.register("status", {
        sticky = true,
        create = function()
            ui.async_refresh()
            return state.buf
        end,
        on_leave = function()
            ui.close_diff()
        end,
        keymaps = function(buf)
            local km = state.config.keymaps.status

            view.local_map(buf, "n", km.stage, function()
                local file = git.get_file_under_cursor()
                git.stage_file(file, function()
                    ui.async_refresh()
                    ui.show_diff_at_cursor()
                end)
            end, { desc = "Stage file under cursor" })

            view.local_map(buf, "n", km.unstage, function()
                local file = git.get_file_under_cursor()
                git.unstage_file(file, function()
                    ui.async_refresh(ui.show_diff_at_cursor)
                end)
            end, { desc = "Unstage file under cursor" })

            view.local_map(buf, "n", km.stage_all, function()
                git.stage_all(function()
                    ui.async_refresh()
                    ui.close_diff()
                end)
            end, { desc = "Stage all changes" })

            view.local_map(buf, "n", km.unstage_all, function()
                git.unstage_all(function()
                    ui.async_refresh()
                    ui.close_diff()
                end)
            end, { desc = "Unstage all changes" })

            view.local_map(buf, "n", km.push, function()
                ui.start_spinner("Pushing to Remote")
                git.push(function(error)
                    if not error then
                        ui.stop_spinner("✔ Pushed", 2000)
                        ui.async_refresh(ui.show_diff_at_cursor)
                    else
                        ui.stop_spinner("Error", 2000)
                        ui.show_message(error)
                    end
                end)
            end, { desc = "Push local commits" })

            view.local_map(buf, "n", km.commit, function()
                view.switch("commit")
            end, { desc = "Open commit buffer" })

            view.local_map(buf, "n", km.branch, function()
                view.switch("branch")
            end, { desc = "Open branch buffer" })

            view.local_map(buf, "n", km.close, function()
                if state.win and vim.api.nvim_win_is_valid(state.win) then
                    vim.api.nvim_win_close(state.win, true)
                end
            end, { desc = "Close window" })

            view.local_map(buf, "n", km.pull, function()
                ui.start_spinner("Pulling from remote")
                git.pull(function(status, detail)
                    if not status then
                        ui.stop_spinner("✔ Pulled", 2000)
                        ui.async_refresh(ui.show_diff_at_cursor)
                    elseif status == "dirty" then
                        ui.stop_spinner("Error", 2000)
                        vim.ui.select({ "Yes", "No" }, {
                            prompt = "You have uncommitted changes. Stash, pull, and restore them?",
                        }, function(choice)
                            if choice ~= "Yes" then return end
                            ui.start_spinner("Stashing and pulling")
                            git.stash_and_pull(function(err)
                                if err then
                                    ui.stop_spinner("Error", 2000)
                                    ui.show_message(err)
                                else
                                    ui.stop_spinner("✔ Pulled", 2000)
                                end
                                ui.async_refresh(ui.show_diff_at_cursor)
                            end)
                        end)
                    elseif status == "conflict" then
                        ui.stop_spinner("Conflict", 2000)
                        ui.show_message(detail or "Pull resulted in conflicts — resolve manually")
                    else
                        ui.stop_spinner("Error", 2000)
                        ui.show_message(detail or "Pull failed")
                    end
                end)
            end, { desc = "Pull from remote" })
        end,
    })
end

return M
