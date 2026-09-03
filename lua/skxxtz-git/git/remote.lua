local M = {}

function M.push(callback)
    vim.system({ "git", "push" }, {}, function(obj)
        vim.schedule(function()
            local error = nil
            if obj.code == 0 then
                vim.notify("Pushed to remote", vim.log.levels.INFO)
            else
                error = obj.stderr
            end
            if callback then callback(error) end
        end)
    end)
end

function M.stash_and_pull(callback)
    vim.system({ "git", "stash", "push", "-m", "skxxtz-git: auto-stash before pull" }, { text = true }, function(stash_obj)
        if stash_obj.code ~= 0 then
            vim.schedule(function()
                vim.notify("Stash failed: " .. (stash_obj.stderr or ""), vim.log.levels.ERROR)
                if callback then callback("Stash failed") end
            end)
            return
        end

        vim.system({ "git", "pull" }, { text = true }, function(pull_obj)
            if pull_obj.code ~= 0 then
                vim.schedule(function()
                    vim.notify("Pull failed after stash: " .. (pull_obj.stderr or ""), vim.log.levels.ERROR)
                    if callback then callback("Pull failed, changes remain stashed") end
                end)
                return
            end

            vim.system({ "git", "stash", "pop" }, { text = true }, function(pop_obj)
                vim.schedule(function()
                    if pop_obj.code == 0 then
                        vim.notify("Pulled and restored changes", vim.log.levels.INFO)
                        if callback then callback(nil) end
                    else
                        vim.notify("Pulled, but couldn't reapply stash (conflict): " .. (pop_obj.stderr or ""), vim.log.levels.WARN)
                        if callback then callback("Pulled, but stash pop conflicted — resolve manually (git stash list)") end
                    end
                end)
            end)
        end)
    end)
end

function M.pull(callback)
    vim.system({ "git", "pull" }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                vim.notify("Pulled from remote", vim.log.levels.INFO)
                if callback then callback() end
            elseif obj.stderr and obj.stderr:match("Please commit your changes or stash them") then
                if callback then callback("dirty", obj.stderr) end
            elseif obj.stderr and obj.stderr:match("You have unmerged paths") then
                if callback then callback("conflict", obj.stderr) end
            else
                vim.notify("Pull failed: " .. (obj.stderr or ""), vim.log.levels.ERROR)
                if callback then callback("error", obj.stderr) end
            end
        end)
    end)
end

function M.fetch(callback)
    vim.system({ "git", "fetch", "--all" }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                vim.notify("Fetched from remote", vim.log.levels.INFO)
                if callback then callback() end
            else
                vim.notify("Fetch failed: " .. (obj.stderr or ""), vim.log.levels.ERROR)
                if callback then callback(obj.stderr or "Fetch failed") end
            end
        end)
    end)
end

return M
