Plants vs. Zombies — OG Eating Flash Pulse Fix v3

WHAT THIS FIX CHANGES
Only scripts\scr_pvz_lawn_runtime\scr_pvz_lawn_runtime.gml.

1. Plant eating flash refreshes on the OG timed chew animation events (the 0.14/0.68 markers for regular zombies, 0.38/0.80 for Pole Vaulter), not on every damage tick. The original 25-tick countdown can now fade completely to normal before the next event.
2. The recreation no longer forces anim_eat to 36 FPS / 20 FPS. Original Zombie.cpp calls PlayZombieReanim("anim_eat", REANIM_LOOP, 20, 0.0f), which preserves the current animation rate. This is important because forcing a faster rate compresses the space between flash pulses.
3. The OG 25-tick countdown and additive grayscale flash rendering are preserved. Sunflower production flash logic is not changed.

SOURCE REFERENCES
Zombie::Animate / Zombie::AnimateChewEffect:
https://github.com/cardbored-code/PVZ-QEWide-Tweaks/blob/main/Lawn/Zombie.cpp
Plant::Animate / Plant::Draw:
https://github.com/cardbored-code/PVZ-QEWide-Tweaks/blob/main/Lawn/Plant.cpp

INSTALL
1. Extract this ZIP into the PvZ_GM_Stage0 project folder, beside PvZ.yyp.
2. Run Install_PvZ_OG_Chew_Flash_Pulse_Fix_v3.bat.
3. Reopen GameMaker.

The installer validates the exact event hook, creates a timestamped backup, and changes only the runtime GML source. If it cannot safely identify the expected blocks, it stops without writing. It is designed to work whether the old damage-time flash assignment is still present or an earlier installer already moved it.

Validation note: the script was checked against the source structure and the ZIP is integrity-checked, but this environment cannot run Windows PowerShell or GameMaker, so in-game runtime testing has not been performed.
