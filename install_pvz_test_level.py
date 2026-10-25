#!/usr/bin/env python3
"""Install a source-driven PvZ plant/zombie reanimation test room into PvZ_GM_Stage0.
Run from the extracted installer folder or the GameMaker project root.
The installer edits only project metadata/source resources and preserves the original assets.
"""
from __future__ import annotations
import json, os, re, shutil, sys, time
from pathlib import Path

ROOM = "rm_pvz_day_plant_test"
SCRIPT = "scr_pvz_test"
CONTROLLER = "obj_pvz_test_controller"

# Values copied from Lawn/Plant.cpp gPlantDefs (sun cost, recharge tick counter,
# shooter subclass/launch rate) and its health overrides. Tick counters are at 100 Hz.
# Damage labels for projectiles use Lawn/Projectile.cpp gProjectileDefinition.
PLANTS = [
 dict(slug="peashooter", name="Peashooter", anim="PeaShooterSingle", cost=100, recharge=750, hp=300, damage="20", rate=150, effect="PEA SHOT"),
 dict(slug="sunflower", name="Sunflower", anim="SunFlower", cost=50, recharge=750, hp=300, damage="--", rate=2500, effect="SUN PRODUCER"),
 dict(slug="cherry_bomb", name="Cherry Bomb", anim="CherryBomb", cost=150, recharge=5000, hp=300, damage="SPECIAL", rate=0, effect="AREA BLAST"),
 dict(slug="wallnut", name="Wall-nut", anim="Wallnut", cost=50, recharge=3000, hp=4000, damage="--", rate=0, effect="DEFENSE"),
 dict(slug="potato_mine", name="Potato Mine", anim="PotatoMine", cost=25, recharge=3000, hp=300, damage="SPECIAL", rate=0, effect="EXPLOSIVE"),
 dict(slug="snow_pea", name="Snow Pea", anim="SnowPea", cost=175, recharge=750, hp=300, damage="20", rate=150, effect="SLOWS"),
 dict(slug="chomper", name="Chomper", anim="Chomper", cost=150, recharge=750, hp=300, damage="SPECIAL", rate=0, effect="BITE"),
 dict(slug="repeater", name="Repeater", anim="PeaShooter", cost=200, recharge=750, hp=300, damage="20 x2", rate=150, effect="DOUBLE PEA"),
 dict(slug="puff_shroom", name="Puff-shroom", anim="Puffshroom", cost=0, recharge=750, hp=300, damage="20", rate=150, effect="SHORT RANGE"),
 dict(slug="sun_shroom", name="Sun-shroom", anim="SunShroom", cost=25, recharge=750, hp=300, damage="--", rate=2500, effect="SUN PRODUCER"),
 dict(slug="fume_shroom", name="Fume-shroom", anim="Fumeshroom", cost=75, recharge=750, hp=300, damage="20", rate=150, effect="FUME"),
 dict(slug="grave_buster", name="Grave Buster", anim="Gravebuster", cost=75, recharge=750, hp=300, damage="--", rate=0, effect="GRAVE EATER"),
 dict(slug="hypno_shroom", name="Hypno-shroom", anim="Hypnoshroom", cost=75, recharge=3000, hp=300, damage="--", rate=0, effect="HYPNOTIZES"),
 dict(slug="scaredy_shroom", name="Scaredy-shroom", anim="ScaredyShroom", cost=25, recharge=750, hp=300, damage="20", rate=150, effect="RANGED"),
 dict(slug="ice_shroom", name="Ice-shroom", anim="Iceshroom", cost=75, recharge=5000, hp=300, damage="SPECIAL", rate=0, effect="FREEZE"),
 dict(slug="doom_shroom", name="Doom-shroom", anim="DoomShroom", cost=125, recharge=5000, hp=300, damage="SPECIAL", rate=0, effect="AREA BLAST"),
 dict(slug="lily_pad", name="Lily Pad", anim="Lilypad", cost=25, recharge=750, hp=300, damage="--", rate=0, effect="WATER PLATFORM"),
 dict(slug="squash", name="Squash", anim="Squash", cost=50, recharge=3000, hp=300, damage="SPECIAL", rate=0, effect="SMASH"),
 dict(slug="threepeater", name="Threepeater", anim="ThreePeater", cost=325, recharge=750, hp=300, damage="20 x3", rate=150, effect="3 LANES"),
 dict(slug="tangle_kelp", name="Tangle Kelp", anim="Tanglekelp", cost=25, recharge=3000, hp=300, damage="SPECIAL", rate=0, effect="PULLS UNDER"),
 dict(slug="jalapeno", name="Jalapeno", anim="Jalapeno", cost=125, recharge=5000, hp=300, damage="SPECIAL", rate=0, effect="ROW BLAST"),
 dict(slug="spikeweed", name="Spikeweed", anim="Caltrop", cost=100, recharge=750, hp=300, damage="20", rate=0, effect="GROUND ATTACK"),
 dict(slug="torchwood", name="Torchwood", anim="Torchwood", cost=175, recharge=750, hp=300, damage="--", rate=0, effect="PEA BOOST"),
 dict(slug="tall_nut", name="Tall-nut", anim="Tallnut", cost=125, recharge=3000, hp=8000, damage="--", rate=0, effect="DEFENSE"),
 dict(slug="sea_shroom", name="Sea-shroom", anim="SeaShroom", cost=0, recharge=3000, hp=300, damage="20", rate=150, effect="WATER SHOT"),
 dict(slug="plantern", name="Plantern", anim="Plantern", cost=25, recharge=3000, hp=300, damage="--", rate=2500, effect="REVEALS FOG"),
 dict(slug="cactus", name="Cactus", anim="Cactus", cost=125, recharge=750, hp=300, damage="20", rate=150, effect="SPIKES"),
 dict(slug="blover", name="Blover", anim="Blover", cost=100, recharge=750, hp=300, damage="--", rate=0, effect="BLOWS FOG"),
 dict(slug="split_pea", name="Split Pea", anim="SplitPea", cost=125, recharge=750, hp=300, damage="20", rate=150, effect="FRONT + BACK"),
 dict(slug="starfruit", name="Starfruit", anim="Starfruit", cost=125, recharge=750, hp=300, damage="20", rate=150, effect="STAR SHOT"),
 dict(slug="pumpkin", name="Pumpkin", anim="Pumpkin", cost=125, recharge=3000, hp=4000, damage="--", rate=0, effect="ARMOR"),
 dict(slug="magnet_shroom", name="Magnet-shroom", anim="Magnetshroom", cost=100, recharge=750, hp=300, damage="--", rate=0, effect="REMOVES METAL"),
 dict(slug="cabbage_pult", name="Cabbage-pult", anim="Cabbagepult", cost=100, recharge=750, hp=300, damage="40", rate=300, effect="LOB"),
 dict(slug="flower_pot", name="Flower Pot", anim="Pot", cost=25, recharge=750, hp=300, damage="--", rate=0, effect="ROOF PLATFORM"),
 dict(slug="kernel_pult", name="Kernel-pult", anim="Cornpult", cost=100, recharge=750, hp=300, damage="20 / 40", rate=300, effect="KERNEL / BUTTER"),
 dict(slug="coffee_bean", name="Coffee Bean", anim="Coffeebean", cost=75, recharge=750, hp=300, damage="--", rate=0, effect="WAKES MUSHROOM"),
 dict(slug="garlic", name="Garlic", anim="Garlic", cost=50, recharge=750, hp=400, damage="--", rate=0, effect="DIVERTS ZOMBIES"),
 dict(slug="umbrella_leaf", name="Umbrella Leaf", anim="Umbrellaleaf", cost=100, recharge=750, hp=300, damage="--", rate=0, effect="PROTECTS NEARBY"),
 dict(slug="marigold", name="Marigold", anim="Marigold", cost=50, recharge=3000, hp=300, damage="--", rate=2500, effect="COIN PRODUCER"),
 dict(slug="melon_pult", name="Melon-pult", anim="Melonpult", cost=300, recharge=750, hp=300, damage="80", rate=300, effect="SPLASH"),
 dict(slug="gatling_pea", name="Gatling Pea", anim="GatlingPea", cost=250, recharge=5000, hp=300, damage="20 x4", rate=150, effect="FOUR PEAS"),
 dict(slug="twin_sunflower", name="Twin Sunflower", anim="TwinSunFlower", cost=150, recharge=5000, hp=300, damage="--", rate=2500, effect="DOUBLE SUN"),
 dict(slug="gloom_shroom", name="Gloom-shroom", anim="GloomShroom", cost=150, recharge=5000, hp=300, damage="20", rate=200, effect="AREA FUME"),
 dict(slug="cattail", name="Cattail", anim="Cattail", cost=225, recharge=5000, hp=300, damage="20", rate=150, effect="HOMING SPIKE"),
 dict(slug="winter_melon", name="Winter Melon", anim="WinterMelon", cost=200, recharge=5000, hp=300, damage="80", rate=300, effect="SPLASH + SLOW"),
 dict(slug="gold_magnet", name="Gold Magnet", anim="GoldMagnet", cost=50, recharge=5000, hp=300, damage="--", rate=0, effect="COLLECTS COINS"),
 dict(slug="spikerock", name="Spikerock", anim="SpikeRock", cost=125, recharge=5000, hp=450, damage="20", rate=0, effect="GROUND ATTACK"),
 dict(slug="cob_cannon", name="Cob Cannon", anim="CobCannon", cost=500, recharge=5000, hp=300, damage="300", rate=600, effect="COB LAUNCH"),
 dict(slug="imitater", name="Imitater", anim="Imitater", cost=0, recharge=750, hp=300, damage="--", rate=0, effect="MIMIC"),
]

