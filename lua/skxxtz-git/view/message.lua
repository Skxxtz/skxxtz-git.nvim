local M = {}

function M.register()
    local view = require("skxxtz-git.view")

    view.register("message", {
        create = function(message)
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
            vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { message })
            vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
            return buf
        end,
    })
end

return M
