# PvZ1 Zombie Bugfix Pass — implementation and verification report

## Scope and reference

This pass edits the existing GameMaker project in place and keeps its existing object architecture. The reference used was the PvZ1 decompilation, especially `Lawn/Zombie.cpp`, `Lawn/Board.cpp`, `Lawn/Plant.cpp`, `Lawn/Projectile.cpp`, `Lawn/GridItem.cpp`, and `Lawn/LawnMower.cpp`:

- https://github.com/ruslan831/PlantsVsZombies-decompilation
- Original assets supplied by the user in the `pvz files` Dropbox folder.

No unrelated menu, UI, or plant system was intentionally redesigned.

## Changes made in the current project

| Area | Change | Verification status |
|---|---|---|
| Digger | Tunnel dirt emitters are spawned as finite, detached bursts on a cadence, not as a continuously re-attached particle loop. Rising and post-tunnel states remain finite. | Static inspection; runtime test required |
| Zomboni | Smoke is emitted only on the body-damage transition into the deepest damage stage, not each update. Position-based speed and vehicle/plant collision updates are retained. | Static inspection; pool/ice-grid system remains simplified |
| Balloon | Ordinary ground projectile targeting and collision now exclude a flying Balloon Zombie, matching `Zombie::EffectedByDamage`. | Static inspection; runtime test required |
| Screen Door | The shield and screen-door arm tracks are not hidden during chewing. Breaking the door hides its tracks, restores normal arms, plays the door particle and shield-hit sound. Armor stages use original `Zombie_screendoor2/3` variants when installed. | Code path present; visual test requires original variants |
| Flag | Flag-holding arm/layer remains separate from the ordinary inner arm; damaged-flag art is applied on arm loss. Head loss now drops the flag effect, hides the attached flag track, and restores the ordinary inner arm. | Code path present; runtime test required |
| Newspaper | Newspaper degradation variants are mapped by remaining shield health; breaking it runs the gasp-to-mad transition, question-mark effect, paper particle, mad-head override and roar. Glasses are detached during death cleanup. | Code path present; visual test requires original paper variants |
| Football | Helmet stages use the original damage-stage names when installed; helmet destruction spawns a helmet particle. Death animation is set to the original 24 fps rate. | Code path present; audio/visual runtime test required |
| Catapult | Damage-stage siding/pole art and remaining ammunition are updated. Four loose balls disappear one at a time as the five-ball supply is spent, and the pole changes to the no-ball version when empty. | Code path present; runtime test required |
| Pogo | Lost-arm uses the source-specific broken arm and damaged stick-hand override, with a safe hidden fallback if that art is missing. Lost-head/PogoBreak emits the Pogo-specific particle, hides the stick and stick-hand tracks, changes to walking, and the stick's two damage stages are mapped. | Code path present; visual test requires original Pogo variants |
| Ladder | Ladder placement/climb no longer snaps the root position to the far side. Climbing preserves horizontal motion; ordinary zombies can climb a placed ladder and then fall/return to walking. The placed obstacle now uses the original `Zombie_ladder_5.png` and original grid-relative x+25/y-4, 0.8x scale. | Static inspection; runtime test required |
| Gargantuar / Red-Eye | Body, arm, foot and head damage-stage sprite variants are mapped. Death animation uses 14 fps, with dedicated death, thud, walking and groan cues; smash attack invokes the existing plant-squish lifecycle. | Code path present; visual/audio runtime test required |
| Imp | Arm disconnection uses the Imp bone/arm image when the original part is installed. | Code path present; runtime test required |
| Dolphin Rider / Snorkel | Pool-specific swim, dive, jump, surface and walking states have explicit transitions, splash effects and submerged damage/targeting rules. | Static inspection only; water rules are still a simplified lawn implementation |
| Bobsled Team | The leader and three riders retain coordinated push/crash states; rider root position now follows the leader instead of being overwritten by a stale position. Sled front/back and damage stage rendering are implemented and riders use the source vertical offset. | Runtime appearance depends on installing the original bobsled images; not engine-tested |
| Bungee | A visible cord is drawn during dive/grab/rise; the plant remains visible and is lifted over time before removal instead of disappearing at the start of the grab. | Static inspection; runtime test required |
| Dancing Zombie | Backup formation slots are refilled if dancers disappear; the dance cycle and each backup dancer use a shared 460-tick leader phase; spotlights are drawn; the lead dancer and backups handle the left house boundary. Backup dancers rise from below the lawn and fade in instead of visibly popping up from the turf. | Static inspection; runtime test required |
| Yeti | Retreat speed/direction and vertical offset follow the original forward/retreat presentation; the damaged arm maps to the Yeti-specific part when installed. | Code path present; runtime test requires asset/runtime verification |
| Dr. Zomboss | Plant targeting and pea collision skip the invulnerable legs/upright body; damage is accepted only while the head-down/spit phases are vulnerable. Attack timers are lengthened and fire/ice projectiles track their selected row. | Static inspection only; boss encounter remains a partial recreation |
| Shared death/arm effects | The shared head/arm detach paths use type-specific part sprites/effects where a source mapping and asset exist. Special types that do not shed parts in the original remain excluded. | Static inspection; some source images are not included in the current asset bundle |
| Existing controls / environment reset | Numpad 1–6 now invokes a full board reset rather than changing the background only: rows, grid, mowers, camera pan, seed-choice state, waves and existing board objects are reset. Pool uses six rows with water rows 2–3; pool-only debug spawns are routed to those lanes and are refused outside a Pool lawn. Ordinary lawn mowers are not incorrectly spawned in pool water rows without a pool-cleaner purchase state. | Static inspection only |

