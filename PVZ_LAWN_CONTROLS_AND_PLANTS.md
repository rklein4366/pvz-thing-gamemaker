# PvZ lawn controls, mower placement, and plant chooser update

## In-level controls

Press **F1** during active gameplay to toggle the on-screen debug controls card. The card lists all current zombie-spawn shortcuts.

### Spawn zombies (debug-only)

Number row:
- `1` Basic Zombie
- `2` Conehead Zombie
- `3` Buckethead Zombie
- `4` Pole Vaulting Zombie

Letter keys:
- `F` Flag Zombie
- `N` Newspaper Zombie
- `S` Screen Door Zombie
- `H` Football Zombie
- `D` Dancing Zombie
- `T` Ducky Tube Zombie
- `U` Conehead Ducky Tube Zombie
- `M` Buckethead Ducky Tube Zombie
- `W` Snorkel Zombie
- `O` Dolphin Rider Zombie
- `Z` Zomboni
- `X` Bobsled Team
- `C` Catapult Zombie
- `J` Jack-in-the-Box Zombie
- `B` Balloon Zombie
- `G` Digger Zombie
- `P` Pogo Zombie
- `V` Bungee Zombie
- `L` Ladder Zombie
- `Y` Yeti Zombie
- `R` Gargantuar
- `E` Red-Eye Gargantuar
- `I` Imp
- `K` Dr. Zomboss

These inputs create debug test instances; they do not alter normal wave tables. They are enabled after the introduction/seed-chooser input lock.

### Switch lawns / reset the test board

With **Num Lock enabled**, use the numeric keypad while playing:
- `Numpad 1` — Day Lawn
- `Numpad 2` — Night Lawn
- `Numpad 3` — Pool Day
- `Numpad 4` — Pool Night
- `Numpad 5` — Roof
- `Numpad 6` — Boss Roof

Each selection now resets the current test board rather than merely changing the backdrop: existing plants, zombies, projectiles, pickups, effects and mowers are cleared; the camera pan restarts; seeds can be picked again; waves and the sun clock reset. Pool environments use six rows, with pool lanes on rows 2 and 3. The lawn's existing pool/roof special mechanics are still simplified and not a full port of the original Board engine.

## Changes in this update

- Added an F1 overlay that explains the existing spawn keys and Numpad background controls.
- Numpad 1–6 now selects an environment and performs a full test-board reset. Pool uses six aligned rows; debug spawns for Ducky Tube variants, Snorkel, Dolphin Rider and Bobsled Team use rows 2–3 and are refused when the active environment is not a Pool lawn.
- Moved lawn-mower instances from x = -160 to x = -45. This project draws world objects in its local room coordinates with the original lawn artwork shifted by the camera; the source x = -160 put the mower off the visible edge here. The original per-row Y formula is retained. Ordinary lawn mowers are not falsely placed in pool water rows because Stage0 has no pool-cleaner purchase state.
- Added **Lily Pad** and **Flower Pot** to the available seed-chooser candidates. In the current reduced 10-plant test inventory they occupy the first two positions of the second chooser row (after the eight existing candidates), and can be selected into the six-packet active seed bank.
- Reused the existing `obj_plant_lily_pad` and `obj_plant_flower_pot` objects and original `Lilypad` / `Pot` reanimations.
- Used the original `Lawn/Plant.cpp` source definitions for both plants' cost (25 sun) and recharge (750 100-Hz ticks).
- Switched mower shadow art for night/boss-night backgrounds. Corrected the placed Ladder Zombie obstacle to use `Zombie_ladder_5.png`, matching `GridItem::DrawLadder`, rather than the carried ladder segment.

## Verification and limits

Static checks confirm the new input handlers and HUD text are present, the Lily Pad / Flower Pot mappings point to existing project objects, seed chooser arrays have matching lengths, all six selected background files exist, and edited script delimiters are balanced.

**Not runtime-tested:** GameMaker is not available in this environment, so the project was not opened, compiled, or played in the GameMaker IDE. Please test the project in GameMaker before treating the changes as fully verified.

**Known gameplay limitation:** this remains the Stage0 test sandbox, not a complete port of original PvZ levels. Pool row geometry is now available for testing, but the full original aquatic/roof interactions, ice-grid lifecycle, all board-specific plant placement rules, and full Zomboss boss encounter remain simplified. Lily Pad and Flower Pot are selectable, but their full original stacking/placement restrictions are not complete.

## Source reference

Original Plants vs. Zombies decompilation: https://github.com/ruslan831/PlantsVsZombies-decompilation

Relevant source comparisons: `Lawn/LawnMower.cpp` (`LawnMowerInitialize`), `Lawn/Board.cpp` (`GridToPixelX`, `GridToPixelY`, `GetPosYBasedOnRow`), and `Lawn/Plant.cpp` (`gPlantDefs` entries for `SEED_LILYPAD` and `SEED_FLOWERPOT`).
