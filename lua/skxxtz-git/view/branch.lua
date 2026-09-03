local M = {}

function M.register()
    local view = require("skxxtz-git.view")
    local git = require("skxxtz-git.git")
    local state = require("skxxtz-git.state")

    view.register("branch", {
        create = function()
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
            vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
            return buf
        end,
        keymaps = function(buf)
            local function refresh()
                git.fetch_branches(function(branches)
                    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, branches)
                    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
                end)
            end

            git.fetch_branches(function(branches)
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, branches)
                vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
            end)

            view.local_map(buf, "n", state.config.keymaps.branch.switch, function()
                local line = vim.api.nvim_get_current_line()
                local name = line:gsub("^[%s●]+", "")
                if name == "" or line:match("───") then return end
                git.switch_branch(name, refresh)
            end, { desc = "Switch branch" })

            view.local_map(buf, "n", state.config.keymaps.branch.delete, function ()
                local line = vim.api.nvim_get_current_line()
                local name = line:gsub("^[%s●]+", "")
                if name == "" or line:match("───") then return end
                git.delete_branch(name, refresh)
            end, { desc = "Delete branch"})

            view.local_map(buf, "n", state.config.keymaps.branch.create, function ()
                vim.ui.input({ prompt = "New branch: " }, function(input)
                    if not input or input == "" then return end
                    vim.system({ "git", "checkout", "-b", input }, {}, function()
                        vim.schedule(refresh)
                    end)
                end)
            end, { desc = "Create branch" })
        end,
    })
end

return M