## Original assets still needed locally

The current project bundle does **not** contain all of the original damage-state parts referenced above. The runtime safely checks for these files, but a missing file means the relevant degradation stage falls back to its last available/base art. The supplied Dropbox `pvz files` directory contains these originals. I added `Install_Original_Zombie_Assets.ps1` to copy only the needed named parts into the correct project directories without overwriting existing files by default.

To install them on Windows:

1. Extract this project ZIP.
2. Run `Install_Original_Zombie_Assets.ps1` from the project folder.
3. Select your downloaded original `pvz files` folder when prompted (the folder containing `reanim` and `images`).
4. Reopen the project in GameMaker and test the affected sprites.

The installer copies the screen-door, newspaper, football helmet, Pogo, Gargantuar, Catapult, Zomboni and ladder damage variants, specific arm pieces, Flag damage part, and the five Bobsled images. It preserves any existing destination file unless explicitly run with `-Force`.

## Static verification performed

- All 283 `.gml` files passed a delimiter-balance scan that ignores strings and comments.
- All 105 GameMaker `.yy` / `.yyp` metadata files parsed after normalizing GameMaker's trailing-comma JSON format.
- All 100 project-manifest resource paths resolved to existing project files.
- Targeted static assertions passed for full numpad board reset, pool-only debug rows, screen-door arm visibility, Balloon ground-target immunity, Catapult ammo-stage visuals, native ladder artwork selection, pool mower lane handling, finite Digger/Zomboni particle paths, Newspaper glasses guard, Zomboss projectile vulnerability, and Pogo damaged-hand art selection.
- The final ZIP archive is checked for integrity after packaging.
- The original source implementations were inspected for the major state/health/animation behaviors touched in this pass.

## What has not been verified

**I could not launch GameMaker Studio or run the game in its engine in this environment.** Therefore, this report does not claim that every listed behavior passes an in-game test. Audio timing, the exact layer composition of each Reanimation, collision edge cases, and all of the listed special-zombie behaviors still require running the project in the user's GameMaker IDE. In particular, the full Pool/Roof board simulation, complete Zomboni ice-grid lifecycle, full Zomboss encounter and every original zombie interaction are not a complete port of the original PopCap engine.

This is a targeted improvement pass, not a claim of a fully complete or perfectly accurate PvZ remake. The ZIP includes the project and the asset installer to make the source-backed visual states available for testing.
