# Development

`PawnAuctionFilter.toc` sets the load order. `PawnAuctionFilter.lua` connects the button to the auction house, requests additional pages and asks Pawn to score each item. `BrowseScan.lua` processes rows in batches and retries items whose data is still loading.

`ItemCache.lua` stores scores for up to 2,048 item links and request times for up to 2,048 item IDs. The current search keeps its own rows so it can show every match, even in larger searches. Closing the auction house clears both caches.

## Tests

Run the scan and cache tests from the repository root with Lua 5.1.

```sh
lua tests/browse_scan.lua
lua tests/item_cache.lua
```

## Release ZIP

From the root of a clean checkout, run the following in PowerShell. The ZIP contains the addon folder and its player README.

```powershell
$buildDir = "runtime/package-$(Get-Date -Format yyyyMMdd)"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
git archive --prefix=PawnAuctionFilter/ --add-file=README.md -o "$buildDir/PawnAuctionFilter.zip" HEAD:PawnAuctionFilter
```
