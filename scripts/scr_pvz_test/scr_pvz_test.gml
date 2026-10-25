/// Source-driven PvZ reanimation test helpers.
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
    pvz_lawn_draw_text_native(x, y + 3, display_name, "DwarvenTodcraft15", 0.70);
    draw_set_color(make_color_rgb(248, 226, 141));
    pvz_lawn_draw_text_native(x, y + 17, "SUN " + string(sun_cost) + " | HP " + string(plant_health), "BrianneTod12", 0.68);
    draw_set_color(c_white);
    var _line = effect_label;
    if (damage_label != "--" && damage_label != "SPECIAL") {
        _line = "DMG " + damage_label;
        if (attack_rate_ticks > 0) _line += " / " + string_format(attack_rate_ticks / 100, 2, 1) + "s";
    }
    if (effect_label == "SUN PRODUCER" || effect_label == "DOUBLE SUN" || effect_label == "COIN PRODUCER") {
        _line = effect_label + " / " + string_format(attack_rate_ticks / 100, 2, 1) + "s";
    }
    pvz_lawn_draw_text_native(x, y + 30, _line, "BrianneTod12", 0.68);
    draw_set_color(make_color_rgb(219, 239, 207));
    pvz_lawn_draw_text_native(x, y + 43, "RECHARGE " + string_format(recharge_ticks / 100, 2, 1) + "s", "BrianneTod12", 0.68);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

function pvz_test_draw_zombie() {
    if (!is_undefined(body)) body.draw();
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    pvz_lawn_draw_text_native(x, y + 25, display_name, "DwarvenTodcraft15", 0.70);
    draw_set_color(make_color_rgb(248, 226, 141));
    pvz_lawn_draw_text_native(x, y + 40, "BODY " + string(body_health) + " | ARMOR " + string(armor_health), "BrianneTod12", 0.68);
    draw_set_color(c_white);
    pvz_lawn_draw_text_native(x, y + 55, "TOTAL " + string(total_health), "BrianneTod12", 0.68);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}
