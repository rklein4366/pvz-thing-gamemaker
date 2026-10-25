# PvZ1 Zombie Roster Audit and Implementation Notes

## Scope and truthfulness

This archive is the existing GameMaker lawn project with the missing PvZ1 zombie object entrypoints added to its existing reanimation/runtime architecture. It is **not** a byte-for-byte recreation of the original PopCap engine. The existing project is a single-lawn Stage 1 sandbox with a limited plant roster and no real pool/roof level model. Several environment-specific or multi-phase behaviours therefore remain simplified and are listed below rather than being described as fully accurate.

The uploaded source project initially had zombie objects for only **Basic, Conehead, Buckethead, and Pole Vaulting Zombies**. The missing roster object wrappers were added as children of `obj_zombie_base` so shared systems (pea hits, mower collision, damage, common animations and cleanup) can address the whole roster without duplicate code paths.

## Roster checklist

| Original PvZ1 type | Project object | Status in this build |
|---|---|---|
| Basic Zombie | `obj_zombie_basic` | Existing object retained; parented to shared zombie base |
| Flag Zombie | `obj_zombie_flag` | Added; flag reanimation attached to body |
| Conehead Zombie | `obj_zombie_conehead` | Existing object retained; parented to shared zombie base |
| Pole Vaulting Zombie | `obj_zombie_polevaulter` | Existing object retained; parented to shared zombie base |
| Buckethead Zombie | `obj_zombie_buckethead` | Existing object retained; parented to shared zombie base |
| Newspaper Zombie | `obj_zombie_newspaper` | Added; newspaper armor/state is handled by shared runtime |
| Screen Door Zombie | `obj_zombie_screendoor` | Added; screen-door tracks and armor health configured |
| Football Zombie | `obj_zombie_football` | Added; helmet health and original body animation referenced |
| Dancing Zombie | `obj_zombie_dancer` | Added; initial dance movement, point/summon transition and hold state implemented; full shared choreography is simplified |
| Backup Dancer | `obj_zombie_backup_dancer` | Added; individual entities rise and become independently damageable |
| Ducky Tube Zombie | `obj_zombie_ducky_tube` | Added; original zombie/duck-tube tracks referenced; full water-lane behavior is unavailable in this stage |
| Conehead Ducky Tube Zombie | `obj_zombie_ducky_tube_conehead` | Added; tube + cone variant configured |
| Buckethead Ducky Tube Zombie | `obj_zombie_ducky_tube_buckethead` | Added; tube + bucket variant configured |
| Snorkel Zombie | `obj_zombie_snorkel` | Added; source-specific underwater movement is not fully realizable without pool lanes |
| Dolphin Rider Zombie | `obj_zombie_dolphin_rider` | Added; source reanimation and faster movement configured; pool jump/riding sequence remains simplified |
| Zomboni | `obj_zombie_zomboni` | Added; vehicle animation, plant collision, smoke and durability configured; original persistent ice-grid/trail system is unavailable |
| Bobsled Team | `obj_zombie_bobsled_team` | Added; sled leader manages three rider instances; ice timer/crash and pool prerequisite are simplified |
| Bobsled rider helper | `obj_zombie_bobsled_rider` | Added; riders follow their sled leader and remain individual entities |
| Catapult Zombie | `obj_zombie_catapult` | Added; timed `anim_shoot` event fires a visible original-art basketball projectile; 75-damage value, ammo/reload states and chilled slowdown implemented |
| Jack-in-the-Box Zombie | `obj_zombie_jack_in_the_box` | Added; source-based run timer, pop animation, sound events, 115-pixel zombie radius, 90-pixel plant radius and same-row zombie damage implemented |
| Balloon Zombie | `obj_zombie_balloon` | Added; separate 20-health balloon layer and popping state; plant-specific counters such as Cactus/Blover are limited by the current plant roster |
| Digger Zombie | `obj_zombie_digger` | Added; starts underground, ignores ground-level pea hits, tunnels, emerges and enters a recovery state; turn-around/animation behavior remains approximate |
| Pogo Zombie | `obj_zombie_pogo` | Added; timed bounce phases, high/forward bounce and Tall-nut block counter implemented; original bounce easing is approximated |
| Bungee Zombie | `obj_zombie_bungee` | Added; weighted planted-cell/empty-cell selection, invalid-cell filtering and descent/grab/rise states implemented; visual plant-lift and all exact interruption rules remain simplified |
| Ladder Zombie | `obj_zombie_ladder` | Added; recognizes Wall-nut/Tall-nut/Pumpkin obstacles, plays `anim_placeladder`, attaches the original ladder art and climbs/falls over the obstacle; exact source collision/height handling is approximated |
| Yeti Zombie | `obj_zombie_yeti` | Added; original body health, long delay, retreat and faster exit behavior configured |
| Gargantuar | `obj_zombie_gargantuar` | Added; source health, smash timing and animation-triggered Imp release implemented; exact heavy body/target hitboxes and sound/impact fidelity remain approximate |
| Red-Eye Gargantuar | `obj_zombie_red_eye_gargantuar` | Added; 6000 body-health variant configured |
| Imp | `obj_zombie_imp` | Added; thrown trajectory, landing and subsequent walking states configured |
| Dr. Zomboss | `obj_zombie_boss` | Added; boss body, row-targeted stomp/spawn/head-attack animations, timed attack effects, fire/ice projectile and source-style late-game spawn selection are present; the complete original phase scheduler and RV/bungee support attacks are **not** fully implemented |

