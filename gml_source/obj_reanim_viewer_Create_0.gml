/// obj_reanim_viewer : Create
/// Dev tool: browse every converted reanim and its animations.
logic_clock_init();
reanim_init();

names = reanim_load_index();      // all converted reanim names
sel = array_get_index(names, "PeaShooter");
if (sel < 0) sel = 0;
zoom = 2;
cam_x = room_width * 0.5;         // screen position of the reanim origin (camera pan)
cam_y = room_height * 0.6;
prev_mx = mouse_x;
prev_my = mouse_y;
paused = false;
body = undefined;
head = undefined;
anims = [];                       // named animation ranges of the current reanim
anim_sel = 0;                     // 0 = default idle layers, 1.. = anims[anim_sel - 1]
can_layer = false;                // true for pea-style plants (separate head reanim attached to the body)
layered = false;

/// Rebuilds the reanim(s) with their default animation, like Plant::PlantInitialize does.
rebuild = function() {
    var _name = names[sel];
    body = new Reanim(_name, cam_x, cam_y);
    head = undefined;
    body.loop_type = ReanimLoop.LOOP;
    can_layer = body.track_exists("anim_idle") && body.track_exists("anim_head_idle");
    anims = reanim_anim_list(body.def);
    if (layered && can_layer) {
        // Plant.cpp (SEED_PEASHOOTER ...): body plays anim_idle, a second reanim of the same
        // definition plays anim_head_idle and is attached to the body's "anim_stem" track.
        body.anim_rate = random_range(15, 20);
        body.set_frames_for_layer("anim_idle");
        head = new Reanim(_name, 0, 0);
        head.loop_type = ReanimLoop.LOOP;
        head.anim_rate = body.anim_rate;
        head.set_frames_for_layer("anim_head_idle");
        head.attach_to(body, body.track_exists("anim_stem") ? "anim_stem" : "anim_idle");
    } else {
        layered = false;
        body.play_all(ReanimLoop.LOOP);
    }
};

reset_camera = function() {
    zoom = 2;
    cam_x = room_width * 0.5;
    cam_y = room_height * 0.6;
};

/// Zooms by a factor while keeping the point under (_px, _py) fixed on screen.
zoom_at = function(_factor, _px, _py) {
    var _new = clamp(zoom * _factor, 0.25, 8);
    var _f = _new / zoom;
    cam_x = _px - (_px - cam_x) * _f;
    cam_y = _py - (_py - cam_y) * _f;
    zoom = _new;
};

switch_reanim = function(_d) {
    var _n = array_length(names);
    sel = (sel + _d + _n * 100) mod _n;
    anim_sel = 0;
    layered = true;          // rebuild() turns it back off if the reanim cannot be layered
    rebuild();
};

select_anim = function(_d) {
    var _n = array_length(anims) + 1;
    anim_sel = (anim_sel + _d + _n) mod _n;
    if (anim_sel == 0) { rebuild(); return; }
    var _a = anims[anim_sel - 1];
    var _low = string_lower(_a.name);
    var _target = body;
    if (layered && (string_pos("head", _low) > 0 || string_pos("shoot", _low) > 0)) _target = head;
    _target.play(_a.name, ReanimLoop.LOOP, 20);      // 20 tick blend, like PlayBodyReanim(..., 20, ...)
};

layered = true;
rebuild();
