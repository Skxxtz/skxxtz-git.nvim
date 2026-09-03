local M = {}

local NON_FILE_PATTERNS = {
    "^On branch", "^Your branch", "^no changes", "^nothing added",
    "^nothing to commit", "^Changes to be committed:",
    "^Changes not staged for commit:", "^Untracked files:",
    "^HEAD detached",
}

function M.get_file_under_cursor()
    local line = vim.api.nvim_get_current_line()
    if not line or line == "" or line:match("───") then return nil end

    local trimmed = line:gsub("^%s+", "")
    for _, pat in ipairs(NON_FILE_PATTERNS) do
        if trimmed:match(pat) then return nil end
    end

    local file = line:match("modified:%s+(%S+)")
        or line:match("deleted:%s+(%S+)")
        or line:match("renamed:%s+.*%s+->%s+(%S+)")
        or line:match("new file:%s+(%S+)")
        or line:match("^[%sMADRC%?][%sMADRC%?]%s+(%S+)")
        or trimmed:match("^(%S+)")

    if not file or file == "" or file:match(":$") then
        return nil
    end

    return file
end

function M.fetch_status(callback)
    vim.system({ "git", "status" }, { text = true }, function(obj)
        local lines = {}
        if obj.code == 0 and obj.stdout ~= "" then
            for line in obj.stdout:gmatch("[^\r\n]+") do
                if not line:match("^%s*%(")
                    and not line:match("^%s*use \"git")
                    and not line:match("^%s*no changes added to commit") then
                    table.insert(lines, "  " .. line)
                end
            end
        else
            table.insert(lines, "Clean / Not a git repo")
        end

        vim.schedule(function()
            callback(lines)
        end)
    end)
end

function M.format_diff(stdout)
    if not stdout or stdout == "" then return {} end

    local diff_lines = {}
    local raw_lines = vim.split(stdout, "[\r\n]")

    for _, line in ipairs(raw_lines) do
        local hunk_header, hunk_content = line:match("^(@@.-@@)(.*)$")

        if hunk_header then
            if #diff_lines > 0 then
                table.insert(diff_lines, "")
            end

            table.insert(diff_lines, "  " .. string.rep("─", 30))
            table.insert(diff_lines, hunk_header)

            if hunk_content and hunk_content:match("%S") then
                table.insert(diff_lines, hunk_content)
            end
        else
            table.insert(diff_lines, line)
        end
    end

    return diff_lines
end

function M.get_diff(file, callback)
    vim.system({ "git", "diff", "HEAD", "--unified=3", "--", file }, { text = true }, function(obj)
        local formatted = M.format_diff(obj.stdout)

        if callback then
            vim.schedule(function()
                callback(formatted)
            end)
        end
    end)
end

function M.stage_file(file, callback)
    if not file or file == "" then return end

    vim.system({ "git", "add", file }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                vim.notify("Staged: " .. file, vim.log.levels.INFO)
            else
                vim.notify("Failed to stage: " .. file, vim.log.levels.ERROR)
            end

            if callback then callback() end
        end)
    end)
end

function M.unstage_file(file, callback)
    if not file or file == "" then return end

    vim.system({ "git", "restore", "--staged", file }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                vim.notify("Unstaged: " .. file, vim.log.levels.INFO)
            else
                vim.notify("Failed to unstage: " .. file, vim.log.levels.ERROR)
            end

            if callback then callback() end
        end)
    end)
end

function M.stage_all(callback)
    vim.system({ "git", "add", "." }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                vim.notify("Staged all changes", vim.log.levels.INFO)
            else
                vim.notify("Failed to stage all changes", vim.log.levels.ERROR)
            end

            if callback then callback() end
        end)
    end)
end

function M.unstage_all(callback)
    vim.system({ "git", "restore", "--staged", "." }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                vim.notify("Unstaged all staged changes", vim.log.levels.INFO)
            else
                vim.notify("Failed to unstage all staged changes", vim.log.levels.ERROR)
            end
            if callback then callback() end
        end)
    end)
end

function M.fetch_branches(callback)
    local format = "%(HEAD)|%(refname:short)|%(upstream:short)|%(upstream:track)"
    vim.system({ "git", "branch", "--format=" .. format }, { text = true }, function(obj)
        local branches = {}
        if obj.code == 0 and obj.stdout ~= "" then
            for line in obj.stdout:gmatch("[^\r\n]+") do
                local head, name, upstream, track = line:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
                if name and name ~= "" then
                    local ahead = track:match("ahead (%d+)")
                    local behind = track:match("behind (%d+)")
                    branches[name] = {
                        is_active = (head == "*"),
                        has_upstream = (upstream ~= ""),
                        upstream_name = (upstream ~= "" and upstream or nil),
                        ahead = ahead and tonumber(ahead) or 0,
                        behind = behind and tonumber(behind) or 0,
                        is_synced = (upstream ~= "" and track == ""),
                        is_commit_branch = true,
                    }
                end
            end
        end

        if next(branches) == nil then
            vim.system({ "git", "symbolic-ref", "--short", "HEAD" }, { text = true }, function(head_obj)
                local unborn_branches = {}
                if head_obj.code == 0 then
                    local unborn_name = head_obj.stdout:gsub("%s+", "")
                    unborn_branches[unborn_name] = {
                        is_active = true,
                        has_upstream = false,
                        ahead = 0,
                        behind = 0,
                        is_synced = false,
                        is_commit_branch = false,
                    }
                end
                vim.schedule(function() callback(unborn_branches) end)
            end)
        else
            vim.schedule(function() callback(branches) end)
        end
    end)
