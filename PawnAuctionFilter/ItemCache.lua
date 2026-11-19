local _, addon = ...
local ItemCache = {}
ItemCache.__index = ItemCache

function ItemCache:Clear()
    self.values, self.keys, self.nextSlot = {}, {}, 1
end

function addon.NewItemCache(limit)
    local cache = setmetatable({ limit = limit }, ItemCache)
    cache:Clear()
    return cache
end

function ItemCache:Get(key)
    return self.values[key]
end

-- Evict in insertion order. Updating an existing key keeps its slot.
function ItemCache:Set(key, value)
    if self.values[key] == nil then
        local slot = self.nextSlot
        local oldest = self.keys[slot]
        if oldest ~= nil then self.values[oldest] = nil end
        self.keys[slot] = key
        self.nextSlot = slot % self.limit + 1
    end
    self.values[key] = value
end
