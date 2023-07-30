local M = {}

M.config = {}

M.default_config = {}

M.show = function()
    local split_message = function(message, max_col)
        local parts = {}
        for i = 1, #message, max_col do
            table.insert(parts, message:sub(i, i + max_col - 1))
        end

        return parts
    end

    local get_hl_by_severity = function(severity)
        local hls = {
            error = 'DiagnosticVirtualTextError',
            warn = 'DiagnosticVirtualTextWarn',
            info = 'DiagnosticVirtualTextInfo',
            hint = 'DiagnosticVirtualTextHint',
        }

        local severity_map = {
            [vim.diagnostic.severity.ERROR] = "error",
            [vim.diagnostic.severity.WARN] = "warn",
            [vim.diagnostic.severity.INFO] = "info",
            [vim.diagnostic.severity.HINT] = "hint",
        }

        return hls[severity_map[severity]]
    end

    -- Extract buffer/terminal info
    local curr_cursor = vim.api.nvim_win_get_cursor(0)
    local max_col = vim.api.nvim_get_option("columns") * (3 / 4)
    local topline = vim.fn.getwininfo(vim.fn.win_getid())[1].topline

    -- Delete the old extmarks
    if M.current_extmark_ids then
        for _, id in ipairs(M.current_extmark_ids) do
            vim.api.nvim_buf_del_extmark(0, M.ns_id, id)
        end
    end
    M.current_extmark_ids = {}

    -- Retrieve the diagnostics
    local line_diags = vim.diagnostic.get(0, { lnum = curr_cursor[1] - 1 })
    local extmark_diags = {}

    -- Sort by severity level
    table.sort(line_diags, function(a, b) return a.severity < b.severity end)

    -- Process the diagnostics so they fit on the terminal properly
    for _, entry in ipairs(line_diags) do
        local message = entry.message
        local hl = get_hl_by_severity(entry.severity)

        if #message > max_col then
            local parts = split_message(message, max_col)

            for _, part in ipairs(parts) do
                table.insert(extmark_diags, { part, hl })
            end
            table.insert(extmark_diags, { "", "" })
        else
            table.insert(extmark_diags, { message, hl })
            table.insert(extmark_diags, { "", "" })
        end
    end

    -- Show the diagnostics
    for i, entry in ipairs(extmark_diags) do
        if entry == {} then
            break
        end

        local l = topline + i - 1
        local id = vim.api.nvim_buf_set_extmark(0, M.ns_id, l, 0, {
            virt_text = { entry },
            virt_text_pos = "right_align",
            virt_lines_above = true,
            strict = false
        })

        table.insert(M.current_extmark_ids, id)
    end

    M.last_cursor = curr_cursor
end

M.setup = function(opts)
    -- Parse user provided configuration
    M.config = vim.tbl_deep_extend('keep', opts or {}, M.default_config)

    local au_rcd_group = vim.api.nvim_create_augroup("right_corner_diagnostics", {})
    local show_autocmds = { "CursorMoved", "TextChangedI", "TextChanged" }

    M.ns_id = vim.api.nvim_create_namespace("rcd")

    vim.api.nvim_create_autocmd(show_autocmds, {
        group = au_rcd_group,
        callback = function(opts)
            -- Avoid re-render when the cursor just changed column in normal mode
            if opts.event == "CursorMoved" and M.last_cursor then
                local curr_cursor = vim.api.nvim_win_get_cursor(0)
                if M.last_cursor[1] == curr_cursor[1] then
                    return
                end
            end

            vim.schedule(M.show)
        end
    })

    print("hello rcd")
end

return M
