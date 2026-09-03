local M = {}

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

return M
