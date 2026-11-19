local loader = CreateFrame("Frame")
local keyTooltip

-- Resolve the same variant as Classic's AuctionHouseUtil.SetAuctionHouseTooltip.
local function isUpgrade(row, scores)
    local key = row.itemKey
    if key.battlePetSpeciesID and key.battlePetSpeciesID ~= 0 then return false end
    local _, _, _, slot, _, classID = C_Item.GetItemInfoInstant(key.itemID)
    if not classID then
        C_Item.RequestLoadItemDataByID(key.itemID)
        return nil
    end
    if not slot or slot == "" then return false end
    local link = row.itemLink or C_AuctionHouse.GetItemKeySampleLink(key)
    if not link then
        if not keyTooltip then
            keyTooltip = CreateFrame("GameTooltip", "PawnAuctionFilterItemTooltip", UIParent, "GameTooltipTemplate")
        end
        keyTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        keyTooltip:ClearLines()
        keyTooltip:SetItemKey(key.itemID, key.itemLevel, key.itemSuffix, C_AuctionHouse.GetItemKeyRequiredLevel(key))
        link = PawnGetItemLinkFromTooltip(keyTooltip)
        keyTooltip:Hide()
    end
    if not link then
        C_Item.RequestLoadItemDataByID(key.itemID)
        return nil
    end
    if scores[link] ~= nil then return scores[link] end
    if not PawnCanItemHaveStats(link) then return false end
    local item = PawnGetItemData(link)
    if not item or not item.Link then return nil end
    -- The second return value is an independent item-level hint.
    local upgrades = PawnIsItemAnUpgrade(item)
    scores[link] = upgrades ~= nil and #upgrades > 0
    return scores[link]
end