ZOMBIES = [
 dict(slug="basic", name="Basic Zombie", anim="Zombie", track="anim_walk", body=270, armor=0, rate=12, mask="basic"),
 dict(slug="conehead", name="Conehead Zombie", anim="Zombie", track="anim_walk", body=270, armor=370, rate=12, mask="conehead"),
 dict(slug="buckethead", name="Buckethead Zombie", anim="Zombie", track="anim_walk", body=270, armor=1100, rate=12, mask="buckethead"),
 dict(slug="polevaulter", name="Pole Vaulter Zombie", anim="Zombie_polevaulter", track="anim_run", body=500, armor=0, rate=16, mask="polevaulter"),
]

SCRIPT_GML = r'''/// Source-driven PvZ reanimation test helpers.
/// All motion here advances Reanim.update() against the project's original 100 Hz clock.
function pvz_test_init_plant(_display_name, _reanim_name, _sun_cost, _recharge_ticks, _health, _damage_label, _rate_ticks, _effect) {
    display_name = _display_name;
    reanim_name = _reanim_name;
    sun_cost = _sun_cost;
    recharge_ticks = _recharge_ticks;
    plant_health = _health;
    damage_label = _damage_label;
    attack_rate_ticks = _rate_ticks;
    effect_label = _effect;
    body = new Reanim(_reanim_name, x, y - 12);
    body.scale_x = 0.62;
    body.scale_y = 0.62;
    body.loop_type = ReanimLoop.LOOP;
    body.anim_rate = 12;
    head = undefined;
    // Match Plant.cpp's separate head/body setup for pea-style layered plants.
    if (body.track_exists("anim_idle") && body.track_exists("anim_head_idle") && body.track_exists("anim_stem")) {
        body.anim_rate = 17.5;
        body.set_frames_for_layer("anim_idle");
        head = new Reanim(_reanim_name, 0, 0);
        head.loop_type = ReanimLoop.LOOP;
        head.anim_rate = body.anim_rate;
        head.scale_x = body.scale_x;
        head.scale_y = body.scale_y;
        head.set_frames_for_layer("anim_head_idle");
        head.attach_to(body, "anim_stem");
    } else if (body.track_exists("anim_idle")) {
        body.set_frames_for_layer("anim_idle");
    } else if (body.track_exists("anim_full_idle")) {
        body.set_frames_for_layer("anim_full_idle");
    } else {
        body.play_all(ReanimLoop.LOOP);
    }
    depth = 0;
}

function pvz_test_init_zombie(_display_name, _reanim_name, _track_name, _body_health, _armor_health, _rate, _mask_kind) {
    display_name = _display_name;
    reanim_name = _reanim_name;
    body_health = _body_health;
    armor_health = _armor_health;
    total_health = _body_health + _armor_health;
    body = new Reanim(_reanim_name, x, y - 12);
    body.scale_x = (_mask_kind == "polevaulter") ? 0.82 : 0.78;
    body.scale_y = body.scale_x;
    body.anim_rate = _rate;
    body.play(_track_name, ReanimLoop.LOOP, 0, _rate);
    // The original basic/cone/bucket variants share Zombie.reanim. Hide the same
    // equipment tracks the source hides instead of letting every helmet draw at once.
    if (_mask_kind != "polevaulter") {
        body.set_tracks_hidden_by_prefix("anim_cone", _mask_kind != "conehead");
        body.set_tracks_hidden_by_prefix("anim_bucket", _mask_kind != "buckethead");
        body.set_tracks_hidden_by_prefix("anim_hair", _mask_kind == "conehead" || _mask_kind == "buckethead");
        body.set_tracks_hidden_by_prefix("Zombie_duckytube", true);
        body.set_tracks_hidden_by_prefix("Zombie_whitewater", true);
        body.set_tracks_hidden_by_prefix("Zombie_innerarm_screendoor", true);
        body.set_tracks_hidden_by_prefix("Zombie_outerarm_screendoor", true);
        body.set_tracks_hidden_by_prefix("Zombie_screendoor", true);
        body.set_track_hidden("Zombie_flaghand", true);
    }
    depth = 0;
}

function pvz_test_step_reanim() {
    if (is_undefined(body)) return;
    body.x = x;
    body.y = y - 12;
    var _ticks = global.pvz_test_steps;
    repeat (_ticks) body.update();
}

function pvz_test_draw_plant() {
    if (!is_undefined(body)) body.draw();
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_text(x, y + 3, display_name);
    draw_set_color(make_color_rgb(248, 226, 141));
    draw_text(x, y + 17, "SUN " + string(sun_cost) + " | HP " + string(plant_health));
    draw_set_color(c_white);
    var _line = effect_label;
    if (damage_label != "--" && damage_label != "SPECIAL") {
        _line = "DMG " + damage_label;
        if (attack_rate_ticks > 0) _line += " / " + string_format(attack_rate_ticks / 100, 2, 1) + "s";
    }
    if (effect_label == "SUN PRODUCER" || effect_label == "DOUBLE SUN" || effect_label == "COIN PRODUCER") {
        _line = effect_label + " / " + string_format(attack_rate_ticks / 100, 2, 1) + "s";
    }
    draw_text(x, y + 30, _line);
    draw_set_color(make_color_rgb(219, 239, 207));
    draw_text(x, y + 43, "RECHARGE " + string_format(recharge_ticks / 100, 2, 1) + "s");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

function pvz_test_draw_zombie() {
    if (!is_undefined(body)) body.draw();
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_text(x, y + 25, display_name);
    draw_set_color(make_color_rgb(248, 226, 141));
    draw_text(x, y + 40, "BODY " + string(body_health) + " | ARMOR " + string(armor_health));
    draw_set_color(c_white);
    draw_text(x, y + 55, "TOTAL " + string(total_health));
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}
'''

