# PvZ zombie stability and behavior patch

This update modifies the existing GameMaker Stage0 project, not a rewritten game. It references the original PvZ decompilation for `Zombie.cpp`, `Board.cpp`, `LawnMower.cpp`, `Plant.cpp`, and `Projectile.cpp`.

Implemented in source: dynamic 6-row pool geometry (85px spacing), row-aware mower placement, numpad lawn switch now clears active play objects and restarts the camera pan/seed chooser, finite Digger dirt emitters and explicit Snow Pea trail looping, Jack-in-the-Box ticking while alive, backup dancer replacement/rising/dance state, original spotlight layers, shared ladder climbing completion, source special zombie death rates, Catapult ammo visuals updated after shots, plant squish visuals for Gargantuar/Boss stomps, tighter Zomboss head-only target area, and newspaper-specific head effect/glasses drop handling.

Known limitations: the project bundle does not include several original stage-degradation PNGs present in the separate Dropbox `pvz files/reanim` folder (screen door stage 2/3, newspaper stage 2/3, football helmet stage 2/3, Catapult damaged pole/siding, Zomboni damaged body, Gargantuar stage 2 body/foot/head, Pogo damaged stick variants, and flag stage 3). Code now references those exact original filenames, but those appearances cannot render until the files are copied into `datafiles/parts/reanim`. The original Pool rows/spacing are now represented, but full original overlapping Lily Pad / plant stacking and every pool/roof restriction are not fully implemented.

Validation was static only; no GameMaker runtime/compiler is available in this environment, so no in-game behavior is claimed as verified.
