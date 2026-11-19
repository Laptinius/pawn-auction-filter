local _, addon = ...
local keyTooltip
-- Pawn scores belong to exact links. Row identities are valid within one browse snapshot.
local scores, rowResults, requestedAt = {}, {}, {}

local function requestItemData(itemID, now)
    if not requestedAt[itemID] or now >= requestedAt[itemID] + addon.ITEM_RETRY_SECONDS then
        requestedAt[itemID] = now
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

-- Resolve the same variant as Classic's AuctionHouseUtil.SetAuctionHouseTooltip.
local function isUpgrade(row, now)
    local key = row.itemKey
    if key.battlePetSpeciesID and key.battlePetSpeciesID ~= 0 then return false end
    local _, _, _, slot, _, classID = C_Item.GetItemInfoInstant(key.itemID)
    if not classID then
        requestItemData(key.itemID, now)
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
        requestItemData(key.itemID, now)
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

local function evaluateRow(row, now)
    if rowResults[row] == nil then rowResults[row] = isUpgrade(row, now) end
    return rowResults[row]
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

    local wanted = false
    local originalEntry, originalCount, originalFull, originalRefresh
    local scan
    local pageSource, nextPageAt
    local nextPaint, painted

    local function isComplete()
        return scan and scan.rows == browse.browseResults and scan.finished
    end

    local function update()
        if pageSource ~= browse.browseResults then
            button:SetScript("OnUpdate", nil)
            progress:SetText("")
            return
        end
        if not PawnIsReady() then return end
        local now = GetTime()
        if nextPageAt and now >= nextPageAt then
            if C_AuctionHouse.HasFullBrowseResults() then
                nextPageAt = nil
            elseif C_AuctionHouse.IsThrottledMessageSystemReady() then
                nextPageAt = now + 5 -- Recover if the reply was dropped.
                C_AuctionHouse.RequestMoreBrowseResults()
            else
                nextPageAt = now + 0.2
            end
        end
        local total = #scan.rows
        local checked = addon.AdvanceScan(scan, evaluateRow, now)
        local matches = #scan.visible
        scan.finished = checked == total and not nextPageAt
        if scan.finished or now >= nextPaint or (painted == 0 and matches > 0) then
            nextPaint = now + 0.12
            progress:SetText(scan.finished and "" or checked .. "/" .. total)
            if matches ~= painted or scan.finished then
                painted = matches
                list:DirtyScrollFrame()
            end
        end
        if scan.finished then button:SetScript("OnUpdate", nil) end
    end

    local function resetScan()
        scan = addon.NewScan(browse.browseResults)
        nextPaint, painted = 0, 0
        progress:SetText("")
        button:SetScript("OnUpdate", scan.rows == pageSource and update or nil)
        list:DirtyScrollFrame()
    end

    local function filteredEntry(index)
        return scan.rows[scan.visible[index]]
    end

    local function filteredCount()
        return scan.rows == browse.browseResults and #scan.visible or 0
    end

    local function setActive(enable)
        if (scan ~= nil) == enable then return end
        if enable then
            originalEntry, originalCount = list.getEntry, list.getNumEntries
            originalFull, originalRefresh = list.hasFullResultsFunc, list.refreshCallback
            list.refreshCallback = nil
            resetScan()
            list:SetDataProvider(list.searchStartedFunc, filteredEntry, filteredCount, isComplete)
        else
            button:SetScript("OnUpdate", nil)
            list:SetDataProvider(list.searchStartedFunc, originalEntry, originalCount, originalFull)
            scan = nil
            list:SetRefreshCallback(originalRefresh)
            progress:SetText("")
        end
        if browse:IsVisible() and list.isInitialized then list:Reset() end
    end

    -- Blizzard retains the complete ordered browseResults. Only switch the display
    -- provider, so clicking a filtered row still passes its original auction data.
    hooksecurefunc(list, "SetRefreshCallback", function(_, callback)
        if scan then
            originalRefresh = callback
            list.refreshCallback = nil
        end
    end)
    hooksecurefunc(browse, "UpdateBrowseResults", function(_, added)
        if not added or pageSource ~= browse.browseResults then rowResults = {} end
        pageSource = browse.browseResults
        if C_AuctionHouse.HasFullBrowseResults() then
            nextPageAt = nil
        elseif not added or #added > 0 or not nextPageAt then
            nextPageAt = GetTime()
        end
        if scan then
            if added and scan.rows == pageSource then
                scan.finished = false
                button:SetScript("OnUpdate", update)
            else
                resetScan()
            end
        end
    end)
    browse:HookScript("OnEvent", function(_, event)
        if event == "AUCTION_HOUSE_BROWSE_FAILURE" then
            pageSource, nextPageAt = nil, nil
            button:SetScript("OnUpdate", nil)
            if scan then scan.finished = true end
            progress:SetText("")
        end
    end)
    local function invalidateScores()
        scores, rowResults = {}, {}
        if scan then resetScan() end
    end
    hooksecurefunc("PawnResetTooltips", invalidateScores)
    hooksecurefunc("PawnResetBags", invalidateScores)
    house:HookScript("OnHide", function()
        scores, rowResults, requestedAt = {}, {}, {}
        pageSource, nextPageAt = nil, nil
    end)
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
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, name)
        if name == "Blizzard_AuctionHouseUI" then
            self:UnregisterEvent("ADDON_LOADED")
            install()
        end
    end)
end
