local M = {}
local state = require("skxxtz-git.state")
local git = require("skxxtz-git.git")

local ns = vim.api.nvim_create_namespace("skxxtz-git")
local diff_ns = vim.api.nvim_create_namespace("skxxtz-git-diff")

local function classify(line)
    if line:match("^%s*On branch") or line:match("^%s*HEAD detached") then
        return "SkxxtzGitBranch"
    elseif line:match("Changes to be committed") or line:match("Changes not staged")
        or line:match("Untracked files") then
        return "SkxxtzGitHeader"
    elseif line:match("new file:") then
        return "SkxxtzGitStaged"
    elseif line:match("modified:") then
        return "SkxxtzGitModified"
    elseif line:match("deleted:") then
        return "SkxxtzGitDeleted"
    elseif line:match("renamed:") then
        return "SkxxtzGitRenamed"
    end
    return nil
end

function M.highlight_status(lines)
    vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
    for i, line in ipairs(lines) do
        local group = classify(line)
        if group then
            vim.api.nvim_buf_set_extmark(state.buf, ns, i - 1, 0, {
                end_line = i,
                hl_group = group,
                hl_eol = true,
            })
        end
    end
end

local function classify_diff(line)
    if line:match("^%s*─+%s*$") then
        return "SkxxtzGitDiffSep"
    elseif line:match("^@@.-@@") then
        return "SkxxtzGitDiffHunk"
    elseif line:match("^diff %-%-git") or line:match("^index ")
        or line:match("^%-%-%- ") or line:match("^%+%+%+ ") then
        return "SkxxtzGitDiffMeta"
    elseif line:match("^%+") then
        return "SkxxtzGitDiffAdd"
    elseif line:match("^%-") then
        return "SkxxtzGitDiffDelete"
    end
    return nil
end

function M.highlight_diff(lines)
    vim.api.nvim_buf_clear_namespace(state.diff_buf, diff_ns, 0, -1)
    for i, line in ipairs(lines) do
        local group = classify_diff(line)
        if group then
            vim.api.nvim_buf_set_extmark(state.diff_buf, diff_ns, i - 1, 0, {
                end_line = i,
                hl_group = group,
                hl_eol = true,
            })
        end
    end
end


local function parse_status_summary(lines)
    local branch = "detached"
    local staged, unstaged, untracked, section = 0, 0, 0, nil

    for _, line in ipairs(lines) do
        local b = line:match("On branch (%S+)")
        if b then branch = b end

        local detached = line:match("HEAD detached at (%S+)")
        if detached then branch = "detached@" .. detached end

        if line:match("Changes to be committed:") then section = "staged"
        elseif line:match("Changes not staged for commit:") then section = "unstaged"
        elseif line:match("Untracked files:") then section = "untracked"
        elseif line:match("modified:") or line:match("new file:")
            or line:match("deleted:") or line:match("renamed:") then
            if section == "staged" then staged = staged + 1
            elseif section == "unstaged" then unstaged = unstaged + 1 end
        elseif section == "untracked" and line:match("%S") and not line:match(":$") then
            untracked = untracked + 1
        end
    end

    return branch, staged, unstaged, untracked
end

function M.async_refresh(callback)
    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
    git.fetch_status(function(git_lines)
        local branch, staged, unstaged, untracked = parse_status_summary(git_lines)
        local title = string.format(" %s · %d staged · %d unstaged · %d untracked ",
            branch, staged, unstaged, untracked)

        vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf })
        vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, git_lines)
        M.highlight_status(git_lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })

        vim.api.nvim_buf_set_name(state.buf, title)

        if callback then callback() end
    end)
end

function M.set_opts(target, opts, is_win)
    local key = is_win and "win" or "buf"
    for k, v in pairs(opts) do
        vim.api.nvim_set_option_value(k, v, { [key] = target })
    end
end

