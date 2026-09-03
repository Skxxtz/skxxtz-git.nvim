local M = {}

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

return M
