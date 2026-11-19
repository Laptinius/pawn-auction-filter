local loader = CreateFrame("Frame")
local keyTooltip

-- Resolve the same variant as Classic's AuctionHouseUtil.SetAuctionHouseTooltip.
local function isUpgrade(row)
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
    if not PawnCanItemHaveStats(link) then return false end
    local item = PawnGetItemData(link)
    if not item or not item.Link then return nil end
    -- The second return value is an independent item-level hint.
    local upgrades = PawnIsItemAnUpgrade(item)
    return upgrades ~= nil and #upgrades > 0
end

local function install()
    local house = AuctionHouseFrame
    local browse = house.BrowseResultsFrame
    local list = browse.ItemList
    local button = CreateFrame("Button", nil, browse, "UIPanelButtonTemplate")
    button:SetSize(62, 22)
    button:SetPoint("RIGHT", house.SearchBar.FilterButton, "LEFT", -12, 0)

    local wanted, active = false, false
    local originalEntry, originalCount, originalFull, originalRefresh
    local source, decisions, visible
    local building, cursor, waiting, retryAt
    local pageSource, nextPageAt, failedSource

    local function beginPass()
        building, cursor, waiting, retryAt = {}, 1, false, nil
    end

    local function resetScan()
        if not active then return end
        source, decisions, visible = browse.browseResults, {}, {}
        beginPass()
        list:DirtyScrollFrame()
    end

    local function isComplete()
        return pageSource == browse.browseResults and source == pageSource
            and not building and not retryAt and C_AuctionHouse.HasFullBrowseResults()
    end

    local function update()
        if not active or not browse.searchStarted or not PawnIsReady() then return end
        if failedSource == browse.browseResults then return end
        if source ~= browse.browseResults then resetScan() end
        if source ~= pageSource then return end -- Wait for the first reply to this search.
        local now = GetTime()
        if nextPageAt and now >= nextPageAt and not C_AuctionHouse.HasFullBrowseResults()
            and C_AuctionHouse.IsThrottledMessageSystemReady() then
            nextPageAt = now + 5 -- Also recover a dropped request without flooding the AH.
            C_AuctionHouse.RequestMoreBrowseResults()
        end
        if retryAt and now >= retryAt then beginPass() end
        if not building then return end
        local deadline = debugprofilestop() + 3
        while cursor <= #source do
            local row = source[cursor]
            local keep = decisions[row]
            if keep == nil then
                keep = isUpgrade(row)
                decisions[row] = keep
            end
            if keep then
                building[#building + 1] = row
            elseif keep == nil then
                waiting = true
            end
            cursor = cursor + 1
            if debugprofilestop() >= deadline then return end
        end
        visible, building = building, nil
        if waiting then retryAt = now + 0.75 end
        list:DirtyScrollFrame()
    end

    local function filteredEntry(index)
        return visible[index]
    end

    local function filteredCount()
        return source == browse.browseResults and #visible or 0
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
            source, decisions, visible, building, retryAt = nil, nil, nil, nil, nil
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
            if not added or source ~= pageSource then
                resetScan()
            elseif not building then
                beginPass()
            end
        end
    end)
    browse:HookScript("OnEvent", function(_, event)
        if event == "AUCTION_HOUSE_BROWSE_FAILURE" then
            failedSource, nextPageAt = browse.browseResults, nil
        end
    end)
    hooksecurefunc("PawnResetTooltips", resetScan)
    hooksecurefunc("PawnResetBags", resetScan)
    browse:HookScript("OnHide", function() setActive(false) end)
    browse:HookScript("OnShow", function() setActive(wanted) end)

    if browse.searchStarted and #browse.browseResults > 0 then
        pageSource, nextPageAt = browse.browseResults, GetTime()
    end
    local function updateLabel()
        local label = wanted and "|cff40ff40Pawn|r" or "Pawn"
        button:SetText(PawnUpgradeTexture .. " " .. label)
        if wanted then button:LockHighlight() else button:UnlockHighlight() end
    end
    button:SetScript("OnClick", function()
        wanted = not wanted
        updateLabel()
        setActive(wanted)
    end)
    updateLabel()
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