function M.show_message(message)
    if not message or #message == 0 then
        return
    end

    -- temporary buffer for the commit message
    local message_buf = vim.api.nvim_create_buf(false, true)

    -- open commit buffer
    local original_win = state.win
    vim.api.nvim_set_option_value("winfixbuf", false, { win = original_win })
    vim.api.nvim_win_set_buf(original_win, message_buf)
    vim.api.nvim_set_option_value("winfixbuf", true, { win = original_win })

    -- set buf opts and content
    local opts = {
        buftype = "nofile",
        bufhidden = "wipe",
        modifiable = false,
        swapfile = false,
    }
    vim.api.nvim_buf_set_lines(message_buf, 0, -1, false, { message })
    M.set_opts(message_buf, opts, false)

    -- return map
    vim.keymap.set("n", "<esc>", function()
        vim.api.nvim_set_option_value("winfixbuf", false, { win = original_win })
        vim.api.nvim_win_set_buf(original_win, state.buf)
        vim.api.nvim_set_option_value("winfixbuf", true, { win = original_win })
        M.async_refresh(M.show_diff_at_cursor)
    end, { buffer = message_buf, desc = "Cancel Commit" })
end

function M.create_diff_window()
    local tui_h = 0
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        tui_h = vim.api.nvim_win_get_height(state.win)
    else
        return
    end

    local available_h = vim.o.lines - tui_h - 2
    local available_w = vim.o.columns

    local w = math.floor(available_w * 0.8)
    local h = math.floor(available_h * 0.65)

    local row = math.floor((available_h - h) / 2)
    local col = math.floor((available_w - w) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = w,
        height = h,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = " Git Diff ",
        title_pos = "center",
        focusable = true,
    })

    vim.api.nvim_set_option_value("winhighlight", "Normal:Normal,FloatBorder:Normal", { win = win })

    M.set_opts(buf, {
        filetype = "gitdiff",
        buftype = "nofile",
        bufhidden = "wipe",
        modifiable = false,
        swapfile = false
    }, false)

    return buf, win
end

function M.close_diff()
    if state.diff_win and vim.api.nvim_win_is_valid(state.diff_win) then
        vim.api.nvim_win_close(state.diff_win, true)
    end
    state.diff_win = nil
    state.diff_buf = nil
end

function M.show_diff_at_cursor()
    local file = git.get_file_under_cursor()

    if not file then
        M.close_diff()
        state.diff_file = nil
        return
    end

    -- already showing this file's diff — nothing to do
    if file == state.diff_file and state.diff_win and vim.api.nvim_win_is_valid(state.diff_win) then
        return
    end

    local request_id = (state.diff_request or 0) + 1
    state.diff_request = request_id

    git.get_diff(file, function(diff_lines)
        -- a newer request started after this one — discard
        if state.diff_request ~= request_id then return end

        if not diff_lines or #diff_lines == 0 then
            M.close_diff()
            state.diff_file = nil
            return
        end

        if not state.diff_win or not vim.api.nvim_win_is_valid(state.diff_win)
            or not state.diff_buf or not vim.api.nvim_buf_is_valid(state.diff_buf) then
            local buf, win = M.create_diff_window()
            state.diff_buf = buf
            state.diff_win = win
        end

        state.diff_file = file

        vim.api.nvim_set_option_value("modifiable", true, { buf = state.diff_buf })
        vim.api.nvim_buf_set_lines(state.diff_buf, 0, -1, false, diff_lines)
        M.highlight_diff(diff_lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = state.diff_buf })

        if vim.b[state.diff_buf].diff_syntax_loaded ~= true then
            vim.api.nvim_buf_call(state.diff_buf, function()
                vim.cmd("syntax on")
            end)
            vim.b[state.diff_buf].diff_syntax_loaded = true
        end

        vim.api.nvim_win_set_config(state.diff_win, { title = " " .. file .. " " })
    end)
end

function M.debounced_diff()
    state.timer:stop()
    state.timer:start(150, 0, vim.schedule_wrap(function()
        M.show_diff_at_cursor()
    end))