end

function M.switch_branch(branch, callback)
    if not branch or branch == "" then return end
    vim.system({ "git", "switch", branch }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                vim.notify("Switched to: " .. branch, vim.log.levels.INFO)
                if callback then callback() end
            elseif obj.stderr and obj.stderr:match("Please commit your changes or stash them") then
                if callback then callback("dirty", obj.stderr) end
            else
                vim.notify("Failed to switch: " .. (obj.stderr or ""), vim.log.levels.ERROR)
                if callback then callback("error", obj.stderr) end
            end
        end)
    end)
end

function M.stash_and_switch(branch, callback)
    if not branch or branch == "" then return end

    vim.system({ "git", "stash", "push", "-m", "skxxtz-git: auto-stash before switch" }, { text = true }, function(stash_obj)
        if stash_obj.code ~= 0 then
            vim.schedule(function()
                vim.notify("Stash failed: " .. (stash_obj.stderr or ""), vim.log.levels.ERROR)
                if callback then callback("Stash failed") end
            end)
            return
        end

        vim.system({ "git", "switch", branch }, { text = true }, function(checkout_obj)
            if checkout_obj.code ~= 0 then
                vim.schedule(function()
                    vim.notify("Switch failed after stash: " .. (checkout_obj.stderr or ""), vim.log.levels.ERROR)
                    if callback then callback("Switch failed, changes remain stashed") end
                end)
                return
            end

            vim.system({ "git", "stash", "pop" }, { text = true }, function(pop_obj)
                vim.schedule(function()
                    if pop_obj.code == 0 then
                        vim.notify("Switched to " .. branch .. " and restored changes", vim.log.levels.INFO)
                        if callback then callback(nil) end
                    else
                        vim.notify("Switched, but couldn't reapply stash (conflict): " .. (pop_obj.stderr or ""), vim.log.levels.WARN)
                        if callback then callback("Switched, but stash pop conflicted — resolve manually (git stash list)") end
                    end
                end)
            end)
        end)
    end)
end

function M.delete_branch(branch, callback)
    if not branch or branch == "" then return end
    vim.system({ "git", "branch", "-d", branch }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                vim.notify("Deleted branch: " .. branch, vim.log.levels.INFO)
            else
                vim.notify("Failed to delete: " .. (obj.stderr or ""), vim.log.levels.ERROR)
            end
            if callback then callback() end
        end)
    end)
end

function M.rename_branch(old_name, new_name, callback)
    if not old_name or old_name == "" or not new_name or new_name == "" then return end

    vim.system({ "git", "branch", "-m", old_name, new_name }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                vim.notify("Renamed: " .. old_name .. " → " .. new_name, vim.log.levels.INFO)
            else
                vim.notify("Failed to rename: " .. (obj.stderr or ""), vim.log.levels.ERROR)
            end
            if callback then callback() end
        end)
    end)
end

function M.merge_branch(branch, callback)
    if not branch or branch == "" then return end

    vim.system({ "git", "merge", branch }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                vim.notify("Merged: " .. branch, vim.log.levels.INFO)
            else
                vim.notify("Merge failed: " .. (obj.stderr or ""), vim.log.levels.ERROR)
            end
            if callback then callback(obj.code ~= 0 and (obj.stderr or "Merge failed") or nil) end
        end)
    end)
end

function M.set_upstream(branch, remote, callback)
    if not branch or branch == "" then return end
    remote = remote or "origin"

    vim.system({ "git", "push", "-u", remote, branch }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                vim.notify("Upstream set: " .. remote .. "/" .. branch, vim.log.levels.INFO)
                if callback then callback() end
            else
                vim.notify("Failed to set upstream: " .. (obj.stderr or ""), vim.log.levels.ERROR)
                if callback then callback(obj.stderr or "Failed to set upstream") end
            end
        end)
    end)
end

function M.commit(message, callback)
    if not message or message == "" then return end

    vim.system({ "git", "commit", "-F", "-" }, { stdin = message }, function(obj)
        vim.schedule(function()
            if obj.code ~= 0 then
                if callback then
                    callback(obj.stderr or "Unknown error")
                else
                    vim.notify("Commit failed: " .. (obj.stderr or ""), vim.log.levels.ERROR)
                end
            else
                if callback then
                    callback(nil)
                end
            end
        end)
    end)
end

function M.push(callback)
    vim.system({ "git", "push" }, {}, function(obj)
        vim.schedule(function()
            local error = nil
            if obj.code == 0 then
                vim.notify("Committed all staged changes", vim.log.levels.INFO)
            else
                error = obj.stderr
            end
            if callback then callback(error) end
        end)
    end)
end

return M
