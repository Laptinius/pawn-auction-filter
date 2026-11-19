local _, addon = ...
local FRAME_BUDGET_MS = 3
addon.ITEM_RETRY_SECONDS = 0.75

function addon.NewScan(rows)
    return { rows = rows, visible = {}, pending = {}, nextIndex = 1, retryAt = 0 }
end

-- Keep original row indices so late matches retain Blizzard's sort order.
-- A nil verdict means the item data is still loading. Only those rows need a retry.
function addon.AdvanceScan(scan, evaluate, now)
    local total = #scan.rows
    local pending, visible = scan.pending, scan.visible
    if scan.nextIndex > total and (#pending == 0 or now < scan.retryAt) then
        return total - #pending
    end
    local deadline = debugprofilestop() + FRAME_BUDGET_MS

    while scan.nextIndex <= total do
        local index = scan.nextIndex
        local keep = evaluate(scan.rows[index], now)
        scan.nextIndex = index + 1
        if keep then
            visible[#visible + 1] = index
        elseif keep == nil then
            pending[#pending + 1] = index
            if #pending == 1 then scan.retryAt = now + addon.ITEM_RETRY_SECONDS end
        end
        if debugprofilestop() >= deadline then break end
    end

    if #pending > 0 and scan.nextIndex > total and now >= scan.retryAt then
        local pos = scan.retryIndex or #pending
        local needsSort = false
        while pos > 0 and debugprofilestop() < deadline do
            local index = pending[pos]
            local keep = evaluate(scan.rows[index], now)
            if keep then
                visible[#visible + 1] = index
                needsSort = true
            end
            if keep ~= nil then
                -- Walk backwards so removing a resolved retry is constant time.
                pending[pos] = pending[#pending]
                pending[#pending] = nil
            end
            pos = pos - 1
        end
        scan.retryIndex = pos > 0 and pos or nil
        if not scan.retryIndex then scan.retryAt = now + addon.ITEM_RETRY_SECONDS end
        if needsSort then table.sort(visible) end
    end
    return scan.nextIndex - 1 - #pending
end