end

function M.start_spinner(message, spinner_frames)
    spinner_frames = spinner_frames or { " ", "·", "∘", "o", "O", "@", "*", " " }
    local frame = 1
    M.stop_spinner()

    if not state.default_buffer_is_valid() then return end

    local initial_content = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)

    state.status_bar_timer = vim.uv.new_timer()
    state.status_bar_timer:start(0, 100, vim.schedule_wrap(function()
        if not state.default_buffer_is_valid() then
            M.stop_spinner()
            return
        end

        local current_frame = spinner_frames[frame]
        local header = string.format("  %s %s ", current_frame, message)
        -- update the buffer
        vim.api.nvim_buf_set_name(state.buf, header)

        frame = (frame % #spinner_frames) + 1
    end))
end

function M.stop_spinner(final_msg, delay_ms)
    -- 1. Kill any existing timer (Animation or previous Delay)
    if state.status_bar_timer then
        if state.status_bar_timer:is_active() then
            state.status_bar_timer:stop()
        end
        if not state.status_bar_timer:is_closing() then
            state.status_bar_timer:close()
        end
        state.status_bar_timer = nil
    end

    if not state.default_buffer_is_valid() then return end

    local name = final_msg or "Skxxtz-Git"
    vim.api.nvim_buf_set_name(state.buf, name)

    if delay_ms and delay_ms > 0 then
        state.status_bar_timer = vim.uv.new_timer()
        state.status_bar_timer:start(delay_ms, 0, vim.schedule_wrap(function()
            -- Verify buffer still exists
            if state.default_buffer_is_valid() then
                vim.api.nvim_buf_set_name(state.buf, "Skxxtz-Git")
            end

            if state.status_bar_timer then
                state.status_bar_timer:stop()
                state.status_bar_timer:close()
                state.status_bar_timer = nil
            end
        end))
    end
end

function M.branch_view()
    local original_win = state.win

    -- Helper to refresh the buffer content without closing the window
    local function refresh_branch_view(buf)
        git.fetch_branches(function(branches)
            if not branches or #branches == 0 then
                M.async_refresh()
            end

            -- Allow editing to change lines, then lock it back
            vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, branches)
            vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
        end)
    end

    git.fetch_branches(function(branches)
        if not branches or #branches == 0 then return end

        local branch_buf = vim.api.nvim_create_buf(false, true)

        -- open buffer in existing window
        vim.api.nvim_set_option_value("winfixbuf", false, { win = original_win })
        vim.api.nvim_win_set_buf(original_win, branch_buf)
        vim.api.nvim_set_option_value("winfixbuf", true, { win = original_win })

        vim.api.nvim_buf_set_lines(branch_buf, 0, -1, false, branches)
        M.set_opts(branch_buf, { buftype = "nofile", modifiable = false }, false)

        vim.keymap.set("n", "<CR>", function()
            local line = vim.api.nvim_get_current_line()
            local branch_name = line:gsub("^[%s●]+", "")
            if branch_name == "" or line:match("───") then return end

            git.switch_branch(branch_name, function()
                refresh_branch_view(branch_buf)
            end)
        end, { buffer = branch_buf })

        vim.keymap.set("n", "a", function()
            vim.ui.input({ prompt = "New branch: " }, function(input)
                if not input or input == "" then return end

                vim.system({ "git", "checkout", "-b", input }, {}, function()
                    vim.schedule(function()
                        refresh_branch_view(branch_buf)
                    end)
                end)
            end)
        end, { buffer = branch_buf })

        -- exit mapping
        vim.keymap.set("n", "<esc>", function()
            vim.api.nvim_set_option_value("winfixbuf", false, { win = original_win })
            vim.api.nvim_win_set_buf(original_win, state.buf)
            vim.api.nvim_set_option_value("winfixbuf", true, { win = original_win })
            M.async_refresh(M.show_diff_at_cursor)
        end, { buffer = branch_buf })
    end)
end

return M
