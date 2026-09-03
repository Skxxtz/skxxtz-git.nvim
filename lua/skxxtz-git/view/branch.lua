local M = {}

local branch_ns = vim.api.nvim_create_namespace("skxxtz-git-branch")

local UPSTREAM_ICON = ""
local NO_UPSTREAM_ICON = "󱓌"

local MAX_NAME_LEN = 30
local GAP = 5

local function truncate(name, max_len)
    if vim.fn.strdisplaywidth(name) <= max_len then
        return name
    end
    -- reserve 1 col for the ellipsis
    local truncated = vim.fn.strcharpart(name, 0, max_len - 1)
    return truncated .. "…"
end

local function render_lines(branches)
    local names = {}
    for name in pairs(branches) do table.insert(names, name) end
    table.sort(names, function(a, b)
        if branches[a].is_active ~= branches[b].is_active then
            return branches[a].is_active
        end
        return a < b
    end)

    local name_col_width = MAX_NAME_LEN + 2

    local lines = {}
    local name_end_cols = {}
    local upstream_start_cols = {}
    local upstream_present = {}

    for _, name in ipairs(names) do
        local b = branches[name]
        local prefix = b.is_active and "● " or "  "
        local display_name = truncate(name, MAX_NAME_LEN)
        local left = prefix .. display_name

        local upstream_text
        if not b.has_upstream then
            upstream_text = NO_UPSTREAM_ICON .. "  " .. "no upstream"
            table.insert(upstream_present, false)
        else
            local sync = ""
            if b.ahead > 0 and b.behind > 0 then
                sync = string.format(" ↑%d ↓%d", b.ahead, b.behind)
            elseif b.ahead > 0 then
                sync = string.format(" ↑%d", b.ahead)
            elseif b.behind > 0 then
                sync = string.format(" ↓%d", b.behind)
            end
            upstream_text = UPSTREAM_ICON .. "  " .. b.upstream_name .. sync
            table.insert(upstream_present, true)
        end

        local pad_width = name_col_width - vim.fn.strdisplaywidth(left) + GAP
        local padding = string.rep(" ", pad_width)
        local line = left .. padding .. upstream_text

        table.insert(name_end_cols, #left)
        table.insert(upstream_start_cols, #left + #padding)
        table.insert(lines, line)
    end

    return lines, names, name_end_cols, upstream_start_cols, upstream_present
end

local function highlight_lines(buf, names, branches, name_end_cols, upstream_start_cols, upstream_present)
    vim.api.nvim_buf_clear_namespace(buf, branch_ns, 0, -1)
    for i, name in ipairs(names) do
        local b = branches[name]
        local sync_group = b.is_synced and "Normal" or "SkxxtzGitBranchUnsynced"

        vim.api.nvim_buf_set_extmark(buf, branch_ns, i - 1, 0, {
            end_col = name_end_cols[i],
            hl_group = sync_group,
        })

        local upstream_group = upstream_present[i] and "Normal" or "Comment"
        vim.api.nvim_buf_set_extmark(buf, branch_ns, i - 1, upstream_start_cols[i], {
            end_line = i,
            hl_group = upstream_group,
            hl_eol = true,
        })
    end
end

function M.register()
    local view = require("skxxtz-git.view")
    local state = require("skxxtz-git.state")
    local git = require("skxxtz-git.git")
    local current_branches = {}

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
                    if not vim.api.nvim_buf_is_valid(buf) then return end

                    current_branches = branches
                    local lines, names, name_end_cols, upstream_start_cols, upstream_present = render_lines(branches)
                    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
                    highlight_lines(buf, names, branches, name_end_cols, upstream_start_cols, upstream_present)
                    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
                end)
            end

            refresh()

            local km = state.config.keymaps.branch

            view.local_map(buf, "n", km.switch, function()
                local line = vim.api.nvim_get_current_line()
                local name = line:match("^[%s●]+(%S+)")
                if not name or line:match("───") then return end

                git.switch_branch(name, function(status, detail)
                    if not status then
                        refresh()
                    elseif status == "dirty" then
                        vim.ui.select({ "Yes", "No" }, {
                            prompt = "You have uncommitted changes. Stash, switch, and restore them?",
                        }, function(choice)
                            if choice ~= "Yes" then return end
                            git.stash_and_switch(name, function(err)
                                if err then
                                    require("skxxtz-git.ui").show_message(err)
                                end
                                refresh()
                            end)
                        end)
                    else
                        require("skxxtz-git.ui").show_message(detail or "Switch failed")
                    end
                end)
            end, { desc = "Switch branch" })

            view.local_map(buf, "n", km.delete, function()
                local line = vim.api.nvim_get_current_line()
                local name = line:match("^[%s●]+(%S+)")
                if not name or line:match("───") then return end
                git.delete_branch(name, refresh)
            end, { desc = "Delete branch" })

            view.local_map(buf, "n", km.create, function()
                vim.ui.input({ prompt = "New branch: " }, function(input)
                    if not input or input == "" then return end
                    vim.system({ "git", "checkout", "-b", input }, {}, function()
                        vim.schedule(refresh)
                    end)
                end)
            end, { desc = "Create branch" })

            view.local_map(buf, "n", km.rename, function()
                local line = vim.api.nvim_get_current_line()
                local name = line:match("^[%s●]+(%S+)")
                if not name or line:match("───") then return end

                vim.ui.input({ prompt = "Rename '" .. name .. "' to: ", default = name }, function(input)
                    if not input or input == "" or input == name then return end
                    git.rename_branch(name, input, refresh)
                end)
            end, { desc = "Rename branch" })

            view.local_map(buf, "n", km.merge, function()
                local line = vim.api.nvim_get_current_line()
                local name = line:match("^[%s●]+(%S+)")
                if not name or line:match("───") then return end

                if current_branches[name] and current_branches[name].is_active then
                    vim.notify("Already on " .. name, vim.log.levels.WARN)
                    return
                end

                vim.ui.select({ "Yes", "No" }, { prompt = "Merge '" .. name .. "' into current branch?" }, function(choice)
                    if choice ~= "Yes" then return end
                    git.merge_branch(name, function(err)
                        if err then
                            require("skxxtz-git.ui").show_message(err)
                        else
                            refresh()
                        end
                    end)
                end)
            end, { desc = "Merge branch into current" })

            view.local_map(buf, "n", km.set_upstream, function()
                local line = vim.api.nvim_get_current_line()
                local name = line:match("^[%s●]+(%S+)")
                if not name or line:match("───") then return end

                if current_branches[name] and current_branches[name].has_upstream then
                    vim.notify(name .. " already has an upstream", vim.log.levels.WARN)
                    return
                end

                vim.ui.input({ prompt = "Set upstream for '" .. name .. "' (remote): ", default = "origin" }, function(remote)
                    if not remote or remote == "" then return end
                    git.set_upstream(name, remote, function(err)
                        if err then
                            require("skxxtz-git.ui").show_message(err)
                        else
                            refresh()
                        end
                    end)
                end)
            end, { desc = "Set upstream for branch" })
        end,
    })
end

return M
