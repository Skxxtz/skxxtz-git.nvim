local M = {}

local modules = {
    "status",
    "staging",
    "branch",
    "commit",
    "remote",
}

for _, name in ipairs(modules) do
    local mod = require("skxxtz-git.git." .. name)
    for fn_name, fn in pairs(mod) do
        M[fn_name] = fn
    end
end

return M