## Source-derived values and behavior used

The primary source reference was [`Lawn/Zombie.cpp`](https://github.com/ruslan831/PlantsVsZombies-decompilation/blob/master/Lawn/Zombie.cpp), with [`Lawn/Zombie.h`](https://github.com/ruslan831/PlantsVsZombies-decompilation/blob/master/Lawn/Zombie.h), [`Lawn/Challenge.cpp`](https://github.com/ruslan831/PlantsVsZombies-decompilation/blob/master/Lawn/Challenge.cpp), and [`Lawn/Projectile.cpp`](https://github.com/ruslan831/PlantsVsZombies-decompilation/blob/master/Lawn/Projectile.cpp) used for roster definitions, wave/boss selection, health and damage data.

Source values represented in the runtime include: default body health 270; cone 370; bucket and screen door 1100 protective health; newspaper 150; football helmet 1400; digger headgear 100; ladder 500; bobsled sled 300; Pole Vaulter/Dancer/Dolphin Rider/Jack-in-the-Box/Pogo/Ladder 500 body health; Bungee 450; Yeti and Zomboni 1350; Catapult 850; Gargantuar 3000; Red-Eye Gargantuar 6000; Dr. Zomboss adventure health 40000. These values are now source-referenced rather than treated as universal generic zombie stats.

Relevant original assets checked in the supplied project include:

- `datafiles/sounds/boing.ogg`, `jack_surprise.ogg`, `explosion.ogg`, `basketball.ogg`, `ladder_zombie.ogg`, and `bossboulderattack.ogg`.
- `datafiles/parts/reanim/Zombie_catapult_basketball.png` and `Zombie_ladder_1.png`.
- `datafiles/particles/JackExplode.xml`, `DancerRise.xml`, `DiggerTunnel.xml`, and `DiggerRise.xml`.

## Changed files / integration

- `PvZ.yyp`: registers the new objects and shared base.
- `objects/obj_zombie_*`: new wrappers for the missing roster types; existing Basic/Conehead/Buckethead/Pole Vaulter now inherit from the common base.
- `objects/obj_zombie_base/obj_zombie_base.yy`: shared parent object.
- `scripts/scr_pvz_lawn_runtime/scr_pvz_lawn_runtime.gml`: type-specific initialization and shared behaviors, including the Jack explosion, Bungee targeting, dancer backup spawn, ladder placement/climbing, Catapult firing, Gargantuar Imp throw timing, and partial Zomboss sequence.
- `objects/obj_pvz_boss_projectile/{Create_0,Step_0,Draw_0}.gml`: basketball projectile plus continuous boss fire/ice travel using the existing projectile object.
- `objects/obj_pvz_test_controller/{Create_0,Step_0}.gml`: original ladder/basketball art references and debug spawn integration.
- `objects/obj_pvz_pea_projectile/Step_0.gml`: targets the shared zombie parent and uses type-specific hitboxes; ordinary peas do not hit a flying Balloon or underground Digger.
- `objects/obj_pvz_lawn_mower/Step_0.gml`: mower collision checks the shared zombie parent so new zombie types are included.

The existing level seed chooser, menus, and wave count were not intentionally redesigned as part of this zombie pass. The added debug-spawn hooks do not change the normal first-level wave list.

## Verification performed

Static checks completed on the packaged project:

- All 105 GameMaker `.yy` / `.yyp` JSON-like resource files parsed after accounting for GameMaker's trailing-comma format.
- All 100 resource paths referenced from `PvZ.yyp` resolve to files.
- Delimiter scan passed for all 283 `.gml` files.
- All 29 roster type-to-object mappings in the audit resolve; the Bobsled rider helper is also present.
- All 33 `.ogg` names referenced by the shared runtime exist in `datafiles/sounds`.
- The named special-effect XMLs and original ladder/basketball sprite files exist.

## Not verified / remaining limitations

No GameMaker IDE/runtime compiler was available in this environment, so **the project has not been compiled or playtested in-engine**. These static checks do not prove that all GML calls compile or that all behavior is correct at runtime.

The current project is the first lawn stage, not the full collection of PvZ1 environments. In particular, the complete Pool/Fog/Roof-specific mechanics, original ice-lane state for Zomboni/Bobsled, full Snorkel and Dolphin transitions, the full Dancer choreography scheduler, exact Bungee target-lift/interruption timing, all plant-specific counters, and the full Dr. Zomboss multi-phase encounter still need implementation and/or a compatible environment. The simplified boss and movement states are not presented as fully accurate. Use this report as an implementation/verification record, not as a claim of a complete original-engine port.
