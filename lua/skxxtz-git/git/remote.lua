local M = {}

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
