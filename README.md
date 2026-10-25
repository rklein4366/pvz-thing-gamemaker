# Plants vs. Zombies GameMaker test project

This is the existing GameMaker Stage0 project with targeted zombie behavior and stability fixes.

## Important files
- `PvZ.yyp` — open this project in GameMaker Studio.
- `ZOMBIE_BUGFIX_REPORT.md` — changes, verification and limitations.
- `Install_Original_Zombie_Assets.ps1` — copies specific original PvZ1 damage-state/bobsled image assets from your local `pvz files` folder without replacing existing files by default.
- `PVZ_LAWN_CONTROLS_AND_PLANTS.md` — zombie spawn keys, full Numpad lawn-reset controls, water lane behavior, mower positioning and Lily Pad/Flower Pot chooser changes.

## Asset install
Run `Install_Original_Zombie_Assets.ps1` and select the original `pvz files` folder containing `reanim` and `images`. The current bundle is missing some original damage-stage parts, so installing these files is required for those stages and the bobsled to display their correct original art. Existing files are left untouched unless the script is run with `-Force`.

## Verification note
Numpad 1–6 performs a full test-board reset and reopens seed selection; Pool Day/Night uses six rows with pool lanes at rows 2–3. Water-only debug zombies must be spawned on a Pool lawn. The project passed static source/code consistency checks, but was not compiled or playtested inside GameMaker in this environment. See `ZOMBIE_BUGFIX_REPORT.md` for the change-by-change status and limits.