CONTROLLER_CREATE = r'''/// Test room controller. Initialize the 100 Hz source clock before the plants/zombies update.
logic_clock_init();
reanim_init();
global.pvz_test_steps = 0;
depth = 10000;
window_set_size(room_width, room_height);
'''
CONTROLLER_STEP = r'''/// One shared fixed-step accumulator for every Reanim instance in the room.
global.pvz_test_steps = logic_clock_steps();
if (keyboard_check_pressed(vk_escape)) game_end();
'''
CONTROLLER_DRAW = r'''draw_clear(make_color_rgb(60, 111, 47));
// Day lawn tile board.
for (var _r = 0; _r < 7; _r++) {
    for (var _c = 0; _c < 7; _c++) {
        var _x1 = _c * 170 + 5;
        var _y1 = 52 + _r * 82;
        if ((_r + _c) mod 2 == 0) draw_set_color(make_color_rgb(103, 166, 69));
        else draw_set_color(make_color_rgb(115, 176, 76));
        draw_rectangle(_x1, _y1, _x1 + 160, _y1 + 78, false);
        draw_set_color(make_color_rgb(75, 131, 51));
        draw_rectangle(_x1, _y1, _x1 + 160, _y1 + 78, true);
    }
}
draw_set_color(c_white);
draw_text(18, 10, "PVZ - ORIGINAL PLANT + ZOMBIE REANIMATION TEST");
draw_text(18, 29, "49 separate plant objects | source-derived sun cost, recharge, health and projectile damage");
draw_set_color(make_color_rgb(37, 83, 36));
draw_rectangle(0, 724, room_width, room_height, false);
draw_set_color(c_white);
draw_text(20, 734, "ZOMBIE REANIMATION CHECK: shared Zombie body + per-type equipment masks; Pole Vaulter uses its own reanimation");
draw_text(20, 754, "ESC quits. Animations are updated by the existing Reanim player at the source's 100 Hz logic rate.");
'''


