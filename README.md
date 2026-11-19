# Pawn Auction Filter

By Laptinius.

An addon for WoW Forever 1.60.1. On the **Buy** tab, choose a category and level range, run a search, then click **↑ Pawn** next to the filter menu. The list shows gear that Pawn marks as an upgrade for at least one of your character's enabled scales. The arrow turns green when the filter is on. Click again to restore the full list and turn the arrow gray.

Large searches show matches as they are found. The counter below the button shows how many items have been checked so far. It disappears once all pages have arrived and all items have been checked.

## Installation

1. Install Pawn for WoW Forever and enable the scales you want to use.
2. Extract the `PawnAuctionFilter` folder into `_forever_/Interface/AddOns/`. The `PawnAuctionFilter.toc` file belongs directly inside the `PawnAuctionFilter` folder.
3. If the game is running, type `/reload` in chat. If the addon does not appear in the list, restart the game.

## Development

`PawnAuctionFilter/PawnAuctionFilter.toc` sets the load order. `BrowseScan.lua` checks rows in batches and revisits items whose data is still loading. `PawnAuctionFilter.lua` connects the button to the auction house, requests pages and asks Pawn to score items.

Run the tests for progressive results, retries and row order from the repository root with Lua 5.1.

```sh
lua tests/browse_scan.lua
```

To package the latest commit, run these PowerShell commands from the root of a clean checkout.

```powershell
$buildDir = "runtime/package-$(Get-Date -Format yyyyMMdd)"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
git archive --prefix=PawnAuctionFilter/ --add-file=README.md -o "$buildDir/PawnAuctionFilter.zip" HEAD:PawnAuctionFilter
```
