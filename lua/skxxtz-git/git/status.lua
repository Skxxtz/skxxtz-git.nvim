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

return M