local function install()
    local house = AuctionHouseFrame
    local browse = house.BrowseResultsFrame
    local list = browse.ItemList
    local button = CreateFrame("Button", nil, browse, "UIPanelButtonTemplate")
    button:SetSize(62, 22)
    button:SetPoint("RIGHT", house.SearchBar.FilterButton, "LEFT", -12, 0)
    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\AddOns\\Pawn\\Textures\\UpgradeArrow")
    arrow:SetSize(13, 13)
    arrow:SetPoint("LEFT", button, "LEFT", 5, 0)
    local progress = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    progress:SetPoint("TOP", button, "BOTTOM", 0, 0)

    local wanted, active = false, false
    local originalEntry, originalCount, originalFull, originalRefresh
    local scan
    local scores = {}
    local pageSource, nextPageAt, failedSource

    local function resetScan()
        if not active then return end
        scan = {
            rows = browse.browseResults, nextIndex = 1, pending = {}, visible = {},
            retryAt = 0, nextPaint = 0, painted = 0,
        }
        progress:SetText("")
        list:DirtyScrollFrame()
    end

    local function isComplete()
        return scan and scan.rows == browse.browseResults and scan.finished
    end

    local function update()
        if not active or not browse.searchStarted or not PawnIsReady() then return end
        if failedSource == browse.browseResults then return end
        if scan.rows ~= browse.browseResults then resetScan() end
        if scan.rows ~= pageSource or scan.finished then return end
        local now = GetTime()
        if nextPageAt and now >= nextPageAt and not C_AuctionHouse.HasFullBrowseResults()
            and C_AuctionHouse.IsThrottledMessageSystemReady() then
            nextPageAt = now + 5 -- Also recover a dropped request without flooding the AH.
            C_AuctionHouse.RequestMoreBrowseResults()
        end
        local total = #scan.rows
        local pending, visible = scan.pending, scan.visible
        if scan.nextIndex > total and not scan.retryIndex and #pending > 0 and now >= scan.retryAt then
            scan.retryIndex = #pending
        end
        local needsSort = false
        local deadline = debugprofilestop() + 3
        while scan.nextIndex <= total or scan.retryIndex do
            local fresh = scan.nextIndex <= total
            local pos = scan.retryIndex
            local index = fresh and scan.nextIndex or pending[pos]
            local keep = isUpgrade(scan.rows[index], scores)
            if keep then
                visible[#visible + 1] = index
                if not fresh then needsSort = true end
            end
            if fresh then
                scan.nextIndex = index + 1
                if keep == nil then
                    pending[#pending + 1] = index
                    if #pending == 1 then scan.retryAt = now + 0.75 end
                end
            else
                -- Walk backwards so a resolved retry can be removed in constant time.
                if keep ~= nil then
                    pending[pos] = pending[#pending]
                    pending[#pending] = nil
                end
                scan.retryIndex = pos > 1 and pos - 1 or nil
                if not scan.retryIndex then scan.retryAt = now + 0.75 end
            end
            if debugprofilestop() >= deadline then break end
        end
        if needsSort then table.sort(visible) end
        scan.finished = scan.nextIndex > total and #pending == 0 and C_AuctionHouse.HasFullBrowseResults()
        if scan.finished or now >= scan.nextPaint or (scan.painted == 0 and #visible > 0) then
            scan.nextPaint = now + 0.12
            progress:SetText(scan.finished and "" or (scan.nextIndex - 1 - #pending) .. "/" .. total)
            if #visible ~= scan.painted or scan.finished then
                scan.painted = #visible
                list:DirtyScrollFrame()
            end
        end
    end

    local function filteredEntry(index)
        return scan.rows[scan.visible[index]]
    end

    local function filteredCount()
        return scan.rows == browse.browseResults and #scan.visible or 0
    end

    local function setActive(enable)
        if active == enable then return end
        active = enable
        if active then
            originalEntry, originalCount = list.getEntry, list.getNumEntries
            originalFull, originalRefresh = list.hasFullResultsFunc, list.refreshCallback
            list.refreshCallback = nil
            resetScan()
            list:SetDataProvider(list.searchStartedFunc, filteredEntry, filteredCount, isComplete)
            button:SetScript("OnUpdate", update)
        else
            button:SetScript("OnUpdate", nil)
            list:SetDataProvider(list.searchStartedFunc, originalEntry, originalCount, originalFull)
            list:SetRefreshCallback(originalRefresh)
            scan = nil
            progress:SetText("")
        end
        if browse:IsVisible() and list.isInitialized then list:Reset() end
    end

    -- Blizzard retains the complete ordered browseResults. Only switch the display
    -- provider, so clicking a filtered row still passes its original auction data.
    hooksecurefunc(list, "SetRefreshCallback", function(_, callback)
        if active then
            originalRefresh = callback
            list.refreshCallback = nil
        end
    end)
    hooksecurefunc(browse, "UpdateBrowseResults", function(_, added)
        pageSource, failedSource = browse.browseResults, nil
        nextPageAt = not C_AuctionHouse.HasFullBrowseResults() and GetTime() or nil
        if active then
            if not added or scan.rows ~= pageSource then
                resetScan()
            else
                scan.finished = false
            end
        end
    end)
    browse:HookScript("OnEvent", function(_, event)
        if event == "AUCTION_HOUSE_BROWSE_FAILURE" then
            failedSource, nextPageAt = browse.browseResults, nil
            progress:SetText("")
        end
    end)
    local function invalidateScores()
        scores = {}
        resetScan()
    end
    hooksecurefunc("PawnResetTooltips", invalidateScores)
    hooksecurefunc("PawnResetBags", invalidateScores)
    house:HookScript("OnHide", function() scores = {} end)
    browse:HookScript("OnHide", function() setActive(false) end)
    browse:HookScript("OnShow", function() setActive(wanted) end)

    if browse.searchStarted and #browse.browseResults > 0 then
        pageSource, nextPageAt = browse.browseResults, GetTime()
    end
    local function updateLabel()
        arrow:SetDesaturated(not wanted)
        button:SetText(wanted and "|cff40ff40Pawn|r" or "Pawn")
        if wanted then button:LockHighlight() else button:UnlockHighlight() end
    end
    button:SetScript("OnClick", function()
        wanted = not wanted
        updateLabel()
        setActive(wanted)
    end)
    updateLabel()
    local caption = button:GetFontString()
    caption:ClearAllPoints()
    caption:SetPoint("CENTER", button, "CENTER", 7, 0)
end

if AuctionHouseFrame and AuctionHouseFrame.BrowseResultsFrame then
    install()
else
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, name)
        if name == "Blizzard_AuctionHouseUI" then
            self:UnregisterEvent("ADDON_LOADED")
            install()
        end
    end)
end
