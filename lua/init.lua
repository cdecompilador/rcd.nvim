local M = {}

M.config = {}

M.default_config = {}

M.show = function()
    local split = function(str, delimiter)
        local w = ""
        local i = 1

        local iterator = function()
            while i <= #str do
                local c = str:sub(i, i)
                i = i + 1

                if c ~= delimiter then
                    w = w .. c
                elseif #w > 0 then
                    local res = w
                    w = ""

                    return res
                end
            end

            if #w > 0 then
                local res = w
                w = ""

                return res
            end

            return nil
        end

        return iterator
    end

    local words = function(str)
        return split(str, " ")
    end

    local map = function(iter, map_fn)
        local iterator = function()
            local v = iter()

            if v == nil then
                return nil
            end

            return map_fn(v)
        end

        return iterator
    end
 
    local group_by_len = function(iter, group_size)
        local pending = nil

        local total_len = function(l)
            local acc = 0
            for _, v in ipairs(l) do
                acc = acc + #v
            end

            return acc
        end

        local iterator = function()
            local res = {}

            while true do
                local w
                if pending == nil then
                    w = iter()
                else
                    w = pending
                    pending = nil
                end

                if w == nil then
                    break
                end

                if total_len(res) + #w < group_size then
                    table.insert(res, w)
                else
                    pending = w

                    break
                end
            end
            
            if #res == 0 then
                return nil
            else
                return res
            end
        end

        return iterator
    end

    local split_message = function(str, max_col)
        return map(group_by_len(words(str), max_col), function(ws)
            return table.concat(ws, " ")
        end)
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

            for part in parts do
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
