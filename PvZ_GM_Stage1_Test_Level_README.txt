PVZ STAGE 1 - PLANT AND ZOMBIE REANIMATION TEST

Room: rm_pvz_day_plant_test
Plant objects: 49 independent obj_plant_* object resources, each with its own Create/Step/Draw event code.
Zombie objects: 4 independent obj_zombie_* object resources.

What this room does:
- Uses the existing scr_reanim / Reanim animation player and original JSON + part images; no baked sprites or scale-in/scale-out animation stand-ins.
- Advances each Reanim via update() with the starter project's shared 100 Hz logic clock.
- Uses the original plant definition table in Lawn/Plant.cpp for seed costs/recharge ticks, the source's base/special health overrides, and Lawn/Projectile.cpp projectile damage values where applicable.
- Uses Zombie.cpp health values: Basic 270, Conehead body 270 + 370 armor, Buckethead body 270 + 1100 armor, Pole Vaulter 500.
- Basic/Conehead/Buckethead all use Zombie reanimation. Cone and bucket tracks are toggled per type; hair is hidden on armored variants. Pole Vaulter uses Zombie_polevaulter's own anim_run track.

Controls: Esc quits.

Your previous PvZ.yyp is backed up to: PvZ.yyp.before_test_level_20261022_234957.bak
Original reanimation definitions, part images, and the existing viewer room/object are retained.

Stats note: source attack labels show the actual projectile damage values defined in Projectile.cpp for relevant ranged plants; special/utility plants show an effect label rather than invented direct-damage values. Source seed cooldowns are retained as 100 Hz ticks and displayed in seconds; source launch-rate values are shown for attacks and producers where applicable.
