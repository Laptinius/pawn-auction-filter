# Pawn Auction Filter

Find gear upgrades on the auction house in WoW Forever. The **↑ Pawn** button shows only items that Pawn marks as an upgrade on at least one of your character’s enabled scales.

## Installation

1. Install and enable [Pawn for WoW Forever](https://www.curseforge.com/wow/addons/pawn).
2. Download the addon ZIP from [Releases](https://github.com/Laptinius/pawn-auction-filter/releases/latest). Extract the `PawnAuctionFilter` folder into `_forever_/Interface/AddOns/`.
3. If WoW is running, type `/reload` in chat. If the addon doesn’t appear, restart the game.

## Usage

On the **Buy** tab, run a search with your usual filters. Click **↑ Pawn** beside the search box to check every page for upgrades. The arrow turns green. Matches appear as they’re found, and the counter shows how many items have been checked.

Click **↑ Pawn** again to restore the full list. The arrow turns gray.

Right-click **↑ Pawn** to set a minimum upgrade for this character. Enter a whole percentage and press **Enter** or **OK** to apply it. **Esc** cancels. The filter uses the rounded percentage in Pawn’s tooltip, so an item showing **+6%** on any enabled scale passes a **6%** minimum. **0%** shows all Pawn upgrades. Upgrades that Pawn marks with an arrow alone, such as gear for an empty slot, pass any minimum.

Changing the minimum updates checked items immediately and lets the current scan continue. Hover over **↑ Pawn** to see your saved minimum.

By Laptinius.
