Plants vs. Zombies — Original Chew-Event Flash Timing Fix

WHAT WAS WRONG
The recreation refreshed the plant's eaten-flash countdown whenever it removed plant health (every 4 logic ticks). Original PvZ does not do that. Zombie::Animate() triggers Zombie::AnimateChewEffect() on the chew animation's timed events, and AnimateChewEffect() sets mEatenFlashCountdown to at least 25. This is why changing the countdown number alone did not make the flash accurate.

WHAT THIS FIX CHANGES
- Removes the flash refresh from the bite-damage tick.
- Refreshes the exact same 25-tick counter at the existing original-source-based chew-animation events (the same _hit_t1 / _hit_t2 events used for the chomp sound).
- Leaves damage, chewing animation, particles, plant animation, zombie fade, and every other file unchanged.
- Creates a timestamped backup before writing the GML source.

INSTALL
1. Extract this ZIP directly into your PvZ_GM_Stage0 project folder — the folder containing PvZ.yyp.
2. Run Install_PvZ_OG_Chew_Flash_Event_Fix.bat.
3. Reopen GameMaker and run the project.

The installer validates that it can locate exactly one expected damage-tick assignment and one chew-event hook before making any edits. It does not overwrite a file if those checks fail.

SOURCE REFERENCES
Lawn/Zombie.cpp: Zombie::Animate() calls AnimateChewSound() and AnimateChewEffect() when either timed chew event fires.
Lawn/Zombie.cpp: Zombie::AnimateChewEffect() sets aPlant->mEatenFlashCountdown = max(..., 25).
https://github.com/cardbored-code/PVZ-QEWide-Tweaks/blob/main/Lawn/Zombie.cpp

Note: The installer script was checked for the expected replacement logic, but Windows PowerShell and GameMaker are unavailable in this environment, so I cannot claim an in-game runtime test.
