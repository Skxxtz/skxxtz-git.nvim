local M = {}

function M.setup()
    local links = {
        SkxxtzGitBranch           = "Title",
        SkxxtzGitHeader           = "Comment",
        SkxxtzGitStaged           = "DiffAdd",
        SkxxtzGitModified         = "DiffChange",
        SkxxtzGitDeleted          = "DiffDelete",
        SkxxtzGitRenamed          = "DiffText",
        SkxxtzGitUntracked        = "NonText",

        -- diff view
        SkxxtzGitDiffAdd          = "DiffAdd",
        SkxxtzGitDiffDelete       = "DiffDelete",
        SkxxtzGitDiffHunk         = "Title",
        SkxxtzGitDiffMeta         = "Comment",
        SkxxtzGitDiffSep          = "NonText",

        -- branch view
        SkxxtzGitBranchSynced     = "String",
        SkxxtzGitBranchUnsynced   = "WarningMsg",
        SkxxtzGitUpstream         = "Comment",
    }
    for group, link in pairs(links) do
        vim.api.nvim_set_hl(0, group, { link = link, default = true })
    end
end

return M