def write_text(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n", encoding="utf-8", newline="\n")


def read_yyp(path: Path):
    source = path.read_text(encoding="utf-8-sig")
    # GameMaker project files often use JSONC-style trailing commas.
    clean = re.sub(r",\s*([}\]])", r"\1", source)
    try:
        return json.loads(clean)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Could not parse {path.name} as GameMaker project JSON: {exc}") from exc


def resource(name: str, rel_path: str):
    return {"id": {"name": name, "path": rel_path}}


def make_script_yy(name: str):
    return {"$GMScript":"v1", "%Name":name, "isCompatibility":False, "isDnD":False,
            "name":name, "parent":{"name":"Scripts","path":"folders/Scripts.yy"},
            "resourceType":"GMScript", "resourceVersion":"2.0"}


def make_object_yy(name: str, events):
    ev = []
    for event_type, event_num, _filename in events:
        ev.append({"$GMEvent":"v1", "%Name":"", "collisionObjectId":None,
                   "eventNum":event_num, "eventType":event_type, "isDnD":False,
                   "name":"", "resourceType":"GMEvent", "resourceVersion":"2.0"})
    return {"$GMObject":"", "%Name":name, "eventList":ev, "managed":True, "name":name,
            "overriddenProperties":[], "parent":{"name":"Objects","path":"folders/Objects.yy"},
            "parentObjectId":None, "persistent":False, "physicsAngularDamping":0.1,
            "physicsDensity":0.5, "physicsFriction":0.2, "physicsGroup":1,
            "physicsKinematic":False, "physicsLinearDamping":0.1, "physicsObject":False,
            "physicsRestitution":0.1, "physicsSensor":False, "physicsShape":1,
            "physicsShapePoints":[], "physicsStartAwake":True, "properties":[],
            "resourceType":"GMObject", "resourceVersion":"2.0", "solid":False,
            "spriteId":None, "spriteMaskId":None, "visible":True}


def make_room_instance(instance_name, object_name, x, y):
    return {"$GMRInstance":"v4", "%Name":instance_name, "colour":4294967295,
            "frozen":False, "hasCreationCode":False, "ignore":False, "imageIndex":0,
            "imageSpeed":1.0, "inheritCode":False, "inheritedItemId":None,
            "inheritItemSettings":False, "isDnd":False, "name":instance_name,
            "objectId":{"name":object_name,"path":f"objects/{object_name}/{object_name}.yy"},
            "properties":[], "resourceType":"GMRInstance", "resourceVersion":"2.0",
            "rotation":0.0, "scaleX":1.0, "scaleY":1.0, "x":float(x), "y":float(y)}


def make_room(plant_objects, zombie_objects):
    instances = [make_room_instance("inst_test_controller", CONTROLLER, 0, 0)]
    creation = [{"name":"inst_test_controller","path":f"rooms/{ROOM}/{ROOM}.yy"}]
    for i, plant in enumerate(PLANTS):
        col, row = i % 7, i // 7
        obj = plant_objects[i]
        inst_name = f"inst_{plant['slug']}"
        px, py = 85 + col * 170, 88 + row * 82
        instances.append(make_room_instance(inst_name, obj, px, py))
        creation.append({"name":inst_name,"path":f"rooms/{ROOM}/{ROOM}.yy"})
    zxs = [220, 480, 740, 1000]
    for i, zombie in enumerate(ZOMBIES):
        obj = zombie_objects[i]
        inst_name = f"inst_zombie_{zombie['slug']}"
        instances.append(make_room_instance(inst_name, obj, zxs[i], 810))
        creation.append({"name":inst_name,"path":f"rooms/{ROOM}/{ROOM}.yy"})

    view = {"hborder":32,"hport":1200,"hspeed":-1,"hview":1200,"inherit":False,"objectId":None,
            "vborder":32,"visible":False,"vspeed":-1,"wport":1200,"wview":1200,
            "xport":0,"xview":0,"yport":0,"yview":0}
    return {"$GMRoom":"v1", "%Name":ROOM, "creationCodeFile":"", "inheritCode":False,
            "inheritCreationOrder":False, "inheritLayers":False, "instanceCreationOrder":creation,
            "isDnd":False, "layers":[{"$GMRInstanceLayer":"", "%Name":"Instances", "depth":0,
            "effectEnabled":True,"effectType":None,"gridX":32,"gridY":32,"hierarchyFrozen":False,
            "inheritLayerDepth":False,"inheritLayerSettings":False,"inheritSubLayers":True,
            "inheritVisibility":True,"instances":instances,"layers":[],"name":"Instances",
            "properties":[],"resourceType":"GMRInstanceLayer","resourceVersion":"2.0",
            "userdefinedDepth":False,"visible":True}], "name":ROOM,
            "parent":{"name":"Rooms","path":"folders/Rooms.yy"}, "parentRoom":None,
            "physicsSettings":{"inheritPhysicsSettings":False,"PhysicsWorld":False,
            "PhysicsWorldGravityX":0.0,"PhysicsWorldGravityY":10.0,"PhysicsWorldPixToMetres":0.1},
            "resourceType":"GMRoom","resourceVersion":"2.0",
            "roomSettings":{"Height":900,"inheritRoomSettings":False,"persistent":False,"Width":1200},
            "sequenceId":None,"views":[dict(view) for _ in range(8)],
            "viewSettings":{"clearDisplayBuffer":True,"clearViewBackground":False,"enableViews":False,
            "inheritViewSettings":False},"volume":1.0}


def write_object(root: Path, name: str, create_code: str, step_code: str, draw_code: str):
    objdir = root / "objects" / name
    events = [(0,0,"Create_0.gml"),(3,0,"Step_0.gml"),(8,0,"Draw_0.gml")]
    for _, _, _f in events:
        (objdir / _f).parent.mkdir(parents=True, exist_ok=True)
    write_text(objdir / "Create_0.gml", create_code)
    write_text(objdir / "Step_0.gml", step_code)
    write_text(objdir / "Draw_0.gml", draw_code)
    write_text(objdir / f"{name}.yy", json.dumps(make_object_yy(name, events), indent=2))


def patch_reanim_paths(root: Path):
    # Included files may be exposed at the standard runtime root OR retain their source datafiles/ prefix.
    candidates = [root / "gml_source" / "scr_reanim.gml", root / "scripts" / "scr_reanim" / "scr_reanim.gml"]
    replacements = [
        ('var _file = working_directory + "parts/" + _path;',
         'var _file = working_directory + "parts/" + _path;\n    if (!file_exists(_file)) _file = working_directory + "datafiles/parts/" + _path;'),
        ('var _file = working_directory + "reanim/" + _name + ".json";',
         'var _file = working_directory + "reanim/" + _name + ".json";\n    if (!file_exists(_file)) _file = working_directory + "datafiles/reanim/" + _name + ".json";'),
        ('var _buf = buffer_load(working_directory + "reanim/_index.json");',
         'var _index_file = working_directory + "reanim/_index.json";\n    if (!file_exists(_index_file)) _index_file = working_directory + "datafiles/reanim/_index.json";\n    var _buf = buffer_load(_index_file);')
    ]
    for path in candidates:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        changed = False
        for old, new in replacements:
            # Keep this patch idempotent; users may run the lawn installer more than once.
            if old in text and new not in text:
                text = text.replace(old, new)
                changed = True
        if changed:
            write_text(path, text)


def install(root: Path):
    yyp_path = root / "PvZ.yyp"
    if not yyp_path.exists():
        raise RuntimeError("PvZ.yyp was not found. Extract this installer into the root of the existing PvZ_GM_Stage0 project.")
    if not (root / "datafiles" / "reanim" / "_index.json").exists():
        raise RuntimeError("datafiles/reanim/_index.json is missing. This installer needs the original PvZ_GM_Stage0 assets.")
    if not (root / "datafiles" / "parts").exists():
        raise RuntimeError("datafiles/parts is missing. This installer needs the original animation part images.")

    project = read_yyp(yyp_path)
    resources = project.setdefault("resources", [])
    existing_names = {entry.get("id", {}).get("name") for entry in resources if isinstance(entry, dict)}
    new_resources = []

    # Common script containing the Reanim-driven draw/update helpers.
    script_dir = root / "scripts" / SCRIPT
    write_text(script_dir / f"{SCRIPT}.gml", SCRIPT_GML)
    write_text(script_dir / f"{SCRIPT}.yy", json.dumps(make_script_yy(SCRIPT), indent=2))
    if SCRIPT not in existing_names:
        new_resources.append(resource(SCRIPT, f"scripts/{SCRIPT}/{SCRIPT}.yy"))
        existing_names.add(SCRIPT)

    # Controller draws the day lawn and owns one shared fixed-timestep accumulator.
    write_object(root, CONTROLLER, CONTROLLER_CREATE, CONTROLLER_STEP, CONTROLLER_DRAW)
    if CONTROLLER not in existing_names:
        new_resources.append(resource(CONTROLLER, f"objects/{CONTROLLER}/{CONTROLLER}.yy"))
        existing_names.add(CONTROLLER)

    plant_object_names = []
    for plant in PLANTS:
        obj_name = "obj_plant_" + plant["slug"]
        plant_object_names.append(obj_name)
        create = (f'pvz_test_init_plant("{plant["name"]}", "{plant["anim"]}", '
                  f'{plant["cost"]}, {plant["recharge"]}, {plant["hp"]}, '
                  f'"{plant["damage"]}", {plant["rate"]}, "{plant["effect"]}");')
        write_object(root, obj_name, create, "pvz_test_step_reanim();", "pvz_test_draw_plant();")
        if obj_name not in existing_names:
            new_resources.append(resource(obj_name, f"objects/{obj_name}/{obj_name}.yy"))
            existing_names.add(obj_name)

    zombie_object_names = []
    for zombie in ZOMBIES:
        obj_name = "obj_zombie_" + zombie["slug"]
        zombie_object_names.append(obj_name)
        create = (f'pvz_test_init_zombie("{zombie["name"]}", "{zombie["anim"]}", '
                  f'"{zombie["track"]}", {zombie["body"]}, {zombie["armor"]}, '
                  f'{zombie["rate"]}, "{zombie["mask"]}");')
        write_object(root, obj_name, create, "pvz_test_step_reanim();", "pvz_test_draw_zombie();")
        if obj_name not in existing_names:
            new_resources.append(resource(obj_name, f"objects/{obj_name}/{obj_name}.yy"))
            existing_names.add(obj_name)

    # Build the room with all 49 plants on the lawn and the four requested zombie variants below.
    room_dir = root / "rooms" / ROOM
    write_text(room_dir / f"{ROOM}.yy", json.dumps(make_room(plant_object_names, zombie_object_names), indent=2))
    if ROOM not in existing_names:
        new_resources.append(resource(ROOM, f"rooms/{ROOM}/{ROOM}.yy"))
        existing_names.add(ROOM)

    resources.extend(new_resources)
    order = project.setdefault("RoomOrderNodes", [])
    old_order = [n for n in order if n.get("roomId", {}).get("name") != ROOM]
    project["RoomOrderNodes"] = [{"roomId":{"name":ROOM,"path":f"rooms/{ROOM}/{ROOM}.yy"}}] + old_order

    # Backup, then rewrite as valid JSON. GameMaker's own project generator also emits standard JSON.
    backup = root / f"PvZ.yyp.before_test_level_{time.strftime('%Y%m%d_%H%M%S')}.bak"
    shutil.copy2(yyp_path, backup)
    write_text(yyp_path, json.dumps(project, indent=2, ensure_ascii=False))
    patch_reanim_paths(root)

    readme = f'''PVZ STAGE 1 - PLANT AND ZOMBIE REANIMATION TEST

Room: {ROOM}
Plant objects: {len(PLANTS)} independent obj_plant_* object resources, each with its own Create/Step/Draw event code.
Zombie objects: {len(ZOMBIES)} independent obj_zombie_* object resources.

What this room does:
- Uses the existing scr_reanim / Reanim animation player and original JSON + part images; no baked sprites or scale-in/scale-out animation stand-ins.
- Advances each Reanim via update() with the starter project's shared 100 Hz logic clock.
- Uses the original plant definition table in Lawn/Plant.cpp for seed costs/recharge ticks, the source's base/special health overrides, and Lawn/Projectile.cpp projectile damage values where applicable.
- Uses Zombie.cpp health values: Basic 270, Conehead body 270 + 370 armor, Buckethead body 270 + 1100 armor, Pole Vaulter 500.
- Basic/Conehead/Buckethead all use Zombie reanimation. Cone and bucket tracks are toggled per type; hair is hidden on armored variants. Pole Vaulter uses Zombie_polevaulter's own anim_run track.

Controls: Esc quits.

Your previous PvZ.yyp is backed up to: {backup.name}
Original reanimation definitions, part images, and the existing viewer room/object are retained.

Stats note: source attack labels show the actual projectile damage values defined in Projectile.cpp for relevant ranged plants; special/utility plants show an effect label rather than invented direct-damage values. Source seed cooldowns are retained as 100 Hz ticks and displayed in seconds; source launch-rate values are shown for attacks and producers where applicable.
'''
    write_text(root / "PvZ_GM_Stage1_Test_Level_README.txt", readme)
    return backup, len(new_resources)


def find_project_root(start: Path):
    for path in [start, *start.parents]:
        if (path / "PvZ.yyp").is_file():
            return path
    return None


def main():
    explicit = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parent
    root = find_project_root(explicit)
    if root is None:
        root = find_project_root(Path.cwd().resolve())
    if root is None:
        print("ERROR: PvZ.yyp not found. Extract this installer into PvZ_GM_Stage0, next to PvZ.yyp, then run it again.")
        return 2
    try:
        backup, count = install(root)
        print(f"Installed into: {root}")
        print(f"Added {count} new GameMaker resource references; generated {len(PLANTS)} plant objects and {len(ZOMBIES)} zombie objects.")
        print(f"New startup room: {ROOM}")
        print(f"Backup: {backup}")
        print("Next: open PvZ.yyp in GameMaker 2024.x and press F5. This package has been statically validated, but it has not been run in GameMaker here.")
        return 0
    except Exception as exc:
        print(f"INSTALL FAILED: {exc}")
        print("Your project metadata has not been overwritten if the failure occurred before the final save. Check the project folder and try again.")
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
