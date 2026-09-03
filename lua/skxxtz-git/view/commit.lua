local M = {}

function M.register()
    local view = require("skxxtz-git.view")
    local state = require("skxxtz-git.state")
    local git = require("skxxtz-git.git")

    view.register("commit", {
        create = function()
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_set_option_value("filetype", "gitcommit", { buf = buf })
            vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
            vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
            vim.api.nvim_buf_set_name(buf, "Commit Message:" .. buf)
            vim.cmd("startinsert")
            return buf
        end,
        keymaps = function(buf)
            view.local_map(buf, "n", state.config.keymaps.confirm_commit, function ()
                local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                local msg_lines = {}
                for _, l in ipairs(lines) do
                    if not l:match("^#") then table.insert(msg_lines, l) end
                end
                local message = table.concat(msg_lines, "\n"):gsub("%s+$", "")

                if message:match("%S") then
                    git.commit(message, function()
                        view.switch("status")
                    end)
                else
                    vim.notify("Commit cancelled: Empty message", vim.log.levels.WARN)
                    view.switch("status")
                end
            end, { desc = "Confirm Commit" })
        end,
    })
end

return M
