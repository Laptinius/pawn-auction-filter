local addon = {}
assert(loadfile("PawnAuctionFilter/ItemCache.lua"))("PawnAuctionFilter", addon)

local cache = addon.NewItemCache(3)
cache:Set("first", false)
cache:Set("second", 0)
cache:Set("third", true)
assert(cache:Get("first") == false and cache:Get("second") == 0)
cache:Set("first", true)
cache:Set("fourth", false)
assert(cache:Get("first") == nil and cache:Get("second") == 0)
assert(cache:Get("third") and cache:Get("fourth") == false)
cache:Clear()
assert(cache:Get("second") == nil and cache:Get("fourth") == nil)

-- Weak references let the test detect keys or values retained after eviction.
local refs = setmetatable({}, { __mode = "v" })
local function insertPair(index)
    local key, value = {}, {}
    cache:Set(key, value)
    refs[index], refs[index + 1] = key, value
end
insertPair(1)
for i = 1, 100000 do cache:Set(i, i) end
insertPair(3)
collectgarbage("collect")
assert(refs[1] == nil and refs[2] == nil)
assert(refs[3] and cache:Get(refs[3]) == refs[4])
for i = 1, 99998 do assert(cache:Get(i) == nil) end
assert(cache:Get(99999) == 99999 and cache:Get(100000) == 100000)
cache:Clear()
collectgarbage("collect")
assert(refs[3] == nil and refs[4] == nil)

print("OK: bounded entries, cached false, updates, eviction and collection")
