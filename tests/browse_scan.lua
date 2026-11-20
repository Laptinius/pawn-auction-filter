-- Run from the repository root with Lua 5.1.
local addon = {}
assert(loadfile("PawnAuctionFilter/BrowseScan.lua"))("PawnAuctionFilter", addon)

-- A deterministic clock makes a single frame too short for the whole search.
local elapsed = 0
function debugprofilestop()
    elapsed = elapsed + 0.5
    return elapsed
end

local rows, verdicts, calls = {}, {}, {}
local scan = addon.NewScan(rows)
local function evaluate(row)
    calls[row] = (calls[row] or 0) + 1
    return verdicts[row]
end

assert(addon.AdvanceScan(scan, evaluate, 0) == 0)
for i = 1, 854 do
    rows[i] = i
    verdicts[i] = i % 17 == 1
end
-- Two of the eventual 51 matches load after the first page is processed.
verdicts[1], verdicts[18] = nil, nil
local now = 0
local function frame()
    now = now + 0.02
    return addon.AdvanceScan(scan, evaluate, now)
end

local checked = frame()
assert(checked > 0 and checked < #rows)
while #scan.visible == 0 do
    checked = frame()
    assert(now < 1, "early matches must be published")
end
assert(checked < #rows and scan.visible[1] == 35)

for _ = 1, 200 do checked = frame() end
assert(checked == 852 and #scan.visible == 49)
assert(calls[1] > 1 and calls[18] > 1)
for i = 2, 854 do
    if i ~= 18 then assert(calls[i] == 1, "resolved rows must not be retried") end
end

-- A newly appended page must be processed while earlier data is pending.
rows[855], verdicts[855] = 855, true
assert(frame() == 853 and scan.visible[#scan.visible] == 855)
verdicts[1], verdicts[18] = true, true
for _ = 1, 60 do checked = frame() end
assert(checked == 855 and #scan.visible == 52)
local match = 0
for index, row in ipairs(rows) do
    if verdicts[row] then
        match = match + 1
        assert(scan.visible[match] == index, "late matches must retain auction order")
    end
end

-- Append a page in the middle of a retry batch, when some old rows still lack data.
rows, verdicts, calls = {}, {}, {}
for i = 1, 30 do rows[i] = i end
scan = addon.NewScan(rows)
for _ = 1, 10 do frame() end
for i = 1, 30 do
    if i % 3 ~= 0 then verdicts[i] = i % 2 == 0 end
end
now = now + 1
checked = frame()
assert(checked > 0 and checked < 20)
for i = 31, 40 do rows[i] = i end
for _ = 1, 10 do frame() end
for i = 1, 40 do verdicts[i] = i % 2 == 0 end
for _ = 1, 120 do checked = frame() end
assert(checked == 40 and #scan.visible == 20)
for index, row in ipairs(scan.visible) do assert(row == 2 * index) end

-- Changing the threshold must preserve finished work, retry timing and row order.
rows = { "cold", "six", "both", "no", "empty", "future" }
local scores = { six = 6, both = 12, no = false, empty = math.huge, future = 20 }
scan = addon.NewScan(rows)
local minimum, evaluated = 0, 0
local function score(row)
    evaluated = evaluated + 1
    local percent = scores[row]
    return percent and percent >= minimum
end
local checked = addon.AdvanceScan(scan, score, 0)
assert(checked == 5 and #scan.pending == 1)
local retryAt = scan.retryAt
rows[7], scores.appended = "appended", 7
minimum = 7
addon.RefilterScan(scan, scores, minimum)
assert(table.concat(scan.visible, ",") == "3,5,6")
assert(scan.nextIndex == 7 and scan.retryAt == retryAt and evaluated == 6)
addon.AdvanceScan(scan, score, 0.1)
assert(table.concat(scan.visible, ",") == "3,5,6,7")
scores.cold = 7
addon.AdvanceScan(scan, score, retryAt)
assert(table.concat(scan.visible, ",") == "1,3,5,6,7" and evaluated == 8)
addon.RefilterScan(scan, scores, 6)
assert(table.concat(scan.visible, ",") == "1,2,3,5,6,7")
addon.RefilterScan(scan, scores, 99999)
assert(table.concat(scan.visible, ",") == "5" and evaluated == 8)

print("OK: partial results, frame budget, deferred items, appended pages and auction order")
