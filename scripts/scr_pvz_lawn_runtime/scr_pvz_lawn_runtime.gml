/// PvZ lawn sandbox helpers. Uses the original Reanim player + 100 Hz source clock.
#macro PVZ_GRID_X 40
#macro PVZ_GRID_Y 80
#macro PVZ_CELL_W 80
#macro PVZ_CELL_H 100
#macro PVZ_COLS 9
#macro PVZ_ROWS 5
// Original PC PvZ Board constants (ruslan831/PlantsVsZombies-decompilation, Board.cpp / CutScene.cpp).
// The PC lawn has no QEWide extension. Board drawing is translated from (-220, 0), then panned.
#macro PVZ_BOARD_ADDITIONAL_WIDTH 0
#macro PVZ_BOARD_OFFSET_X 220
#macro PVZ_BOARD_OFFSET_Y 0
#macro PVZ_BOARD_IMAGE_WIDTH_OFFSET 1180
// CutScene.cpp: street pan ends at BOARD_IMAGE_WIDTH_OFFSET - screen width = 1180 - 800 = 380.
#macro PVZ_CAMERA_STREET_OFFSET (PVZ_BOARD_IMAGE_WIDTH_OFFSET - 800)
// CutScene.cpp pan times are advanced by 10 per 100Hz update, so use the divided-by-10 ticks.
#macro PVZ_CAMERA_PAN_RIGHT_START 150
#macro PVZ_CAMERA_PAN_RIGHT_END 350
#macro PVZ_CAMERA_PAN_LEFT_START 450
#macro PVZ_CAMERA_PAN_LEFT_END 600
// CutScene.cpp: SeedChooser slides on from 4000-4250ms, pauses the scene while choosing,
// then slides away from 4500-4750ms before the camera finishes panning back.
#macro PVZ_SEED_CHOOSER_SLIDE_ON_START 400
#macro PVZ_SEED_CHOOSER_SLIDE_ON_END 425
#macro PVZ_SEED_CHOOSER_SLIDE_OFF_START 450
#macro PVZ_SEED_CHOOSER_SLIDE_OFF_END 475
#macro PVZ_SEED_CHOOSER_REQUIRED 6
#macro PVZ_SEED_CHOOSER_GRID_COLS 8
#macro PVZ_SEED_CHOOSER_GRID_ROWS 5
#macro PVZ_SEED_CHOOSER_GRID_X 22
#macro PVZ_SEED_CHOOSER_GRID_Y 123
#macro PVZ_SEED_CHOOSER_GRID_STEP_X 53
#macro PVZ_SEED_CHOOSER_GRID_STEP_Y 72
#macro PVZ_SEED_BANK_PACKET_X 85
#macro PVZ_SEED_BANK_PACKET_STEP 59
#macro PVZ_SEED_BANK_PACKET_SCALE 1.0
#macro PVZ_SEED_BANK_SLIDE_ON_START 400
#macro PVZ_SEED_BANK_COMPACT_FRAMES 6
// CutScene.cpp: ReadySetPlant starts at 6000ms and ends at 7830ms.
#macro PVZ_READY_SET_PLANT_START 600
#macro PVZ_READY_SET_PLANT_END 783
#macro PVZ_STREET_ZOMBIE_START_X 830
#macro PVZ_STREET_ZOMBIE_START_Y 70
#macro PVZ_STREET_ZOMBIE_GRID_X 56
#macro PVZ_STREET_ZOMBIE_GRID_Y 90

/// Board::StageHasPool / StageHasRoof geometry for the six-row PC pool board and five-row lawn boards.
function pvz_lawn_active_rows() {
    if (variable_global_exists("pvz_lawn_active_rows") && global.pvz_lawn_active_rows > 0) return global.pvz_lawn_active_rows;
    return 5;
}
function pvz_lawn_cell_height() {
    if (variable_global_exists("pvz_lawn_environment_index") && global.pvz_lawn_environment_index >= 2) return 85;
    return 100;
}
function pvz_lawn_row_y(_row, _x = 780, _offset = 0) {
    var _h = pvz_lawn_cell_height();
    var _y = PVZ_GRID_Y + _row * _h;
    // Board::GetPosYBasedOnRow for roof boards: the tiles slope down toward the lower-left.
    if (variable_global_exists("pvz_lawn_environment_index") && global.pvz_lawn_environment_index >= 4) {
        _y -= 10;
        if (_x < 440) _y += (440 - _x) * 0.25;
    }
    return _y + _offset;
}
function pvz_lawn_is_pool_row(_row) {
    return variable_global_exists("pvz_lawn_environment_index") && (global.pvz_lawn_environment_index == 2 || global.pvz_lawn_environment_index == 3) && (_row == 2 || _row == 3);
}

/// Reset the board when changing the test lawn. The original CutScene pan and SeedChooser are replayed,
/// rather than changing only the backdrop while leaving old rows, camera, plants, zombies, and seed bank behind.
function pvz_lawn_reset_for_environment(_environment) {
    global.pvz_lawn_environment_index = clamp(_environment, 0, 5);
    global.pvz_lawn_active_rows = (global.pvz_lawn_environment_index == 2 || global.pvz_lawn_environment_index == 3) ? 6 : 5;
    global.pvz_lawn_bg_sprite = global.pvz_lawn_bg_sprites[global.pvz_lawn_environment_index];

    with (obj_zombie_base) { pvz_lawn_zombie_cleanup_group(id); instance_destroy(); }
    var _plant_objects = [obj_plant_sunflower, obj_plant_peashooter, obj_plant_cherry_bomb, obj_plant_wallnut, obj_plant_potato_mine, obj_plant_snow_pea, obj_plant_chomper, obj_plant_repeater, obj_plant_lily_pad, obj_plant_flower_pot, obj_plant_cattail, obj_plant_tangle_kelp, obj_plant_sea_shroom, obj_plant_cactus, obj_plant_spikeweed, obj_plant_spikerock, obj_plant_tall_nut, obj_plant_pumpkin];
    for (var _pi = 0; _pi < array_length(_plant_objects); _pi++) with (_plant_objects[_pi]) instance_destroy();
    with (obj_pvz_pea_projectile) instance_destroy();
    with (obj_pvz_boss_projectile) instance_destroy();
    with (obj_pvz_sun_pickup) instance_destroy();
    with (obj_pvz_lawn_fx_piece) instance_destroy();
    with (obj_pvz_lawn_fx_splat) instance_destroy();
    with (obj_pvz_lawn_fx_dirt) instance_destroy();
    with (obj_pvz_lawn_mower) { if (!is_undefined(mower_body)) mower_body.dead = true; instance_destroy(); }

    if (variable_global_exists("pvz_lawn_grid") && ds_exists(global.pvz_lawn_grid, ds_type_grid)) ds_grid_destroy(global.pvz_lawn_grid);
    global.pvz_lawn_grid = ds_grid_create(PVZ_COLS, pvz_lawn_active_rows());
    ds_grid_clear(global.pvz_lawn_grid, noone);
    for (var _row = 0; _row < pvz_lawn_active_rows(); _row++) {
        // Board::LawnMowerInitialize only creates pool cleaners in water rows when the
        // Pool Cleaner purchase is owned. Stage0 has no shop/save purchase state, so don't
        // place ordinary lawn mowers on pool rows as a misleading visual/behavioral substitute.
        if (pvz_lawn_is_pool_row(_row)) continue;
        instance_create_layer(-45, pvz_lawn_row_y(_row, -45, 23), "Instances", obj_pvz_lawn_mower, {row: _row});
    }

    // Restart the original camera/seed-selection timeline and clear the carried seed bank.
    global.pvz_lawn_camera_x = -PVZ_BOARD_OFFSET_X;
    global.pvz_lawn_camera_pan_tick = 0;
    global.pvz_lawn_ready_set_plant_ticks = -1;
    if (!is_undefined(global.pvz_lawn_ready_set_plant_reanim)) global.pvz_lawn_ready_set_plant_reanim.dead = true;
    global.pvz_lawn_seed_chooser_entered = false;
    global.pvz_lawn_seed_chooser_active = false;
    global.pvz_lawn_seed_chooser_completed = false;
    global.pvz_lawn_seed_chooser_panel_y = 720;
    global.pvz_lawn_seed_chooser_selected = [];
    global.pvz_lawn_seed_chooser_frame = 0;
    global.pvz_lawn_seed_chooser_flights = array_create(array_length(global.pvz_lawn_seed_available_kinds), undefined);
    global.pvz_lawn_seed_kinds = [];
    global.pvz_lawn_seed_costs = [];
    global.pvz_lawn_seed_recharges = [];
    global.pvz_lawn_seed_labels = [];
    global.pvz_lawn_seed_tooltip_keys = [];
    global.pvz_lawn_seed_packet_icons = [];
    global.pvz_lawn_seed_ghost_icons = [];
    global.pvz_lawn_seed_cursor_icons = [];
    global.pvz_lawn_seed_packet_refresh = [];
    global.pvz_lawn_seed_packet_flash = [];
    global.pvz_lawn_seed_packet_ready_state = [];
    global.pvz_lawn_selected = "";
    global.pvz_lawn_shovel_selected = false;
    global.pvz_lawn_sun = 150;
    global.pvz_lawn_sun_countdown = 425 + irandom(274);
    global.pvz_lawn_suns_fallen = 0;
    global.pvz_lawn_spawn_wave = 0;
    global.pvz_lawn_spawn_wave_count = 4;
    global.pvz_lawn_spawn_countdown = 1800;
    global.pvz_lawn_lost_state = "";
    global.pvz_lawn_lost_tick = 0;
    global.pvz_lawn_lost_winner = noone;
    global.pvz_lawn_lost_reanim = undefined;
    global.pvz_lawn_message = "Lawn reset to " + global.pvz_lawn_environment_labels[global.pvz_lawn_environment_index] + ". Choose your seeds again.";
    global.pvz_lawn_message_ticks = 240;

    // Place the cutscene's street-preview zombies again so the repeated intro is complete.
    var _taken = array_create(5 * pvz_lawn_active_rows(), false);
    for (var _i = 0; _i < 5; _i++) {
        var _c = irandom(4), _r = irandom(pvz_lawn_active_rows() - 1);
        var _cell = _c * pvz_lawn_active_rows() + _r;
        var _guard = 0;
        while (_taken[_cell] && _guard < 100) {
            _c = irandom(4); _r = irandom(pvz_lawn_active_rows() - 1);
            _cell = _c * pvz_lawn_active_rows() + _r; _guard++;
        }
        _taken[_cell] = true;
        var _sx = PVZ_STREET_ZOMBIE_START_X + _c * PVZ_STREET_ZOMBIE_GRID_X + irandom(14);
        var _sy = PVZ_STREET_ZOMBIE_START_Y + _r * PVZ_STREET_ZOMBIE_GRID_Y + ((_c mod 2) * 30) + irandom(14);
        instance_create_layer(_sx, _sy, "Instances", obj_zombie_basic, {row: _r, intro_preview: true});
    }
}


/// Console diagnostics for Snow Pea projectile -> chill timer -> zombie draw.
/// Enabled by default in this troubleshooting build; set global.pvz_snowpea_debug_enabled = false to silence.
function pvz_lawn_snowpea_debug(_message) {
    if (!variable_global_exists("pvz_snowpea_debug_enabled")) global.pvz_snowpea_debug_enabled = true;
    if (global.pvz_snowpea_debug_enabled) show_debug_message("[SNOWPEA DEBUG] " + string(_message));
}

function pvz_lawn_load_strings() {
    if (variable_global_exists("pvz_lawn_strings") && ds_exists(global.pvz_lawn_strings, ds_type_map)) {
        ds_map_destroy(global.pvz_lawn_strings);
    }
    global.pvz_lawn_strings = ds_map_create();

    // In the editor this is the project's datafiles folder; the install helper replaces
    // the bundled minimal set with the complete original LawnStrings.txt from Dropbox.
    var _strings_path = working_directory + "datafiles/LawnStrings.txt";
    if (!file_exists(_strings_path)) _strings_path = working_directory + "LawnStrings.txt";
    if (file_exists(_strings_path)) {
        var _f = file_text_open_read(_strings_path);
        var _key = "";
        while (!file_text_eof(_f)) {
            var _line = string_trim(file_text_readln(_f));
            var _line_len = string_length(_line);
            if (_line_len >= 3 && string_char_at(_line, 1) == "[" && string_char_at(_line, _line_len) == "]") {
                _key = string_upper(string_copy(_line, 2, _line_len - 2));
            } else if (_key != "" && _line != "") {
                // ToolTipWidget consumes the first line of a normal (single-line) LawnString.
                if (!ds_map_exists(global.pvz_lawn_strings, _key)) ds_map_add(global.pvz_lawn_strings, _key, _line);
                _key = "";
            }
        }
        file_text_close(_f);
    }

    // Safe fallback values match the exact source file entries if included-file access is unavailable.
    if (!ds_map_exists(global.pvz_lawn_strings, "PEASHOOTER")) ds_map_add(global.pvz_lawn_strings, "PEASHOOTER", "Peashooter");
    if (!ds_map_exists(global.pvz_lawn_strings, "SUNFLOWER")) ds_map_add(global.pvz_lawn_strings, "SUNFLOWER", "Sunflower");
    if (!ds_map_exists(global.pvz_lawn_strings, "CHERRY_BOMB")) ds_map_add(global.pvz_lawn_strings, "CHERRY_BOMB", "Cherry Bomb");
    if (!ds_map_exists(global.pvz_lawn_strings, "WALL_NUT")) ds_map_add(global.pvz_lawn_strings, "WALL_NUT", "Wall-nut");
    if (!ds_map_exists(global.pvz_lawn_strings, "POTATO_MINE")) ds_map_add(global.pvz_lawn_strings, "POTATO_MINE", "Potato Mine");
    if (!ds_map_exists(global.pvz_lawn_strings, "SNOW_PEA")) ds_map_add(global.pvz_lawn_strings, "SNOW_PEA", "Snow Pea");
    if (!ds_map_exists(global.pvz_lawn_strings, "CHOMPER")) ds_map_add(global.pvz_lawn_strings, "CHOMPER", "Chomper");
    if (!ds_map_exists(global.pvz_lawn_strings, "REPEATER")) ds_map_add(global.pvz_lawn_strings, "REPEATER", "Repeater");
    if (!ds_map_exists(global.pvz_lawn_strings, "LILY_PAD")) ds_map_add(global.pvz_lawn_strings, "LILY_PAD", "Lily Pad");
    if (!ds_map_exists(global.pvz_lawn_strings, "FLOWER_POT")) ds_map_add(global.pvz_lawn_strings, "FLOWER_POT", "Flower Pot");
    if (!ds_map_exists(global.pvz_lawn_strings, "WAITING_FOR_SEED")) ds_map_add(global.pvz_lawn_strings, "WAITING_FOR_SEED", "recharging...");
    if (!ds_map_exists(global.pvz_lawn_strings, "NOT_ENOUGH_SUN")) ds_map_add(global.pvz_lawn_strings, "NOT_ENOUGH_SUN", "not enough sun");
}

function pvz_lawn_string(_key, _fallback = "") {
    if (variable_global_exists("pvz_lawn_strings") && ds_exists(global.pvz_lawn_strings, ds_type_map)) {
        var _upper_key = string_upper(_key);
        if (ds_map_exists(global.pvz_lawn_strings, _upper_key)) return ds_map_find_value(global.pvz_lawn_strings, _upper_key);
    }
    return _fallback;
}

function pvz_lawn_seed_index(_kind) {
    if (!variable_global_exists("pvz_lawn_seed_kinds")) return -1;
    for (var _i = 0; _i < array_length(global.pvz_lawn_seed_kinds); _i++) {
        if (global.pvz_lawn_seed_kinds[_i] == _kind) return _i;
    }
    return -1;
}

function pvz_lawn_seedchooser_available_index(_kind) {
    if (!variable_global_exists("pvz_lawn_seed_available_kinds")) return -1;
    for (var _i = 0; _i < array_length(global.pvz_lawn_seed_available_kinds); _i++) {
        if (global.pvz_lawn_seed_available_kinds[_i] == _kind) return _i;
    }
    return -1;
}

function pvz_lawn_seedchooser_flight_value(_flight, _age, _axis) {
    var _duration = max(1, _flight.duration);
    var _t = clamp((_age - _flight.start_age) / _duration, 0, 1);
    // SeedChooserScreen animates packet transfers with a short smooth ease, not an instantaneous snap.
    _t = _t * _t * (3 - 2 * _t);
    if (_axis == 0) return lerp(_flight.from_x, _flight.to_x, _t);
    return lerp(_flight.from_y, _flight.to_y, _t);
}

/// SeedChooserScreen::OnStartButton + CloseSeedChooser: install the user's chosen packets
/// into the active seed bank, while keeping the unselected Stage0 plants available in the chooser.
function pvz_lawn_seedchooser_commit() {
    var _count = array_length(global.pvz_lawn_seed_chooser_selected);
    if (_count != PVZ_SEED_CHOOSER_REQUIRED) return false;

    var _kinds = array_create(_count, "");
    var _costs = array_create(_count, 0);
    var _recharges = array_create(_count, 0);
    var _labels = array_create(_count, "");
    var _tips = array_create(_count, "");
    var _packet_icons = array_create(_count, undefined);
    var _ghost_icons = array_create(_count, undefined);
    var _cursor_icons = array_create(_count, undefined);

    for (var _i = 0; _i < _count; _i++) {
        var _kind = global.pvz_lawn_seed_chooser_selected[_i];
        _kinds[_i] = _kind;
        var _available_i = -1;
        for (var _j = 0; _j < array_length(global.pvz_lawn_seed_available_kinds); _j++) {
            if (global.pvz_lawn_seed_available_kinds[_j] == _kind) { _available_i = _j; break; }
        }
        if (_available_i < 0) continue;
        _costs[_i] = global.pvz_lawn_seed_available_costs[_available_i];
        _recharges[_i] = global.pvz_lawn_seed_available_recharges[_available_i];
        _labels[_i] = global.pvz_lawn_seed_available_labels[_available_i];
        _tips[_i] = global.pvz_lawn_seed_available_tooltip_keys[_available_i];
        _packet_icons[_i] = global.pvz_lawn_seed_chooser_icons[_available_i];
        _ghost_icons[_i] = pvz_lawn_create_plant_ui_icon(_kind);
        _cursor_icons[_i] = pvz_lawn_create_plant_ui_icon(_kind);
    }

    global.pvz_lawn_seed_kinds = _kinds;
    global.pvz_lawn_seed_costs = _costs;
    global.pvz_lawn_seed_recharges = _recharges;
    global.pvz_lawn_seed_labels = _labels;
    global.pvz_lawn_seed_tooltip_keys = _tips;
    global.pvz_lawn_seed_packet_icons = _packet_icons;
    global.pvz_lawn_seed_ghost_icons = _ghost_icons;
    global.pvz_lawn_seed_cursor_icons = _cursor_icons;
    // Level-start packets for these three plants begin a normal recharge, matching the first-game source setup.
    global.pvz_lawn_seed_packet_refresh = array_create(_count, 0);
    global.pvz_lawn_seed_packet_flash = array_create(_count, 0);
    global.pvz_lawn_seed_packet_ready_state = array_create(_count, true);
    for (var _recharge_i = 0; _recharge_i < _count; _recharge_i++) {
        var _recharge_kind = _kinds[_recharge_i];
        if (_recharge_kind == "cherry_bomb" || _recharge_kind == "wallnut" || _recharge_kind == "potato_mine") {
            global.pvz_lawn_seed_packet_refresh[_recharge_i] = _recharges[_recharge_i];
            global.pvz_lawn_seed_packet_ready_state[_recharge_i] = false;
        }
    }
    global.pvz_lawn_selected = "";
    global.pvz_lawn_shovel_selected = false;
    return true;
}

/// CutScene::PlaceAZombie uses the original PC preview-zombie grid coordinates from Lawn/CutScene.cpp.
/// SeedChooserScreen::ShowToolTip finds a hovered street-preview zombie without advancing gameplay.
function pvz_lawn_seedchooser_hovered_preview_zombie() {
    if (!global.pvz_lawn_seed_chooser_active) return undefined;
    var _types = [obj_zombie_basic, obj_zombie_conehead, obj_zombie_buckethead, obj_zombie_polevaulter];
    var _keys = ["ZOMBIE", "CONEHEAD_ZOMBIE", "BUCKETHEAD_ZOMBIE", "POLE_VAULTING_ZOMBIE"];
    var _fallbacks = ["Zombie", "Conehead Zombie", "Buckethead Zombie", "Pole Vaulting Zombie"];
    var _world_mouse_x = mouse_x + global.pvz_lawn_camera_x;
    for (var _type_i = 0; _type_i < array_length(_types); _type_i++) {
        var _instances = instance_number(_types[_type_i]);
        for (var _z_i = 0; _z_i < _instances; _z_i++) {
            var _zid = instance_find(_types[_type_i], _z_i);
            if (_zid == noone || !instance_exists(_zid)) continue;
            if (!variable_instance_exists(_zid, "intro_preview") || !_zid.intro_preview || _zid.dead) continue;
            var _left = _zid.x + (_zid.zombie_kind == "polevaulter" ? 50 : 36);
            var _right = _zid.x + 78;
            if (_world_mouse_x < _left || _world_mouse_x >= _right || mouse_y < _zid.y || mouse_y >= _zid.y + 115) continue;
            return {
                key: _keys[_type_i],
                title: pvz_lawn_string(_keys[_type_i], _fallbacks[_type_i]),
                center_x: _zid.x - global.pvz_lawn_camera_x + 62,
                top_y: _zid.y + 105
            };
        }
    }
    return undefined;
}

/// Draw the real SeedPacketSilhouette when installed; otherwise keep a visible slot fallback.
function pvz_lawn_seedchooser_draw_silhouette(_x, _y) {
    if (global.pvz_seed_packet_silhouette_sprite >= 0) {
        draw_sprite(global.pvz_seed_packet_silhouette_sprite, 0, _x, _y);
    } else {
        draw_set_color(make_color_rgb(70, 75, 59));
        draw_rectangle(_x, _y, _x + 50, _y + 70, false);
        draw_set_color(make_color_rgb(122, 126, 104));
        draw_rectangle(_x, _y, _x + 50, _y + 70, true);
        draw_set_color(c_white);
    }
}

/// ToolTipWidget-style pale yellow popup using the original BrianneTod12 atlas at a smaller scale.
function pvz_lawn_seedchooser_draw_tooltip(_center_x, _top_y, _title, _body = "") {
    var _title_font = "BrianneTod12";
    var _body_font = "BrianneTod12";
    var _title_scale = 0.58;
    var _body_scale = 0.52;
    var _max_body_width = 205;
    var _title_info = pvz_lawn_native_font_info(_title_font);
    var _body_info = pvz_lawn_native_font_info(_body_font);
    var _title_line_h = _title_info.glyph_height * _title_scale;
    var _body_line_h = _body_info.glyph_height * _body_scale + 1;
    var _lines = [];
    if (_body != "") {
        var _words = string_split(_body, " ");
        var _line = "";
        for (var _word_i = 0; _word_i < array_length(_words); _word_i++) {
            var _word = _words[_word_i];
            var _candidate = _line == "" ? _word : _line + " " + _word;
            if (_line != "" && pvz_lawn_native_font_text_width(_body_font, _candidate, _body_scale) > _max_body_width) {
                array_push(_lines, _line);
                _line = _word;
            } else {
                _line = _candidate;
            }
        }
        if (_line != "") array_push(_lines, _line);
    }
    var _title_w = pvz_lawn_native_font_text_width(_title_font, _title, _title_scale);
    var _line_w = 0;
    for (var _line_i = 0; _line_i < array_length(_lines); _line_i++) {
        _line_w = max(_line_w, pvz_lawn_native_font_text_width(_body_font, _lines[_line_i], _body_scale));
    }
    var _box_w = ceil(max(_title_w, _line_w)) + 22;
    var _box_h = ceil(8 + _title_line_h + array_length(_lines) * _body_line_h + 8);
    var _box_x = clamp(_center_x - _box_w * 0.5, 0, room_width - _box_w);
    var _box_y = clamp(_top_y, 0, room_height - _box_h);
    draw_set_alpha(1);
    draw_set_color(make_color_rgb(255, 255, 200));
    draw_rectangle(_box_x, _box_y, _box_x + _box_w, _box_y + _box_h, false);
    draw_set_color(c_black);
    draw_rectangle(_box_x, _box_y, _box_x + _box_w, _box_y + _box_h, true);
    draw_set_halign(fa_center); draw_set_valign(fa_top); draw_set_color(c_black);
    pvz_lawn_draw_text_native(_box_x + _box_w * 0.5, _box_y + 4, _title, _title_font, _title_scale);
    for (var _draw_line_i = 0; _draw_line_i < array_length(_lines); _draw_line_i++) {
        pvz_lawn_draw_text_native(_box_x + _box_w * 0.5,
            _box_y + 4 + _title_line_h + _draw_line_i * _body_line_h, _lines[_draw_line_i], _body_font, _body_scale);
    }
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_set_alpha(1);
}

/// SeedChooserScreen::Draw, including original packet silhouettes behind all 40 slots (5 rows).
function pvz_lawn_draw_seed_chooser() {
    var _panel_y = global.pvz_lawn_seed_chooser_panel_y;
    var _panel_top = 87 + _panel_y;
    var _bg = global.pvz_seed_chooser_background_sprite;
    if (_bg >= 0) {
        draw_sprite(_bg, 0, 0, _panel_top);
    } else {
        draw_set_alpha(0.96);
        draw_set_color(make_color_rgb(74, 101, 54));
        draw_rectangle(0, _panel_top, 465, _panel_top + 513, false);
        draw_set_color(make_color_rgb(208, 185, 130));
        draw_rectangle(4, _panel_top + 4, 461, _panel_top + 509, false);
        draw_set_color(make_color_rgb(237, 220, 170));
        draw_rectangle(9, _panel_top + 9, 456, _panel_top + 504, false);
        draw_set_color(make_color_rgb(92, 111, 57));
        draw_rectangle(9, _panel_top + 9, 456, _panel_top + 39, false);
        draw_set_alpha(1);
    }

    // CutScene.cpp starts the seed-bank and chooser entrances together at 4000ms; the bank falls from above.
    var _bank_y = 0;
    // CutScene.cpp uses `mCutsceneTime > TimeSeedBankOnStart`, so the bank stays at y=0
    // through the chooser's exact start tick; on the next cutscene tick it enters from above.
    if (!global.pvz_lawn_seed_chooser_completed && global.pvz_lawn_camera_pan_tick > PVZ_SEED_BANK_SLIDE_ON_START) {
        _bank_y = lerp(-87, 0, clamp((global.pvz_lawn_camera_pan_tick - PVZ_SEED_BANK_SLIDE_ON_START)
            / (PVZ_SEED_CHOOSER_SLIDE_ON_END - PVZ_SEED_BANK_SLIDE_ON_START), 0, 1));
    }
    if (global.pvz_seedbank_sprite >= 0) draw_sprite(global.pvz_seedbank_sprite, 0, 0, _bank_y);
    else {
        draw_set_color(make_color_rgb(45, 75, 43));
        draw_rectangle(0, _bank_y, 446, _bank_y + 87, false);
    }
    // SeedBank::Draw uses ContinuumBold14 at (34, 78). The original GIF atlas loads when supplied;
    // this project includes its metric table, so the native-font helper falls back to another PvZ atlas if missing.
    var _seedchooser_sun_color = c_black;
    draw_set_color(_seedchooser_sun_color);
    draw_set_halign(fa_center); draw_set_valign(fa_top);
    pvz_lawn_draw_text_native(34, _bank_y + 64, string(max(global.pvz_lawn_sun, 0)), "ContinuumBold14", 1.0);
    draw_set_halign(fa_left); draw_set_valign(fa_top); draw_set_color(c_white);

    var _selected_count = array_length(global.pvz_lawn_seed_chooser_selected);

    // Keep the six silhouettes behind packet art, including slots already covered by a selected plant.
    for (var _bank_slot_i = 0; _bank_slot_i < PVZ_SEED_CHOOSER_REQUIRED; _bank_slot_i++) {
        pvz_lawn_seedchooser_draw_silhouette(PVZ_SEED_BANK_PACKET_X + _bank_slot_i * PVZ_SEED_BANK_PACKET_STEP, 8 + _bank_y);
    }

    // SeedChooserScreen::Draw uses silhouettes in locked slots and underneath every available seed packet.
    // The PC chooser inventory has five rows of eight slots (40 silhouette positions).
    for (var _slot_i = 0; _slot_i < PVZ_SEED_CHOOSER_GRID_COLS * PVZ_SEED_CHOOSER_GRID_ROWS; _slot_i++) {
        var _slot_x = PVZ_SEED_CHOOSER_GRID_X + (_slot_i mod PVZ_SEED_CHOOSER_GRID_COLS) * PVZ_SEED_CHOOSER_GRID_STEP_X;
        var _slot_y = PVZ_SEED_CHOOSER_GRID_Y + floor(_slot_i / PVZ_SEED_CHOOSER_GRID_COLS) * PVZ_SEED_CHOOSER_GRID_STEP_Y + _panel_y;
        pvz_lawn_seedchooser_draw_silhouette(_slot_x, _slot_y);
    }

    // Draw the available plants above the silhouettes; selected source slots stay visibly darkened.
    for (var _candidate_i = 0; _candidate_i < array_length(global.pvz_lawn_seed_available_kinds); _candidate_i++) {
        var _candidate_kind = global.pvz_lawn_seed_available_kinds[_candidate_i];
        var _candidate_x = PVZ_SEED_CHOOSER_GRID_X + (_candidate_i mod PVZ_SEED_CHOOSER_GRID_COLS) * PVZ_SEED_CHOOSER_GRID_STEP_X;
        var _candidate_y = PVZ_SEED_CHOOSER_GRID_Y + floor(_candidate_i / PVZ_SEED_CHOOSER_GRID_COLS) * PVZ_SEED_CHOOSER_GRID_STEP_Y + _panel_y;
        var _already_chosen = false;
        for (var _chosen_i = 0; _chosen_i < _selected_count; _chosen_i++) {
            if (global.pvz_lawn_seed_chooser_selected[_chosen_i] == _candidate_kind) { _already_chosen = true; break; }
        }
        // The silhouette was drawn first; now draw the real packet, plant icon, and source Pico129 cost above it.
        if (global.pvz_seeds_atlas >= 0) {
            draw_sprite_part_ext(global.pvz_seeds_atlas, 0, 100, 0, 50, 70,
                _candidate_x, _candidate_y, 1, 1, c_white, 1);
        } else {
            draw_set_color(make_color_rgb(227, 210, 156));
            draw_rectangle(_candidate_x, _candidate_y, _candidate_x + 50, _candidate_y + 70, false);
            draw_set_color(c_white);
        }
        pvz_lawn_draw_plant_ui_icon(global.pvz_lawn_seed_chooser_icons[_candidate_i], _candidate_x + 5,
            _candidate_y + 8, 0.5, 1.0);
        draw_set_color(c_black);
        var _candidate_cost = string(global.pvz_lawn_seed_available_costs[_candidate_i]);
        var _candidate_cost_x = _candidate_x + 32 - pvz_lawn_native_font_text_width("Pico129", _candidate_cost, 1.0);
        draw_set_halign(fa_left); draw_set_valign(fa_top);
        pvz_lawn_draw_text_native(_candidate_cost_x, _candidate_y + 54, _candidate_cost, "Pico129", 1.0);
        draw_set_color(c_white);
        if (_already_chosen) {
            draw_set_alpha(200 / 255.0);
            draw_set_color(c_black);
            draw_rectangle(_candidate_x, _candidate_y, _candidate_x + 50, _candidate_y + 70, false);
            draw_set_alpha(1);
            draw_set_color(c_white);
        }
    }

    // Draw the six seed-bank packets. Silhouettes were drawn first and remain underneath all six slots.
    var _flight_active = false;
    for (var _selected_i = 0; _selected_i < _selected_count; _selected_i++) {
        var _selected_kind = global.pvz_lawn_seed_chooser_selected[_selected_i];
        var _source_i = pvz_lawn_seedchooser_available_index(_selected_kind);
        var _target_x = PVZ_SEED_BANK_PACKET_X + _selected_i * PVZ_SEED_BANK_PACKET_STEP;
        var _packet_x = _target_x;
        var _packet_y = 8 + _bank_y;
        var _flight = undefined;
        if (_source_i >= 0 && variable_global_exists("pvz_lawn_seed_chooser_flights")) {
            _flight = global.pvz_lawn_seed_chooser_flights[_source_i];
        }
        var _in_flight = !is_undefined(_flight) && global.pvz_lawn_seed_chooser_frame - _flight.start_age < _flight.duration;
        if (_in_flight) {
            _flight_active = true;
            _packet_x = pvz_lawn_seedchooser_flight_value(_flight, global.pvz_lawn_seed_chooser_frame, 0);
            _packet_y = pvz_lawn_seedchooser_flight_value(_flight, global.pvz_lawn_seed_chooser_frame, 1);
        }
        // Keep the selected packet above the silhouette; do not draw the silhouette over the original packet art.
        if (global.pvz_seeds_atlas >= 0) {
            draw_sprite_part_ext(global.pvz_seeds_atlas, 0, 100, 0, 50, 70, _packet_x, _packet_y, 1, 1, c_white, 1);
        }
        if (_source_i >= 0) {
            pvz_lawn_draw_plant_ui_icon(global.pvz_lawn_seed_chooser_icons[_source_i], _packet_x + 5, _packet_y + 8, 0.5, 1.0);
            draw_set_color(c_black);
            var _bank_cost = string(global.pvz_lawn_seed_available_costs[_source_i]);
            var _bank_cost_x = _packet_x + 32 - pvz_lawn_native_font_text_width("Pico129", _bank_cost, 1.0);
            draw_set_halign(fa_left); draw_set_valign(fa_top);
            pvz_lawn_draw_text_native(_bank_cost_x, _packet_y + 54, _bank_cost, "Pico129", 1.0);
            draw_set_color(c_white);
        }
    }
    if (!_flight_active) {
        for (var _flight_scan_i = 0; _flight_scan_i < array_length(global.pvz_lawn_seed_chooser_flights); _flight_scan_i++) {
            var _flight_scan = global.pvz_lawn_seed_chooser_flights[_flight_scan_i];
            if (!is_undefined(_flight_scan) && global.pvz_lawn_seed_chooser_frame - _flight_scan.start_age < _flight_scan.duration) {
                _flight_active = true;
                break;
            }
        }
    }

    draw_set_halign(fa_center); draw_set_valign(fa_top);
    var _chooser_title = pvz_lawn_string("CHOOSE_YOUR_PLANTS", "CHOOSE YOUR PLANTS!");
    var _chooser_yellow_font = pvz_lawn_native_font_info("DwarvenTodcraft18Yellow");
    if (_chooser_yellow_font.sprite >= 0) {
        // The original Yellow atlas already contains the gold glyphs, so draw it with a neutral tint.
        draw_set_color(c_white);
        pvz_lawn_draw_text_native(229, 96 + _panel_y, _chooser_title, "DwarvenTodcraft18Yellow", 1.12);
    } else {
        // Gold tint fallback prevents the heading from becoming white if the Yellow atlas is missing.
        draw_set_color(make_color_rgb(213, 159, 43));
        pvz_lawn_draw_text_native(229, 96 + _panel_y, _chooser_title, "DwarvenTodcraft18", 1.12);
    }
    draw_set_halign(fa_left); draw_set_valign(fa_top); draw_set_color(c_white);

    var _start_x = 154;
    var _start_y = 545 + _panel_y;
    var _start_hover = global.pvz_lawn_seed_chooser_active && _selected_count == PVZ_SEED_CHOOSER_REQUIRED
        && point_in_rectangle(mouse_x, mouse_y, _start_x, _start_y, _start_x + 156, _start_y + 42);
    if (_start_hover && global.pvz_seed_chooser_button_glow_sprite >= 0) {
        draw_sprite(global.pvz_seed_chooser_button_glow_sprite, 0, _start_x, _start_y);
    }
    if (_selected_count == PVZ_SEED_CHOOSER_REQUIRED) {
        if (global.pvz_seed_chooser_button_sprite >= 0) draw_sprite(global.pvz_seed_chooser_button_sprite, 0, _start_x, _start_y);
    } else if (variable_global_exists("pvz_seed_chooser_button_disabled_sprite") && global.pvz_seed_chooser_button_disabled_sprite >= 0) {
        draw_sprite(global.pvz_seed_chooser_button_disabled_sprite, 0, _start_x, _start_y);
    } else if (global.pvz_seed_chooser_button_sprite >= 0) {
        draw_sprite_ext(global.pvz_seed_chooser_button_sprite, 0, _start_x, _start_y, 1, 1, 0, make_color_rgb(135, 135, 135), 0.85);
    } else {
        draw_set_color(make_color_rgb(100, 100, 100));
        draw_rectangle(_start_x, _start_y, _start_x + 156, _start_y + 42, false);
        draw_set_color(c_white);
    }
    draw_set_color(c_white); draw_set_halign(fa_center); draw_set_valign(fa_middle);
    pvz_lawn_draw_text_native(_start_x + 78, _start_y + 20, pvz_lawn_string("PLAY_BUTTON", "LET'S ROCK"), "DwarvenTodcraft15", 0.92);
    draw_set_halign(fa_left); draw_set_valign(fa_top); draw_set_color(c_white); draw_set_alpha(1);

    // Original ShowToolTip checks preview zombies before seed packets.
    if (global.pvz_lawn_seed_chooser_active) {
        var _hover_zombie = pvz_lawn_seedchooser_hovered_preview_zombie();
        if (!is_undefined(_hover_zombie)) {
            pvz_lawn_seedchooser_draw_tooltip(_hover_zombie.center_x, _hover_zombie.top_y, _hover_zombie.title, "");
        } else if (!_flight_active) {
            var _hover_seed_key = "";
            var _hover_seed_name = "";
            var _hover_seed_desc = "";
            var _hover_seed_center = -1;
            var _hover_seed_top = -1;
            // Hover over each real chooser packet, including packets whose source is darkened after selection.
            for (var _hover_i = 0; _hover_i < array_length(global.pvz_lawn_seed_available_kinds); _hover_i++) {
                var _hover_x = PVZ_SEED_CHOOSER_GRID_X + (_hover_i mod PVZ_SEED_CHOOSER_GRID_COLS) * PVZ_SEED_CHOOSER_GRID_STEP_X;
                var _hover_y = PVZ_SEED_CHOOSER_GRID_Y + floor(_hover_i / PVZ_SEED_CHOOSER_GRID_COLS) * PVZ_SEED_CHOOSER_GRID_STEP_Y + _panel_y;
                if (point_in_rectangle(mouse_x, mouse_y, _hover_x, _hover_y, _hover_x + 50, _hover_y + 70)) {
                    _hover_seed_key = global.pvz_lawn_seed_available_tooltip_keys[_hover_i];
                    _hover_seed_name = pvz_lawn_string(_hover_seed_key, global.pvz_lawn_seed_available_labels[_hover_i]);
                    _hover_seed_desc = pvz_lawn_string(_hover_seed_key + "_TOOLTIP", "");
                    _hover_seed_center = _hover_x + 25;
                    _hover_seed_top = _hover_y + 70;
                    break;
                }
            }
            // The bank packets can be in flight or compacting, so hit-test their current animated position.
            if (_hover_seed_center < 0) {
                for (var _hover_bank_i = 0; _hover_bank_i < _selected_count; _hover_bank_i++) {
                    var _hover_kind = global.pvz_lawn_seed_chooser_selected[_hover_bank_i];
                    var _hover_src = pvz_lawn_seedchooser_available_index(_hover_kind);
                    if (_hover_src < 0) continue;
                    var _hover_bank_x = PVZ_SEED_BANK_PACKET_X + _hover_bank_i * PVZ_SEED_BANK_PACKET_STEP;
                    var _hover_bank_y = 8 + _bank_y;
                    var _hover_flight = global.pvz_lawn_seed_chooser_flights[_hover_src];
                    if (!is_undefined(_hover_flight) && global.pvz_lawn_seed_chooser_frame - _hover_flight.start_age < _hover_flight.duration) {
                        _hover_bank_x = pvz_lawn_seedchooser_flight_value(_hover_flight, global.pvz_lawn_seed_chooser_frame, 0);
                        _hover_bank_y = pvz_lawn_seedchooser_flight_value(_hover_flight, global.pvz_lawn_seed_chooser_frame, 1);
                    }
                    if (point_in_rectangle(mouse_x, mouse_y, _hover_bank_x, _hover_bank_y, _hover_bank_x + 50, _hover_bank_y + 70)) {
                        _hover_seed_src = _hover_src;
                        _hover_seed_key = global.pvz_lawn_seed_available_tooltip_keys[_hover_src];
                        _hover_seed_name = pvz_lawn_string(_hover_seed_key, global.pvz_lawn_seed_available_labels[_hover_src]);
                        _hover_seed_desc = pvz_lawn_string(_hover_seed_key + "_TOOLTIP", "");
                        _hover_seed_center = _hover_bank_x + 25;
                        _hover_seed_top = _hover_bank_y + 70;
                        break;
                    }
                }
            }
            if (_hover_seed_center >= 0 && _hover_seed_name != "") {
                pvz_lawn_seedchooser_draw_tooltip(_hover_seed_center, _hover_seed_top, _hover_seed_name, _hover_seed_desc);
            }
        }
    }

    // SeedChooserScreen::mMenuButton remains visible in the chooser and moves from y=-50 to y=-10.
    var _menu_enter_t = clamp((global.pvz_lawn_camera_pan_tick - PVZ_SEED_CHOOSER_SLIDE_ON_START)
        / (PVZ_SEED_CHOOSER_SLIDE_ON_END - PVZ_SEED_CHOOSER_SLIDE_ON_START), 0, 1);
    var _menu_y = lerp(-50, -10, _menu_enter_t);
    if (global.pvz_lawn_seed_chooser_completed) {
        var _menu_exit_t = clamp((global.pvz_lawn_camera_pan_tick - PVZ_SEED_CHOOSER_SLIDE_OFF_START)
            / (PVZ_SEED_CHOOSER_SLIDE_OFF_END - PVZ_SEED_CHOOSER_SLIDE_OFF_START), 0, 1);
        _menu_y = lerp(-10, -50, _menu_exit_t);
    }
    var _menu_hover = !global.pvz_lawn_menu_open && point_in_rectangle(mouse_x, mouse_y, 681, _menu_y, 798, _menu_y + 46);
    pvz_lawn_draw_stone_button(681, _menu_y, 117, 46, pvz_lawn_string("MENU_BUTTON", "MENU"),
        _menu_hover, _menu_hover && mouse_check_button(mb_left));
    if (global.pvz_lawn_menu_open) pvz_lawn_draw_options_overlay();
    draw_set_color(c_white); draw_set_alpha(1); draw_set_halign(fa_left); draw_set_valign(fa_top);
}

function pvz_lawn_draw_options_overlay() {
    draw_set_alpha(0.58);
    draw_set_color(c_black);
    draw_rectangle(0, 0, room_width, room_height, false);
    draw_set_alpha(1);
    var _opt_bg = global.pvz_lawn_options_bg_sprite;
    var _opt_w = _opt_bg >= 0 ? sprite_get_width(_opt_bg) : 423;
    var _opt_h = _opt_bg >= 0 ? sprite_get_height(_opt_bg) : 498;
    var _ox = floor((room_width - _opt_w) * 0.5);
    var _oy = floor((room_height - _opt_h) * 0.5);
    if (_opt_bg >= 0) draw_sprite(_opt_bg, 0, _ox, _oy);

    // NewOptionsDialog text uses PvZ bitmap fonts, not GameMaker's default font.
    draw_set_color(make_color_rgb(107, 109, 145));
    draw_set_halign(fa_right); draw_set_valign(fa_middle);
    pvz_lawn_draw_text_native(_ox + 186, _oy + 145, pvz_lawn_string("OPTIONS_MUSIC", "Music"), "DwarvenTodcraft12", 0.85);
    pvz_lawn_draw_text_native(_ox + 186, _oy + 177, pvz_lawn_string("OPTIONS_SOUND", "Sound"), "DwarvenTodcraft12", 0.85);
    pvz_lawn_draw_text_native(_ox + 274, _oy + 212, pvz_lawn_string("OPTIONS_ACCELERATION", "3D Acceleration"), "DwarvenTodcraft12", 0.85);
    pvz_lawn_draw_text_native(_ox + 274, _oy + 248, pvz_lawn_string("OPTIONS_FULLSCREEN", "Fullscreen"), "DwarvenTodcraft12", 0.85);
    if (global.pvz_lawn_options_slider_sprite >= 0) {
        draw_sprite(global.pvz_lawn_options_slider_sprite, 0, _ox + 199, _oy + 121);
        draw_sprite(global.pvz_lawn_options_slider_sprite, 0, _ox + 199, _oy + 153);
    }
    if (global.pvz_lawn_options_knob_sprite >= 0) {
        var _kw = sprite_get_width(global.pvz_lawn_options_knob_sprite);
        var _kh = sprite_get_height(global.pvz_lawn_options_knob_sprite);
        var _music_kx = _ox + 207 + global.pvz_lawn_music_volume * max(0, 135 - _kw - 16);
        var _sfx_kx = _ox + 207 + global.pvz_lawn_sfx_volume * max(0, 135 - _kw - 16);
        draw_sprite(global.pvz_lawn_options_knob_sprite, 0, _music_kx, _oy + 121 + (40 - _kh) * 0.5);
        draw_sprite(global.pvz_lawn_options_knob_sprite, 0, _sfx_kx, _oy + 153 + (40 - _kh) * 0.5);
    }
    draw_set_halign(fa_left);
    draw_set_color(make_color_rgb(107, 109, 145));
    pvz_lawn_draw_text_native(_ox + 342, _oy + 148, string(round(global.pvz_lawn_music_volume * 100)), "DwarvenTodcraft12", 0.85);
    pvz_lawn_draw_text_native(_ox + 342, _oy + 180, string(round(global.pvz_lawn_sfx_volume * 100)), "DwarvenTodcraft12", 0.85);
    if (global.pvz_lawn_options_check_off_sprite >= 0 && global.pvz_lawn_options_check_on_sprite >= 0) {
        draw_sprite(global.pvz_lawn_accel_enabled ? global.pvz_lawn_options_check_on_sprite : global.pvz_lawn_options_check_off_sprite, 0, _ox + 284, _oy + 190);
        draw_sprite(global.pvz_lawn_fullscreen_enabled ? global.pvz_lawn_options_check_on_sprite : global.pvz_lawn_options_check_off_sprite, 0, _ox + 284, _oy + 226);
    }
    var _almanac_hover = point_in_rectangle(mouse_x, mouse_y, _ox + 107, _oy + 241, _ox + 316, _oy + 287);
    var _restart_hover = point_in_rectangle(mouse_x, mouse_y, _ox + 107, _oy + 284, _ox + 316, _oy + 330);
    var _main_hover = point_in_rectangle(mouse_x, mouse_y, _ox + 107, _oy + 327, _ox + 316, _oy + 373);
    pvz_lawn_draw_stone_button(_ox + 107, _oy + 241, 209, 46, pvz_lawn_string("VIEW_ALMANAC_BUTTON", "View Almanac"), _almanac_hover, _almanac_hover && mouse_check_button(mb_left));
    pvz_lawn_draw_stone_button(_ox + 107, _oy + 284, 209, 46, pvz_lawn_string("RESTART_LEVEL_BUTTON", "Restart Level"), _restart_hover, _restart_hover && mouse_check_button(mb_left));
    pvz_lawn_draw_stone_button(_ox + 107, _oy + 327, 209, 46, pvz_lawn_string("MAIN_MENU_BUTTON", "Main Menu"), _main_hover, _main_hover && mouse_check_button(mb_left));
    var _back_w = global.pvz_lawn_options_back_sprite >= 0 ? sprite_get_width(global.pvz_lawn_options_back_sprite) : 360;
    var _back_h = global.pvz_lawn_options_back_sprite >= 0 ? sprite_get_height(global.pvz_lawn_options_back_sprite) : 100;
    var _back_hover = point_in_rectangle(mouse_x, mouse_y, _ox + 30, _oy + 381, _ox + 30 + _back_w, _oy + 381 + _back_h);
    var _back_art = (_back_hover && mouse_check_button(mb_left) && global.pvz_lawn_options_back_down_sprite >= 0) ? global.pvz_lawn_options_back_down_sprite : global.pvz_lawn_options_back_sprite;
    if (_back_art >= 0) draw_sprite(_back_art, 0, _ox + 30, _oy + 381);
    draw_set_color(c_white); draw_set_halign(fa_center); draw_set_valign(fa_middle);
    pvz_lawn_draw_text_native(_ox + 30 + _back_w * 0.5, _oy + 381 + _back_h * 0.5 - 4,
        pvz_lawn_string("BACK_TO_GAME", "Back to Game"), "DwarvenTodcraft15", 0.90);
    draw_set_halign(fa_left); draw_set_valign(fa_top); draw_set_color(c_white); draw_set_alpha(1);
}

function pvz_lawn_plant_reanim_name(_kind) {
    switch (_kind) {
        case "sunflower": return "SunFlower";
        case "peashooter": return "PeaShooterSingle";
        case "cherry_bomb": return "CherryBomb";
        case "wallnut": return "Wallnut";
        case "potato_mine": return "PotatoMine";
        case "snow_pea": return "SnowPea";
        case "chomper": return "Chomper";
        case "repeater": return "PeaShooter";
        case "lily_pad": return "Lilypad";
        case "flower_pot": return "Pot";
    }
    return "PeaShooterSingle";
}

function pvz_lawn_create_plant_ui_icon(_kind) {
    var _name = pvz_lawn_plant_reanim_name(_kind);
    var _body = new Reanim(_name, 0, 0);
    var _head = undefined;
    var _shooting = (_kind == "peashooter" || _kind == "snow_pea" || _kind == "repeater");
    _body.scale_x = 0.5;
    _body.scale_y = 0.5;
    _body.alpha = 1.0;
    _body.loop_type = ReanimLoop.LOOP;
    _body.anim_rate = 12.0;
    if (_shooting) {
        _body.set_frames_for_layer("anim_idle");
        if (_body.track_exists("anim_head_idle") && _body.track_exists("anim_stem")) {
            _head = new Reanim(_name, 0, 0);
            _head.loop_type = ReanimLoop.LOOP;
            _head.set_frames_for_layer("anim_head_idle");
            _head.attach_to(_body, "anim_stem");
        }
    } else if (_body.track_exists("anim_idle")) {
        _body.play("anim_idle", ReanimLoop.LOOP, 0, 12.0);
    } else {
        _body.play_all(ReanimLoop.LOOP);
    }
    return { body: _body, head: _head };
}

function pvz_lawn_draw_plant_ui_icon(_icon, _x, _y, _scale, _alpha) {
    if (is_undefined(_icon) || is_undefined(_icon.body) || _icon.body == noone) return;
    var _body = _icon.body;
    var _head = _icon.head;
    _body.x = _x;
    _body.y = _y;
    _body.scale_x = _scale;
    _body.scale_y = _scale;
    _body.alpha = _alpha;
    if (!is_undefined(_head) && _head != noone) {
        // Attached head inherits the plant body scale; its local scale stays at one.
        _head.scale_x = 1.0;
        _head.scale_y = 1.0;
        _head.alpha = _alpha;
        var _stem = _body.find_track("anim_stem");
        if (_stem >= 0) _head.overlay = _body.get_attachment_overlay_matrix(_stem);
    }
    _body.draw();
}

function pvz_lawn_plant_object(_kind) {
    switch (_kind) {
        case "sunflower": return obj_plant_sunflower;
        case "peashooter": return obj_plant_peashooter;
        case "cherry_bomb": return obj_plant_cherry_bomb;
        case "wallnut": return obj_plant_wallnut;
        case "potato_mine": return obj_plant_potato_mine;
        case "snow_pea": return obj_plant_snow_pea;
        case "chomper": return obj_plant_chomper;
        case "repeater": return obj_plant_repeater;
        case "lily_pad": return obj_plant_lily_pad;
        case "flower_pot": return obj_plant_flower_pot;
    }
    return obj_plant_peashooter;
}

/// Plant::UpdatePotato / Plant::FindTargetZombie: use the Potato Mine's real attack
/// rectangle (mX, mY, mWidth - 25, mHeight), and Zombie::GetZombieRect overlap,
/// rather than triggering early from a distance between arbitrary sprite centers.
/// Source-oriented hitboxes for zombie body types that do not use the standard 42x115 body rectangle.
function pvz_lawn_zombie_hitbox(_zid) {
    if (!instance_exists(_zid)) return [0, 0, 0, 0];
    var _x = _zid.x, _y = _zid.y, _a = 0;
    if (variable_instance_exists(_zid, "altitude")) _a = max(0, _zid.altitude);
    switch (_zid.zombie_kind) {
        case "polevaulter": return [_x + 50, _y, _x + 107, _y + 115];
        case "gargantuar":
        case "red_eye_gargantuar": return [_x - 17, _y - 38, _x + 108, _y + 116];
        case "zomboni":
        case "catapult": return [_x, _y - 13, _x + 153, _y + 127];
        case "boss":
            if (_zid.phase != "boss_head_down" && _zid.phase != "boss_head_spit" && _zid.phase != "boss_head_idle_after_spit") return [0, 0, 0, 0];
            var _boss_head_track = _zid.body.find_track("Boss_head");
            var _boss_head_pos = (_boss_head_track >= 0) ? _zid.body.get_current_transform(_boss_head_track) : undefined;
            if (!is_undefined(_boss_head_pos)) return [_x + _boss_head_pos[0] + 18, _y + _boss_head_pos[1] + 14, _x + _boss_head_pos[0] + 106, _y + _boss_head_pos[1] + 98];
            return [_x + 620, _y + 200, _x + 735, _y + 305];
        case "balloon": return [_x + 36, _y - _a + 30, _x + 78, _y - _a + 145];
        case "snorkel": if (_zid.phase == "snorkel_swimming") return [0, 0, 0, 0]; else return [_x + 36, _y - _a, _x + 78, _y + 115 - _a];
        case "bungee": return [_x - 20, _y - _a + 22, _x + 90, _y - _a + 116];
        case "pogo": return [_x + 10, _y - _a, _x + 40, _y - _a + 115];
        case "imp":
            if (_zid.phase == "imp_thrown" || _zid.phase == "imp_landing") return [_x + 36, _y - _a, _x + 78, _y - _a + 115];
            return [_x + 36, _y, _x + 78, _y + 115];
        case "bobsled_team": return [_x - 50, _y - 10, _x + 225, _y + 115];
        default: return [_x + 36, _y - _a, _x + 78, _y + 115 - _a];
    }
}

/// Underground diggers cannot be hit by ordinary ground-level projectiles or trigger Potato Mines.
function pvz_lawn_zombie_ignores_ground_collision(_zid) {
    if (!instance_exists(_zid)) return true;
    return _zid.zombie_kind == "digger" && _zid.phase == "digger_underground";
}

function pvz_lawn_zombie_remove_plant(_pid) {
    if (!instance_exists(_pid)) return;
    var _col = _pid.cell_col, _row = _pid.cell_row;
    if (variable_global_exists("pvz_lawn_grid") && _col >= 0 && _col < PVZ_COLS && _row >= 0 && _row < pvz_lawn_active_rows()) {
        if (global.pvz_lawn_grid[# _col, _row] == _pid) global.pvz_lawn_grid[# _col, _row] = noone;
    }
    instance_destroy(_pid);
}

/// Jack-in-the-Box's original local explosion affects plants and other zombies, without leaving its own corpse.
function pvz_lawn_zombie_special_blast(_zid, _damage, _radius, _plant_radius = 90) {
    if (!instance_exists(_zid)) return;
    // Zombie::UpdateZombieJackInTheBox calls KillAllZombiesInRadius with mRow, then
    // KillAllPlantsInRadius with its smaller JackInTheBoxPlantRadius.
    var _cx = _zid.x + 60, _cy = _zid.y + 60 - (variable_instance_exists(_zid, "altitude") ? _zid.altitude : 0);
    var _blast_row = _zid.row;
    with (obj_zombie_base) {
        if (id != _zid && row == _blast_row && !dead && !intro_preview && !(zombie_kind == "digger" && phase == "digger_underground")) {
            var _r = pvz_lawn_zombie_hitbox(id);
            var _nx = clamp(_cx, _r[0], _r[2]);
            var _ny = clamp(_cy, _r[1], _r[3]);
            if (sqr(_nx - _cx) + sqr(_ny - _cy) <= sqr(_radius)) pvz_lawn_zombie_take_damage(id, _damage, true);
        }
    }
    if (!variable_global_exists("pvz_lawn_grid")) return;
    for (var _c = 0; _c < PVZ_COLS; _c++) {
        for (var _r = 0; _r < pvz_lawn_active_rows(); _r++) {
            var _p = global.pvz_lawn_grid[# _c, _r];
            if (instance_exists(_p) && variable_instance_exists(_p, "plant_health")) {
                var _left = _p.x, _top = _p.y, _right = _p.x + 80, _bottom = _p.y + 80;
                var _nx = clamp(_cx, _left, _right), _ny = clamp(_cy, _top, _bottom);
                if (sqr(_nx - _cx) + sqr(_ny - _cy) <= sqr(_plant_radius)) pvz_lawn_zombie_remove_plant(_p);
            }
        }
    }
}

function pvz_lawn_zombie_throw_imp(_zid) {
    if (!instance_exists(_zid) || _zid.imp_thrown || _zid.dead) return;
    // Zombie::UpdateZombieGargantuar begins the throw animation here; the Imp is
    // actually spawned at anim_throw's 0.74 timed event, not at animation start.
    _zid.imp_thrown = true;
    _zid.imp_released = false;
    _zid.phase = "garg_throwing";
    _zid.body.play("anim_throw", ReanimLoop.PLAY_ONCE_AND_HOLD, 20, 24.0);
    _zid.special_counter = max(1, round(_zid.body.frame_count / 24.0 * 100.0));
}

function pvz_lawn_zombie_release_imp(_zid) {
    if (!instance_exists(_zid) || _zid.imp_released) return;
    _zid.imp_released = true;
    _zid.has_object = false;
    _zid.body.set_tracks_hidden_by_prefix("Zombie_imp", true);
    _zid.body.set_track_hidden("Zombie_gargantuar_whiterope", true);
    var _throw_distance = _zid.x - 360.0;
    var _minimum_throw_distance = 40.0;
    if (_throw_distance < _minimum_throw_distance) _throw_distance = _minimum_throw_distance;
    else if (_throw_distance > 140.0) _throw_distance -= random_range(0.0, 100.0);
    var _imp = instance_create_layer(_zid.x - 133, _zid.y, "Instances", obj_zombie_imp, {row: _zid.row});
    if (!instance_exists(_imp)) return;
    _imp.phase = "imp_thrown";
    _imp.base_y = _imp.y;
    _imp.altitude = 88.0;
    _imp.horizontal_velocity = 3.0;
    // Zombie.cpp sets mVelZ = 0.5 * (throwDistance / mVelX) * gravity.
    // This runtime stores screen-up velocity with the opposite sign.
    _imp.vertical_velocity = -0.5 * (_throw_distance / 3.0) * 0.05;
    _imp.special_counter = 0;
    _imp.chilled_countdown = _zid.chilled_countdown;
    _imp.body.play("anim_thrown", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 18.0);
    pvz_lawn_play_sound("imp.ogg");
}

function pvz_lawn_zombie_step_special(_zid, _ground_speed) {
    if (!instance_exists(_zid) || _zid.dead) return false;
    var _kind = _zid.zombie_kind;

    if (_kind == "jackbox") {
        if (_zid.phase == "jack_exploding") {
            // Original: 110 ticks in the box-pop animation; the surprise cue fires at 80.
            _zid.special_counter--;
            if (_zid.special_counter == 80 && !_zid.special_triggered) {
                _zid.special_triggered = true;
                pvz_lawn_play_sound("jack_surprise.ogg");
            }
            if (_zid.special_counter <= 0) {
                pvz_lawn_play_sound("explosion.ogg");
                pvz_lawn_spawn_particle("JackExplode", _zid.x + 60, _zid.y + 60);
                pvz_lawn_zombie_special_blast(_zid, 1800, 115, 90);
                pvz_lawn_zombie_die_no_body(_zid);
            }
            return true;
        }
        if (_zid.phase == "jack_running") {
            if (_zid.chilled_countdown <= 0) _zid.special_counter--;
            if (!variable_instance_exists(_zid, "jack_sound_counter")) _zid.jack_sound_counter = irandom_range(55, 85);
            _zid.jack_sound_counter--;
            if (_zid.jack_sound_counter <= 0) { pvz_lawn_play_sound("jackinthebox.ogg"); _zid.jack_sound_counter = irandom_range(65, 95); }
            if (_zid.special_counter <= 0 && !_zid.special_triggered) {
                _zid.special_triggered = false;
                _zid.phase = "jack_exploding";
                _zid.special_counter = 110;
                _zid.eating = false;
                _zid.target_plant = noone;
                _zid.body.play("anim_pop", ReanimLoop.PLAY_ONCE_AND_HOLD, 20, 28.0);
                pvz_lawn_play_sound("boing.ogg");
            }
            return _zid.phase == "jack_exploding";
        }
    }

    if (_kind == "newspaper" && _zid.phase == "newspaper_maddening") {
        _zid.special_counter--;
        if (_zid.special_counter <= 0 || _zid.body.loop_count > 0) {
            _zid.phase = "newspaper_mad";
            _zid.body.play("anim_walk_nopaper", ReanimLoop.LOOP, 20, 0.0);
            _zid.body.anim_rate = pvz_lawn_zombie_anim_rate(_zid.body, _zid.move_speed);
            var _madhead = reanim_get_part_sprite("reanim/Zombie_paper_madhead.png");
            var _madhead_track = _zid.body.find_track("anim_head1");
            if (_madhead >= 0 && _madhead_track >= 0) _zid.body.track_sprite_override[_madhead_track] = _madhead;
            if (!_zid.special_triggered) {
                _zid.special_triggered = true;
                pvz_lawn_play_random_sound(["newspaper_rarrgh.ogg", "newspaper_rarrgh2.ogg"]);
            }
        }
        _zid.body.x = _zid.x; _zid.body.y = _zid.y;
        return true;
    }

    if (_kind == "balloon") {
        if (_zid.phase == "balloon_flying") {
            var _balloon_speed = _zid.move_speed * (_zid.chilled_countdown > 0 ? 0.4 : 1.0);
            _zid.x -= _balloon_speed * 0.47;
            _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
            _zid.body.set_track_hidden("balloon_pop", false);
            if (_zid.flying_health <= 0) {
                _zid.phase = "balloon_popping";
                _zid.special_counter = 30;
                _zid.body.play("anim_pop", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 24.0);
                pvz_lawn_play_sound("balloon_pop.ogg");
            }
            if (_zid.x < -100) instance_destroy(_zid);
            return true;
        }
        if (_zid.phase == "balloon_popping") {
            _zid.special_counter--;
            if (_zid.special_counter <= 0) {
                _zid.phase = "balloon_falling";
                _zid.special_counter = 30;
                _zid.body.set_track_hidden("Zombie_balloon_top", true);
                _zid.body.set_track_hidden("Zombie_balloon_bottom", true);
                _zid.body.play("anim_walk", ReanimLoop.LOOP, 0, 12.0);
            }
            _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
            return true;
        }
        if (_zid.phase == "balloon_falling") {
            _zid.special_counter--;
            _zid.altitude = max(0, _zid.altitude - 1.0);
            _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
            if (_zid.special_counter <= 0 || _zid.altitude <= 0) {
                _zid.altitude = 0;
                _zid.phase = "normal";
                _zid.move_speed = random_range(0.16, 0.22);
                _zid.body.play("anim_walk", ReanimLoop.LOOP, 10, 0);
                _zid.body.anim_rate = pvz_lawn_zombie_anim_rate(_zid.body, _zid.move_speed);
            }
            return true;
        }
    }

    if (_kind == "snorkel" && pvz_lawn_is_pool_row(_zid.row)) {
        if (_zid.phase == "snorkel_walking") {
            if (_zid.x > 720) {
                _zid.x -= _zid.move_speed * 0.47;
            } else if (_zid.x > 640 && _zid.x <= 720) {
                _zid.phase = "snorkel_into_pool";
                _zid.special_triggered = false;
                _zid.body.play("anim_jumpinpool", ReanimLoop.PLAY_ONCE_AND_HOLD, 20, 16.0);
                _zid.special_counter = max(1, round(_zid.body.frame_count / 16.0 * 100.0));
            }
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            return true;
        }
        if (_zid.phase == "snorkel_into_pool") {
            _zid.special_counter--;
            _zid.altitude = lerp(0, 10, clamp(_zid.body.anim_time, 0, 1));
            if (_zid.body.anim_time >= 0.83 && !_zid.special_triggered) {
                _zid.special_triggered = true;
                pvz_lawn_spawn_particle("PlantingPool", _zid.x - 10, _zid.y + 115);
                pvz_lawn_play_sound("zombie_entering_water.ogg");
            }
            _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
            if (_zid.body.loop_count > 0 || _zid.special_counter <= 0) {
                _zid.phase = "snorkel_swimming";
                _zid.altitude = 0;
                _zid.move_speed = 0.30;
                _zid.body.play("anim_swim", ReanimLoop.LOOP, 0, 12.0);
            }
            return true;
        }
        if (_zid.phase == "snorkel_swimming") {
            if (!_zid.has_head) {
                pvz_lawn_zombie_take_damage(_zid, 1800, true);
                return true;
            }
            var _snorkel_plant = pvz_lawn_find_plant(_zid, 78);
            if (instance_exists(_snorkel_plant) && _zid.x <= _snorkel_plant.x + 76) {
                _zid.target_plant = _snorkel_plant;
                _zid.phase = "snorkel_up_to_eat";
                _zid.special_counter = max(1, round(_zid.body.frame_count / 24.0 * 100.0));
                _zid.body.play("anim_uptoeat", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 24.0);
                _zid.altitude = 0;
                _zid.body.x = _zid.x; _zid.body.y = _zid.y;
                return true;
            }
            if (_zid.x <= 25) {
                _zid.x -= 15;
                _zid.phase = "normal";
                _zid.altitude = 0;
                _zid.move_speed = random_range(0.16, 0.22);
                _zid.body.play("anim_walk", ReanimLoop.LOOP, 0, 0);
                _zid.body.anim_rate = pvz_lawn_zombie_anim_rate(_zid.body, _zid.move_speed);
                _zid.body.x = _zid.x; _zid.body.y = _zid.y;
                return true;
            }
            _zid.x -= _zid.move_speed * 0.47;
            _zid.altitude = 0;
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            return true;
        }
        if (_zid.phase == "snorkel_up_to_eat") {
            _zid.special_counter--;
            if (!instance_exists(_zid.target_plant) || _zid.target_plant.plant_health <= 0) {
                _zid.phase = "snorkel_down_from_eat";
                _zid.body.play("anim_uptoeat", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, -24.0);
                _zid.special_counter = max(1, round(_zid.body.frame_count / 24.0 * 100.0));
            } else if (_zid.body.loop_count > 0 || _zid.special_counter <= 0) {
                _zid.phase = "snorkel_eating";
                _zid.eating = true;
                _zid.bite_ticks = 0;
                _zid.body.play("anim_eat", ReanimLoop.LOOP, 0, 20.0);
            }
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            return true;
        }
        if (_zid.phase == "snorkel_eating") {
            if (!_zid.eating || !instance_exists(_zid.target_plant) || _zid.target_plant.plant_health <= 0) {
                _zid.eating = false;
                _zid.phase = "snorkel_down_from_eat";
                _zid.special_counter = max(1, round(_zid.body.frame_count / 24.0 * 100.0));
                _zid.body.play("anim_uptoeat", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, -24.0);
                return true;
            }
            return false; // use the shared source 4-tick bite/damage and gulp logic while exposed to attacks
        }
        if (_zid.phase == "snorkel_down_from_eat") {
            _zid.special_counter--;
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            if (_zid.body.loop_count > 0 || _zid.special_counter <= 0) {
                _zid.phase = "snorkel_swimming";
                _zid.eating = false;
                _zid.target_plant = noone;
                _zid.move_speed = 0.30;
                _zid.body.play("anim_swim", ReanimLoop.LOOP, 0, 12.0);
            }
            return true;
        }
    }

    if (_kind == "dolphin_rider" && pvz_lawn_is_pool_row(_zid.row)) {
        if (_zid.phase == "dolphin_walking") {
            if (_zid.x > 720) _zid.x -= _zid.move_speed * 0.47;
            else if (_zid.x > 640 && _zid.x <= 720) {
                _zid.phase = "dolphin_into_pool";
                _zid.special_triggered = false;
                _zid.body.play("anim_jumpinpool", ReanimLoop.PLAY_ONCE_AND_HOLD, 20, 16.0);
                _zid.special_counter = max(1, round(_zid.body.frame_count / 16.0 * 100.0));
            }
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            return true;
        }
        if (_zid.phase == "dolphin_into_pool") {
            _zid.special_counter--;
            if (_zid.body.anim_time >= 0.56 && !_zid.special_triggered) {
                _zid.special_triggered = true;
                pvz_lawn_spawn_particle("PlantingPool", _zid.x - 46, _zid.y + 115);
                pvz_lawn_play_sound("zombie_entering_water.ogg");
            }
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            if (_zid.body.loop_count > 0 || _zid.special_counter <= 0) {
                _zid.x -= 70;
                _zid.phase = "dolphin_riding";
                _zid.move_speed = 0.9;
                _zid.body.play("anim_ride", ReanimLoop.LOOP, 0, 12.0);
            }
            return true;
        }
        if (_zid.phase == "dolphin_riding") {
            var _dolphin_plant = pvz_lawn_find_plant(_zid, 98);
            if (instance_exists(_dolphin_plant) && _zid.x <= _dolphin_plant.x + 78) {
                _zid.target_plant = _dolphin_plant;
                _zid.phase = "dolphin_jump";
                _zid.special_triggered = false;
                _zid.special_counter = max(1, round(_zid.body.frame_count / 10.0 * 100.0));
                _zid.body.play("anim_dolphinjump", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 10.0);
                _zid.move_speed = 0.5;
                return true;
            }
            if (_zid.x <= 10) {
                _zid.phase = "dolphin_walking_without_dolphin";
                _zid.altitude = -40;
                _zid.move_speed = random_range(0.23, 0.37);
                _zid.body.play("anim_walk", ReanimLoop.LOOP, 0, 12.0);
                return true;
            }
            _zid.x -= _zid.move_speed * 0.47;
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            return true;
        }
        if (_zid.phase == "dolphin_jump") {
            _zid.special_counter--;
            if (_zid.body.anim_time >= 0.49 && !_zid.special_triggered) {
                _zid.special_triggered = true;
                pvz_lawn_spawn_particle("PlantingPool", _zid.x - 26, _zid.y + 115);
                pvz_lawn_play_sound("zombie_entering_water.ogg");
                _zid.move_speed = 0;
            }
            if (_zid.body.anim_time >= 0.30 && instance_exists(_zid.target_plant) && _zid.target_plant.plant_kind == "tall_nut") {
                pvz_lawn_play_sound("bonk.ogg");
                pvz_lawn_spawn_particle("TallNutBlock", _zid.target_plant.x + 60, _zid.target_plant.y - 20);
                _zid.x = _zid.target_plant.x + 25;
                _zid.altitude = 30;
                _zid.special_counter = 1;
            }
            _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
            if (_zid.body.loop_count > 0 || _zid.special_counter <= 0) {
                _zid.x -= 94;
                _zid.altitude = 0;
                _zid.phase = "dolphin_walking_in_pool";
                _zid.target_plant = noone;
                _zid.move_speed = random_range(0.23, 0.37);
                _zid.body.play("anim_walk", ReanimLoop.LOOP, 0, 12.0);
            }
            return true;
        }
        if (_zid.phase == "dolphin_walking_in_pool") {
            if (_zid.x <= 10) {
                _zid.phase = "dolphin_walking_without_dolphin";
                _zid.altitude = -40;
                _zid.body.play("anim_walk", ReanimLoop.LOOP, 0, 12.0);
                _zid.move_speed = random_range(0.23, 0.37);
            } else _zid.x -= _zid.move_speed * 0.47;
            _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
            return true;
        }
        if (_zid.phase == "dolphin_walking_without_dolphin") return false;
    }

    if (_kind == "digger") {
        if (_zid.phase == "digger_underground") {
            if (_zid.chilled_countdown <= 0) _zid.x -= _zid.move_speed * 0.47;
            _zid.special_counter++;
            _zid.body.x = _zid.x; _zid.body.y = _zid.y + 16;
            if (_zid.special_counter % 120 == 0) pvz_lawn_spawn_particle("DiggerTunnel", _zid.x + 60, _zid.y + 98); // One finite emitter about every 1.2 seconds; no live-attached loop.
            // Zombie::UpdateZombieDigger turns at the far-left boundary, then rises over 130 source ticks.
            if (_zid.x <= 10) {
                _zid.phase = "digger_rising";
                _zid.special_counter = 130;
                _zid.altitude = -120;
                _zid.walks_backwards = true;
                _zid.body.set_track_hidden("Zombie_digger_dig", false);
                _zid.body.play("anim_drill", ReanimLoop.LOOP, 0, 20.0);
                pvz_lawn_play_sound("digger_zombie.ogg");
                pvz_lawn_spawn_particle("DiggerRise", _zid.x + 60, _zid.y + 118);
            }
            return true;
        }
        if (_zid.phase == "digger_rising") {
            _zid.special_counter--;
            if (_zid.special_counter > 40) {
                _zid.altitude = lerp(-120, 20, clamp((130 - _zid.special_counter) / 90.0, 0, 1));
            } else {
                _zid.altitude = lerp(20, 0, clamp((40 - _zid.special_counter) / 40.0, 0, 1));
            }
            if (_zid.special_counter == 30) _zid.body.play("anim_landing", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 12.0);
            _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
            if (_zid.special_counter <= 0) {
                _zid.altitude = 0;
                _zid.phase = "digger_stunned";
                _zid.special_counter = 250;
                _zid.body.play("anim_dizzy", ReanimLoop.LOOP, 10, 12.0);
            }
            return true;
        }
        if (_zid.phase == "digger_stunned") {
            _zid.special_counter--;
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            if (_zid.body.loop_count > 1 || _zid.special_counter <= 0) {
                _zid.phase = "normal";
                _zid.move_speed = 0.12;
                _zid.body.set_track_hidden("Zombie_digger_dig", true);
                _zid.body.play("anim_walk", ReanimLoop.LOOP, 20, 0);
                _zid.body.scale_x = -1;
                _zid.body.anim_rate = pvz_lawn_zombie_anim_rate(_zid.body, _zid.move_speed);
            }
            return true;
        }
    }

    if (_kind == "pogo" && (_zid.phase == "pogo_bouncing" || _zid.phase == "pogo_high_bounce" || _zid.phase == "pogo_forward_bounce")) {
        var _pogo_counter_before = _zid.special_counter;
        var _pogo_plant = pvz_lawn_find_plant(_zid, 100);
        var _pogo_is_tallnut = instance_exists(_pogo_plant) && ((variable_instance_exists(_pogo_plant, "plant_kind") && string_lower(string(_pogo_plant.plant_kind)) == "tallnut")
            || (variable_instance_exists(_pogo_plant, "display_name") && _pogo_plant.display_name == "Tall-nut")
            || (variable_instance_exists(_pogo_plant, "reanim_name") && string_pos("tallnut", string_lower(string(_pogo_plant.reanim_name))) > 0));
        // Zombie::UpdateZombiePogo: the standard cycle is 80 ticks; the phase picks the source arc height.
        var _pogo_height = _zid.phase == "pogo_forward_bounce" ? 90 : (_zid.phase == "pogo_high_bounce" ? 50 : 40);
        if (_zid.phase == "pogo_forward_bounce" && _pogo_counter_before == 70 && _pogo_is_tallnut) {
            pvz_lawn_play_sound("bonk.ogg");
            pvz_lawn_spawn_particle("TallNutBlock", _pogo_plant.x + 60, _pogo_plant.y - 20);
            _zid.phase = "normal";
            _zid.altitude = 0;
            _zid.armor_health = 0;
            _zid.has_object = false;
            _zid.move_speed = random_range(0.16, 0.22);
            _zid.body.set_tracks_hidden_by_prefix("Zombie_pogo_stick", true);
            _zid.body.play("anim_walk", ReanimLoop.LOOP, 10, 0);
            _zid.body.anim_rate = pvz_lawn_zombie_anim_rate(_zid.body, _zid.move_speed);
            return true;
        }
        var _pogo_speed = _zid.move_speed * (_zid.chilled_countdown > 0 ? 0.4 : 1.0);
        if (_zid.phase == "pogo_forward_bounce" || _zid.phase == "pogo_bouncing") _zid.x -= _pogo_speed * 0.47;
        if (_pogo_counter_before == 7) _zid.body.anim_time = 0.0;
        if (_pogo_counter_before == 5) pvz_lawn_play_sound("pogo_zombie.ogg");
        _zid.special_counter--;
        var _pogo_t = 1.0 - clamp(_zid.special_counter / 80.0, 0.0, 1.0);
        _zid.altitude = 9.0 + sin(_pogo_t * pi) * _pogo_height;
        _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
        if (_zid.special_counter <= 0) {
            if (!instance_exists(_pogo_plant)) {
                _zid.phase = "pogo_bouncing";
                _zid.move_speed = 0.45;
                _zid.special_counter = 80;
            } else if (_zid.phase == "pogo_high_bounce") {
                _zid.phase = "pogo_forward_bounce";
                _zid.move_speed = max(0.1, (_zid.x - _pogo_plant.x + 60) / 80.0);
                _zid.special_counter = 80;
            } else {
                _zid.phase = "pogo_high_bounce";
                _zid.move_speed = 0.0;
                _zid.special_counter = 80;
            }
        }
        if (_zid.x < -100) instance_destroy(_zid);
        return true;
    }

    if (_kind == "imp" && (_zid.phase == "imp_thrown" || _zid.phase == "imp_landing")) {
        if (_zid.phase == "imp_thrown") {
            _zid.x -= _zid.horizontal_velocity * 0.47;
            _zid.altitude -= _zid.vertical_velocity;
            _zid.vertical_velocity += 0.05;
            _zid.body.x = _zid.x; _zid.body.y = _zid.base_y - _zid.altitude;
            if (_zid.altitude <= 0 && _zid.vertical_velocity > 0) {
                _zid.altitude = 0;
                _zid.phase = "imp_landing";
                _zid.special_counter = 20;
                _zid.body.y = _zid.base_y;
                _zid.body.play("anim_land", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 18.0);
            }
        } else {
            _zid.special_counter--;
            _zid.body.x = _zid.x; _zid.body.y = _zid.base_y;
            if (_zid.special_counter <= 0 || _zid.body.loop_count > 0) {
                _zid.y = _zid.base_y;
                _zid.phase = "normal";
                _zid.move_speed = random_range(0.16, 0.22);
                _zid.body.play("anim_walk", ReanimLoop.LOOP, 10, 0);
                _zid.body.anim_rate = pvz_lawn_zombie_anim_rate(_zid.body, _zid.move_speed);
            }
        }
        if (_zid.x < -100) instance_destroy();
        return true;
    }

    if (_kind == "bungee") {
        if (_zid.phase == "bungee_dive") {
            _zid.altitude = max(0, _zid.altitude - 8.0);
            _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
            if (_zid.altitude <= 0) {
                _zid.altitude = 0;
                _zid.phase = "bungee_grab";
                _zid.special_counter = 35;
                _zid.body.play("anim_grab", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 24.0);
                pvz_lawn_play_sound("bungee_scream.ogg");
            }
            return true;
        }
        if (_zid.phase == "bungee_grab") {
            _zid.special_counter--;
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            if (instance_exists(_zid.target_plant)) {
                // PlantOnBungeeState::GETTING_GRABBED remains visible for the entire grab pose.
                _zid.target_plant.on_bungee = true;
                _zid.target_plant.bungee_lift_counter = 0;
                _zid.target_plant.bungee_start_y = _zid.target_plant.y;
            }
            if (_zid.special_counter <= 0 || _zid.body.loop_count > 0) {
                if (instance_exists(_zid.target_plant)) {
                    _zid.target_plant.on_bungee = true;
                    _zid.target_plant.bungee_lift_counter = 1;
                    _zid.target_plant.bungee_start_y = _zid.target_plant.y;
                }
                _zid.phase = "bungee_rise";
                _zid.special_counter = 0;
                _zid.body.play("anim_raise", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 36.0);
                pvz_lawn_play_sound("bungee_floop.ogg");
            }
            return true;
        }
        if (_zid.phase == "bungee_rise") {
            _zid.altitude += 4.0;
            if (instance_exists(_zid.target_plant)) {
                _zid.target_plant.bungee_lift_counter += 1;
                _zid.target_plant.y -= 4.0;
                _zid.target_plant.body.y = _zid.target_plant.y;
                if (!is_undefined(_zid.target_plant.head)) _zid.target_plant.head.y = _zid.target_plant.y;
                if (!is_undefined(_zid.target_plant.blink)) _zid.target_plant.blink.y = _zid.target_plant.y;
            }
            _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
            if (_zid.altitude >= 600) {
                if (instance_exists(_zid.target_plant)) pvz_lawn_zombie_remove_plant(_zid.target_plant);
                _zid.target_plant = noone;
                instance_destroy(_zid);
            }
            return true;
        }
    }

    if (_kind == "dancer") {
        if (_zid.phase == "dancer_in") {
            // The original dancer walks in, then waits until it is on the lawn before snapping.
            if (_zid.x > 700.0) _zid.x -= _zid.move_speed * 0.47;
            _zid.special_counter--;
            if (_zid.special_counter <= 0 && _zid.has_head && _zid.x <= 700.0) {
                _zid.phase = "dancer_snapping";
                _zid.special_triggered = false;
                _zid.body.play("anim_point", ReanimLoop.PLAY_ONCE_AND_HOLD, 20, 24.0);
                _zid.special_counter = max(1, round(_zid.body.frame_count / 24.0 * 100.0));
            }
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            return true;
        }
        if (_zid.phase == "dancer_snapping") {
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            if (_zid.body.loop_count > 0 || _zid.special_counter <= 0) {
                // Source SummonBackupDancers fills only missing positions in its four-zombie formation.
                var _backup_rows = [_zid.row - 1, _zid.row + 1, _zid.row, _zid.row];
                var _backup_xs = [_zid.x, _zid.x, _zid.x - 100, _zid.x + 100];
                for (var _bi = 0; _bi < 4; _bi++) {
                    var _br = _backup_rows[_bi];
                    if (_br < 0 || _br >= pvz_lawn_active_rows()) continue;
                    var _bx = _backup_xs[_bi];
                    var _existing_follower = false;
                    with (obj_zombie_backup_dancer) {
                        if (!dead && backup_dancer_leader == _zid && abs(x - _bx) < 24 && row == _br) _existing_follower = true;
                    }
                    if (_existing_follower) continue;
                    var _by = pvz_lawn_row_y(_br, _bx, -30);
                    var _b = instance_create_layer(_bx, _by, "Instances", obj_zombie_backup_dancer, {row:_br});
                    if (instance_exists(_b)) {
                        _b.backup_dancer_leader = _zid;
                        _b.phase = "backup_rising";
                        // Source ZOMBIE_BACKUP_DANCER_RISE_HEIGHT is -200: draw it below
                        // ground first, then raise it to altitude zero over 150 source ticks.
                        _b.altitude = -200;
                        _b.special_counter = 150;
                        _b.body.anim_rate = 0;
                        _b.body.alpha = 0;
                        _b.body.x = _b.x; _b.body.y = _b.y - _b.altitude;
                        pvz_lawn_spawn_particle("DancerRise", _bx + 60, _by + 110);
                    }
                }
                if (!_zid.special_triggered) pvz_lawn_play_sound("dancer.ogg");
                _zid.special_triggered = true;
                _zid.phase = "dancer_hold";
                _zid.special_counter = 200;
                _zid.dance_phase_counter = 0;
            }
            return true;
        }
        if (_zid.phase == "dancer_hold") {
            _zid.special_counter--;
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            if (_zid.special_counter <= 0) {
                _zid.phase = "dancer_dancing";
                _zid.dance_phase_counter = 0;
                _zid.special_triggered = false;
                _zid.body.play("anim_walk", ReanimLoop.LOOP, 10, 18.0);
            }
            return true;
        }
        if (_zid.phase == "dancer_dancing") {
            // GetDancerFrame uses 23 frames, 20 source ticks each (460 ticks per cycle).
            _zid.dance_phase_counter = (variable_instance_exists(id, "dance_phase_counter") ? dance_phase_counter + 1 : 1) mod 460;
            var _dance_frame = floor(_zid.dance_phase_counter / 20);
            var _missing_backup = false;
            var _check_rows = [_zid.row - 1, _zid.row + 1, _zid.row, _zid.row];
            var _check_xs = [_zid.x, _zid.x, _zid.x - 100, _zid.x + 100];
            for (var _check_i = 0; _check_i < 4; _check_i++) {
                var _check_row = _check_rows[_check_i];
                if (_check_row < 0 || _check_row >= pvz_lawn_active_rows()) continue;
                var _check_x = _check_xs[_check_i];
                var _slot_found = false;
                with (obj_zombie_backup_dancer) {
                    if (!dead && backup_dancer_leader == _zid && row == _check_row && abs(x - _check_x) < 24) _slot_found = true;
                }
                if (!_slot_found) { _missing_backup = true; break; }
            }
            if (_dance_frame <= 11) {
                if (_zid.body.anim_name != "anim_walk") _zid.body.play("anim_walk", ReanimLoop.LOOP, 10, 18.0);
            } else {
                if (_zid.body.anim_name != "anim_armraise") {
                    _zid.body.play("anim_armraise", ReanimLoop.LOOP, 10, 18.0);
                    if (_dance_frame == 12) _zid.body.anim_time = 0.6;
                }
                // Replacement summoning is queued at the source's frame-12 snap, never every frame.
                if (_dance_frame == 12 && _missing_backup && !_zid.special_triggered && _zid.has_head && _zid.x < 700.0) {
                    _zid.phase = "dancer_snapping";
                    _zid.special_triggered = true;
                    _zid.body.play("anim_point", ReanimLoop.PLAY_ONCE_AND_HOLD, 20, 24.0);
                    _zid.special_counter = max(1, round(_zid.body.frame_count / 24.0 * 100.0));
                }
            }
            // Dancer movement remains in the normal lawn direction; it no longer switches to the wrong moonwalk state.
            _zid.x -= _zid.move_speed * 0.47;
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            // Special-state updates return before the common house collision check, so preserve it here.
            if (_zid.has_head && _zid.x + 36 < 0) {
                pvz_lawn_zombie_start_house_cutscene(_zid);
                return true;
            }
            if (_zid.x < -70) { instance_destroy(_zid); return true; }
            return true;
        }
    }

    if (_kind == "backup_dancer" && _zid.phase == "backup_rising") {
        _zid.special_counter--;
        _zid.altitude = lerp(-200, 0, clamp((150 - _zid.special_counter) / 150.0, 0, 1));
        // Keep the body hidden during most of emergence so it does not visibly pop through the turf.
        _zid.body.alpha = clamp((40 - _zid.special_counter) / 40.0, 0, 1);
        _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
        if (_zid.special_counter <= 0) {
            _zid.altitude = 0;
            _zid.body.alpha = 1;
            _zid.phase = "backup_dancing";
            var _leader_phase = instance_exists(_zid.backup_dancer_leader) && variable_instance_exists(_zid.backup_dancer_leader, "dance_phase_counter")
                ? _zid.backup_dancer_leader.dance_phase_counter : (global.pvz_lawn_tick mod 460);
            _zid.dance_phase_counter = _leader_phase;
            if (floor(_leader_phase / 20) <= 11) _zid.body.play("anim_walk", ReanimLoop.LOOP, 10, 18.0);
            else { _zid.body.play("anim_armraise", ReanimLoop.LOOP, 10, 18.0); if (floor(_leader_phase / 20) == 12) _zid.body.anim_time = 0.6; }
        }
        return true;
    }
    if (_kind == "backup_dancer" && _zid.phase == "backup_dancing") {
        // Zombie::GetDancerFrame reads the common Board counter; backup animations must not
        // maintain an independent clock that drifts into rapid or mismatched transitions.
        _zid.dance_phase_counter = instance_exists(_zid.backup_dancer_leader)
            && variable_instance_exists(_zid.backup_dancer_leader, "dance_phase_counter")
            ? _zid.backup_dancer_leader.dance_phase_counter : (global.pvz_lawn_tick mod 460);
        if (floor(_zid.dance_phase_counter / 20) <= 11) {
            if (_zid.body.anim_name != "anim_walk") _zid.body.play("anim_walk", ReanimLoop.LOOP, 10, 0);
        } else {
            if (_zid.body.anim_name != "anim_armraise") _zid.body.play("anim_armraise", ReanimLoop.LOOP, 10, 18.0);
        }
        _zid.x -= _zid.move_speed * 0.47;
        _zid.body.x = _zid.x; _zid.body.y = _zid.y;
        if (_zid.has_head && _zid.x + 36 < 0) {
            pvz_lawn_zombie_start_house_cutscene(_zid);
            return true;
        }
        if (_zid.x < -70) { instance_destroy(_zid); return true; }
        return true;
    }

    if (_kind == "yeti" && _zid.phase == "normal") {
        _zid.special_counter--;
        if (_zid.special_counter <= 0) {
            _zid.phase = "yeti_retreat";
            _zid.eating = false; _zid.target_plant = noone;
            _zid.move_speed = 0.8;
            _zid.body.play("anim_walk", ReanimLoop.LOOP, 10, 0);
            _zid.body.scale_x = -1;
            _zid.body.anim_rate = pvz_lawn_zombie_anim_rate(_zid.body, _zid.move_speed);
            return true;
        }
        return false; // keep normal bite/plant behavior while the Yeti timer runs.
    }
    if (_kind == "yeti" && _zid.phase == "yeti_retreat") {
        var _yeti_retreat_speed = _zid.move_speed * (_zid.chilled_countdown > 0 ? 0.4 : 1.0);
        _zid.x += _yeti_retreat_speed * 0.47;
        _zid.body.scale_x = -1;
        _zid.body.x = _zid.x;
        if (_zid.x > room_width + 80) instance_destroy(_zid);
        return true;
    }

    if (_kind == "ladder") {
        if (_zid.phase == "ladder_carrying") {
            var _ladder_target = pvz_lawn_find_ladder_target(_zid);
            if (instance_exists(_ladder_target)) {
                _zid.target_plant = _ladder_target;
                _zid.eating = false;
                _zid.phase = "ladder_placing";
                _zid.body.play("anim_placeladder", ReanimLoop.PLAY_ONCE_AND_HOLD, 10, 24.0);
                _zid.special_counter = max(1, round(_zid.body.frame_count / 24.0 * 100.0));
                return true;
            }
            return false;
        }
        if (_zid.phase == "ladder_placing") {
            _zid.special_counter--;
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            if (_zid.special_counter <= 0 || _zid.body.loop_count > 0) {
                if (instance_exists(_zid.target_plant) && _zid.target_plant.plant_health > 0 && !_zid.target_plant.laddered) {
                    _zid.target_plant.laddered = true;
                    pvz_lawn_play_sound("ladder_zombie.ogg");
                    _zid.armor_health = 0;
                    _zid.body.set_track_hidden("Zombie_ladder_1", true);
                    _zid.phase = "ladder_climbing";
                    _zid.special_counter = 112;
                    _zid.altitude = 0;
                    _zid.move_speed = 0.3;
                } else {
                    _zid.phase = "ladder_carrying";
                    _zid.target_plant = noone;
                    _zid.body.play("anim_ladderwalk", ReanimLoop.LOOP, 10, 0);
                }
            }
            return true;
        }
        if (_zid.phase == "ladder_climbing") {
            _zid.special_counter--;
            _zid.altitude = min(90.0, _zid.altitude + 0.8);
            if (_zid.move_speed < 0.5) _zid.x -= 0.5;
            _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
            if (_zid.special_counter <= 0 || _zid.altitude >= 90.0) {
                // The original climb clears the top of the obstacle, then drops to ground level
                // on its far side. Carry the root X past the plant before lowering altitude.
                // Zombie::UpdateClimbingLadder advances horizontally a little during the climb.
                // Keep that accumulated position; snapping to target_plant.x + 90 caused a visible teleport.
                _zid.phase = "ladder_falling";
                _zid.special_counter = 30;
                _zid.altitude = 90.0;
            }
            return true;
        }
        if (_zid.phase == "ladder_falling") {
            _zid.special_counter--;
            _zid.altitude = lerp(90.0, 0.0, clamp((30 - _zid.special_counter) / 30.0, 0, 1));
            _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
            if (_zid.special_counter <= 0) {
                _zid.altitude = 0;
                _zid.target_plant = noone;
                _zid.phase = "normal";
                _zid.move_speed = random_range(0.16, 0.22);
                _zid.body.play("anim_walk", ReanimLoop.LOOP, 10, 0);
                _zid.body.anim_rate = pvz_lawn_zombie_anim_rate(_zid.body, _zid.move_speed);
            }
            return true;
        }
    }

    if (_zid.phase == "climbing_existing_ladder") {
        _zid.special_counter--;
        _zid.altitude = min(90.0, _zid.altitude + 0.8);
        // Source UpdateClimbingLadder shifts the zombie 0.5 px left per tick when walking speed is low.
        if (_zid.move_speed < 0.5) _zid.x -= 0.5;
        _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
        if (_zid.special_counter <= 0 || _zid.altitude >= 90.0) {
            // Zombie::UpdateClimbingLadder only changes altitude and the height state; it does not
            // teleport the zombie back to either side of the plant once the climb reaches 90px.
            _zid.phase = "ladder_falling";
            _zid.special_counter = 30;
        }
        return true;
    }
    if (_zid.phase == "ladder_falling" && _kind != "ladder") {
        _zid.special_counter--;
        _zid.altitude = lerp(90.0, 0.0, clamp((30 - _zid.special_counter) / 30.0, 0, 1));
        _zid.body.x = _zid.x; _zid.body.y = _zid.y - _zid.altitude;
        if (_zid.special_counter <= 0) {
            _zid.altitude = 0;
            _zid.target_plant = noone;
            _zid.phase = "normal";
            _zid.body.y = _zid.y;
            pvz_lawn_zombie_play_walk(id, 0);
        }
        return true;
    }

    if (_kind == "zomboni") {
        if (_zid.x > 400 && !_zid.flat_tires) _zid.move_speed = lerp(0.25, 0.05, clamp((_zid.x - 300.0) / 400.0, 0, 1));
        else if (variable_instance_exists(_zid, "flat_tires") && _zid.flat_tires && _zid.move_speed > 0.0005) _zid.move_speed = max(0, _zid.move_speed - 0.0005);
        _zid.x -= _zid.move_speed;
        _zid.special_counter++;
        // Original Zombie::UpdateZamboni produces ice, not an endless smoke emitter.
        // Smoke is spawned once on the body damage-stage transition below.
        // Vehicle collision destroys plants it drives over; the first lawn has no ice-grid model, so no tile is fabricated.
        if (variable_global_exists("pvz_lawn_grid")) {
            for (var _c = 0; _c < PVZ_COLS; _c++) {
                var _p = global.pvz_lawn_grid[# _c, _zid.row];
                if (instance_exists(_p) && _p.x + 72 >= _zid.x - 20 && _p.x <= _zid.x + 125) pvz_lawn_zombie_remove_plant(_p);
            }
        }
        _zid.body.x = _zid.x; _zid.body.y = _zid.y - 8;
        if (_zid.x < -180) instance_destroy(_zid);
        return true;
    }

    if (_kind == "bobsled_team") {
        if (_zid.phase == "bobsled_crashing") {
            _zid.special_counter--;
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            if (_zid.special_counter <= 0) {
                var _released_ids = _zid.bobsled_rider_ids;
                for (var _ridx = 0; _ridx < array_length(_released_ids); _ridx++) {
                    var _rid = _released_ids[_ridx];
                    if (instance_exists(_rid)) {
                        _rid.sled_leader = noone;
                        _rid.phase = "normal";
                        _rid.x = _zid.x + (_rid.follower_index + 1) * 32;
                        _rid.y = _zid.y;
                        _rid.move_speed = random_range(0.23, 0.37);
                        _rid.body.play("anim_walk", ReanimLoop.LOOP, 0, 0);
                        _rid.body.anim_rate = pvz_lawn_zombie_anim_rate(_rid.body, _rid.move_speed);
                    }
                }
                _zid.bobsled_rider_ids = [];
                _zid.phase = "normal";
                _zid.move_speed = random_range(0.23, 0.37);
                _zid.body.play("anim_walk", ReanimLoop.LOOP, 0, 0);
                _zid.body.anim_rate = pvz_lawn_zombie_anim_rate(_zid.body, _zid.move_speed);
            }
            return true;
        }
        _zid.x -= _zid.move_speed * 0.47;
        _zid.body.x = _zid.x; _zid.body.y = _zid.y;
        if (_zid.x < -180) { pvz_lawn_zombie_cleanup_group(_zid); instance_destroy(_zid); }
        return true;
    }
    if (_kind == "bobsled_rider") {
        if (instance_exists(_zid.sled_leader) && !_zid.sled_leader.dead) {
            // Keep the rider instance root and Reanim aligned to the lead zombie.
            // Assigning body.x alone then overwriting it with the stale rider x made the
            // riders appear disconnected or hidden inside the sled.
            _zid.x = _zid.sled_leader.x + (_zid.follower_index + 1) * 42;
            _zid.y = _zid.sled_leader.y;
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            if (_zid.sled_leader.phase == "bobsled_crashing") {
                if (_zid.body.anim_name != "anim_walk") _zid.body.play("anim_walk", ReanimLoop.LOOP, 0, 0);
            } else if (_zid.body.anim_name != "anim_push") {
                _zid.body.play("anim_push", ReanimLoop.LOOP, 0, 30.0);
            }
            _zid.depth = _zid.sled_leader.depth + _zid.follower_index;
            return true;
        }
        return false;
    }

    if (_kind == "catapult") {
        if (_zid.phase == "catapult_attacking") {
            _zid.special_counter--;
            // Zombie::UpdateZombieCatapult launches at the original anim_shoot timed event.
            if (!_zid.catapult_shot_fired && _zid.body.anim_time >= 0.545) {
                _zid.catapult_shot_fired = true;
                if (instance_exists(_zid.target_plant)) {
                    var _target = _zid.target_plant;
                    instance_create_layer(_zid.x + 113, _zid.y - 44, "Instances", obj_pvz_boss_projectile, {
                        projectile_row: _zid.row,
                        projectile_kind: "basketball",
                        start_x: _zid.x + 113,
                        start_y: _zid.y - 44,
                        target_x: _target.x,
                        target_y: _target.y,
                        target_plant: _target
                    });
                    pvz_lawn_play_sound("basketball.ogg");
                }
            }
            if (_zid.special_counter <= 0 || _zid.body.loop_count > 0) {
                _zid.catapult_ammo = max(0, _zid.catapult_ammo - 1);
                pvz_lawn_zombie_update_catapult_visuals(id);
                pvz_lawn_zombie_update_body_damage_stage(id);
                _zid.target_plant = noone;
                _zid.catapult_shot_fired = false;
                if (_zid.catapult_ammo > 0) {
                    _zid.phase = "catapult_reloading";
                    _zid.special_counter = 300;
                    _zid.body.play("anim_idle", ReanimLoop.LOOP, 20, 12.0);
                } else {
                    _zid.phase = "normal";
                    _zid.special_counter = 0;
                    _zid.body.play("anim_walk", ReanimLoop.LOOP, 20, 0.0);
                    _zid.move_speed = random_range(0.38, 0.46);
                }
            }
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            return true;
        }
        if (_zid.phase == "catapult_reloading") {
            _zid.special_counter--;
            if (_zid.special_counter <= 0) {
                var _reload_target = pvz_lawn_find_plant(_zid, 700);
                if (_zid.catapult_ammo > 0 && instance_exists(_reload_target)) {
                    _zid.phase = "catapult_attacking";
                    _zid.target_plant = _reload_target;
                    _zid.catapult_shot_fired = false;
                    _zid.body.play("anim_shoot", ReanimLoop.PLAY_ONCE_AND_HOLD, 20, 24.0);
                    _zid.special_counter = max(1, round(_zid.body.frame_count / 24.0 * 100.0));
                } else {
                    _zid.phase = "normal";
                    _zid.body.play("anim_walk", ReanimLoop.LOOP, 20, 0.0);
                    _zid.move_speed = random_range(0.38, 0.46);
                }
            }
            _zid.body.x = _zid.x; _zid.body.y = _zid.y;
            return true;
        }
        // Original Catapult fires from x<=650, then resumes walking if no plant is in range.
        if (_zid.x <= 650 && _zid.catapult_ammo > 0 && _zid.special_counter <= 0) {
            var _catapult_target = pvz_lawn_find_plant(_zid, 700);
            if (instance_exists(_catapult_target)) {
                _zid.phase = "catapult_attacking";
                _zid.target_plant = _catapult_target;
                _zid.catapult_shot_fired = false;
                _zid.body.play("anim_shoot", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 24.0);
                _zid.special_counter = max(1, round(_zid.body.frame_count / 24.0 * 100.0));
                return true;
            }
            _zid.special_counter = 45;
        } else if (_zid.special_counter > 0) {
            _zid.special_counter--;
        }
        var _catapult_speed = _zid.move_speed * (_zid.chilled_countdown > 0 ? 0.4 : 1.0);
        _zid.x -= _catapult_speed * 0.47;
        _zid.body.x = _zid.x; _zid.body.y = _zid.y;
        if (_zid.x < -180) instance_destroy(_zid);
        return true;
    }

    if (_kind == "gargantuar" || _kind == "red_eye_gargantuar") {
        if (_zid.phase == "normal" && !_zid.imp_thrown && _zid.has_head && _zid.has_object
            && _zid.body_health > 0 && _zid.body_health < _zid.body_max_health * 0.5 && (_zid.x - 360.0) > 40.0) {
            pvz_lawn_zombie_throw_imp(_zid);
        }
        if (_zid.phase == "garg_throwing") {
            _zid.special_counter--;
            if (!_zid.imp_released && _zid.body.anim_time >= 0.74) pvz_lawn_zombie_release_imp(_zid);
            if (_zid.special_counter <= 0 || _zid.body.loop_count > 0) {
                _zid.phase = "normal";
                _zid.has_object = false;
                _zid.move_speed = 0.18;
                _zid.body.play("anim_walk", ReanimLoop.LOOP, 10, 0);
                _zid.body.anim_rate = pvz_lawn_zombie_anim_rate(_zid.body, _zid.move_speed);
            }
            _zid.body.x = _zid.x; _zid.body.y = _zid.y - 6;
            return true;
        }
        if (_zid.phase == "garg_smashing") {
            _zid.special_counter--;
            // Source triggers the smash at animation time 0.64, then resumes walking when the one-shot ends.
            if (!_zid.special_triggered && _zid.body.anim_time >= 0.64) {
                _zid.special_triggered = true;
                if (instance_exists(_zid.target_plant)) pvz_lawn_plant_squish(_zid.target_plant);
                pvz_lawn_play_sound("gargantuar_thump.ogg");
            }
            if (_zid.special_counter <= 0 || _zid.body.loop_count > 0) {
                _zid.target_plant = noone;
                _zid.phase = "normal";
                _zid.move_speed = 0.18;
                _zid.body.play("anim_walk", ReanimLoop.LOOP, 10, 0);
                _zid.body.anim_rate = pvz_lawn_zombie_anim_rate(_zid.body, _zid.move_speed);
            }
            _zid.body.x = _zid.x; _zid.body.y = _zid.y - 6;
            return true;
        }
        var _gtarget = pvz_lawn_find_plant(_zid, 78);
        if (instance_exists(_gtarget) && _zid.x <= _gtarget.x + 65 && _zid.x >= _gtarget.x - 12) {
            _zid.phase = "garg_smashing";
            _zid.target_plant = _gtarget;
            _zid.special_triggered = false;
            _zid.eating = false;
            _zid.body.play("anim_smash", ReanimLoop.PLAY_ONCE_AND_HOLD, 10, 16.0);
            _zid.special_counter = max(1, round(_zid.body.frame_count / 16.0 * 100.0));
            return true;
        }
        _zid.x -= _ground_speed;
        _zid.body.x = _zid.x; _zid.body.y = _zid.y - 6;
        if (_zid.x < -180) instance_destroy(_zid);
        return true;
    }

    if (_kind == "boss") {
        _zid.boss_age_ticks++;
        if (_zid.phase == "boss_enter") {
            if (_zid.body.loop_count > 0 || _zid.body.anim_time >= 1.0) {
                _zid.phase = "boss_idle";
                _zid.special_counter = irandom_range(100, 200);
                _zid.boss_stomp_counter = irandom_range(5500, 6500);
                _zid.boss_summon_counter = irandom_range(450, 550);
                _zid.boss_head_counter = irandom_range(4000, 5000);
                _zid.body.play("anim_idle", ReanimLoop.LOOP, 0, 6.0);
            }
            return true;
        }
        // Source UpdateBoss keeps independent cooldowns; stomps are intentionally several seconds apart.
        if (_zid.phase == "boss_idle") {
            _zid.special_counter--;
            _zid.boss_stomp_counter--;
            _zid.boss_summon_counter--;
            _zid.boss_head_counter--;
            if (_zid.special_counter <= 0) {
                if (_zid.boss_stomp_counter <= 0) {
                    _zid.phase = "boss_stomp";
                    _zid.boss_stomp_counter = irandom_range(5500, 6500);
                    _zid.boss_target_row = irandom(min(3, pvz_lawn_active_rows() - 1));
                    var _stomp_anim = "anim_stomp_" + string(_zid.boss_target_row + 1);
                    if (!_zid.body.track_exists(_stomp_anim)) _stomp_anim = "anim_stomp_1";
                    _zid.body.play(_stomp_anim, ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 12.0);
                    _zid.special_triggered = false;
                    _zid.special_counter = max(1, round(_zid.body.frame_count / 12.0 * 100.0));
                } else if (_zid.boss_head_counter <= 0) {
                    _zid.phase = "boss_head_enter";
                    _zid.boss_head_counter = 4500;
                    _zid.boss_target_row = irandom(pvz_lawn_active_rows() - 1);
                    _zid.boss_fireball_kind = (irandom(1) == 0) ? "fire" : "ice";
                    _zid.body.play("anim_head_enter", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 12.0);
                    _zid.special_counter = max(1, round(_zid.body.frame_count / 12.0 * 100.0));
                    _zid.special_triggered = false;
                } else if (_zid.boss_summon_counter <= 0) {
                    _zid.phase = "boss_spawn";
                    _zid.boss_summon_counter = irandom_range(450, 550);
                    _zid.boss_target_row = irandom(pvz_lawn_active_rows() - 1);
                    var _spawn_anim = "anim_spawn_" + string(_zid.boss_target_row + 1);
                    if (!_zid.body.track_exists(_spawn_anim)) _spawn_anim = "anim_spawn_1";
                    _zid.body.play(_spawn_anim, ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 12.0);
                    _zid.special_counter = max(1, round(_zid.body.frame_count / 12.0 * 100.0));
                    _zid.special_triggered = false;
                } else {
                    _zid.special_counter = irandom_range(100, 200);
                    _zid.body.play("anim_idle", ReanimLoop.LOOP, 0, 6.0);
                }
            }
            return true;
        }
        _zid.special_counter--;
        if (_zid.phase == "boss_head_enter" && (_zid.body.loop_count > 0 || _zid.special_counter <= 0)) {
            _zid.phase = "boss_head_down";
            _zid.body.play("anim_head_idle", ReanimLoop.LOOP, 0, 12.0);
            _zid.special_counter = 500;
            return true;
        }
        if (_zid.phase == "boss_head_down" && _zid.special_counter <= 0) {
            _zid.phase = "boss_head_spit";
            var _head_anim = "anim_head_attack_" + string(_zid.boss_target_row + 1);
            if (!_zid.body.track_exists(_head_anim)) _head_anim = "anim_head_attack_1";
            _zid.body.play(_head_anim, ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 12.0);
            _zid.special_counter = max(1, round(_zid.body.frame_count / 12.0 * 100.0));
            _zid.special_triggered = false;
            return true;
        }
        if (_zid.phase == "boss_stomp" && _zid.body.anim_time >= ((_zid.boss_target_row >= 2) ? 0.55 : 0.5) && !_zid.special_triggered) {
            _zid.special_triggered = true;
            // BossStompContact squishes plants in the selected row and the row below,
            // restricted to the right-hand three lawn columns in the original PC fight.
            for (var _sr = _zid.boss_target_row; _sr <= min(pvz_lawn_active_rows() - 1, _zid.boss_target_row + 1); _sr++) {
                for (var _sc = 5; _sc < PVZ_COLS; _sc++) {
                    var _stomp_plant = global.pvz_lawn_grid[# _sc, _sr];
                    if (instance_exists(_stomp_plant)) pvz_lawn_plant_squish(_stomp_plant);
                }
            }
            pvz_lawn_play_sound("gargantuar_thump.ogg");
        }
        if (_zid.phase == "boss_spawn" && _zid.body.anim_time >= 0.6 && !_zid.special_triggered) {
            _zid.special_triggered = true;
            var _spawn_row = _zid.boss_target_row;
            // BossSpawnContact follows the source's zombie-age progression and late-game list.
            var _boss_spawn_kind = "basic";
            if (_zid.boss_age_ticks >= 3500 && _zid.boss_age_ticks < 8000) _boss_spawn_kind = "conehead";
            else if (_zid.boss_age_ticks >= 8000 && _zid.boss_age_ticks < 12500) _boss_spawn_kind = "buckethead";
            else if (_zid.boss_age_ticks >= 12500) {
                var _boss_late_kinds = ["conehead", "buckethead", "football", "polevaulter", "jackbox", "ladder", "zomboni", "catapult", "pogo", "newspaper", "screendoor", "gargantuar"];
                // The original omits Gargantuar from the top row's late-game selection.
                var _boss_pick_max = (_spawn_row == 0) ? array_length(_boss_late_kinds) - 2 : array_length(_boss_late_kinds) - 1;
                _boss_spawn_kind = _boss_late_kinds[irandom(_boss_pick_max)];
            }
            var _boss_spawn_object = obj_zombie_basic;
            switch (_boss_spawn_kind) {
                case "conehead": _boss_spawn_object = obj_zombie_conehead; break;
                case "buckethead": _boss_spawn_object = obj_zombie_buckethead; break;
                case "football": _boss_spawn_object = obj_zombie_football; break;
                case "polevaulter": _boss_spawn_object = obj_zombie_polevaulter; break;
                case "jackbox": _boss_spawn_object = obj_zombie_jack_in_the_box; break;
                case "ladder": _boss_spawn_object = obj_zombie_ladder; break;
                case "zomboni": _boss_spawn_object = obj_zombie_zomboni; break;
                case "catapult": _boss_spawn_object = obj_zombie_catapult; break;
                case "pogo": _boss_spawn_object = obj_zombie_pogo; break;
                case "newspaper": _boss_spawn_object = obj_zombie_newspaper; break;
                case "screendoor": _boss_spawn_object = obj_zombie_screendoor; break;
                case "gargantuar": _boss_spawn_object = obj_zombie_gargantuar; break;
            }
            // Original boss-spawn entry point places one zombie at x=600 in the selected row.
            instance_create_layer(600, pvz_lawn_row_y(_spawn_row, 600, -30), "Instances", _boss_spawn_object, {row:_spawn_row});
        }
        if (_zid.phase == "boss_head_spit" && _zid.body.anim_time >= 0.42 && !_zid.special_triggered) {
            _zid.special_triggered = true;
            var _ball_y = pvz_lawn_row_y(_zid.boss_target_row, 550, -90);
            var _ball = instance_create_layer(455, _ball_y, "Instances", obj_pvz_boss_projectile, {projectile_row:_zid.boss_target_row, projectile_kind:(variable_instance_exists(_zid, "boss_fireball_kind") ? _zid.boss_fireball_kind : "fire")});
            pvz_lawn_play_sound("bossboulderattack.ogg");
        }
        if (_zid.phase == "boss_head_spit" && (_zid.body.loop_count > 0 || _zid.special_counter <= 0)) {
            _zid.phase = "boss_head_idle_after_spit";
            _zid.body.play("anim_head_idle", ReanimLoop.LOOP, 0, 12.0);
            _zid.special_counter = 300;
            _zid.special_triggered = false;
            return true;
        }
        if (_zid.phase == "boss_head_idle_after_spit" && _zid.special_counter <= 0) {
            _zid.phase = "boss_head_leave";
            _zid.body.play("anim_head_leave", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 12.0);
            _zid.special_counter = max(1, round(_zid.body.frame_count / 12.0 * 100.0));
            return true;
        }
        if (_zid.phase == "boss_head_leave" && (_zid.body.loop_count > 0 || _zid.special_counter <= 0)) {
            _zid.phase = "boss_idle";
            _zid.special_counter = irandom_range(100, 200);
            _zid.body.play("anim_idle", ReanimLoop.LOOP, 10, 6.0);
            return true;
        }
        if (_zid.special_counter <= 0 || _zid.body.loop_count > 0) {
            _zid.phase = "boss_idle";
            _zid.special_counter = irandom_range(100, 200);
            _zid.special_triggered = false;
            _zid.body.play("anim_idle", ReanimLoop.LOOP, 10, 6.0);
        }
        return true;
    }
    return false;
}

function pvz_lawn_potato_mine_find_trigger(_plant_id) {
    if (!instance_exists(_plant_id)) return false;

    var _plant_left = _plant_id.x;
    var _plant_right = _plant_left + 55.0; // OG attack width: 80px plant width - 25px.
    var _plant_top = _plant_id.y;
    var _plant_bottom = _plant_top + 80.0;
    var _row = _plant_id.cell_row;
    var _triggered = false;
    var _closest_distance = 1000.0; // Plant::DistanceToClosestZombie default.
    var _zombie_objects = [obj_zombie_base];

    for (var _oi = 0; _oi < array_length(_zombie_objects); _oi++) {
        var _zombie_object = _zombie_objects[_oi];
        var _zombie_count = instance_number(_zombie_object);
        for (var _zi = _zombie_count - 1; _zi >= 0; _zi--) {
            var _zid = instance_find(_zombie_object, _zi);
            if (!instance_exists(_zid) || _zid.dead || _zid.intro_preview || !_zid.has_head || _zid.row != _row) continue;
            if (pvz_lawn_zombie_ignores_ground_collision(_zid)) continue;
            // A Pole Vaulter cannot trigger a mine while pre-vault or in the jump arc.
            if (_zid.zombie_kind == "polevaulter" && (_zid.phase == "pre_vault" || _zid.phase == "vault")) continue;

            var _zrect = pvz_lawn_zombie_hitbox(_zid);
            var _zombie_left = _zrect[0];
            var _zombie_right = _zrect[2];
            var _zombie_top = _zrect[1];
            var _zombie_bottom = _zrect[3];
            var _dx = max(0.0, max(_plant_left - _zombie_right, _zombie_left - _plant_right));
            var _dy = max(0.0, max(_plant_top - _zombie_bottom, _zombie_top - _plant_bottom));
            var _distance = sqrt(sqr(_dx) + sqr(_dy));
            _closest_distance = min(_closest_distance, _distance);

            if (_zombie_right > _plant_left && _zombie_left < _plant_right
                && _zombie_bottom > _plant_top && _zombie_top < _plant_bottom) {
                _triggered = true;
            }
        }
    }

    _plant_id.mine_closest_distance = _closest_distance;
    return _triggered;
}

function pvz_lawn_plant_explode(_plant_id, _damage, _radius, _row_radius = 1, _center_offset_x = 40, _mode = "damage") {
    if (!instance_exists(_plant_id)) return;
    var _blast_x = _plant_id.x + _center_offset_x;
    var _blast_y = _plant_id.y + 40;
    var _blast_row = _plant_id.cell_row;
    // PvZ Board::KillAllZombiesInRadius tests the circle against Zombie::GetZombieRect,
    // not the distance to the zombie center. Pole Vaulter's left edge is x+50; normal is x+36.
    var _zombie_objects = [obj_zombie_base];
    for (var _oi = 0; _oi < array_length(_zombie_objects); _oi++) {
        var _obj = _zombie_objects[_oi];
        var _count = instance_number(_obj);
        for (var _zi = _count - 1; _zi >= 0; _zi--) {
            var _zid = instance_find(_obj, _zi);
            if (!instance_exists(_zid) || _zid.dead || _zid.intro_preview) continue;
            if (_zid.zombie_kind != "boss" && abs(_zid.row - _blast_row) > _row_radius) continue;
            if (pvz_lawn_zombie_ignores_ground_collision(_zid)) continue;
            var _zrect = pvz_lawn_zombie_hitbox(_zid);
            var _left = _zrect[0];
            var _right = _zrect[2];
            var _top = _zrect[1];
            var _bottom = _zrect[3];
            var _near_x = clamp(_blast_x, _left, _right);
            var _near_y = clamp(_blast_y, _top, _bottom);
            if (sqr(_near_x - _blast_x) + sqr(_near_y - _blast_y) > sqr(_radius)) continue;
            if (_mode == "burn") pvz_lawn_zombie_apply_burn(_zid);
            // PvZ potato mine uses 1800 damage with DAMAGE_DOESNT_LEAVE_BODY.
            // This suppresses a corpse only when that hit is lethal; it is not an unconditional kill.
            else if (_mode == "no_body") pvz_lawn_zombie_take_damage(_zid, _damage, true);
            else pvz_lawn_zombie_take_damage(_zid, _damage);
        }
    }
}

function pvz_lawn_load_sprite(_file, _frames) {
    var _p = working_directory + "pvzfx/" + _file;
    if (!file_exists(_p)) _p = working_directory + "datafiles/pvzfx/" + _file;
    if (!file_exists(_p)) _p = working_directory + "datafiles/particles/" + _file;
    if (!file_exists(_p)) _p = working_directory + "particles/" + _file;
    if (!file_exists(_p)) _p = working_directory + "datafiles/images/" + _file;
    if (!file_exists(_p)) _p = working_directory + "images/" + _file;
    if (!file_exists(_p)) return -1;
    return sprite_add(_p, _frames, false, true, 0, 0);
}

function pvz_lawn_set_reanim_flash(_body, _count, _kind) {
    if (is_undefined(_body) || _body == noone) return;
    if (_kind == "zombie") {
        var _gray = clamp(_count * 10, 0, 255);
        _body.flash_color = make_color_rgb(_gray, _gray, _gray);
        _body.flash_alpha = _count > 0 ? 1.0 : 0.0;
    } else {
        // Plant::UpdateReanim uses an additive grayscale overlay, Color(countdown*3),
        // with full overlay alpha (as opposed to a translucent white normal-blend wash).
        var _grayness = clamp(_count * 3, 0, 255);
        _body.flash_color = make_color_rgb(_grayness, _grayness, _grayness);
        _body.flash_alpha = _count > 0 ? 1.0 : 0.0;
    }

    // PvZ draws each attached zombie part through DrawZombiePart too. Propagate the
    // hit flash so the head, arms, and armor flash with the body even while chilled-blue.
    if (variable_struct_exists(_body, "attached")) {
        for (var _track = 0; _track < array_length(_body.attached); _track++) {
            for (var _child = 0; _child < array_length(_body.attached[_track]); _child++) {
                pvz_lawn_set_reanim_flash(_body.attached[_track][_child], _count, _kind);
            }
        }
    }
}

function pvz_lawn_track_sprite(_body, _track_name) {
    if (is_undefined(_body) || _body == noone || _body.def == undefined) return -1;
    var _ti = _body.find_track(_track_name);
    if (_ti < 0) return -1;
    var _tt = _body.def.tracks[_ti].t;
    for (var _f = 0; _f < array_length(_tt); _f++) {
        var _img = _tt[_f][RT_IMG];
        if (_img >= 0 && _img < array_length(_body.def.sprites)) {
            var _spr = _body.def.sprites[_img];
            if (_spr >= 0) return _spr;
        }
    }
    return -1;
}

function pvz_lawn_track_world_pos(_body, _track_name, _fallback_x, _fallback_y) {
    if (is_undefined(_body) || _body == noone || _body.def == undefined) return [_fallback_x, _fallback_y];
    var _ti = _body.find_track(_track_name);
    if (_ti < 0) return [_fallback_x, _fallback_y];
    var _xf = _body.get_current_transform(_ti);
    return [_body.x + _xf[RT_X], _body.y + _xf[RT_Y]];
}


/// Temporarily shift every attachment overlay while drawing a world-space reanimation.
/// Reanim attachments cache their world matrix during Update(), so changing only the root x
/// would leave attached heads/blinks behind during a camera pan.
function pvz_lawn_reanim_shift_children(_reanim, _offset_x) {
    if (is_undefined(_reanim) || _reanim == noone || _reanim.def == undefined) return;
    for (var _track = 0; _track < _reanim.track_count; _track++) {
        var _child_count = array_length(_reanim.attached[_track]);
        for (var _child_index = 0; _child_index < _child_count; _child_index++) {
            var _child = _reanim.attached[_track][_child_index];
            if (_child.overlay != undefined) {
                var _matrix = _child.overlay;
                _matrix[2] += _offset_x;
                _child.overlay = _matrix;
            }
            pvz_lawn_reanim_shift_children(_child, _offset_x);
        }
    }
}

/// Draw one root reanimation in screen space without changing simulation/world coordinates.
function pvz_lawn_reanim_draw_camera(_reanim, _world_x, _world_y, _camera_x) {
    if (is_undefined(_reanim) || _reanim == noone) return;
    _reanim.x = _world_x - _camera_x;
    _reanim.y = _world_y;
    pvz_lawn_reanim_shift_children(_reanim, -_camera_x);
    _reanim.draw();
    pvz_lawn_reanim_shift_children(_reanim, _camera_x);
    _reanim.x = _world_x;
    _reanim.y = _world_y;
}

function pvz_lawn_use_later_track_image(_body, _track_name) {
    if (is_undefined(_body) || _body == noone || _body.def == undefined) return;
    var _ti = _body.find_track(_track_name);
    if (_ti < 0) return;
    var _tt = _body.def.tracks[_ti].t;
    var _first_img = -1;
    for (var _f = 0; _f < array_length(_tt); _f++) {
        var _img = _tt[_f][RT_IMG];
        if (_img < 0 || _img >= array_length(_body.def.sprites)) continue;
        if (_first_img < 0) _first_img = _img;
        else if (_img != _first_img && _body.def.sprites[_img] >= 0) {
            _body.track_sprite_override[_ti] = _body.def.sprites[_img];
            return;
        }
    }
}

function pvz_lawn_spawn_piece(_sprite, _x, _y, _vx, _vy, _spin, _life, _kind, _gravity, _ground_offset, _reflect, _fade_start, _scale) {
    // Image layers remain source assets; motion/ground response mirrors the original FX XML values.
    if (_sprite < 0 && _kind != "cone" && _kind != "bucket" && _kind != "nut") return noone;
    return instance_create_layer(_x, _y, "Instances", obj_pvz_lawn_fx_piece, {
        fx_sprite: _sprite, fx_vx: _vx, fx_vy: _vy, fx_spin: _spin,
        fx_life: _life, fx_kind: _kind, fx_gravity: _gravity,
        fx_ground_y: _y + _ground_offset, fx_reflect: _reflect,
        fx_fade_start: _fade_start, fx_scale: _scale
    });
}

// Original PvZ Foley loader. Audio files are kept beside the JSON/Reanim data in datafiles/sounds,
// so the full asset pack can be shipped with the project and the sound streams are cached on first use.
/// PVZ_XML_LOADER_REV 2
/// Runtime loader for original PopCap/PvZ particle XML definitions.
/// Reads datafiles/particles/<name>.xml (or particles/<name>.xml), parses each Emitter,
/// resolves IMAGE_* sprite sheets from the loose asset folders, and simulates the emitter in GML.

function pvz_lawn_particle_read_xml(_requested_name) {
    var _file_name = _requested_name;
    if (string_pos(".xml", string_lower(_file_name)) <= 0) _file_name += ".xml";

    var _paths = [
        working_directory + "datafiles/particles/" + _file_name,
        working_directory + "particles/" + _file_name
    ];
    var _path = "";
    for (var _i = 0; _i < array_length(_paths); _i++) {
        if (file_exists(_paths[_i])) { _path = _paths[_i]; break; }
    }

    if (_path == "") {
        if (!variable_global_exists("pvz_lawn_particle_missing_xml")) global.pvz_lawn_particle_missing_xml = {};
        var _missing_key = string_lower(_file_name);
        if (!variable_struct_exists(global.pvz_lawn_particle_missing_xml, _missing_key)) {
            variable_struct_set(global.pvz_lawn_particle_missing_xml, _missing_key, true);
            show_debug_message("PvZ particle XML missing: datafiles/particles/" + _file_name);
        }
        return "";
    }

    var _file = file_text_open_read(_path);
    if (_file < 0) {
        show_debug_message("PvZ particle XML could not be opened: " + _path);
        return "";
    }

    var _xml = "";
    while (!file_text_eof(_file)) _xml += file_text_readln(_file) + "\n";
    file_text_close(_file);
    return _xml;
}

/// Return the text inside the first exact <Tag>...</Tag> pair, or a fallback.
function pvz_lawn_particle_xml_tag(_source, _tag, _fallback = "") {
    var _open = "<" + _tag + ">";
    var _close = "</" + _tag + ">";
    var _start = string_pos(_open, _source);
    if (_start <= 0) return _fallback;
    _start += string_length(_open);
    var _tail = string_copy(_source, _start, string_length(_source) - _start + 1);
    var _end = string_pos(_close, _tail);
    if (_end <= 0) return _fallback;
    return string_trim(string_copy(_tail, 1, _end - 1));
}

/// Parse the first numeric value/range in a PopCap XML value.
/// Examples: "[100 120]" -> [100,120], "40 0" -> [40,40], "1,80 0" -> [1,1].
function pvz_lawn_particle_xml_range(_value, _default_min = 0, _default_max = 0) {
    var _s = string_trim(_value);
    if (_s == "") return [_default_min, _default_max];

    var _open = string_pos("[", _s);
    if (_open > 0) {
        var _inside_tail = string_copy(_s, _open + 1, string_length(_s) - _open);
        var _close = string_pos("]", _inside_tail);
        if (_close > 0) {
            var _inside = string_trim(string_copy(_inside_tail, 1, _close - 1));
            // Multiple spaces are allowed between the two values.
            while (string_length(_inside) > 0 && string_char_at(_inside, 1) == " ") _inside = string_delete(_inside, 1, 1);
            var _space = string_pos(" ", _inside);
            if (_space > 0) {
                var _left_text = string_trim(string_copy(_inside, 1, _space - 1));
                var _right_text = string_trim(string_copy(_inside, _space + 1, string_length(_inside) - _space));
                while (string_length(_right_text) > 0 && string_char_at(_right_text, 1) == " ") _right_text = string_delete(_right_text, 1, 1);
                var _right_space = string_pos(" ", _right_text);
                if (_right_space > 0) _right_text = string_copy(_right_text, 1, _right_space - 1);
                var _a = real(_left_text);
                var _b = real(_right_text);
                return [min(_a, _b), max(_a, _b)];
            }
            var _single = real(_inside);
            return [_single, _single];
        }
    }

    var _cut = string_length(_s) + 1;
    var _space0 = string_pos(" ", _s);
    var _comma0 = string_pos(",", _s);
    if (_space0 > 0) _cut = min(_cut, _space0);
    if (_comma0 > 0) _cut = min(_cut, _comma0);
    var _n = real(string_trim(string_copy(_s, 1, _cut - 1)));
    return [_n, _n];
}

/// For values such as "1,80 0", use the percentage after the comma as the alpha fade start.
function pvz_lawn_particle_xml_fade_start(_value, _fallback = 0.9) {
    var _comma = string_pos(",", _value);
    if (_comma <= 0) return _fallback;
    var _tail = string_trim(string_copy(_value, _comma + 1, string_length(_value) - _comma));
    var _space = string_pos(" ", _tail);
    if (_space > 0) _tail = string_copy(_tail, 1, _space - 1);
    return clamp(real(_tail) / 100.0, 0.0, 1.0);
}

/// Resolve the original IMAGE_* identifiers to the exact filenames shipped in the PvZ asset pack.
/// Keep the original case in the path (important if the project is moved off Windows).
function pvz_lawn_particle_image_filename(_image_id) {
    var _key = string_lower(_image_id);
    switch (_key) {
        case "image_dirtsmall": return "dirtsmall.png";
        case "image_pea_splats": return "pea_splats.png";
        case "image_pea_particles": return "Pea_particles.png";
        case "image_wallnutparticlessmall": return "WallnutParticlesSmall.png";
        case "image_wallnutparticleslarge": return "WallnutParticlesLarge.png";
        case "image_snowpea_splats": return "SnowPea_splats.png";
        case "image_snowflakes": return "SnowFlakes.png";
        case "image_snowpea_particles": return "SnowPea_particles.png";
        case "image_snowpea_puff": return "SnowPea_puff.png";
        case "image_explosioncloud": return "ExplosionCloud.png";
        case "image_explosionpowie": return "ExplosionPowie.png";
        case "image_explosionspudow": return "ExplosionSpudow.png";
        case "image_potatomineflash": return "PotatoMineFlash.png";
        case "image_potatomine_particles": return "PotatoMine_particles.png";
        case "image_reanim_potatomine_mashed": return "PotatoMine_mashed.png";
        case "image_star_splats": return "Star_splats.png";
        case "image_star_particles": return "Star_particles.png";
        default: return string_lower(string_replace(_image_id, "IMAGE_", "")) + ".png";
    }
}

/// The original resources manifest specifies DIRTSMALL as an 8x2 sheet; XML ImageRow selects a row.
function pvz_lawn_particle_image_rows(_image_id) {
    switch (string_lower(_image_id)) {
        case "image_dirtsmall": return 2;
        default: return 1;
    }
}

/// Decode one PopCap numeric key track of the form "start,time end" (for example "0.0,40 .1").
/// Returns [value_at_start, value_after_key, key_time_fraction]. Constant values return the same endpoints.
function pvz_lawn_particle_xml_track(_value, _fallback = 0) {
    var _text = string_trim(_value);
    if (_text == "") return [_fallback, _fallback, 1.0];
    var _comma = string_pos(",", _text);
    if (_comma <= 0) {
        var _range = pvz_lawn_particle_xml_range(_text, _fallback, _fallback);
        return [_range[0], _range[0], 1.0];
    }
    var _before = string_trim(string_copy(_text, 1, _comma - 1));
    var _tail = string_trim(string_copy(_text, _comma + 1, string_length(_text) - _comma));

    // Most tracks are "start,keyPercent end". Some original particle XML files
    // (including PotatoMine.xml) store "start end,keyPercent", e.g. ".2 .1,30".
    // Handle that two-value form before real() is given the whole ".2 .1" string.
    var _space_before = string_pos(" ", _before);
    if (_space_before > 0 && string_pos(" ", _tail) <= 0
        && string_pos("[", _before) <= 0 && string_pos("]", _before) <= 0) {
        var _start_value = real(string_trim(string_copy(_before, 1, _space_before - 1)));
        var _end_value = real(string_trim(string_copy(_before, _space_before + 1, string_length(_before) - _space_before)));
        var _key_value = real(_tail);
        var _key_time = (_key_value > 1.0) ? _key_value / 100.0 : _key_value;
        return [_start_value, _end_value, clamp(_key_time, 0.001, 1.0)];
    }

    var _start = real(_before);
    var _space = string_pos(" ", _tail);
    if (_space <= 0) return [_start, _start, 1.0];
    var _time = clamp(real(string_trim(string_copy(_tail, 1, _space - 1))) / 100.0, 0.0, 1.0);
    var _end_text = string_trim(string_copy(_tail, _space + 1, string_length(_tail) - _space));
    // A few original XML tracks contain more than one later key, e.g. "0.4,20 0.6,80 0.2,100".
    // Scale tracks are kept as full curves by pvz_lawn_particle_xml_scale_track; for other
    // scalar callers, safely reduce the remainder to its last numeric key rather than real()ing
    // a whole multi-key string (which crashes the runtime).
    if (string_pos(",", _end_text) > 0) {
        var _end_tokens = string_split(_end_text, " ");
        var _last_end_token = string_trim(_end_tokens[array_length(_end_tokens) - 1]);
        var _last_end_comma = string_pos(",", _last_end_token);
        if (_last_end_comma > 0) {
            var _last_end_value = real(string_trim(string_copy(_last_end_token, 1, _last_end_comma - 1)));
            var _last_end_time_value = real(string_trim(string_copy(_last_end_token, _last_end_comma + 1, string_length(_last_end_token) - _last_end_comma)));
            var _last_end_time = (_last_end_time_value > 1.0) ? _last_end_time_value / 100.0 : _last_end_time_value;
            return [_start, _last_end_value, max(0.001, clamp(_last_end_time, 0.0, 1.0))];
        } else if (array_length(_end_tokens) > 1) {
            // Also tolerate tracks whose last value is written without an explicit key time.
            var _final_value = real(_last_end_token);
            return [_start, _final_value, 1.0];
        }
    }
    var _end = real(_end_text);
    return [_start, _end, max(0.001, _time)];
}

/// Parse original particle RGB tracks. A two-number value such as ".7 0" means fade from .7 to 0;
/// bracketed values are randomized once for each particle.
function pvz_lawn_particle_xml_color_track(_value, _fallback = 1) {
    var _text = string_trim(_value);
    if (_text == "") return [_fallback, _fallback, 1.0, false];
    if (string_pos("[", _text) > 0) {
        var _range = pvz_lawn_particle_xml_range(_text, _fallback, _fallback);
        return [_range[0], _range[1], 1.0, true];
    }
    if (string_pos(",", _text) > 0) {
        var _track = pvz_lawn_particle_xml_track(_text, _fallback);
        return [_track[0], _track[1], _track[2], false];
    }
    var _space = string_pos(" ", _text);
    if (_space > 0) {
        var _first = real(string_trim(string_copy(_text, 1, _space - 1)));
        var _rest = string_trim(string_copy(_text, _space + 1, string_length(_text) - _space));
        var _next_space = string_pos(" ", _rest);
        if (_next_space > 0) _rest = string_copy(_rest, 1, _next_space - 1);
        return [_first, real(_rest), 1.0, false];
    }
    var _constant = real(_text);
    return [_constant, _constant, 1.0, false];
}

function pvz_lawn_particle_find_image_path(_base) {
    var _paths = [
        working_directory + "datafiles/particles/" + _base,
        working_directory + "particles/" + _base,
        working_directory + "datafiles/pvzfx/" + _base,
        working_directory + "pvzfx/" + _base,
        working_directory + "datafiles/images/" + _base,
        working_directory + "images/" + _base,
        working_directory + "datafiles/parts/images/" + _base,
        working_directory + "datafiles/parts/reanim/" + _base
    ];
    for (var _i = 0; _i < array_length(_paths); _i++) {
        if (file_exists(_paths[_i])) return _paths[_i];
    }
    return "";
}

/// Load/crop every frame referenced by an IMAGE_* entry. PvZ particle sheets often have
/// multiple rows (e.g. dirtsmall.png), while GameMaker sprites are normally single-row strips.
/// The XML ImageRow selects which row to use; generated frame sprites are cached per sheet/row.
function pvz_lawn_particle_load_image(_image_id, _frames, _row = 0) {
    if (_image_id == "") return [-1];
    var _base = pvz_lawn_particle_image_filename(_image_id);
    var _frame_count = max(1, round(_frames));
    var _requested_row = max(0, round(_row));
    var _key = _base + "#" + string(_frame_count) + "#" + string(_requested_row);

    if (!variable_global_exists("pvz_lawn_particle_sprite_cache")) global.pvz_lawn_particle_sprite_cache = {};
    if (variable_struct_exists(global.pvz_lawn_particle_sprite_cache, _key)) {
        return variable_struct_get(global.pvz_lawn_particle_sprite_cache, _key);
    }

    if (!variable_global_exists("pvz_lawn_particle_sheet_cache")) global.pvz_lawn_particle_sheet_cache = {};
    var _sheet = -1;
    if (variable_struct_exists(global.pvz_lawn_particle_sheet_cache, _base)) {
        _sheet = variable_struct_get(global.pvz_lawn_particle_sheet_cache, _base);
    } else {
        var _path = pvz_lawn_particle_find_image_path(_base);
        if (_path != "") _sheet = sprite_add(_path, 1, false, true, 0, 0);
        variable_struct_set(global.pvz_lawn_particle_sheet_cache, _base, _sheet);
    }

    var _result = [];
    if (_sheet >= 0) {
        var _sheet_width = sprite_get_width(_sheet);
        var _sheet_height = sprite_get_height(_sheet);
        // Use the original Resources manifest's ImageRow count. A one-frame, one-row image
        // such as PotatoMine_mashed.png needs no crop at all; avoiding a surface round-trip
        // prevents the particle loader from falsely reporting valid single-frame art as missing.
        var _row_count = max(1, pvz_lawn_particle_image_rows(_image_id));
        if (_frame_count == 1 && _row_count == 1) {
            sprite_set_offset(_sheet, floor(_sheet_width * 0.5), floor(_sheet_height * 0.5));
            _result = [_sheet];
        } else {
            var _frame_width = max(1, floor(_sheet_width / _frame_count));
            var _frame_height = max(1, floor(_sheet_height / _row_count));
            _requested_row = clamp(_requested_row, 0, _row_count - 1);
            var _source_y = _requested_row * _frame_height;

            for (var _frame = 0; _frame < _frame_count; _frame++) {
                var _surf = surface_create(_frame_width, _frame_height);
                var _frame_sprite = -1;
                if (surface_exists(_surf)) {
                    surface_set_target(_surf);
                    draw_clear_alpha(c_black, 0);
                    draw_sprite_part(_sheet, 0, _frame * _frame_width, _source_y,
                        _frame_width, _frame_height, 0, 0);
                    surface_reset_target();
                    _frame_sprite = sprite_create_from_surface(_surf, 0, 0,
                        _frame_width, _frame_height, false, false,
                        floor(_frame_width * 0.5), floor(_frame_height * 0.5));
                    surface_free(_surf);
                }
                array_push(_result, _frame_sprite);
            }
        }
    }

    if (array_length(_result) != _frame_count) _result = [];
    var _usable = false;
    for (var _j = 0; _j < array_length(_result); _j++) if (_result[_j] >= 0) _usable = true;
    if (!_usable) {
        _result = [-1];
        if (!variable_global_exists("pvz_lawn_particle_missing_images")) global.pvz_lawn_particle_missing_images = {};
        if (!variable_struct_exists(global.pvz_lawn_particle_missing_images, _key)) {
            variable_struct_set(global.pvz_lawn_particle_missing_images, _key, true);
            show_debug_message("PvZ particle image missing or could not be cropped: " + _base + " (referenced by " + _image_id + ")");
        }
    }
    variable_struct_set(global.pvz_lawn_particle_sprite_cache, _key, _result);
    return _result;
}

/// Parse every <Emitter> block in one original XML particle definition.
function pvz_lawn_particle_load_definition(_requested_name) {
    var _file_name = _requested_name;
    if (string_pos(".xml", string_lower(_file_name)) <= 0) _file_name += ".xml";
    var _cache_key = string_lower(_file_name);

    if (!variable_global_exists("pvz_lawn_particle_definition_cache")) global.pvz_lawn_particle_definition_cache = {};
    if (variable_struct_exists(global.pvz_lawn_particle_definition_cache, _cache_key)) {
        return variable_struct_get(global.pvz_lawn_particle_definition_cache, _cache_key);
    }

    var _xml = pvz_lawn_particle_read_xml(_file_name);
    if (_xml == "") return [];

    var _emitters = [];
    var _xml_len = string_length(_xml);
    var _cursor = 1;
    var _open_tag = "<Emitter>";
    var _close_tag = "</Emitter>";
    var _open_len = string_length(_open_tag);
    var _close_len = string_length(_close_tag);

    while (_cursor <= _xml_len) {
        var _remaining = string_copy(_xml, _cursor, _xml_len - _cursor + 1);
        var _open_rel = string_pos(_open_tag, _remaining);
        if (_open_rel <= 0) break;
        var _open_abs = _cursor + _open_rel - 1;
        var _body_start = _open_abs + _open_len;
        var _tail = string_copy(_xml, _body_start, _xml_len - _body_start + 1);
        var _close_rel = string_pos(_close_tag, _tail);
        if (_close_rel <= 0) break;
        var _block = string_copy(_xml, _body_start, _close_rel - 1);
        _cursor = _body_start + _close_rel - 1 + _close_len;

        var _image_id = pvz_lawn_particle_xml_tag(_block, "Image", "");
        var _image_frames_raw = pvz_lawn_particle_xml_tag(_block, "ImageFrames", "1");
        var _image_frames_range = pvz_lawn_particle_xml_range(_image_frames_raw, 1, 1);
        var _image_frames = max(1, round(_image_frames_range[0]));
        var _image_row = max(0, round(real(pvz_lawn_particle_xml_tag(_block, "ImageRow", "0"))));
        var _sprites = pvz_lawn_particle_load_image(_image_id, _image_frames, _image_row);
        var _sprite = array_length(_sprites) > 0 ? _sprites[0] : -1;

        var _spawn_rate_raw = pvz_lawn_particle_xml_tag(_block, "SpawnRate", "");
        var _spawn_rate_range = pvz_lawn_particle_xml_range(_spawn_rate_raw, 1, 1);
        var _spawn_rate = max(1, round(_spawn_rate_range[0]));
        var _min_active_raw = pvz_lawn_particle_xml_tag(_block, "SpawnMinActive", "");
        var _min_active_range = pvz_lawn_particle_xml_range(_min_active_raw, 0, 0);
        var _max_launched_raw = pvz_lawn_particle_xml_tag(_block, "SpawnMaxLaunched", "");
        var _max_launched = -1;
        if (_max_launched_raw != "") {
            var _max_launched_range = pvz_lawn_particle_xml_range(_max_launched_raw, 1, 1);
            _max_launched = max(1, round(_max_launched_range[0]));
        }
        // A one-shot emitter with no explicit rate/count should still launch one particle.
        if (_min_active_raw == "" && _spawn_rate_raw == "") {
            _min_active_range = [1, 1];
        }

        var _particle_duration_range = pvz_lawn_particle_xml_range(pvz_lawn_particle_xml_tag(_block, "ParticleDuration", "30"), 30, 30);
        var _system_duration_range = pvz_lawn_particle_xml_range(pvz_lawn_particle_xml_tag(_block, "SystemDuration", "100"), 100, 100);
        // ParticleScale is a key track in PopCap XML, not just a single number or random range.
        // Examples: "10 15", ".5,60 0", and "[1.2 1.6],60 0".
        var _scale_track = pvz_lawn_particle_xml_scale_track(pvz_lawn_particle_xml_tag(_block, "ParticleScale", "[1 1]"));

        var _particle_alpha_raw = pvz_lawn_particle_xml_tag(_block, "ParticleAlpha", "1");
        var _particle_alpha_range = pvz_lawn_particle_xml_range(_particle_alpha_raw, 1, 1);
        var _particle_red = pvz_lawn_particle_xml_color_track(pvz_lawn_particle_xml_tag(_block, "ParticleRed", "1"), 1);
        var _particle_green = pvz_lawn_particle_xml_color_track(pvz_lawn_particle_xml_tag(_block, "ParticleGreen", "1"), 1);
        var _particle_blue = pvz_lawn_particle_xml_color_track(pvz_lawn_particle_xml_tag(_block, "ParticleBlue", "1"), 1);
        var _system_alpha_raw = pvz_lawn_particle_xml_tag(_block, "SystemAlpha", "1");
        var _system_alpha_range = pvz_lawn_particle_xml_range(_system_alpha_raw, 1, 1);
        var _spin_range = pvz_lawn_particle_xml_range(pvz_lawn_particle_xml_tag(_block, "ParticleSpinSpeed", "[0 0]"), 0, 0);
        var _speed_range = pvz_lawn_particle_xml_range(pvz_lawn_particle_xml_tag(_block, "LaunchSpeed", "[0 0]"), 0, 0);
        var _angle_raw = pvz_lawn_particle_xml_tag(_block, "LaunchAngle", "");
        var _angle_range = pvz_lawn_particle_xml_range(_angle_raw, 0, 0);
        // TodParticle.cpp randomizes the launch angle whenever its track is unset/constant zero.
        var _launch_angle_random = (_angle_raw == "" || (abs(_angle_range[0]) < 0.0001 && abs(_angle_range[1]) < 0.0001));
        var _radius_range = pvz_lawn_particle_xml_range(pvz_lawn_particle_xml_tag(_block, "EmitterRadius", "[0 0]"), 0, 0);
        var _offset_x_range = pvz_lawn_particle_xml_range(pvz_lawn_particle_xml_tag(_block, "EmitterOffsetX", "[0 0]"), 0, 0);
        var _offset_y_range = pvz_lawn_particle_xml_range(pvz_lawn_particle_xml_tag(_block, "EmitterOffsetY", "[0 0]"), 0, 0);
        var _random_spin = real(pvz_lawn_particle_xml_tag(_block, "RandomLaunchSpin", "0")) != 0;
        var _emitter_type = string_lower(pvz_lawn_particle_xml_tag(_block, "EmitterType", "Point"));

        var _gravity_y = 0;
        var _friction_x_track = [0, 0, 1];
        var _friction_y_track = [0, 0, 1];
        var _position_x_range = [0, 0];
        var _position_y_range = [0, 0];
        var _ground_enabled = false;
        var _ground_offset = 0;
        var _field_cursor = 1;
        var _field_open_tag = "<Field>";
        var _field_close_tag = "</Field>";
        var _field_open_len = string_length(_field_open_tag);
        var _field_close_len = string_length(_field_close_tag);
        var _block_len = string_length(_block);
        while (_field_cursor <= _block_len) {
            var _field_remaining = string_copy(_block, _field_cursor, _block_len - _field_cursor + 1);
            var _field_open_rel = string_pos(_field_open_tag, _field_remaining);
            if (_field_open_rel <= 0) break;
            var _field_open_abs = _field_cursor + _field_open_rel - 1;
            var _field_body_start = _field_open_abs + _field_open_len;
            var _field_tail = string_copy(_block, _field_body_start, _block_len - _field_body_start + 1);
            var _field_close_rel = string_pos(_field_close_tag, _field_tail);
            if (_field_close_rel <= 0) break;
            var _field_block = string_copy(_block, _field_body_start, _field_close_rel - 1);
            _field_cursor = _field_body_start + _field_close_rel - 1 + _field_close_len;

            var _field_type = string_lower(pvz_lawn_particle_xml_tag(_field_block, "FieldType", ""));
            var _field_x = pvz_lawn_particle_xml_tag(_field_block, "X", "");
            var _field_y = pvz_lawn_particle_xml_tag(_field_block, "Y", "");
            if (_field_type == "acceleration") {
                var _ay = pvz_lawn_particle_xml_range(_field_y, 0, 0);
                _gravity_y += _ay[0];
            } else if (_field_type == "friction") {
                var _fx = pvz_lawn_particle_xml_track(_field_x, 0);
                var _fy = pvz_lawn_particle_xml_track(_field_y, 0);
                // PopCap friction values are direct per-tick multipliers (0.08 means 8%, not 0.08%).
                if (abs(_fx[0]) + abs(_fx[1]) > abs(_friction_x_track[0]) + abs(_friction_x_track[1])) _friction_x_track = _fx;
                if (abs(_fy[0]) + abs(_fy[1]) > abs(_friction_y_track[0]) + abs(_friction_y_track[1])) _friction_y_track = _fy;
            } else if (_field_type == "position") {
                if (_field_x != "") _position_x_range = pvz_lawn_particle_xml_range(_field_x, 0, 0);
                if (_field_y != "") _position_y_range = pvz_lawn_particle_xml_range(_field_y, 0, 0);
            } else if (_field_type == "groundconstraint") {
                _ground_enabled = true;
                var _gy = pvz_lawn_particle_xml_range(_field_y, 0, 0);
                _ground_offset = _gy[0];
            }
        }

        var _name = pvz_lawn_particle_xml_tag(_block, "Name", _file_name);
        array_push(_emitters, {
            name: _name,
            sprite: _sprite,
            sprites: _sprites,
            image_id: _image_id,
            image_frames: _image_frames,
            image_row: _image_row,
            spawn_rate: _spawn_rate,
            has_spawn_rate: _spawn_rate_raw != "",
            min_active_min: max(0, round(_min_active_range[0])),
            min_active_max: max(0, round(_min_active_range[1])),
            max_launched: _max_launched,
            particle_duration_min: max(1, round(_particle_duration_range[0])),
            particle_duration_max: max(1, round(_particle_duration_range[1])),
            system_duration: max(1, round(_system_duration_range[0])),
            particle_scale_min: max(0.0, _scale_track[0]),
            particle_scale_max: max(0.0, _scale_track[1]),
            particle_scale_end_min: max(0.0, _scale_track[2]),
            particle_scale_end_max: max(0.0, _scale_track[3]),
            particle_scale_keytime: clamp(_scale_track[4], 0.001, 1.0),
            particle_scale_random_start: _scale_track[5],
            particle_scale_random_end: _scale_track[6],
            particle_scale_end_matches_start: _scale_track[7],
            particle_scale_curve_times: array_length(_scale_track) > 8 ? _scale_track[8] : [],
            particle_scale_curve_min: array_length(_scale_track) > 9 ? _scale_track[9] : [],
            particle_scale_curve_max: array_length(_scale_track) > 10 ? _scale_track[10] : [],
            particle_alpha: clamp(_particle_alpha_range[0], 0, 1),
            particle_fade_start: pvz_lawn_particle_xml_fade_start(_particle_alpha_raw, 0.9),
            particle_red_start: _particle_red[0],
            particle_red_end: _particle_red[1],
            particle_red_keytime: _particle_red[2],
            particle_red_random: _particle_red[3],
            particle_green_start: _particle_green[0],
            particle_green_end: _particle_green[1],
            particle_green_keytime: _particle_green[2],
            particle_green_random: _particle_green[3],
            particle_blue_start: _particle_blue[0],
            particle_blue_end: _particle_blue[1],
            particle_blue_keytime: _particle_blue[2],
            particle_blue_random: _particle_blue[3],
            system_alpha: clamp(_system_alpha_range[0], 0, 1),
            system_fade_start: pvz_lawn_particle_xml_fade_start(_system_alpha_raw, 0.9),
            spin_min: _spin_range[0],
            spin_max: _spin_range[1],
            launch_speed_min: _speed_range[0],
            launch_speed_max: _speed_range[1],
            launch_angle_min: _angle_range[0],
            launch_angle_max: _angle_range[1],
            launch_angle_random: _launch_angle_random,
            emitter_radius_min: _radius_range[0],
            emitter_radius_max: _radius_range[1],
            offset_x_min: _offset_x_range[0],
            offset_x_max: _offset_x_range[1],
            offset_y_min: _offset_y_range[0],
            offset_y_max: _offset_y_range[1],
            emitter_type: _emitter_type,
            random_launch_spin: _random_spin,
            gravity_y: _gravity_y,
            friction_x_start: _friction_x_track[0],
            friction_x_end: _friction_x_track[1],
            friction_x_keytime: _friction_x_track[2],
            friction_y_start: _friction_y_track[0],
            friction_y_end: _friction_y_track[1],
            friction_y_keytime: _friction_y_track[2],
            position_x_min: _position_x_range[0],
            position_x_max: _position_x_range[1],
            position_y_min: _position_y_range[0],
            position_y_max: _position_y_range[1],
            ground_enabled: _ground_enabled,
            ground_offset: _ground_offset
        });
    }

    variable_struct_set(global.pvz_lawn_particle_definition_cache, _cache_key, _emitters);
    if (array_length(_emitters) <= 0) show_debug_message("PvZ particle XML has no <Emitter> blocks: " + _file_name);
    return _emitters;
}

/// Parse PopCap particle scale tracks while keeping bracketed random ranges per particle.
/// Returns [start_min,start_max,end_min,end_max,keytime,random_start,random_end,end_matches_start].
function pvz_lawn_particle_xml_scale_track(_value) {
    var _text = string_trim(_value);
    if (_text == "") return [1, 1, 1, 1, 1.0, false, false, true];

    // PopCap's FloatParameterTrack supports a sequence of value,time keys, not only one
    // start/end pair. Examples include SnowPeaPuff.xml's ".2,0 .4,20 .6,80 .2,100"
    // and bracketed random ranges such as "[.4 1.5],10 [.4 1.5],70 0,100".
    // Split on spaces only outside brackets so that "[min max]" stays as one key.
    var _curve_tokens = [];
    var _curve_token = "";
    var _bracket_depth = 0;
    for (var _char_i = 1; _char_i <= string_length(_text); _char_i++) {
        var _ch = string_char_at(_text, _char_i);
        if (_ch == "[") _bracket_depth++;
        else if (_ch == "]") _bracket_depth = max(0, _bracket_depth - 1);
        if (_ch == " " && _bracket_depth == 0) {
            if (_curve_token != "") array_push(_curve_tokens, _curve_token);
            _curve_token = "";
        } else {
            _curve_token += _ch;
        }
    }
    if (_curve_token != "") array_push(_curve_tokens, _curve_token);
    if (array_length(_curve_tokens) >= 2) {
        var _curve_valid = true;
        var _curve_times = [];
        var _curve_min = [];
        var _curve_max = [];
        for (var _key_i = 0; _key_i < array_length(_curve_tokens); _key_i++) {
            var _key_token = string_trim(_curve_tokens[_key_i]);
            var _key_comma = string_pos(",", _key_token);
            if (_key_comma <= 0) {
                _curve_valid = false;
                break;
            }
            var _key_value_text = string_trim(string_copy(_key_token, 1, _key_comma - 1));
            var _key_time_text = string_trim(string_copy(_key_token, _key_comma + 1, string_length(_key_token) - _key_comma));
            var _key_range = pvz_lawn_particle_xml_range(_key_value_text, 1, 1);
            var _key_time_value = real(_key_time_text);
            var _key_time_norm = (_key_time_value > 1.0) ? _key_time_value / 100.0 : _key_time_value;
            array_push(_curve_times, clamp(_key_time_norm, 0.0, 1.0));
            array_push(_curve_min, _key_range[0]);
            array_push(_curve_max, _key_range[1]);
        }
        if (_curve_valid) {
            var _curve_last = array_length(_curve_times) - 1;
            // Keep the legacy first/end fields for callers that still need them, and also
            // expose all keyframes for exact per-particle scale interpolation in Draw.
            return [_curve_min[0], _curve_max[0], _curve_min[_curve_last], _curve_max[_curve_last], 1.0,
                _curve_min[0] != _curve_max[0], _curve_min[_curve_last] != _curve_max[_curve_last], false,
                _curve_times, _curve_min, _curve_max];
        }
    }

    var _comma = string_pos(",", _text);
    if (_comma > 0) {
        var _before = string_trim(string_copy(_text, 1, _comma - 1));
        var _tail = string_trim(string_copy(_text, _comma + 1, string_length(_text) - _comma));
        if (string_pos("[", _before) > 0) {
            var _start_range = pvz_lawn_particle_xml_range(_before, 1, 1);
            var _space = string_pos(" ", _tail);
            if (_space > 0) {
                var _key_value = real(string_trim(string_copy(_tail, 1, _space - 1)));
                var _key_time = (_key_value > 1.0) ? _key_value / 100.0 : _key_value;
                var _end_text = string_trim(string_copy(_tail, _space + 1, string_length(_tail) - _space));
                var _end_value = real(_end_text);
                return [_start_range[0], _start_range[1], _end_value, _end_value, clamp(_key_time, 0.001, 1.0), true, false, false];
            }
            return [_start_range[0], _start_range[1], _start_range[0], _start_range[1], 1.0, true, false, true];
        }

        var _track = pvz_lawn_particle_xml_track(_text, 1);
        return [_track[0], _track[0], _track[1], _track[1], _track[2], false, false, false];
    }

    if (string_pos("[", _text) > 0) {
        var _start_bracket_range = pvz_lawn_particle_xml_range(_text, 1, 1);
        var _second_bracket_range = pvz_lawn_particle_xml_second_range(_text);
        if (array_length(_second_bracket_range) >= 2) {
            return [_start_bracket_range[0], _start_bracket_range[1], _second_bracket_range[0], _second_bracket_range[1], 1.0, true, true, false];
        }
        return [_start_bracket_range[0], _start_bracket_range[1], _start_bracket_range[0], _start_bracket_range[1], 1.0, true, false, true];
    }

    // An unbracketed two-value scale is a start/end track, e.g. PotatoMine's 10-to-15 flash.
    var _space_plain = string_pos(" ", _text);
    if (_space_plain > 0) {
        var _start_value = real(string_trim(string_copy(_text, 1, _space_plain - 1)));
        var _tail_plain = string_trim(string_copy(_text, _space_plain + 1, string_length(_text) - _space_plain));
        var _space_again = string_pos(" ", _tail_plain);
        if (_space_again > 0) _tail_plain = string_copy(_tail_plain, 1, _space_again - 1);
        var _end_value_plain = real(_tail_plain);
        return [_start_value, _start_value, _end_value_plain, _end_value_plain, 1.0, false, false, false];
    }

    var _constant = real(_text);
    return [_constant, _constant, _constant, _constant, 1.0, false, false, true];
}

/// Read the second [min max] range in values such as "[.4 .6] [.8 1.2]".
function pvz_lawn_particle_xml_second_range(_value) {
    var _first_open = string_pos("[", _value);
    if (_first_open <= 0) return [];
    var _first_tail = string_copy(_value, _first_open + 1, string_length(_value) - _first_open);
    var _first_close = string_pos("]", _first_tail);
    if (_first_close <= 0) return [];
    var _after_first = _first_open + _first_close + 1;
    if (_after_first > string_length(_value)) return [];
    var _rest = string_copy(_value, _after_first, string_length(_value) - _after_first + 1);
    if (string_pos("[", _rest) <= 0) return [];
    return pvz_lawn_particle_xml_range(_rest, 0, 0);
}

function pvz_lawn_particle_count_children(_emitter_id) {
    var _count = 0;
    var _num = instance_number(obj_pvz_lawn_fx_piece);
    for (var _i = 0; _i < _num; _i++) {
        var _particle = instance_find(obj_pvz_lawn_fx_piece, _i);
        if (_particle != noone && _particle.fx_kind != "xml_emitter" && _particle.fx_parent_emitter == _emitter_id) _count++;
    }
    return _count;
}

/// Emit one child particle from an already-running XML emitter instance.
function pvz_lawn_particle_emit(_emitter_id) {
    if (!instance_exists(_emitter_id)) return false;
    var _cfg = _emitter_id.fx_xml_data;
    if (!is_struct(_cfg) || _cfg.sprite < 0) return false;

    // TodParticleEmitter::SpawnParticle chooses one launch angle first; circular emitter position
    // uses that same angle, and the velocity uses sin(angle)/cos(angle), not GameMaker lengthdir axes.
    var _angle = _cfg.launch_angle_random
        ? random(360)
        : random_range(_cfg.launch_angle_min, _cfg.launch_angle_max);
    var _angle_rad = degtorad(_angle);
    // EmitterOffset applies to Point/Circle as well as Box emitters in the original TodParticle code.
    // PotatoMine.xml relies on EmitterOffsetY=20 to keep its launch rings above the mine.
    var _x = _emitter_id.fx_xml_origin_x + random_range(_cfg.offset_x_min, _cfg.offset_x_max);
    var _y = _emitter_id.fx_xml_origin_y + random_range(_cfg.offset_y_min, _cfg.offset_y_max);
    if (_cfg.emitter_type == "circle") {
        var _radius = random_range(_cfg.emitter_radius_min, _cfg.emitter_radius_max);
        _x += sin(_angle_rad) * _radius;
        _y += cos(_angle_rad) * _radius;
    }
    _x += random_range(_cfg.position_x_min, _cfg.position_x_max);
    _y += random_range(_cfg.position_y_min, _cfg.position_y_max);

    // TodParticle.cpp: launch speed is scaled by 0.01, then velocity is sin/cos of the launch angle.
    var _speed = random_range(_cfg.launch_speed_min, _cfg.launch_speed_max) / 100.0;
    var _vx = sin(_angle_rad) * _speed;
    var _vy = cos(_angle_rad) * _speed;
    var _life = irandom_range(_cfg.particle_duration_min, _cfg.particle_duration_max);
    var _scale_start = _cfg.particle_scale_random_start
        ? random_range(_cfg.particle_scale_min, _cfg.particle_scale_max)
        : _cfg.particle_scale_min;
    var _scale_end = _cfg.particle_scale_end_matches_start
        ? _scale_start
        : (_cfg.particle_scale_random_end
            ? random_range(_cfg.particle_scale_end_min, _cfg.particle_scale_end_max)
            : _cfg.particle_scale_end_min);
    // Sample a random scale value for each original key range once per particle, then
    // interpolate each segment over that particle's life as PopCap's track evaluator does.
    var _scale_curve_times = _cfg.particle_scale_curve_times;
    var _scale_curve = [];
    if (array_length(_scale_curve_times) >= 2
        && array_length(_cfg.particle_scale_curve_min) == array_length(_scale_curve_times)
        && array_length(_cfg.particle_scale_curve_max) == array_length(_scale_curve_times)) {
        for (var _scale_key_i = 0; _scale_key_i < array_length(_scale_curve_times); _scale_key_i++) {
            array_push(_scale_curve, random_range(_cfg.particle_scale_curve_min[_scale_key_i], _cfg.particle_scale_curve_max[_scale_key_i]));
        }
        _scale_start = _scale_curve[0];
        _scale_end = _scale_curve[array_length(_scale_curve) - 1];
    }
    var _spin = random_range(_cfg.spin_min, _cfg.spin_max) / 100.0;
    var _system_alpha = _cfg.system_alpha;
    var _system_fade_tick = _cfg.system_duration * _cfg.system_fade_start;
    if (_emitter_id.fx_xml_age >= _system_fade_tick) {
        _system_alpha *= clamp((_cfg.system_duration - _emitter_id.fx_xml_age) / max(1, _cfg.system_duration - _system_fade_tick), 0, 1);
    }
    var _fade_start = round(_life * _cfg.particle_fade_start);
    var _initial_angle = _cfg.random_launch_spin ? random(360) : 0;
    // Random bracketed ParticleRed/Green/Blue tracks are sampled once per particle, like TodParticle.cpp.
    var _red_start = _cfg.particle_red_random ? random_range(_cfg.particle_red_start, _cfg.particle_red_end) : _cfg.particle_red_start;
    var _green_start = _cfg.particle_green_random ? random_range(_cfg.particle_green_start, _cfg.particle_green_end) : _cfg.particle_green_start;
    var _blue_start = _cfg.particle_blue_random ? random_range(_cfg.particle_blue_start, _cfg.particle_blue_end) : _cfg.particle_blue_start;
    var _red_end = _cfg.particle_red_random ? _red_start : _cfg.particle_red_end;
    var _green_end = _cfg.particle_green_random ? _green_start : _cfg.particle_green_end;
    var _blue_end = _cfg.particle_blue_random ? _blue_start : _cfg.particle_blue_end;
    // Original XML has no AnimationRate for these effects: choose a sprite frame once per particle.
    var _frame = irandom(max(0, _cfg.image_frames - 1));

    var _particle = instance_create_layer(_x, _y, "Instances", obj_pvz_lawn_fx_piece, {
        fx_sprite: _cfg.sprite,
        fx_xml_sprites: _cfg.sprites,
        fx_xml_frame: _frame,
        fx_vx: _vx,
        fx_vy: _vy,
        fx_spin: _spin,
        fx_life: _life,
        fx_kind: "piece",
        fx_gravity: _cfg.gravity_y / 100.0,
        fx_ground_y: _y + _cfg.ground_offset,
        fx_reflect: 0.0,
        fx_fade_start: _fade_start,
        fx_scale: _scale_start,
        fx_scale_end: _scale_end,
        fx_scale_keytime: _cfg.particle_scale_keytime,
        fx_scale_times: _scale_curve_times,
        fx_scale_curve: _scale_curve,
        fx_frame_count: _cfg.image_frames,
        fx_alpha_mult: _cfg.particle_alpha * _system_alpha,
        fx_color_r_start: _red_start,
        fx_color_r_end: _red_end,
        fx_color_r_keytime: _cfg.particle_red_keytime,
        fx_color_g_start: _green_start,
        fx_color_g_end: _green_end,
        fx_color_g_keytime: _cfg.particle_green_keytime,
        fx_color_b_start: _blue_start,
        fx_color_b_end: _blue_end,
        fx_color_b_keytime: _cfg.particle_blue_keytime,
        fx_friction_x: _cfg.friction_x_start,
        fx_friction_x_end: _cfg.friction_x_end,
        fx_friction_x_keytime: _cfg.friction_x_keytime,
        fx_friction_y: _cfg.friction_y_start,
        fx_friction_y_end: _cfg.friction_y_end,
        fx_friction_y_keytime: _cfg.friction_y_keytime,
        fx_ground_enabled: _cfg.ground_enabled,
        fx_spin_decay: false,
        fx_spin_active_until: _life,
        fx_parent_emitter: _emitter_id,
        fx_angle: _initial_angle
    });
    return instance_exists(_particle);
}

/// Start a named original XML effect. Returns false only when no usable emitter/image is available.
function pvz_lawn_spawn_particle(_name, _x, _y, _follow_id = noone, _loop_while_following = false) {
    var _emitters = pvz_lawn_particle_load_definition(_name);
    if (array_length(_emitters) <= 0) return false;
    var _started = false;
    for (var _i = 0; _i < array_length(_emitters); _i++) {
        var _cfg = _emitters[_i];
        if (_cfg.sprite < 0) continue;
        var _initial = irandom_range(_cfg.min_active_min, _cfg.min_active_max);
        if (_cfg.max_launched >= 0) _initial = min(_initial, _cfg.max_launched);
        var _emitter = instance_create_layer(_x, _y, "Instances", obj_pvz_lawn_fx_piece, {
            fx_sprite: -1,
            fx_vx: 0,
            fx_vy: 0,
            fx_spin: 0,
            fx_life: _cfg.system_duration,
            fx_kind: "xml_emitter",
            fx_gravity: 0,
            fx_ground_y: _y,
            fx_reflect: 0,
            fx_fade_start: _cfg.system_duration,
            fx_scale: 1,
            fx_xml_data: _cfg,
            fx_xml_origin_x: _x,
            fx_xml_origin_y: _y,
            fx_xml_age: 0,
            fx_xml_spawned: 0,
            fx_xml_next_spawn: 1,
            fx_xml_initial_active: _initial,
            fx_follow_id: _follow_id,
            fx_loop_while_following: _loop_while_following
        });
        if (instance_exists(_emitter)) _started = true;
    }
    return _started;
}

/// Original Zombie::AnimateChewEffect: special chewing particles are for Wall-nut/Tall-nut only.
function pvz_lawn_spawn_wallnut_bite_particle(_zid, _plant) {
    if (!instance_exists(_zid) || !instance_exists(_plant)) return false;
    var _plant_label = "";
    if (variable_instance_exists(_plant, "plant_kind")) _plant_label = string_lower(_plant.plant_kind);
    else if (variable_instance_exists(_plant, "reanim_name")) _plant_label = string_lower(_plant.reanim_name);
    else if (variable_instance_exists(_plant, "display_name")) _plant_label = string_lower(_plant.display_name);
    var _is_wallnut = string_pos("wall", _plant_label) > 0 && string_pos("nut", _plant_label) > 0;
    var _is_tallnut = string_pos("tall", _plant_label) > 0 && string_pos("nut", _plant_label) > 0;
    if (!_is_wallnut && !_is_tallnut) return false;

    // Zombie.cpp: mouth effect is rooted near mPosX+37, mPosY+40 plus its body draw offset.
    var _px = _zid.x + 37;
    var _py = _zid.y + 34;
    if (pvz_lawn_spawn_particle("WallnutEatSmall", _px, _py)) return true;
    for (var _i = 0; _i < 2; _i++) {
        pvz_lawn_spawn_piece(-1,
            _px + random_range(-2.0, 2.0), _py + random_range(-2.0, 2.0),
            random_range(-1.35, 1.35), random_range(-3.4, -1.7), random_range(-22.0, 22.0),
            irandom_range(16, 23), "nut", 0.17, 8.0, 0.12, 14, 1.0);
    }
    return true;
}

function pvz_lawn_get_sound_stream(_filename) {
    if (!variable_global_exists("pvz_lawn_audio_cache")) global.pvz_lawn_audio_cache = {};
    var _cache = global.pvz_lawn_audio_cache;
    if (variable_struct_exists(_cache, _filename)) return variable_struct_get(_cache, _filename);

    var _path = working_directory + "datafiles/sounds/" + _filename;
    if (!file_exists(_path)) _path = working_directory + "sounds/" + _filename;
    var _stream = -1;
    if (file_exists(_path)) {
        _stream = audio_create_stream(_path);
    } else {
        // Do not crash if a sound hasn't been packaged; the asset path is logged once for debugging.
        show_debug_message("PvZ sound missing: " + _path);
    }
    variable_struct_set(_cache, _filename, _stream);
    return _stream;
}

function pvz_lawn_play_sound(_filename, _priority = 0) {
    var _lower_filename = string_lower(_filename);
    var _is_music = string_pos("music", _lower_filename) > 0;
    if (_is_music && variable_global_exists("pvz_lawn_music_enabled") && !global.pvz_lawn_music_enabled) return false;
    if (!_is_music && variable_global_exists("pvz_lawn_sfx_enabled") && !global.pvz_lawn_sfx_enabled) return false;
    var _stream = pvz_lawn_get_sound_stream(_filename);
    if (_stream < 0) return false;
    var _instance = audio_play_sound(_stream, _priority, false);
    // NewOptionsDialog uses real 0..100 volume sliders rather than only on/off toggles.
    var _gain = 1.0;
    if (_is_music && variable_global_exists("pvz_lawn_music_volume")) _gain = clamp(global.pvz_lawn_music_volume, 0.0, 1.0);
    else if (!_is_music && variable_global_exists("pvz_lawn_sfx_volume")) _gain = clamp(global.pvz_lawn_sfx_volume, 0.0, 1.0);
    audio_sound_gain(_instance, _gain, 0);
    return true;
}

function pvz_lawn_play_random_sound(_filenames, _priority = 0) {
    var _count = array_length(_filenames);
    if (_count <= 0) return false;
    // Mirrors TodFoley's random selection among entries in FoleyParams.
    return pvz_lawn_play_sound(_filenames[irandom(_count - 1)], _priority);
}

function pvz_lawn_play_zombie_groan(_is_variant = false) {
    if (_is_variant) {
        return pvz_lawn_play_random_sound(["groan.ogg", "groan2.ogg", "groan3.ogg", "groan4.ogg", "groan5.ogg", "groan6.ogg", "sukhbir4.ogg", "sukhbir5.ogg", "sukhbir6.ogg"]);
    }
    return pvz_lawn_play_random_sound(["groan.ogg", "groan2.ogg", "groan3.ogg", "groan4.ogg", "groan5.ogg", "groan6.ogg"]);
}

function pvz_lawn_play_splat() {
    // TodFoley.cpp: FOLEY_SPLAT randomly selects SOUND_SPLAT, SOUND_SPLAT2, or SOUND_SPLAT3.
    return pvz_lawn_play_random_sound(["splat.ogg", "splat2.ogg", "splat3.ogg"]);
}

/// Projectile.cpp: pea splat origin is mPosX-3, mPosY+12. Attached zombie splats use the original vertical clamp/side adjustment.
function pvz_lawn_spawn_splat(_x, _y, _zid = noone) {
    var _spawn_x = _x - 3.0;
    var _spawn_y = _y + 12.0;
    if (instance_exists(_zid)) {
        if (_x > _zid.x + 40) _spawn_x -= 60.0;
        var _phase = "";
        if (variable_instance_exists(_zid, "phase")) _phase = string_lower(_zid.phase);
        var _local_y = _spawn_y - _zid.y;
        if (string_pos("snorkel", _phase) > 0 || string_pos("dolphin", _phase) > 0) _local_y += 60.0;
        _spawn_y = _zid.y + clamp(_local_y, 20.0, 100.0);
    }
    if (pvz_lawn_spawn_particle("PeaSplat", _spawn_x, _spawn_y)) return;
    instance_create_layer(_spawn_x + 12, _spawn_y, "Instances", obj_pvz_lawn_fx_splat, {});
}

/// Board::DoPlantingEffects: PARTICLE_PLANTING is centered at GridToPixel + (41,74).
/// The original particle XML isn't included in this sandbox package, so use a short brown
/// dirt puff with a source-style upward launch, spread, gravity and fade instead.
/// Board::DoPlantingEffects: PARTICLE_PLANTING is centered at GridToPixel + (41,74).
/// Prefer the original datafiles/particles/Planting.xml definition; keep existing dirt fallback if unavailable.
/// Board::DoPlantingEffects: PARTICLE_PLANTING is centered at GridToPixel + (41,74).
function pvz_lawn_spawn_planting_dirt(_x, _y) {
    if (pvz_lawn_spawn_particle("Planting", _x + 41, _y + 74)) return;
    instance_create_layer(_x + 41, _y + 74, "Instances", obj_pvz_lawn_fx_dirt, {});
}

function pvz_lawn_return_to_menu() {
    // The original Main Menu action opens GameSelector directly; do not replay PopCap/title/loading screens.
    global.pvz_open_main_menu_direct = true;
    var _boot_room = asset_get_index("rm_pvz_boot");
    if (_boot_room >= 0) { room_goto(_boot_room); return; }
    game_end();
}

function pvz_lawn_draw_stone_button(_x, _y, _w, _h, _label, _hover, _down) {
    // GameButton::DrawStoneButton uses the six original left/middle/right art pieces.
    var _left = -1;
    var _mid = -1;
    var _right = -1;
    if (_down) {
        if (variable_global_exists("pvz_button_down_left")) _left = global.pvz_button_down_left;
        if (variable_global_exists("pvz_button_down_middle")) _mid = global.pvz_button_down_middle;
        if (variable_global_exists("pvz_button_down_right")) _right = global.pvz_button_down_right;
    } else {
        if (variable_global_exists("pvz_button_left")) _left = global.pvz_button_left;
        if (variable_global_exists("pvz_button_middle")) _mid = global.pvz_button_middle;
        if (variable_global_exists("pvz_button_right")) _right = global.pvz_button_right;
    }
    if (_left >= 0 && _mid >= 0 && _right >= 0) {
        var _lw = sprite_get_width(_left);
        var _mw = max(1, sprite_get_width(_mid));
        var _rw = sprite_get_width(_right);
        var _mh = sprite_get_height(_mid);
        draw_sprite(_left, 0, _x, _y);
        var _pos = _x + _lw;
        var _available = max(0, _w - _lw - _rw);
        var _repeat = floor(_available / _mw);
        for (var _i = 0; _i < _repeat; _i++) {
            draw_sprite(_mid, 0, _pos, _y);
            _pos += _mw;
        }
        var _rem = _available - _repeat * _mw;
        if (_rem > 0) draw_sprite_part(_mid, 0, 0, 0, min(_rem, _mw), _mh, _pos, _y);
        draw_sprite(_right, 0, _x + _w - _rw, _y);
    } else {
        draw_set_color(make_color_rgb(91, 74, 48));
        draw_roundrect(_x, _y, _x + _w, _y + _h, false);
        draw_set_color(make_color_rgb(204, 174, 117));
        draw_roundrect(_x, _y, _x + _w, _y + _h, true);
    }
    draw_set_color(_hover ? make_color_rgb(94, 205, 65) : make_color_rgb(55, 149, 47));
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    pvz_lawn_draw_text_native(_x + _w * 0.5 + (_down ? 1 : 0), _y + _h * 0.5 + (_down ? 1 : 0), _label, _hover ? "DwarvenTodcraft18BrightGreenInset" : "DwarvenTodcraft18GreenInset", 1.0);
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

/// Approximate the original UpdateAnimSpeed ground-track coupling used by Zombie.cpp.
function pvz_lawn_zombie_anim_rate(_body, _speed) {
    var _idx = _body.find_track("_ground");
    if (_idx < 0 || _body.frame_count <= 1) return 12.0;
    var _frames = _body.def.tracks[_idx].t;
    var _a = clamp(_body.frame_start, 0, array_length(_frames) - 1);
    var _b = clamp(_body.frame_start + _body.frame_count - 1, 0, array_length(_frames) - 1);
    var _dist = abs(_frames[_b][RT_X] - _frames[_a][RT_X]);
    if (_dist < 0.001) return 12.0;
    // Exact Zombie::UpdateAnimSpeed relationship: mVelX * frame_count / ground distance * 47.
    // Root motion is converted separately to this recreation's 100 Hz logic tick below.
    return max(1.0, _speed * _body.frame_count / _dist * 47.0);
}


/// Source-matched Zombie::UpdateZombieWalking / Reanimation::GetTrackVelocity("_ground").
/// Movement uses the current frame-to-frame ground displacement and the active animation rate.
function pvz_lawn_ground_track_speed(_body, _fallback_speed) {
    if (is_undefined(_body) || _body == noone || _body.def == undefined) return _fallback_speed * 0.47;
    var _ground_index = _body.find_track("_ground");
    if (_ground_index < 0) return _fallback_speed * 0.47;
    var _ground_ft = _body.get_frame_time();
    var _ground_frames = _body.def.tracks[_ground_index].t;
    var _ground_frame_total = array_length(_ground_frames);
    if (_ground_frame_total <= 0) return _fallback_speed * 0.47;
    var _ground_before = clamp(floor(_ground_ft[0]), 0, _ground_frame_total - 1);
    var _ground_after = clamp(floor(_ground_ft[1]), 0, _ground_frame_total - 1);
    return (_ground_frames[_ground_after][RT_X] - _ground_frames[_ground_before][RT_X]) * LOGIC_STEP_SECONDS * _body.anim_rate;
}
function pvz_lawn_zombie_play_walk(_zid, _blend) {
    if (!instance_exists(_zid)) return;
    with (_zid) {
        if (dead || is_undefined(body)) exit;
        eating = false;
        // Zombie::StartWalkAnim selects both gait animation and mVelX from the active type/phase.
        // Keep the target project's established baseline speed range for ordinary walkers.
        if (zombie_kind == "polevaulter" && pole_used) {
            move_speed = random_range(0.16, 0.22);
            body.play("anim_walk", ReanimLoop.LOOP, _blend, 0);
        } else if (zombie_kind == "polevaulter") {
            move_speed = random_range(0.66, 0.68);
            body.play("anim_run", ReanimLoop.LOOP, _blend, 0);
        } else if (zombie_kind == "football" || zombie_kind == "jackbox" || zombie_kind == "snorkel") {
            move_speed = random_range(0.66, 0.68);
            body.play("anim_walk", ReanimLoop.LOOP, _blend, 0);
        } else if (zombie_kind == "flag" || zombie_kind == "dancer" || zombie_kind == "backup_dancer" || (zombie_kind == "pogo" && phase == "pogo_bouncing")) {
            move_speed = 0.45;
            body.play(zombie_kind == "dancer" ? "anim_walk" : "anim_walk2", ReanimLoop.LOOP, _blend, 0);
        } else if (zombie_kind == "newspaper" && phase == "newspaper_mad") {
            move_speed = random_range(0.89, 0.91);
            body.play("anim_walk_nopaper", ReanimLoop.LOOP, _blend, 0);
        } else if (zombie_kind == "newspaper") {
            move_speed = random_range(0.16, 0.22);
            body.play("anim_walk", ReanimLoop.LOOP, _blend, 0);
        } else if (zombie_kind == "dolphin_rider") {
            move_speed = random_range(0.89, 0.91);
            body.play("anim_walkdolphin", ReanimLoop.LOOP, _blend, 0);
        } else if (zombie_kind == "yeti" && phase != "yeti_retreat") {
            move_speed = 0.4;
            body.play("anim_walk", ReanimLoop.LOOP, _blend, 0);
        } else if (zombie_kind == "digger" && walks_backwards) {
            move_speed = 0.12;
            body.play("anim_walk", ReanimLoop.LOOP, _blend, 0);
            body.scale_x = -1;
        } else if (zombie_kind == "ladder" && phase == "ladder_carrying" && armor_health > 0) {
            move_speed = random_range(0.79, 0.81);
            body.play("anim_ladderwalk", ReanimLoop.LOOP, _blend, 0);
        } else {
            move_speed = random_range(0.16, 0.22);
            if (body.track_exists("anim_walk2") && irandom(1) == 0) body.play("anim_walk2", ReanimLoop.LOOP, _blend, 0);
            else body.play("anim_walk", ReanimLoop.LOOP, _blend, 0);
        }
        if (zombie_kind == "screendoor" && armor_health > 0) {
            body.set_track_hidden("Zombie_innerarm_screendoor", false);
            body.set_track_hidden("anim_screendoor", false);
            body.set_track_hidden("Zombie_innerarm_screendoor_hand", false);
            body.set_track_hidden("Zombie_outerarm_screendoor", false);
        }
        // Restore correct gait direction after Digger has emerged and turned around.
        if (zombie_kind == "digger" && walks_backwards) body.scale_x = -1;
        body.dead = false;
        body.anim_rate = pvz_lawn_zombie_anim_rate(body, move_speed);
    }
}

function pvz_lawn_find_ladder_target(_zid) {
    if (!instance_exists(_zid) || _zid.dead || !_zid.has_head) return noone;
    var _best = noone;
    var _best_dist = 1000000;
    for (var _c = 0; _c < PVZ_COLS; _c++) {
        var _p = global.pvz_lawn_grid[# _c, _zid.row];
        if (!instance_exists(_p) || !variable_instance_exists(_p, "plant_kind") || !variable_instance_exists(_p, "plant_health")) continue;
        if (_p.plant_health <= 0 || _p.laddered) continue;
        if (_p.plant_kind != "wallnut" && _p.plant_kind != "tallnut" && _p.plant_kind != "pumpkin") continue;
        var _distance = abs(_zid.x - _p.x);
        // Zombie::CanTargetPlant(ATTACKTYPE_LADDER): the ladder zombie targets only
        // Wall-nut, Tall-nut, or Pumpkin Shell and only where no ladder is already fitted.
        var _ahead = _zid.walks_backwards ? (_p.x >= _zid.x - 40) : (_p.x <= _zid.x + 40);
        if (_ahead && _distance < 88 && _distance < _best_dist) { _best = _p; _best_dist = _distance; }
    }
    return _best;
}

function pvz_lawn_find_plant(_zid, _max_dist) {
    if (!instance_exists(_zid) || !_zid.has_head || _zid.dead) return noone;
    var _best = noone;
    var _best_dist = 1000000;
    var _row = _zid.row;
    var _zx = _zid.x;
    for (var _c = 0; _c < PVZ_COLS; _c++) {
        var _p = global.pvz_lawn_grid[# _c, _row];
        if (instance_exists(_p)) {
            // Source Zombie::CanEatPlant excludes explosive plants; armed Potato Mines also trigger instead of being chewed.
            if (variable_instance_exists(_p, "plant_kind") && (_p.plant_kind == "cherry_bomb" || (_p.plant_kind == "potato_mine" && _p.plant_state != "arming"))) continue;
            if (variable_instance_exists(_p, "plant_state") && _p.plant_state == "explode") continue;
            // Source ladder placement makes the selected wall plant passable to following zombies.
            if (variable_instance_exists(_p, "laddered") && _p.laddered && _zid.zombie_kind != "ladder") continue;
            // Keep targeting on the zombie's forward-side attack footprint. A small +40px allowance
            // lets the Pole Vaulter notice a plant placed directly under the sprite; its fixed
            // 150px jump leaves it behind on landing, so it won't turn around and eat it.
            var _facing_condition = (variable_instance_exists(_zid, "walks_backwards") && _zid.walks_backwards) ? (_p.x >= _zx - 40) : (_p.x <= _zx + 40);
            if (variable_instance_exists(_p, "plant_health") && _p.plant_health > 0 && _facing_condition) {
                var _d = abs(_zx - _p.x);
                if (_d < _max_dist && _d < _best_dist) { _best = _p; _best_dist = _d; }
            }
        }
    }
    return _best;
}

function pvz_lawn_zombie_begin_eating(_zid, _pid) {
    if (!instance_exists(_zid) || !instance_exists(_pid)) return;
    with (_zid) {
        if (dead || !has_head || eating || phase == "vault") exit;
        eating = true;
        target_plant = _pid;
        bite_ticks = 0;
        var _eat_anim = "anim_eat";
        if (zombie_kind == "newspaper" && phase == "newspaper_mad") _eat_anim = "anim_eat_nopaper";
        else if (zombie_kind == "ladder" && phase == "ladder_carrying" && armor_health > 0) _eat_anim = "anim_laddereat";
        var _slow_eating_type = zombie_kind == "polevaulter" || zombie_kind == "balloon" || zombie_kind == "imp"
            || zombie_kind == "digger" || zombie_kind == "jackbox" || zombie_kind == "snorkel" || zombie_kind == "yeti";
        if (body.track_exists(_eat_anim)) {
            body.play(_eat_anim, ReanimLoop.LOOP, 20, _slow_eating_type ? 20.0 : 36.0);
            chew_anim_time = 0;
        }
        // Keep the shield and shield-specific arms visible during chewing. The original
        // SetupDoorArms controls the ordinary-vs-shield arms as separate render groups;
        // hiding all shield tracks here made the door disappear for the entire bite cycle.
    }
}

function pvz_lawn_zombie_lose_arm(_zid) {
    if (!instance_exists(_zid)) return;
    with (_zid) {
        if (!has_arm) exit;
        if ((zombie_kind == "screendoor" || zombie_kind == "newspaper") && armor_health > 0) exit;
        has_arm = false;
        pvz_lawn_play_sound("limbs_pop.ogg"); // Zombie::DropArm -> FOLEY_LIMBS_POP.
        var _lower_track = "Zombie_outerarm_lower";
        var _hand_track = "Zombie_outerarm_hand";
        var _upper_track = "Zombie_outerarm_upper";
        if (zombie_kind == "polevaulter") { _lower_track = "Zombie_polevaulter_outerarm_lower"; _upper_track = "Zombie_polevaulter_outerarm_upper"; }
        else if (zombie_kind == "football") { _lower_track = "Zombie_football_leftarm_lower"; _hand_track = "Zombie_football_leftarm_hand"; _upper_track = "Zombie_football_leftarm_upper"; }
        else if (zombie_kind == "newspaper") { _lower_track = "Zombie_paper_leftarm_lower"; _hand_track = "Zombie_paper_hands"; _upper_track = "Zombie_paper_leftarm_upper"; }
        else if (zombie_kind == "dancer") { _lower_track = "Zombie_Jackson_outerarm_lower"; _hand_track = "Zombie_Jackson_outerarm_hand"; _upper_track = "Zombie_Jackson_outerarm_upper"; }
        else if (zombie_kind == "backup_dancer") { _lower_track = "Zombie_innerarm_lower"; _hand_track = "Zombie_innerarm_hand"; _upper_track = "Zombie_innerarm_upper"; }
        else if (zombie_kind == "imp") { _lower_track = "Zombie_imp_outerarm_lower"; _hand_track = "Zombie_imp_outerarm_hand"; _upper_track = "Zombie_imp_outerarm_upper"; }
        else if (zombie_kind == "digger") { _lower_track = "Zombie_digger_outerarm_lower"; _hand_track = "Zombie_digger_outerarm_hand"; _upper_track = "Zombie_digger_outerarm_upper"; }
        else if (zombie_kind == "jackbox") { _lower_track = "Zombie_jackbox_outerarm_lower"; _hand_track = "Zombie_jackbox_outerarm_hand"; _upper_track = "Zombie_jackbox_outerarm_lower"; }
        else if (zombie_kind == "snorkel") { _lower_track = "Zombie_snorkle_outerarm_lower"; _hand_track = "Zombie_outerarm_hand"; _upper_track = "Zombie_snorkle_outerarm_upper"; }
        else if (zombie_kind == "dolphin_rider") { _lower_track = "Zombie_dolphinrider_outerarm_lower"; _hand_track = "Zombie_outerarm_hand"; _upper_track = "Zombie_dolphinrider_outerarm_upper"; }
        else if (zombie_kind == "bobsled_rider") { _lower_track = "Zombie_outerarm_lower"; _hand_track = "Zombie_outerarm_hand"; _upper_track = "Zombie_dolphinrider_outerarm_upper"; }
        else if (zombie_kind == "ladder") { _lower_track = "Zombie_ladder_outerarm_lower"; _hand_track = "Zombie_ladder_outerarm_hand"; _upper_track = "Zombie_ladder_outerarm_upper"; }
        else if (zombie_kind == "yeti") { _lower_track = "Zombie_yeti_outerarm_lower"; _hand_track = "Zombie_yeti_outerarm_hand"; _upper_track = "Zombie_yeti_outerarm_upper"; }
        else if (zombie_kind == "pogo") { _lower_track = "Zombie_outerarm_lower"; _hand_track = "Zombie_outerarm_hand"; _upper_track = "Zombie_outerarm_upper"; }
        else if (zombie_kind == "flag") { _lower_track = "Zombie_outerarm_lower"; _hand_track = "Zombie_outerarm_hand"; _upper_track = "Zombie_outerarm_upper"; }
        var _low = pvz_lawn_track_sprite(body, _lower_track);
        var _hand = pvz_lawn_track_sprite(body, _hand_track);
        var _pos = pvz_lawn_track_world_pos(body, _lower_track, x + 45, y + 78);
        // Zombie::SetupReanimForLostArm hides the lower arm/hand and replaces the upper arm.
        // Pole Vaulter uses its own lower-arm artwork for the detached piece instead of the generic ZombieArm particle.
        if (_lower_track != _upper_track) body.set_track_hidden(_lower_track, true);
        body.set_track_hidden(_hand_track, true);
        if (zombie_kind == "football") { body.set_track_hidden("Zombie_football_leftarm_hand", true); body.set_track_hidden("Zombie_football_leftarm_lower", true); }
        if (zombie_kind == "newspaper") { body.set_track_hidden("Zombie_paper_hands", true); body.set_track_hidden("Zombie_paper_leftarm_lower", true); }
        var _stump_index = body.find_track(_upper_track);
        var _stump_image = -1;
        switch (zombie_kind) {
            case "polevaulter": _stump_image = global.pvz_fx_pole_arm_stump; break;
            case "football": _stump_image = reanim_get_part_sprite("reanim/Zombie_football_leftarm_upper2.png"); break;
            case "newspaper": _stump_image = reanim_get_part_sprite("reanim/Zombie_paper_leftarm_upper2.png"); break;
            case "dancer": _stump_image = reanim_get_part_sprite("reanim/Zombie_Jackson_outerarm_upper2.png"); break;
            case "imp": _stump_image = reanim_get_part_sprite("reanim/Zombie_imp_arm1_bone.png"); break;
            case "digger": _stump_image = reanim_get_part_sprite("reanim/Zombie_digger_outerarm_upper2.png"); break;
            case "jackbox": _stump_image = reanim_get_part_sprite("reanim/Zombie_jackbox_outerarm_lower2.png"); break;
            case "snorkel": _stump_image = reanim_get_part_sprite("reanim/Zombie_snorkle_outerarm_upper2.png"); break;
            case "dolphin_rider": _stump_image = reanim_get_part_sprite("reanim/Zombie_dolphinrider_outerarm_upper2.png"); break;
            case "bobsled_rider": _stump_image = reanim_get_part_sprite("reanim/Zombie_bobsled_outerarm_upper2.png"); break;
            case "pogo": _stump_image = reanim_get_part_sprite("reanim/Zombie_pogo_outerarm_upper2.png"); break;
            case "ladder": _stump_image = reanim_get_part_sprite("reanim/Zombie_ladder_outerarm_upper2.png"); break;
            case "yeti": _stump_image = reanim_get_part_sprite("reanim/Zombie_yeti_outerarm_upper2.png"); break;
            default: _stump_image = global.pvz_fx_arm_stump; break;
        }
        if (_stump_image >= 0 && _stump_index >= 0) body.track_sprite_override[_stump_index] = _stump_image;
        if (zombie_kind == "flag") {
            var _flag_hand_track = body.find_track("Zombie_flaghand");
            if (_flag_hand_track >= 0 && array_length(body.attached[_flag_hand_track]) > 0) {
                var _flag_reanim = body.attached[_flag_hand_track][0];
                var _flag_track_index = _flag_reanim.find_track("Zombie_flag");
                var _flag_image3 = reanim_get_part_sprite("reanim/Zombie_flag3.png");
                if (_flag_track_index >= 0 && _flag_image3 >= 0) _flag_reanim.track_sprite_override[_flag_track_index] = _flag_image3;
            }
        }
        else pvz_lawn_use_later_track_image(body, _upper_track);
        if (zombie_kind == "pogo") {
            var _hands_track = body.find_track("Zombie_pogo_stickhands");
            var _hands_image = reanim_get_part_sprite("reanim/Zombie_pogo_stickhands2.png");
            if (_hands_track >= 0 && _hands_image >= 0) {
                body.track_sprite_override[_hands_track] = _hands_image;
                body.set_track_hidden("Zombie_pogo_stickhands", false);
            } else if (_hands_track >= 0) {
                // If the original damaged-hand art is not installed, don't leave the intact hand visible.
                body.set_track_hidden("Zombie_pogo_stickhands", true);
            }
            var _stick1 = body.find_track("Zombie_pogo_stick");
            var _stick1img = reanim_get_part_sprite("reanim/Zombie_pogo_stickdamage2.png");
            if (_stick1 >= 0 && _stick1img >= 0) body.track_sprite_override[_stick1] = _stick1img;
            var _stick2 = body.find_track("Zombie_pogo_stick2");
            var _stick2img = reanim_get_part_sprite("reanim/Zombie_pogo_stick2damage2.png");
            if (_stick2 >= 0 && _stick2img >= 0) body.track_sprite_override[_stick2] = _stick2img;
        }
        var _ang = random_range(90, 185);
        var _speed = 0.4; // ZombieArm.xml LaunchSpeed 40 * 0.01
        var _vx = sin(degtorad(_ang)) * _speed;
        var _vy = cos(degtorad(_ang)) * _speed;
        if (zombie_kind == "polevaulter") {
            var _pole_arm_piece = global.pvz_fx_pole_arm;
            if (_pole_arm_piece < 0) _pole_arm_piece = _low;
            if (_pole_arm_piece < 0) _pole_arm_piece = global.pvz_fx_zombie_arm;
            if (_pole_arm_piece >= 0) pvz_lawn_spawn_piece(_pole_arm_piece, _pos[0], _pos[1], _vx, _vy, random_range(0, 3.6), 160, "arm", 0.15, 85, 0.5, 144, 0.8);
        } else {
            // Source SetupReanimForLostArm selects each zombie's own detached hand/arm image.
            var _arm_particle = _hand;
            if (zombie_kind == "digger" && global.pvz_fx_digger_arm >= 0) _arm_particle = global.pvz_fx_digger_arm;
            if (zombie_kind == "jackbox" && global.pvz_fx_jackbox_arm >= 0) _arm_particle = global.pvz_fx_jackbox_arm;
            if (zombie_kind == "imp") _arm_particle = pvz_lawn_track_sprite(body, "Zombie_imp_arm2");
            if (zombie_kind == "dancer") _arm_particle = pvz_lawn_track_sprite(body, "Zombie_Jackson_outerarm_hand");
            if (zombie_kind == "backup_dancer") _arm_particle = pvz_lawn_track_sprite(body, "Zombie_innerarm_hand");
            if (zombie_kind == "bobsled_rider") _arm_particle = pvz_lawn_track_sprite(body, "Zombie_outerarm_hand");
            if (zombie_kind == "newspaper") _arm_particle = pvz_lawn_track_sprite(body, "Zombie_paper_leftarm_lower");
            if (zombie_kind == "football") _arm_particle = pvz_lawn_track_sprite(body, "Zombie_football_leftarm_hand");
            if (_arm_particle < 0) _arm_particle = _low;
            if (_arm_particle < 0) _arm_particle = global.pvz_fx_zombie_arm;
            if (_arm_particle >= 0) pvz_lawn_spawn_piece(_arm_particle, _pos[0], _pos[1], _vx, _vy, random_range(0, 3.6), 160, "arm", 0.15, 85, 0.5, 144, 0.8);
        }
    }
}

function pvz_lawn_zombie_lose_head(_zid) {
    if (!instance_exists(_zid)) return;
    with (_zid) {
        if (!has_head || dead) exit;
        if (zombie_kind == "zomboni" || zombie_kind == "catapult" || zombie_kind == "bobsled_team" || zombie_kind == "boss" || zombie_kind == "gargantuar" || zombie_kind == "red_eye_gargantuar") exit;
        if (zombie_kind == "jackbox" && phase == "jack_exploding") exit;
        has_head = false;
        var _resume_after_head_loss = body_health > 0;
        pvz_lawn_play_sound("limbs_pop.ogg"); // Zombie::DropHead -> FOLEY_LIMBS_POP.
        var _pos = pvz_lawn_track_world_pos(body, "anim_head1", x + 11, y + 21);
        // Zombie::DropHead + DropLoot releases Newspaper glasses as soon as the head is lost,
        // not only when the body is finally removed. Keep a guard so final cleanup cannot duplicate it.
        if (zombie_kind == "newspaper" && !glasses_dropped) {
            var _glasses_track = body.find_track("Zombie_paper_glasses");
            var _glasses_image = pvz_lawn_track_sprite(body, "Zombie_paper_glasses");
            if (_glasses_image >= 0) {
                var _gp = pvz_lawn_track_world_pos(body, "Zombie_paper_glasses", x + 34, y + 18);
                pvz_lawn_spawn_piece(_glasses_image, _gp[0], _gp[1], random_range(-1.4,1.4), -2.2, random_range(-5,5), 85, "armor", 0.12, 100, 0.2, 15, 0.55);
                if (_glasses_track >= 0) body.set_track_hidden("Zombie_paper_glasses", true);
            }
            glasses_dropped = true;
        }
        // Zombie::DropHead calls DropFlag before the generic head particle. Remove the flag
        // from the attached flag-hand layer and restore the ordinary inner arm; otherwise the
        // flag remains attached to a headless zombie until its body is removed.
        if (zombie_kind == "flag") {
            var _flag_pos = pvz_lawn_track_world_pos(body, "Zombie_flaghand", x + 60, y + 35);
            pvz_lawn_spawn_particle("ZombieFlag", _flag_pos[0] + 6, _flag_pos[1] - 45);
            body.set_track_hidden("Zombie_flaghand", true);
            body.set_track_hidden("Zombie_innerarm_screendoor", true);
            body.set_track_hidden("anim_innerarm", false);
            flag_part = undefined;
        }
        body.set_tracks_hidden_by_prefix("anim_head", true);
        body.set_tracks_hidden_by_prefix("anim_hair", true);
        body.set_tracks_hidden_by_prefix("anim_tongue", true);
        // DropHead selects the original type-specific effect/sprite; do not use the basic head for every zombie.
        var _head = global.pvz_fx_zombie_head;
        if (zombie_kind == "newspaper") {
            // DropHead uses the Newspaper-specific head effect, and its glasses drop through DropLoot.
            pvz_lawn_spawn_particle("ZombieNewspaperHead", _pos[0], _pos[1]);
            _head = -1;
        }
        switch (zombie_kind) {
            case "polevaulter": _head = global.pvz_fx_pole_head; break;
            case "dancer": _head = global.pvz_fx_dancer_head; break;
            case "backup_dancer": _head = global.pvz_fx_backup_dancer_head; break;
            case "football": _head = global.pvz_fx_football_head; break;
            case "balloon": _head = global.pvz_fx_balloon_head; break;
            case "digger": _head = global.pvz_fx_digger_head; break;
            case "dolphin_rider": _head = global.pvz_fx_dolphin_head; break;
            case "bobsled_rider": _head = global.pvz_fx_bobsled_head; break;
            case "imp": _head = global.pvz_fx_imp_head; break;
            case "ladder": _head = global.pvz_fx_ladder_head; break;
            case "pogo": _head = global.pvz_fx_pogo_head; break;
            case "yeti": _head = global.pvz_fx_yeti_head; break;
        }
        // If the optional Pole Vaulter particle PNG is absent, prefer its own live reanimation head part before generic ZombieHead art.
        if (_head < 0 && zombie_kind != "newspaper" && zombie_kind == "polevaulter") _head = pvz_lawn_track_sprite(body, "anim_head1");
        if (_head < 0 && zombie_kind != "newspaper") _head = global.pvz_fx_zombie_head;
        if (_head < 0 && zombie_kind != "newspaper") _head = pvz_lawn_track_sprite(body, "anim_head1");
        if (_head < 0 && zombie_kind != "newspaper") _head = pvz_lawn_track_sprite(body, "anim_head2");
        var _ang = random_range(150, 185);
        var _speed = 3.3; // ZombieHead.xml LaunchSpeed 330 * 0.01
        var _vx = sin(degtorad(_ang)) * _speed;
        var _vy = cos(degtorad(_ang)) * _speed;
        if (_head >= 0) pvz_lawn_spawn_piece(_head, _pos[0], _pos[1], _vx, _vy, random_range(-7.2, 7.2), 180, "head", 0.17, 115, 0.3, 171, 0.8);
        if (zombie_kind == "polevaulter") {
            body.set_track_hidden("Zombie_polevaulter_pole", true);
            body.set_track_hidden("Zombie_polevaulter_pole2", true);
            pole_used = true;
            if (_resume_after_head_loss) phase = "post_vault";
        }
        if (zombie_kind == "pogo" && has_object) {
            // PogoBreak runs from Zombie::DropHead: detach the stick, drop its particle, and resume a normal gait.
            var _stick_track = body.find_track("Zombie_pogo_stick");
            var _stick_pos = pvz_lawn_track_world_pos(body, "Zombie_pogo_stick", x + 38, y + 42);
            var _pogo_particle_started = pvz_lawn_spawn_particle("ZombiePogo", _stick_pos[0], _stick_pos[1] + 30);
            if (!_pogo_particle_started && _stick_track >= 0) {
                var _stick_sprite = pvz_lawn_track_sprite(body, "Zombie_pogo_stick");
                if (_stick_sprite >= 0) pvz_lawn_spawn_piece(_stick_sprite, _stick_pos[0], _stick_pos[1], -0.3, -1.2, 0.05, 120, "armor", 0.12, 70, 0.25, 0, 0.7);
            }
            body.set_tracks_hidden_by_prefix("Zombie_pogo_stick", true);
            body.set_track_hidden("Zombie_pogo_stickhands", true);
            has_object = false;
            armor_health = 0;
            altitude = 0;
            phase = "normal";
            move_speed = random_range(0.16, 0.22);
        }
        // A headless zombie cannot chew or start another vault. It walks with no head and
        // takes the source residual damage until the body reaches zero health.
        eating = false;
        target_plant = noone;
        bite_ticks = 0;
        headless_drain_counter = 0;
        if (_resume_after_head_loss) pvz_lawn_zombie_play_walk(id, 20);
    }
}

function pvz_lawn_zombie_break_armor(_zid, _armor_kind) {
    if (!instance_exists(_zid)) return;
    with (_zid) {
        var _kind = zombie_kind;
        if (_armor_kind == "conehead" || _kind == "conehead" || _kind == "ducky_tube_conehead") {
            var _piece = global.pvz_fx_cone;
            if (_piece < 0) _piece = pvz_lawn_track_sprite(body, "anim_cone");
            var _pos = pvz_lawn_track_world_pos(body, "anim_cone", x + 7, y - 25);
            body.set_tracks_hidden_by_prefix("anim_cone", true);
            var _cone_angle = random_range(100, 140);
            pvz_lawn_spawn_piece(_piece, _pos[0], _pos[1], sin(degtorad(_cone_angle))*2.0, cos(degtorad(_cone_angle))*2.0, -3, 50, "cone", 0.17, 90, 0.3, 40, 0.8);
        } else if (_armor_kind == "buckethead" || _kind == "buckethead" || _kind == "ducky_tube_buckethead") {
            var _piece = global.pvz_fx_bucket;
            if (_piece < 0) _piece = pvz_lawn_track_sprite(body, "anim_bucket");
            var _pos = pvz_lawn_track_world_pos(body, "anim_bucket", x + 7, y - 25);
            body.set_tracks_hidden_by_prefix("anim_bucket", true);
            var _bucket_angle = random_range(120, 180);
            pvz_lawn_spawn_piece(_piece, _pos[0], _pos[1], sin(degtorad(_bucket_angle))*2.0, cos(degtorad(_bucket_angle))*2.0, -3, 50, "bucket", 0.17, 90, 0.3, 40, 0.8);
        } else if (_kind == "newspaper") {
            // DropShield(SHIELDTYPE_NEWSPAPER): the newspaper comes away, the zombie gasps,
            // shows its question-mark reaction, and only then enters its fast angry gait.
            body.set_track_hidden("Zombie_paper_paper", true);
            phase = "newspaper_maddening";
            special_counter = max(1, round((body.track_exists("anim_gasp") ? body.frame_count : 18) / 8.0 * 100.0));
            special_triggered = false;
            move_speed = random_range(0.89, 0.91);
            eating = false; target_plant = noone;
            if (body.track_exists("anim_gasp")) body.play("anim_gasp", ReanimLoop.PLAY_ONCE_AND_HOLD, 10, 8.0);
            if (!variable_global_exists("pvz_fx_newspaper_questionmark")) global.pvz_fx_newspaper_questionmark = reanim_get_part_sprite("reanim/Zombie_questionmark.png");
            var _qpos = pvz_lawn_track_world_pos(body, "anim_head1", x + 50, y - 25);
            if (global.pvz_fx_newspaper_questionmark >= 0) pvz_lawn_spawn_piece(global.pvz_fx_newspaper_questionmark, _qpos[0], _qpos[1] - 22, 0, -0.45, 0, 55, "arm", 0.01, 48, 0.4, 0, 0.6);
            pvz_lawn_play_sound("newspaper_rip.ogg");
            pvz_lawn_spawn_particle("ZombieNewspaper", x + 40, y + 36);
        } else if (_kind == "screendoor") {
            body.set_track_hidden("Zombie_innerarm_screendoor", true);
            body.set_track_hidden("anim_screendoor", true);
            body.set_track_hidden("Zombie_innerarm_screendoor_hand", true);
            body.set_track_hidden("Zombie_outerarm_screendoor", true);
            body.set_track_hidden("Zombie_outerarm_lower", false);
            body.set_track_hidden("Zombie_outerarm_hand", false);
            body.set_track_hidden("Zombie_outerarm_upper", false);
            body.set_track_hidden("anim_innerarm", false);
            pvz_lawn_spawn_particle("ZombieDoor", x + 34, y + 50);
            pvz_lawn_play_random_sound(["shieldhit.ogg", "shieldhit2.ogg"]);
        } else if (_kind == "football") {
            body.set_track_hidden("zombie_football_helmet", true);
            pvz_lawn_spawn_particle("ZombieHelmet", x + 48, y + 12);
            pvz_lawn_play_sound("plastichit.ogg");
        } else if (_kind == "digger") {
            body.set_track_hidden("Zombie_digger_hardhat", true);
            pvz_lawn_play_sound("plastichit.ogg");
        } else if (_kind == "ladder") {
            body.set_track_hidden("Zombie_ladder_1", true);
            if (phase == "ladder_carrying") { phase = "normal"; move_speed = random_range(0.16, 0.22); body.play("anim_walk", ReanimLoop.LOOP, 10, 0); }
            pvz_lawn_play_sound("ladder_zombie.ogg");
        } else if (_kind == "bobsled_team") {
            phase = "bobsled_crashing";
            special_counter = 150;
            body.play("anim_walk", ReanimLoop.LOOP, 0, 0);
            for (var _ri = 0; _ri < array_length(bobsled_rider_ids); _ri++) {
                var _crash_rider = bobsled_rider_ids[_ri];
                if (instance_exists(_crash_rider)) {
                    _crash_rider.phase = "bobsled_crashing";
                    _crash_rider.special_counter = 150;
                    _crash_rider.body.play("anim_walk", ReanimLoop.LOOP, 0, 0);
                    _crash_rider.body.anim_rate = body.anim_rate;
                }
            }
            pvz_lawn_play_sound("shieldhit.ogg");
        }
        armor_health = 0;
    }
}

function pvz_lawn_zombie_update_armor_damage_stage(_zid) {
    if (!instance_exists(_zid)) return;
    with (_zid) {
        var _is_cone = (zombie_kind == "conehead" || zombie_kind == "ducky_tube_conehead");
        var _is_bucket = (zombie_kind == "buckethead" || zombie_kind == "ducky_tube_buckethead");
        if (!_is_cone && !_is_bucket && zombie_kind != "screendoor" && zombie_kind != "newspaper" && zombie_kind != "football" && zombie_kind != "ladder" && zombie_kind != "digger") exit;

        // Match Zombie::GetHelmDamageIndex / GetShieldDamageIndex: stage 1 below 2/3,
        // stage 2 below 1/3. Source values are type-specific.
        var _max_armor = _is_cone ? 370 : (_is_bucket || zombie_kind == "screendoor" ? 1100 : (zombie_kind == "newspaper" ? 150 : (zombie_kind == "football" ? 1400 : (zombie_kind == "ladder" ? 500 : 100))));
        var _stage = 0;
        if (armor_health < floor(_max_armor / 3)) _stage = 2;
        else if (armor_health < floor(_max_armor * 2 / 3)) _stage = 1;
        if (_stage == armor_damage_index) exit;

        var _track = _is_cone ? "anim_cone" : (_is_bucket ? "anim_bucket" : (zombie_kind == "screendoor" ? "anim_screendoor" : (zombie_kind == "newspaper" ? "Zombie_paper_paper" : (zombie_kind == "football" ? "zombie_football_helmet" : (zombie_kind == "ladder" ? "Zombie_ladder_1" : "Zombie_digger_hardhat")))));
        var _image = -1;
        if (_is_cone) {
            if (_stage == 1) _image = global.pvz_fx_cone2; else if (_stage == 2) _image = global.pvz_fx_cone;
        } else if (_is_bucket) {
            if (_stage == 1) _image = global.pvz_fx_bucket2; else if (_stage == 2) _image = global.pvz_fx_bucket;
        } else if (zombie_kind == "screendoor") {
            if (_stage == 1) _image = reanim_get_part_sprite("reanim/Zombie_screendoor2.png"); else if (_stage == 2) _image = reanim_get_part_sprite("reanim/Zombie_screendoor3.png");
        } else if (zombie_kind == "newspaper") {
            if (_stage == 1) _image = reanim_get_part_sprite("reanim/Zombie_paper_paper2.png"); else if (_stage == 2) _image = reanim_get_part_sprite("reanim/Zombie_paper_paper3.png");
        } else if (zombie_kind == "football") {
            if (_stage == 1) _image = reanim_get_part_sprite("reanim/Zombie_football_helmet2.png"); else if (_stage == 2) _image = reanim_get_part_sprite("reanim/Zombie_football_helmet3.png");
        } else if (zombie_kind == "ladder") {
            if (_stage == 1) _image = reanim_get_part_sprite("reanim/Zombie_ladder_1_damage1.png"); else if (_stage == 2) _image = reanim_get_part_sprite("reanim/Zombie_ladder_1_damage2.png");
        } else if (zombie_kind == "digger") {
            if (_stage == 1) _image = reanim_get_part_sprite("reanim/Zombie_digger_hardhat2.png"); else if (_stage == 2) _image = reanim_get_part_sprite("reanim/Zombie_digger_hardhat3.png");
        }

        var _track_index = body.find_track(_track);
        // Like Reanimation::SetImageOverride, replace only the helmet's art; its animated
        // transform/position continues to come from the original Reanim track.
        if (_image >= 0 && _track_index >= 0) body.track_sprite_override[_track_index] = _image;
        armor_damage_index = _stage;
    }
}

function pvz_lawn_zombie_update_catapult_visuals(_zid) {
    if (!instance_exists(_zid) || _zid.zombie_kind != "catapult" || is_undefined(_zid.body) || _zid.body == noone) return;
    with (_zid) {
        // Original Catapult Reanim has four loose ball tracks plus the ball on the pole.
        // Five balls total: one loaded on the pole and four loose balls in the rig.
        // A loose ball disappears after each shot; at one ammo only the loaded ball remains.
        body.set_track_hidden("Zombie_catapult_basketball", catapult_ammo <= 4);
        body.set_track_hidden("Zombie_catapult_basketball2", catapult_ammo <= 3);
        body.set_track_hidden("Zombie_catapult_basketball3", catapult_ammo <= 2);
        body.set_track_hidden("Zombie_catapult_basketball4", catapult_ammo <= 1);
        var _pole = body.find_track("Zombie_catapult_pole");
        var _pole_path;
        if (body_damage_index >= 2) _pole_path = catapult_ammo > 0 ? "reanim/Zombie_catapult_pole_damage_withball.png" : "reanim/Zombie_catapult_pole_damage.png";
        else _pole_path = catapult_ammo > 0 ? "reanim/Zombie_catapult_pole_withball.png" : "reanim/Zombie_catapult_pole.png";
        var _pole_image = reanim_get_part_sprite(_pole_path);
        if (_pole >= 0 && _pole_image >= 0) body.track_sprite_override[_pole] = _pole_image;
    }
}

function pvz_lawn_zombie_update_body_damage_stage(_zid) {
    if (!instance_exists(_zid) || is_undefined(_zid.body) || _zid.body == noone) return;
    if (_zid.zombie_kind == "catapult") pvz_lawn_zombie_update_catapult_visuals(_zid);
    with (_zid) {
        if (zombie_kind == "boss") exit;
        var _stage = 0;
        if (body_health < floor(body_max_health / 3)) _stage = 2;
        else if (body_health < floor(body_max_health * 2 / 3)) _stage = 1;
        if (_stage == body_damage_index) exit;
        body_damage_index = _stage;
        var _track = -1;
        var _image = -1;
        if (zombie_kind == "zomboni") {
            var _one = reanim_get_part_sprite("reanim/Zombie_zamboni_1_damage" + string(_stage) + ".png");
            var _two = reanim_get_part_sprite("reanim/Zombie_zamboni_2_damage" + string(_stage) + ".png");
            _track = body.find_track("Zombie_zamboni_1");
            if (_track >= 0 && _one >= 0) body.track_sprite_override[_track] = _one;
            _track = body.find_track("Zombie_zamboni_2");
            if (_track >= 0 && _two >= 0) body.track_sprite_override[_track] = _two;
            if (_stage == 2) pvz_lawn_spawn_particle("ZamboniSmoke", x + 27, y + 72);
        } else if (zombie_kind == "catapult") {
            if (_stage >= 1) {
                _track = body.find_track("Zombie_catapult_siding");
                _image = reanim_get_part_sprite("reanim/Zombie_catapult_siding_damage.png");
                if (_track >= 0 && _image >= 0) body.track_sprite_override[_track] = _image;
            }
            var _ball_track = -1;
            // Four original loose-ball tracks are exposed by Catapult Reanim; hide one after each shot.
            if (catapult_ammo <= 4) body.set_track_hidden("Zombie_catapult_basketball", true); else body.set_track_hidden("Zombie_catapult_basketball", false);
            if (catapult_ammo <= 3) body.set_track_hidden("Zombie_catapult_basketball2", true); else body.set_track_hidden("Zombie_catapult_basketball2", false);
            if (catapult_ammo <= 2) body.set_track_hidden("Zombie_catapult_basketball3", true); else body.set_track_hidden("Zombie_catapult_basketball3", false);
            if (catapult_ammo <= 1) body.set_track_hidden("Zombie_catapult_basketball4", true); else body.set_track_hidden("Zombie_catapult_basketball4", false);
            var _pole_track = body.find_track("Zombie_catapult_pole");
            var _pole_path = _stage >= 2
                ? (catapult_ammo > 0 ? "reanim/Zombie_catapult_pole_damage_withball.png" : "reanim/Zombie_catapult_pole_damage.png")
                : (catapult_ammo > 0 ? "reanim/Zombie_catapult_pole_withball.png" : "reanim/Zombie_catapult_pole.png");
            if (_pole_track >= 0) {
                var _pole_img = reanim_get_part_sprite(_pole_path);
                if (_pole_img >= 0) body.track_sprite_override[_pole_track] = _pole_img;
            }
        } else if (zombie_kind == "gargantuar" || zombie_kind == "red_eye_gargantuar") {
            var _body_image = _stage == 1 ? reanim_get_part_sprite("reanim/Zombie_gargantuar_body1_2.png") : reanim_get_part_sprite("reanim/Zombie_gargantuar_body1_3.png");
            _track = body.find_track("Zombie_gargantua_body1");
            if (_stage > 0 && _track >= 0 && _body_image >= 0) body.track_sprite_override[_track] = _body_image;
            if (_stage >= 1) {
                _track = body.find_track("Zombie_gargantuar_outerarm_lower");
                _image = reanim_get_part_sprite("reanim/Zombie_gargantuar_outerarm_lower2.png");
                if (_track >= 0 && _image >= 0) body.track_sprite_override[_track] = _image;
            }
            if (_stage == 2) {
                _track = body.find_track("Zombie_gargantuar_outerleg_foot");
                _image = reanim_get_part_sprite("reanim/Zombie_gargantuar_foot2.png");
                if (_track >= 0 && _image >= 0) body.track_sprite_override[_track] = _image;
                _track = body.find_track("anim_head1");
                _image = reanim_get_part_sprite(zombie_kind == "red_eye_gargantuar" ? "reanim/Zombie_gargantuar_head2_redeye.png" : "reanim/Zombie_gargantuar_head2.png");
                if (_track >= 0 && _image >= 0) body.track_sprite_override[_track] = _image;
            }
        } else if (zombie_kind == "pogo") {
            if (_stage > 0) {
                _track = body.find_track("Zombie_pogo_stick");
                _image = reanim_get_part_sprite("reanim/Zombie_pogo_stickdamage" + string(_stage) + ".png");
                if (_track >= 0 && _image >= 0) body.track_sprite_override[_track] = _image;
                _track = body.find_track("Zombie_pogo_stick2");
                _image = reanim_get_part_sprite("reanim/Zombie_pogo_stick2damage" + string(_stage) + ".png");
                if (_track >= 0 && _image >= 0) body.track_sprite_override[_track] = _image;
            }
        }
    }
}

function pvz_lawn_zombie_cleanup_group(_zid) {
    if (!instance_exists(_zid) || !variable_instance_exists(_zid, "bobsled_rider_ids")) return;
    var _riders = _zid.bobsled_rider_ids;
    for (var _i = 0; _i < array_length(_riders); _i++) {
        var _rider = _riders[_i];
        if (instance_exists(_rider)) instance_destroy(_rider);
    }
    _zid.bobsled_rider_ids = [];
}

function pvz_lawn_zombie_die_no_body(_zid) {
    if (!instance_exists(_zid)) return;
    pvz_lawn_zombie_cleanup_group(_zid);
    _zid.dead = true;
    _zid.fade_ticks = 0;
    _zid.phase = "destroyed_no_body";
    _zid.eating = false;
    _zid.target_plant = noone;
    _zid.death_sound_played = true;
    // DAMAGE_DOESNT_LEAVE_BODY: destroy the instance directly; never play anim_death or leave a corpse.
    instance_destroy(_zid);
}

function pvz_lawn_zombie_apply_burn(_zid) {
    if (!instance_exists(_zid)) return;
    if (_zid.body_health >= 1800) {
        // Zombie::ApplyBurn deals 1800 damage with DAMAGE_DOESNT_LEAVE_BODY. If it kills,
        // remove the zombie outright rather than leaving the ordinary anim_death corpse.
        pvz_lawn_zombie_take_damage(_zid, 1800, true);
        return;
    }
    var _charred_x = _zid.x + 22.0;
    var _charred_y = _zid.y - 10.0;
    var _charred = new Reanim("Zombie_charred", _charred_x, _charred_y);
    _charred.anim_rate *= random_range(0.9, 1.1);
    if (_charred.track_exists("anim_crumble")) _charred.play("anim_crumble", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, _charred.anim_rate);
    else _charred.play_all(ReanimLoop.PLAY_ONCE_AND_HOLD);
    instance_create_layer(_charred_x, _charred_y, "Instances", obj_pvz_lawn_fx_piece, {
        fx_sprite: -1,
        fx_vx: 0,
        fx_vy: 0,
        fx_spin: 0,
        // Zombie::ApplyBurn's Zombie_charred anim_crumble is a ~42-frame sequence at ~15 FPS;
        // 160 ticks removed the effect before the last frames that disintegrate the charred zombie.
        fx_life: 360,
        fx_kind: "charred_zombie",
        fx_charred_reanim: _charred,
        fx_charred_finished_age: -1,
        fx_gravity: 0,
        fx_ground_y: _charred_y,
        fx_reflect: 0,
        fx_fade_start: 150,
        fx_scale: 1,
        fx_alpha_mult: 1
    });
    pvz_lawn_zombie_die_no_body(_zid);
}

function pvz_lawn_zombie_die(_zid) {
    if (!instance_exists(_zid)) return;
    pvz_lawn_zombie_cleanup_group(_zid);
    with (_zid) {
        if (dead || global.pvz_lawn_lost_state != "") exit;
        dead = true;
        fade_ticks = -1;
        eating = false;
        phase = "dying";
        target_plant = noone;
        death_sound_played = false;
        if (zombie_kind == "zomboni") { pvz_lawn_play_sound("zamboni.ogg"); pvz_lawn_spawn_particle("ZamboniExplosion", x + 65, y + 45); }
        if (zombie_kind == "catapult") pvz_lawn_spawn_particle("CatapultExplosion", x + 65, y + 45);
        if (zombie_kind == "gargantuar" || zombie_kind == "red_eye_gargantuar") pvz_lawn_play_sound("gargantudeath.ogg");
        if (zombie_kind == "newspaper" && !glasses_dropped) {
            // Fallback for special kill paths that do not first invoke the normal head-loss stage.
            var _glasses_track = body.find_track("Zombie_paper_glasses");
            var _glasses_image = pvz_lawn_track_sprite(body, "Zombie_paper_glasses");
            if (_glasses_image >= 0) {
                var _gp = pvz_lawn_track_world_pos(body, "Zombie_paper_glasses", x + 34, y + 18);
                pvz_lawn_spawn_piece(_glasses_image, _gp[0], _gp[1], random_range(-1.4,1.4), -2.2, random_range(-5,5), 85, "armor", 0.12, 100, 0.2, 15, 0.55);
                if (_glasses_track >= 0) body.set_track_hidden("Zombie_paper_glasses", true);
            }
            glasses_dropped = true;
        }
        if (zombie_kind == "boss") { pvz_lawn_play_sound("bossexplosion.ogg"); pvz_lawn_spawn_particle("BossExplosion", x + 700, y + 280); }
        if (body.track_exists("anim_death")) {
            // Zombie::PlayDeathAnim (Zombie.cpp): standard zombies play anim_death at RandRangeFloat(24,30),
            // and roughly half use anim_death2 when that track exists. Do not force every type into a 12fps pose.
            var _death_track = "anim_death";
            var _death_rate = random_range(24.0, 30.0);
            var _death_roll = irandom(99);
            if (zombie_kind == "football") _death_rate = 24.0;
            else if (zombie_kind == "gargantuar" || zombie_kind == "red_eye_gargantuar" || zombie_kind == "yeti" || zombie_kind == "snorkel") _death_rate = 14.0;
            else if (zombie_kind == "digger") _death_rate = 18.0;
            else if (zombie_kind == "boss") _death_rate = 18.0;
            else if (zombie_kind == "polevaulter") _death_rate = random_range(24.0, 30.0);
            // Source order: rare superlong death requires a later campaign level, no chill, and <=5 zombies.
            var _alive_count = instance_number(obj_zombie_base);
            var _campaign_level = variable_global_exists("pvz_lawn_campaign_level") ? global.pvz_lawn_campaign_level : 1;
            if (_death_roll == 99 && _campaign_level > 5 && body.track_exists("anim_superlongdeath") && _alive_count <= 5) {
                _death_track = "anim_superlongdeath";
                _death_rate = 14.0;
            } else if (_death_roll > 50 && body.track_exists("anim_death2")) {
                _death_track = "anim_death2";
            }
            body.play(_death_track, ReanimLoop.PLAY_ONCE_AND_HOLD, (zombie_kind == "polevaulter" ? 0 : 20), _death_rate);
            death_ticks = max(35, ceil(body.frame_count / max(_death_rate, 1.0) * 100.0) + 20);
        } else death_ticks = 100;
    }
}

/// Board::ZombieHitHouse -> Zombie::WalkIntoHouse + CutScene::StartZombiesWon.
/// Begin the source-timed pan when a living headed zombie's GetZombieRect enters the house edge.
function pvz_lawn_zombie_start_house_cutscene(_zid) {
    if (!instance_exists(_zid) || global.pvz_lawn_lost_state != "") return;
    global.pvz_lawn_lost_state = "pan";
    global.pvz_lawn_lost_tick = 0;
    global.pvz_lawn_lost_winner = _zid;
    global.pvz_lawn_camera_x = 0;
    global.pvz_lawn_lost_reanim = undefined;
    pvz_lawn_play_sound("losemusic.ogg");
    with (_zid) {
        var _was_eating = eating;
        var _was_pre_vault = phase == "pre_vault";
        eating = false;
        target_plant = noone;
        bite_ticks = 0;
        phase = "house_winner";
        y = 290.0; // Zombie::WalkIntoHouse for day/night/pool/fog backgrounds.
        depth = -y - 31;
        if (zombie_kind == "polevaulter") {
            // Zombie::WalkIntoHouse changes pre-vault pole vaulters to the post-vault walk pose.
            pole_used = true;
            body.set_track_hidden("Zombie_polevaulter_pole", true);
            body.set_track_hidden("Zombie_polevaulter_pole2", true);
            if (_was_pre_vault || _was_eating) pvz_lawn_zombie_play_walk(id, 0);
            else if (body.track_exists("anim_walk")) body.play("anim_walk", ReanimLoop.LOOP, 0, 0);
        } else if (_was_eating) {
            // Reset the 36fps chew animation to the source-calculated walking rate when entering the house.
            pvz_lawn_zombie_play_walk(id, 20);
        }
    }
}

/// LawnMower::MowZombie + Zombie::MowDown. The source plays the mower Foley once when
/// the mower first starts, then FOLEY_SPLAT for each normal zombie it hits. The body is driven
/// by LawnMoweredZombie's 8-frame locator animation; detached parts pop at its end.
function pvz_lawn_zombie_mowdown(_zid) {
    if (!instance_exists(_zid)) return;
    with (_zid) {
        if (dead || phase == "mowered") exit;
        if (zombie_kind == "boss") exit;
        eating = false;
        target_plant = noone;
        bite_ticks = 0;
        if (armor_health > 0) pvz_lawn_zombie_break_armor(id, zombie_kind);
        pvz_lawn_play_splat();
        phase = "mowered";
        mowered_pose = new Reanim("LawnMoweredZombie", x, y);
        mowered_pose.play_all(ReanimLoop.PLAY_ONCE_AND_HOLD);
        // Exact Zombie::MowDown rate from Zombie.cpp: 8 fps, once-and-hold.
        mowered_pose.anim_rate = 8.0;
        mowered_ticks = max(1, ceil(mowered_pose.frame_count / 8.0 * 100.0) + 12);
        mowered_pose.loop_type = ReanimLoop.PLAY_ONCE_AND_HOLD;
    }
}

function pvz_lawn_mower_try_hit(_mower_id, _zid) {
    if (!instance_exists(_mower_id) || !instance_exists(_zid)) return;
    if (_zid.dead || _zid.intro_preview || _zid.phase == "mowered" || _zid.row != _mower_id.row) return;
    if (_zid.zombie_kind == "boss") return;
    if (pvz_lawn_zombie_ignores_ground_collision(_zid)) return;
    // Use original-type rectangles so large vehicles/giants are not treated as a standard 42x115 body.
    var _zrect = pvz_lawn_zombie_hitbox(_zid);
    var _zleft = _zrect[0];
    var _zright = _zrect[2];
    var _ztop = _zrect[1];
    var _zbottom = _zrect[3];
    var _overlap = _mower_id.x < _zright && _mower_id.x + 50 > _zleft
        && _mower_id.y < _zbottom && _mower_id.y + 80 > _ztop;
    // Original mower waits if a headless bungee zombie is the first thing it touches.
    if (!_overlap || (_mower_id.mower_state == "ready" && !_zid.has_head)) return;
    if (_mower_id.mower_state == "ready") {
        _mower_id.mower_state = "triggered";
        _mower_id.chomp_counter = 25;
        _mower_id.mower_body.anim_rate = 70.0;
        pvz_lawn_play_sound("lawnmower.ogg"); // FOLEY_LAWNMOWER in LawnMower::StartMower.
    } else {
        _mower_id.chomp_counter = 50; // LawnMower::MowZombie resets this when it hits another zombie.
    }
    pvz_lawn_zombie_mowdown(_zid);
}

function pvz_lawn_zombie_take_damage(_zid, _damage, _no_body = false) {
    if (!instance_exists(_zid)) return;
    with (_zid) {
        if (dead || _damage <= 0) exit;
        // Zombie::EffectedByDamage: Zomboss legs/body are invulnerable while upright, entering,
        // leaving, stomping, spawning, and taking the RV/Bungee attacks. Damage is accepted only
        // while the head is lowered and actively held down for the spit sequence.
        if (zombie_kind == "boss" && phase != "boss_head_down" && phase != "boss_head_spit" && phase != "boss_head_idle_after_spit") exit;
        // Zombie::TakeDamage ignores further hits once Jack-in-the-Box enters its popping phase.
        if (zombie_kind == "jackbox" && phase == "jack_exploding") exit;
        just_got_shot = 25;
        pvz_lawn_set_reanim_flash(body, just_got_shot, "zombie");
        if (chilled_countdown > 0) {
            pvz_lawn_snowpea_debug("CHILLED HIT FLASH REFRESHED: zombie_id=" + string(id)
                + ", chill_ticks=" + string(chilled_countdown) + ", flash_ticks=" + string(just_got_shot));
        }
        var _remain = _damage;
        // Balloon::TakeFlyingDamage uses its separate 20-health balloon before body health.
        if (zombie_kind == "balloon" && phase == "balloon_flying") {
            flying_health -= _remain;
            _remain = 0;
            if (flying_health <= 0) {
                flying_health = 0;
                phase = "balloon_popping";
                special_counter = 30;
                body.play("anim_pop", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, 24.0);
                pvz_lawn_play_sound("balloon_pop.ogg");
            }
        }
        if (_remain > 0 && armor_health > 0) {
            var _before = armor_health;
            var _applied = min(armor_health, _remain);
            armor_health -= _applied;
            _remain -= _applied;
            if (_before > 0 && armor_health <= 0) pvz_lawn_zombie_break_armor(id, zombie_kind);
            else if (armor_health > 0) pvz_lawn_zombie_update_armor_damage_stage(id);
        }
        if (_remain > 0) body_health -= _remain;
        pvz_lawn_zombie_update_body_damage_stage(id);
        if (has_arm && body_health > 0 && body_health < body_max_health * 2 / 3) pvz_lawn_zombie_lose_arm(id);
        if (has_head && body_health < body_max_health / 3) pvz_lawn_zombie_lose_head(id);
        if (body_health <= 0) {
            if (_no_body) pvz_lawn_zombie_die_no_body(id);
            else pvz_lawn_zombie_die(id);
        }
    }
}

function pvz_lawn_zombie_start_vault(_zid, _plant) {
    if (!instance_exists(_zid) || !instance_exists(_plant)) return;
    with (_zid) {
        if (phase != "pre_vault" || pole_used || dead) exit;
        phase = "vault";
        eating = false;
        target_plant = _plant;
        pole_used = true;
        vault_ticks = 42;
        vault_elapsed = 0;
        vault_start_x = x;
        // Zombie::UpdateZombiePolevaulter calculates mVelX = (mX - plant.mX - 80) / animation duration,
        // then UpdateZombieWalking moves by that velocity during the jump and applies mPosX -= 150
        // when anim_jump ends. Freeze the calculated endpoint at takeoff, not a changing plant target.
        body.play("anim_jump", ReanimLoop.PLAY_ONCE_AND_HOLD, 20, 24.0);
        vault_ticks = max(1, round(body.frame_count / max(body.anim_rate, 1.0) * 100.0));
        vault_speed = (x - _plant.x - 80) / vault_ticks;
        vault_end_x = vault_start_x - (vault_speed * vault_ticks) - 150;
    }
}

/// Source-derived isolated update for the one Zombie::WalkIntoHouse winner.
/// The shared lawn clock remains at zero during defeat, so plants, projectiles, pickups and other zombies freeze.
function pvz_lawn_zombie_step_house_winner(_zid, _ticks) {
    if (!instance_exists(_zid) || _ticks <= 0) return;
    with (_zid) {
        if (global.pvz_lawn_lost_winner != id || dead || phase != "house_winner" || is_undefined(body)) exit;
        repeat (_ticks) {
            if (!instance_exists(id)) break;
            x -= max(0.0, move_speed * 0.47);
            body.x = x;
            body.y = y;
            body.update();
        }
        depth = -y - 31;
    }
}
function pvz_lawn_zombie_step(_zid) {
    if (!instance_exists(_zid)) return;
    with (_zid) {
        if (is_undefined(body)) exit;
        if (global.pvz_lawn_lost_state != "") {
            if (global.pvz_lawn_lost_winner != id || dead || phase != "house_winner") exit;
            repeat (global.pvz_lawn_steps) {
                if (!instance_exists(id)) break;
                // The original mVelX is tuned for the 47 Hz source animation clock; this project simulates at 100 Hz.
                var _winner_speed = max(0.0, move_speed * 0.47);
                x -= _winner_speed;
                // No fixed X clamp: source doorway clipping hides the winner as it walks fully into the house.
                body.x = x;
                body.y = y;
                body.update();
            }
            depth = -y - 31;
            exit;
        }
        if (intro_preview) {
            // Board::UpdateGameObjects keeps cutscene zombies updating while CutScene::Update
            // pauses its timeline for SeedChooserScreen. Advance only the body reanimation here;
            // do not move the zombie or advance its gameplay state while the chooser is open.
            var _preview_visual_steps = global.pvz_lawn_steps;
            if (_preview_visual_steps <= 0 && variable_global_exists("pvz_lawn_seed_chooser_active")
                && global.pvz_lawn_seed_chooser_active) {
                _preview_visual_steps = max(0, global.pvz_lawn_visual_steps);
            }
            repeat (_preview_visual_steps) {
                body.x = x;
                body.y = y;
                body.update();
            }
            // CutScene::Update removes scenery zombies after the full ReadySetPlant sequence,
            // not at the instant the camera reaches the lawn again.
            if (global.pvz_lawn_ready_set_plant_ticks >= PVZ_READY_SET_PLANT_END - PVZ_READY_SET_PLANT_START) instance_destroy();
            exit;
        }
        // Zombie::GetPosYBasedOnRow: row anchor minus 30px. Keep Pole Vaulters locked to
        // their assigned lane even through the jump/run animation state transitions.
        if (zombie_kind == "polevaulter") y = pvz_lawn_row_y(row, x, -30);
        depth = -y - 31; // Match source row-based render ordering.
        var _ticks = global.pvz_lawn_steps;
        repeat (_ticks) {
            if (!instance_exists(id)) break;
            if (just_got_shot > 0) just_got_shot--;
            var _snowpea_chill_before_step = chilled_countdown;
            if (chilled_countdown > 0) chilled_countdown--;
            if (_snowpea_chill_before_step > 0 && chilled_countdown <= 0) {
                pvz_lawn_snowpea_debug("CHILL EXPIRED: zombie_id=" + string(id) + ", kind=" + string(zombie_kind) + ", tint should now be cleared");
            }
            pvz_lawn_set_reanim_flash(body, just_got_shot, "zombie");
            // Snow Pea applies the source chill slowdown through the zombie's gait clock, not a separate X slide.
            if (!dead && !eating && (phase == "normal" || phase == "pre_vault" || phase == "post_vault")) {
                var _base_walk_rate = pvz_lawn_zombie_anim_rate(body, move_speed);
                body.anim_rate = chilled_countdown > 0 ? _base_walk_rate * 0.4 : _base_walk_rate;
            }
            // OG movement speed (mVelX) is calibrated for the 47 Hz game/animation clock.
            // Reanim updates run on the 100 Hz recreation clock, so convert position-per-tick by 47/100;
            // otherwise the body moves roughly twice as far per gait cycle and visibly slides.
            var _ground_speed = 0.0;
            if (!dead && !eating && phase != "vault" && phase != "mowered") _ground_speed = pvz_lawn_ground_track_speed(body, move_speed);
            if (phase == "mowered" && !is_undefined(mowered_pose)) {
                mowered_pose.x = x;
                mowered_pose.y = y;
                mowered_pose.update();
                var _mowed_track = mowered_pose.find_track("locator");
                if (_mowed_track >= 0) body.overlay = mowered_pose.get_attachment_overlay_matrix(_mowed_track);
            }
            body.x = x;
            body.y = y;
            var _old_anim_time = body.anim_time;
            body.update();
            // The blue visual follows the exact same timer as the slowdown: clear it
            // immediately when the counter reaches zero, including on attached parts.
            var _chill_active = chilled_countdown > 0;
            pvz_lawn_reanim_set_tint(body, _chill_active,
                _chill_active ? make_color_rgb(75, 75, 255) : c_white);
// Targeted fix: recover a stopped gait without changing the source movement conversion.
            if (!dead && !eating && (phase == "normal" || phase == "pre_vault" || phase == "post_vault")
                && (body.dead || move_speed <= 0.001 || body.anim_rate <= 0.001)) {
                pvz_lawn_zombie_play_walk(id, 0);
            }

            // Zombie::UpdateReanim plays FOLEY_ZOMBIE_FALLING at the death animation's timed fall event.
            if (dead && !death_sound_played) {
                var _fall_time = zombie_kind == "polevaulter" ? 0.68 : 0.77;
                if (_old_anim_time < _fall_time && body.anim_time >= _fall_time) {
                    pvz_lawn_play_random_sound(["zombie_falling_1.ogg", "zombie_falling_2.ogg"]);
                    death_sound_played = true;
                }
            }

            // Zombie::UpdatePlaying: one in mZombies.mSize chance at countdown 0, only for
            // living headed zombies, not the boss/award state. Reset only after an actual groan.
            if (phase != "mowered") {
                if (groan_countdown > 0) groan_countdown--;
                if (groan_countdown == 0 && has_head && !dead && zombie_kind != "boss" && zombie_kind != "zomboni" && zombie_kind != "catapult") {
                    var _total_zombies = instance_number(obj_zombie_base);
                    if (zombie_kind == "gargantuar" || zombie_kind == "red_eye_gargantuar") {
                        pvz_lawn_play_random_sound(["lowgroan.ogg", "lowgroan2.ogg"]);
                        groan_countdown = 650 + irandom(500);
                    } else if (_total_zombies > 0 && irandom(_total_zombies - 1) == 0) {
                        pvz_lawn_play_zombie_groan(has_tongue);
                        groan_countdown = 500 + irandom(999); // Source: Rand(1000) + 500.
                    } else groan_countdown = 120;
                }
                if ((zombie_kind == "gargantuar" || zombie_kind == "red_eye_gargantuar") && !dead && !eating) {
                    garg_footstep_counter--;
                    if (garg_footstep_counter <= 0) {
                        pvz_lawn_play_sound("grassstep.ogg");
                        garg_footstep_counter = 40 + irandom(35);
                    }
                }
                if (dead && (zombie_kind == "gargantuar" || zombie_kind == "red_eye_gargantuar") && !garg_death_thud_played && body.anim_time >= 0.72) {
                    pvz_lawn_play_sound("gargantuar_thump.ogg");
                    garg_death_thud_played = true;
                }
            }

            // Zombie::AnimateChewSound calls Foley at the original timed event phases (normal
            // zombies 0.14/0.68, Pole Vaulter 0.38/0.80). Recreate those crossings on the same
            // Reanim animation clock rather than playing a chomp every bite damage tick.
            if (eating && !dead) {
                var _sound_t1 = zombie_kind == "polevaulter" ? 0.38 : 0.14;
                var _sound_t2 = zombie_kind == "polevaulter" ? 0.80 : 0.68;
                var _new_anim_time = body.anim_time;
                var _wrapped = _new_anim_time < _old_anim_time;
                var _hit_t1 = (!_wrapped && _old_anim_time < _sound_t1 && _new_anim_time >= _sound_t1) || (_wrapped && (_old_anim_time < _sound_t1 || _new_anim_time >= _sound_t1));
                var _hit_t2 = (!_wrapped && _old_anim_time < _sound_t2 && _new_anim_time >= _sound_t2) || (_wrapped && (_old_anim_time < _sound_t2 || _new_anim_time >= _sound_t2));
                if (_hit_t1 || _hit_t2) {
                    // Zombie::AnimateChewSound: FOLEY_CHOMP_SOFT for Wall-nut/Tall-nut/Pumpkin, else FOLEY_CHOMP.
                    var _chew_label = "";
                    if (instance_exists(target_plant) && variable_instance_exists(target_plant, "plant_kind")) _chew_label = string_lower(string(target_plant.plant_kind));
                    var _soft_chew = string_pos("nut", _chew_label) > 0 || string_pos("pumpkin", _chew_label) > 0;
                    if (_soft_chew) pvz_lawn_play_sound("chompsoft.ogg");
                    else pvz_lawn_play_random_sound(["chomp.ogg", "chomp2.ogg"]);
                    // Zombie::AnimateChewEffect: Wall-nut/Tall-nut crumb particle + flash refresh to 25,
                    // both only on the chew-animation timed events (never per bite damage tick).
                    if (instance_exists(target_plant) && target_plant.plant_health > 0) {
                        pvz_lawn_spawn_wallnut_bite_particle(id, target_plant);
                        target_plant.eaten_flash_countdown = max(target_plant.eaten_flash_countdown, 25);
                    }
                }
                chew_anim_time = _new_anim_time;
            }

            if (dead) {
                // Zombie::UpdateReanim: keep the completed death pose, then fade with mZombieFade.
                // The timer is a safety fallback if an imported death track never reports its loop.
                if (fade_ticks < 0) {
                    death_ticks--;
                    if (body.loop_count > 0 || death_ticks <= 0) fade_ticks = 100;
                } else {
                    fade_ticks--;
                    if (fade_ticks <= 0) instance_destroy();
                }
                continue;
            }
            if (phase == "mowered") {
                mowered_ticks--;
                if (mowered_ticks <= 0 || (!is_undefined(mowered_pose) && mowered_pose.loop_count > 0)) {
                    // UpdateMowered drops the head and arm when LawnMoweredZombie finishes.
                    // Do both while the last transform is still available for part positioning.
                    pvz_lawn_zombie_lose_head(id);
                    pvz_lawn_zombie_lose_arm(id);
                    instance_destroy();
                }
                continue;
            }
            if (!has_head) {
                // Zombie::Update applies residual damage with Rand(5)==0. This explicit branch
                // prevents every bite/target path from running on a headless zombie.
                eating = false;
                target_plant = noone;
                bite_ticks = 0;
                if (irandom(4) == 0) {
                    body_health -= (body_max_health >= 500 ? 3 : 1);
                    if (body_health <= 0) { pvz_lawn_zombie_die(id); continue; }
                }
                if (phase != "vault") x -= _ground_speed;
                body.x = x;
                body.y = y;
                if (x < -70) instance_destroy();
                continue;
            }
            if (phase == "vault") {
                vault_elapsed++;
                // Original UpdateZombieWalking moves by mVelX during the vault. That speed is
                // calculated from the remaining plant gap (not a second 150px interpolation).
                x -= vault_speed;
                body.x = x;
                if (vault_elapsed >= vault_ticks) {
                    // The locked endpoint is exactly: per-tick mVelX travel, then source mPosX -= 150.
                    // Using the precomputed value avoids any endpoint snap if the target changes mid-jump.
                    x = vault_end_x;
                    body.x = x;
                    body.set_track_hidden("Zombie_polevaulter_pole", true);
                    body.set_track_hidden("Zombie_polevaulter_pole2", true);
                    body.play("anim_walk", ReanimLoop.LOOP, 0, 0);
                    phase = "post_vault";
                    move_speed = random_range(0.16, 0.22);
                    body.anim_rate = pvz_lawn_zombie_anim_rate(body, move_speed);
                    target_plant = noone;
                }
                continue;
            }
            // Zombie::UpdateClimbingLadder: ordinary zombies climb a ladder fitted to a Wall-nut/Tall-nut/Pumpkin.
            if (phase == "normal" && !eating && has_head && !dead) {
                var _ladder_cell_col = clamp(floor((x + 55 - PVZ_GRID_X) / PVZ_CELL_W), 0, PVZ_COLS - 1);
                var _ladder_plant = global.pvz_lawn_grid[# _ladder_cell_col, row];
                if (instance_exists(_ladder_plant) && variable_instance_exists(_ladder_plant, "laddered") && _ladder_plant.laddered
                    && abs(x - _ladder_plant.x) < 86 && !(_ladder_plant.plant_kind == "flower_pot")) {
                    phase = "climbing_existing_ladder"; target_plant = _ladder_plant; eating = false;
                    special_counter = 112; altitude = 0; move_speed = 0.3;
                    if (body.track_exists("anim_walk")) body.play("anim_walk", ReanimLoop.LOOP, 10, 0);
                    continue;
                }
            }
            if (pvz_lawn_zombie_step_special(id, _ground_speed)) continue;
            var _reach = phase == "pre_vault" ? 105 : 63;
            var _plant = pvz_lawn_find_plant(id, _reach);
            if (phase == "pre_vault" && zombie_kind == "polevaulter" && has_head && instance_exists(_plant)) {
                pvz_lawn_zombie_start_vault(id, _plant);
                continue;
            }
            if (eating) {
                // Keep the same zombie-relative bite reach used when eating begins. Comparing
                // plant.x against x here used the inverse bounds, so adjacent plants made the
                // zombie cancel/restart its chew animation before the first bite timer elapsed.
                if (!instance_exists(target_plant) || target_plant.plant_health <= 0 || x < target_plant.x - 60 || x > target_plant.x + 20) {
                    pvz_lawn_zombie_play_walk(id, 20);
                    target_plant = noone;
                    continue;
                }
                bite_ticks++;
                var _bite_interval = 4; // Zombie.h: TICKS_BETWEEN_EATS = 4 for every ordinary zombie type
                if (bite_ticks >= _bite_interval) {
                    bite_ticks = 0;
                    target_plant.plant_health -= 4; // Zombie.h: DAMAGE_PER_EAT = TICKS_BETWEEN_EATS = 4
                    target_plant.recently_eaten = 50;
                    if (target_plant.plant_health <= 0) {
                        // Zombie::EatPlant plays SOUND_GULP when the plant is eaten completely.
                        pvz_lawn_play_sound("gulp.ogg");
                        var _col = target_plant.cell_col;
                        var _row = target_plant.cell_row;
                        if (global.pvz_lawn_grid[# _col, _row] == target_plant) global.pvz_lawn_grid[# _col, _row] = noone;
                        instance_destroy(target_plant);
                        target_plant = noone;
                        pvz_lawn_zombie_play_walk(id, 20);
                    }
                }
            } else {
                if (instance_exists(_plant) && x <= _plant.x + 20 && x >= _plant.x - 60) {
                    pvz_lawn_zombie_begin_eating(id, _plant);
                } else {
                    if (walks_backwards) x += _ground_speed; else x -= _ground_speed;
                }
            }
            body.x = x;
            body.y = y;
            // Zombie::GetZombieRect left edge = mPosX+36 (normal), +50 (Pole Vaulter).
            // Board::ZombieHitHouse starts the loss cutscene when that headed-zombie rect reaches x<0.
            var _house_rect_left = x + (zombie_kind == "polevaulter" ? 50 : 36);
            if (walks_backwards && x > room_width + 100) { instance_destroy(); continue; }
            if (has_head && _house_rect_left < 0) {
                pvz_lawn_zombie_start_house_cutscene(id);
                exit;
            }
            if (x < -70) instance_destroy();
        }
    }
}

function pvz_lawn_plant_init(_kind) {
    plant_kind = _kind;
    cell_col = clamp(floor((x - PVZ_GRID_X) / PVZ_CELL_W), 0, PVZ_COLS - 1);
    cell_row = clamp(floor((y - PVZ_GRID_Y) / pvz_lawn_cell_height()), 0, pvz_lawn_active_rows() - 1);
    // Plant.cpp defaults ordinary plant health to 300; Wall-nut overrides this to 4000.
    plant_health = (_kind == "wallnut") ? 4000 : 300;
    laddered = false;
    recently_eaten = 0;
    on_bungee = false;
    bungee_lift_counter = 0;
    bungee_start_y = y;
    eaten_flash_countdown = 0;
    body = undefined;
    head = undefined;
    blink = undefined;
    // Plant::Plant initializes mBlinkCountdown to 400 + Rand(400); Wall-nut's next blink is slower.
    blink_countdown = irandom_range(400, 799);
    anim_shoot_ticks = 0;
    pea_launch_ticks = irandom_range(0, 150);
    produce_countdown = irandom_range(300, 1250);
    plant_state = "idle";
    plant_state_countdown = 0;
    mine_armed = false;
    mine_light = undefined;
    mine_closest_distance = 1000.0;
    chomper_target = noone;
    repeater_second_shot_countdown = -1;

    var _aname = pvz_lawn_plant_reanim_name(_kind);
    var _shooter = (_kind == "peashooter" || _kind == "snow_pea" || _kind == "repeater");
    body = new Reanim(_aname, x, y);
    // Plant::Draw in the original game scales Potato Mine to 0.8 and applies a +12px,+12px draw offset.
    body.scale_x = (_kind == "potato_mine") ? 0.8 : 1.0;
    body.scale_y = (_kind == "potato_mine") ? 0.8 : 1.0;
    body.loop_type = ReanimLoop.LOOP;
    body.anim_rate = random_range(10, 15);
    if (_shooter) {
        body.set_frames_for_layer("anim_idle");
        if (body.track_exists("anim_head_idle") && body.track_exists("anim_stem")) {
            head = new Reanim(_aname, 0, 0);
            head.scale_x = 1.0;
            head.scale_y = 1.0;
            head.loop_type = ReanimLoop.LOOP;
            head.anim_rate = body.anim_rate;
            head.set_frames_for_layer("anim_head_idle");
            head.attach_to(body, "anim_stem");
        }
    } else if (_kind == "potato_mine") {
        // Plant.cpp: stay as a low, non-armed mound for 1500 ticks, with its glow hidden.
        plant_state = "arming";
        plant_state_countdown = 1500;
        body.play("anim_idle", ReanimLoop.LOOP, 0, 12.0);
        body.set_track_hidden("anim_glow", true);
    } else if (_kind == "cherry_bomb") {
        // Plant.cpp starts anim_explode and the reverse-explosion foley at planting time.
        plant_state = "fuse";
        plant_state_countdown = 100;
        body.play("anim_explode", ReanimLoop.PLAY_ONCE_AND_HOLD, 0, body.anim_rate);
        pvz_lawn_play_sound("reverse_explosion.ogg");
    } else if (_kind == "chomper") {
        body.play("anim_idle", ReanimLoop.LOOP, 0, body.anim_rate);
    } else if (body.track_exists("anim_idle")) {
        body.play("anim_idle", ReanimLoop.LOOP, 0, body.anim_rate);
    } else {
        body.play_all(ReanimLoop.LOOP);
    }

    // Plant::AttachBlinkAnim: the authentic anim_blink attachment is reused rather than allocated repeatedly.
    if (body.track_exists("anim_blink") || (_kind == "wallnut" && body.track_exists("anim_blink_twice"))) {
        blink = new Reanim(_aname, 0, 0);
        var _initial_blink_track = (_kind == "wallnut") ? "anim_blink_twice" : "anim_blink";
        blink.play(_initial_blink_track, ReanimLoop.PLAY_ONCE_FULL_LAST_FRAME_AND_HOLD, 0, 15.0);
        blink.dead = true;
        if (_shooter && !is_undefined(head) && head.track_exists("anim_face")) {
            blink.attach_to(head, "anim_face");
        } else if (body.track_exists("anim_face")) {
            blink.attach_to(body, "anim_face");
        } else if (body.track_exists("anim_idle")) {
            blink.attach_to(body, "anim_idle");
        }
    }
    depth = -y;
}

/// Plant::AnimateNuts from Plant.cpp. Preserve the source's integer thresholds and only
/// replace the anim_face image while the Wall-nut is damaged.
function pvz_lawn_update_wallnut_degradation(_plant) {
    if (!instance_exists(_plant) || !variable_instance_exists(_plant, "plant_health")) return;
    if (!variable_instance_exists(_plant, "plant_kind") || _plant.plant_kind != "wallnut") return;
    if (is_undefined(_plant.body) || _plant.body == noone) return;

    if (!variable_global_exists("pvz_fx_wallnut_cracked1")) global.pvz_fx_wallnut_cracked1 = reanim_get_part_sprite("reanim/Wallnut_cracked1.png");
    if (!variable_global_exists("pvz_fx_wallnut_cracked2")) global.pvz_fx_wallnut_cracked2 = reanim_get_part_sprite("reanim/Wallnut_cracked2.png");

    // C++ uses integer division: 4000 / 3 == 1333, (4000 * 2) / 3 == 2666.
    var _stage = 0;
    if (_plant.plant_health < floor(4000 / 3)) _stage = 2;
    else if (_plant.plant_health < floor((4000 * 2) / 3)) _stage = 1;

    var _sprite = -1;
    if (_stage == 1) _sprite = global.pvz_fx_wallnut_cracked1;
    else if (_stage == 2) _sprite = global.pvz_fx_wallnut_cracked2;
    var _track = _plant.body.find_track("anim_face");
    if (_track < 0) return;
    if (_plant.body.track_sprite_override[_track] != _sprite) {
        _plant.body.track_sprite_override[_track] = _sprite;
        if (_stage > 0) pvz_lawn_spawn_particle("WallnutEatLarge", _plant.x + 40, _plant.y + 10);
    }
}



/// Plant::Squish from Plant.cpp: flatten the plant, remove effects, and leave a short-lived smashed sprite.
function pvz_lawn_plant_squish(_pid) {
    if (!instance_exists(_pid)) return;
    with (_pid) {
        if (is_undefined(body) || body == noone || (variable_instance_exists(id, "squished") && squished)) exit;
        if (variable_instance_exists(id, "plant_kind") && plant_kind == "cherry_bomb") {
            // Plant::Squish -> Plant::DoSpecial(SEED_CHERRYBOMB): detonate immediately and consume the plant.
            pvz_lawn_play_sound("cherrybomb.ogg");
            pvz_lawn_play_sound("juicy.ogg");
            pvz_lawn_plant_explode(id, 1800, 115, 1, 40, "burn");
            pvz_lawn_spawn_particle("Powie", x + 40, y + 40);
            plant_state = "explode"; plant_state_countdown = 1;
            if (global.pvz_lawn_grid[# cell_col, cell_row] == id) global.pvz_lawn_grid[# cell_col, cell_row] = noone;
            exit;
        }
        if (variable_instance_exists(id, "plant_kind") && plant_kind == "potato_mine" && plant_state == "armed") {
            // Plant::Squish only triggers a Potato Mine after its armed state; arming/rising mines flatten.
            pvz_lawn_plant_explode(id, 1800, 60, 0, 20, "no_body");
            pvz_lawn_play_sound("potato_mine.ogg");
            if (!is_undefined(mine_light) && mine_light != noone) mine_light.dead = true;
            if (!is_undefined(body) && body != noone) body.set_track_hidden("anim_glow", true);
            pvz_lawn_spawn_particle("PotatoMine", x + 20, y + 40);
            plant_state = "explode"; plant_state_countdown = 1;
            if (global.pvz_lawn_grid[# cell_col, cell_row] == id) global.pvz_lawn_grid[# cell_col, cell_row] = noone;
            exit;
        }
        squished = true; squish_countdown = 500;
        if (variable_global_exists("pvz_lawn_grid") && ds_exists(global.pvz_lawn_grid, ds_type_grid) && cell_col >= 0 && cell_col < PVZ_COLS && cell_row >= 0 && cell_row < pvz_lawn_active_rows() && global.pvz_lawn_grid[# cell_col, cell_row] == id) global.pvz_lawn_grid[# cell_col, cell_row] = noone;
        body.scale_y = 0.25; body.y = y + 45;
        if (!is_undefined(head) && head != noone) { head.scale_y = 0.25; head.y = y + 45; }
        if (!is_undefined(blink) && blink != noone) { blink.scale_y = 0.25; blink.y = y + 45; }
        pvz_lawn_play_sound("squish.ogg");
    }
}

function pvz_lawn_plant_step(_kind) {
    if (is_undefined(body)) exit;
    var _ticks = global.pvz_lawn_steps;
    repeat (_ticks) {
        if (!instance_exists(id)) break;
        body.x = x;
        body.y = y;
        if (variable_instance_exists(id, "squished") && squished) {
            squish_countdown--;
            body.x = x; body.y = y + 45;
            if (!is_undefined(head) && head != noone) { head.x = x; head.y = y + 45; }
            if (!is_undefined(blink) && blink != noone) { blink.x = x; blink.y = y + 45; }
            body.scale_y = 0.25;
            if (!is_undefined(head) && head != noone) head.scale_y = 0.25;
            if (!is_undefined(blink) && blink != noone) blink.scale_y = 0.25;
            if (squish_countdown <= 0) { instance_destroy(); break; }
            body.update();
            continue;
        }
        if (recently_eaten > 0) recently_eaten--;
        // Plant::AnimateNuts nearly freezes Wall-nut's facial animation after a bite, then restores 10-15fps.
        if (_kind == "wallnut") {
            if (recently_eaten > 0) body.anim_rate = 0.1;
            else if (body.anim_rate < 1.0) body.anim_rate = random_range(10.0, 15.0);
        }
        // Reanim::Update recursively advances attached heads/blinks; never advance the children twice.
        body.update();
        if (_kind == "wallnut") pvz_lawn_update_wallnut_degradation(id);
        if (eaten_flash_countdown > 0) eaten_flash_countdown--;
        pvz_lawn_set_reanim_flash(body, eaten_flash_countdown, "plant");
        if (!is_undefined(head)) pvz_lawn_set_reanim_flash(head, eaten_flash_countdown, "plant");
        if (!is_undefined(blink)) pvz_lawn_set_reanim_flash(blink, eaten_flash_countdown, "plant");
        if (plant_health <= 0) {
            if (global.pvz_lawn_grid[# cell_col, cell_row] == id) global.pvz_lawn_grid[# cell_col, cell_row] = noone;
            instance_destroy();
            break;
        }

        // Once a special plant has detonated it leaves the grid immediately, but its real reanimation finishes.
        if (plant_state == "explode") {
            plant_state_countdown--;
            if (plant_state_countdown <= 0) { instance_destroy(); break; }
            continue;
        }

        if (!is_undefined(blink) && !blink.dead && blink.loop_count > 0) {
            blink.dead = true;
            if (_kind == "wallnut") body.set_tracks_hidden_by_prefix("anim_eye", false);
        }
        blink_countdown--;
        if (blink_countdown <= 0) {
            blink_countdown = (_kind == "wallnut") ? irandom_range(1000, 1999) : irandom_range(400, 799);
            var _may_blink = (_kind != "potato_mine" || plant_state == "armed");
            if (!is_undefined(blink) && _may_blink && ((_kind != "peashooter" && _kind != "snow_pea" && _kind != "repeater") || anim_shoot_ticks == 0)) {
                blink.dead = false;
                if (_kind == "wallnut") {
                    // AttachBlinkAnim randomly selects the original twitch/twice/thrice wall-nut blink.
                    var _wallnut_blink_roll = irandom(9);
                    var _wallnut_blink_track = (_wallnut_blink_roll == 0 && body.track_exists("anim_blink_twitch")) ? "anim_blink_twitch" : ((_wallnut_blink_roll < 7) ? "anim_blink_twice" : "anim_blink_thrice");
                    blink.play(_wallnut_blink_track, ReanimLoop.PLAY_ONCE_FULL_LAST_FRAME_AND_HOLD, 0, 15.0);
                    body.set_tracks_hidden_by_prefix("anim_eye", true);
                } else {
                    blink.play("anim_blink", ReanimLoop.PLAY_ONCE_FULL_LAST_FRAME_AND_HOLD, 0, 15.0);
                }
            }
        }

        if (_kind == "sunflower") {
            produce_countdown--;
            if (produce_countdown <= 100) {
                var _produce_flash = clamp(100 - produce_countdown, 0, 100);
                eaten_flash_countdown = max(eaten_flash_countdown, _produce_flash);
            }
            if (produce_countdown <= 0) {
                produce_countdown = irandom_range(2350, 2500);
                instance_create_layer(x, y, "Instances", obj_pvz_sun_pickup, {sun_motion: "from_plant"});
            }
        } else if (_kind == "cherry_bomb") {
            // CherryBomb::InitializePlant gives a 100-tick fuse; DoSpecial detonates in a 115px radius over 3 rows.
            plant_state_countdown--;
            if (plant_state_countdown <= 0) {
                pvz_lawn_play_sound("cherrybomb.ogg");
                pvz_lawn_play_sound("juicy.ogg");
                pvz_lawn_plant_explode(id, 1800, 115, 1, 40, "burn");
                pvz_lawn_spawn_particle("Powie", x + 40, y + 40);
                plant_state = "explode";
                plant_state_countdown = 1;
                if (global.pvz_lawn_grid[# cell_col, cell_row] == id) global.pvz_lawn_grid[# cell_col, cell_row] = noone;
            }
        } else if (_kind == "potato_mine") {
            if (plant_state == "arming") {
                plant_state_countdown--;
                if (plant_state_countdown <= 0) {
                    // PotatoMine::UpdatePotato: rise animation is 18fps, one-shot, then it arms.
                    plant_state = "rising";
                    body.play("anim_rise", ReanimLoop.PLAY_ONCE_AND_HOLD, 20, 18.0);
                    pvz_lawn_play_sound("dirt_rise.ogg");
                    pvz_lawn_spawn_particle("PotatoMineRise", x + 40, y + 40);
                }
            } else if (plant_state == "rising") {
                if (body.loop_count > 0) {
                    var _mine_rate = random_range(12.0, 15.0);
                    body.play("anim_armed", ReanimLoop.LOOP, 0, _mine_rate);
                    body.set_track_hidden("anim_glow", true);
                    mine_light = new Reanim("PotatoMine", 0, 0);
                    mine_light.loop_type = ReanimLoop.LOOP;
                    mine_light.anim_rate = _mine_rate - 2.0;
                    mine_light.set_frames_for_layer("anim_glow");
                    mine_light.frame_count = 10;
                    mine_light.show_only_track("anim_glow");
                    mine_light.set_track_hidden("anim_glow", false);
                    mine_light.attach_to(body, "anim_light");
                    mine_armed = true;
                    plant_state = "armed";
                    blink_countdown = irandom_range(400, 4399);
                }
            } else if (plant_state == "armed") {
                // Plant::UpdatePotato uses FindTargetZombie on the mine's attack rectangle.
                var _mine_triggered = pvz_lawn_potato_mine_find_trigger(id);
                // OG Potato Mine's glow contracts from 10 frames to 3 as a same-row zombie approaches.
                if (!is_undefined(mine_light) && mine_light != noone) {
                    var _glow_progress = clamp((mine_closest_distance - 50.0) / 150.0, 0.0, 1.0);
                    mine_light.frame_count = round(3.0 + 7.0 * _glow_progress);
                }
                if (_mine_triggered) {
                    // Plant.cpp: Potato Mine's detonation is a 60px blast on the planting row only.
                    pvz_lawn_plant_explode(id, 1800, 60, 0, 20, "no_body");
                    pvz_lawn_play_sound("potato_mine.ogg");
                    if (!is_undefined(mine_light)) mine_light.dead = true;
                    body.set_track_hidden("anim_glow", true);
                    plant_state = "explode";
                    plant_state_countdown = 1;
                    if (global.pvz_lawn_grid[# cell_col, cell_row] == id) global.pvz_lawn_grid[# cell_col, cell_row] = noone;
                    // PotatoMine.xml already contains the original Mashed, low/high fragments,
                    // Spudow word and flash emitters. Do not overlay a second plant-body mash.
                    pvz_lawn_spawn_particle("PotatoMine", x + 40, y + 40);
                }
            }
        } else if (_kind == "chomper") {
            if (plant_state == "chomper_bite") {
                plant_state_countdown--;
                if (plant_state_countdown <= 0) {
                    pvz_lawn_play_sound("bigchomp.ogg");
                    var _chomper_miss = !instance_exists(chomper_target);
                    if (!_chomper_miss && instance_exists(chomper_target)) {
                        if (chomper_target.dead || !chomper_target.has_head) {
                            _chomper_miss = true;
                        } else if (chomper_target.zombie_kind == "polevaulter" && (chomper_target.phase == "pre_vault" || chomper_target.phase == "vault")) {
                            _chomper_miss = true;
                        }
                    }
                    if (!_chomper_miss) {
                        // Plant::UpdateChomper: the swallowed zombie is consumed outright; it does not leave a death pose/corpse.
                        if (instance_exists(chomper_target)) instance_destroy(chomper_target);
                        pvz_lawn_play_sound("chomp.ogg");
                        plant_state = "chomper_digesting";
                        plant_state_countdown = 4000;
                        body.play("anim_chew", ReanimLoop.LOOP, 0, 15.0);
                    } else {
                        plant_state = "chomper_miss";
                        plant_state_countdown = 18;
                    }
                }
            } else if (plant_state == "chomper_miss") {
                plant_state_countdown--;
                if (plant_state_countdown <= 0) {
                    chomper_target = noone;
                    plant_state = "idle";
                    body.play("anim_idle", ReanimLoop.LOOP, 20, body.anim_rate);
                }
            } else if (plant_state == "chomper_digesting") {
                // Original Chomper chews for 4000 ticks, then plays the swallow animation and becomes ready.
                plant_state_countdown--;
                if (plant_state_countdown <= 0) {
                    plant_state = "chomper_swallowing";
                    plant_state_countdown = 100;
                    body.play("anim_swallow", ReanimLoop.PLAY_ONCE_AND_HOLD, 20, 12.0);
                }
            } else if (plant_state == "chomper_swallowing") {
                plant_state_countdown--;
                if (body.loop_count > 0 || plant_state_countdown <= 0) {
                    chomper_target = noone;
                    plant_state = "idle";
                    body.play("anim_idle", ReanimLoop.LOOP, 20, body.anim_rate);
                }
            } else if (plant_state == "idle") {
                global.pvz_lawn_chomper_target = noone;
                with (obj_zombie_base) if (global.pvz_lawn_chomper_target == noone && !dead && !intro_preview && has_head && row == other.cell_row && !(zombie_kind == "balloon" && phase == "balloon_flying") && !(zombie_kind == "boss" && phase != "boss_head_down" && phase != "boss_head_spit" && phase != "boss_head_idle_after_spit") && x + 78 > other.x + 25 && x <= other.x + 155) global.pvz_lawn_chomper_target = id;
                if (global.pvz_lawn_chomper_target != noone) {
                    chomper_target = global.pvz_lawn_chomper_target;
                    plant_state = "chomper_bite";
                    // UpdateChomper starts a 24fps bite animation and waits 70 source ticks.
                    plant_state_countdown = 70;
                    body.play("anim_bite", ReanimLoop.PLAY_ONCE_AND_HOLD, 20, 24.0);
                }
            }
        } else if (_kind == "peashooter" || _kind == "snow_pea" || _kind == "repeater") {
            // Source Plant::UpdateShooting / UpdateShooter: target any zombie in this row, then fire on a 150-tick cadence.
            if (anim_shoot_ticks > 0) {
                anim_shoot_ticks--;
                if (anim_shoot_ticks == 1) {
                    pvz_lawn_play_random_sound(["throw.ogg", "throw.ogg", "throw.ogg", "throw2.ogg"]);
                    var _projectile_kind = (_kind == "snow_pea") ? "snowpea" : "pea";
                    if (_kind == "snow_pea") {
                        // Plant::Fire: Snow Pea has its own sparkle foley and muzzle puff.
                        pvz_lawn_play_sound("snow_pea_sparkles.ogg");
                        pvz_lawn_spawn_particle("SnowPeaPuff", x + 62, y + 16);
                    }
                    var _spawned_projectile = instance_create_layer(x + 62, y + 16, "Instances", obj_pvz_pea_projectile, {projectile_row: cell_row, projectile_kind: _projectile_kind});
                    if (_kind == "snow_pea") {
                        var _actual_projectile_kind = instance_exists(_spawned_projectile) ? string(_spawned_projectile.projectile_kind) : "<spawn failed>";
                        pvz_lawn_snowpea_debug("SHOT: plant fired; requested projectile_kind=" + string(_projectile_kind) + ", actual=" + _actual_projectile_kind + ", row=" + string(cell_row) + ", projectile_id=" + string(_spawned_projectile));
                    }
                }
                if (anim_shoot_ticks == 0 && !is_undefined(head) && body.track_exists("anim_head_idle")) head.play("anim_head_idle", ReanimLoop.LOOP, 20, body.anim_rate);
            }
            global.pvz_lawn_target_found = false;
            with (obj_zombie_base) {
                var _zr = pvz_lawn_zombie_hitbox(id);
                if (!dead && !intro_preview && has_head && row == other.cell_row
                    && !(zombie_kind == "balloon" && phase == "balloon_flying")
                    && !(zombie_kind == "snorkel" && phase == "snorkel_swimming")
                    && !(zombie_kind == "boss" && phase != "boss_head_down" && phase != "boss_head_spit" && phase != "boss_head_idle_after_spit")
                    && _zr[2] > other.x + 60 && _zr[0] < other.x + 60 + room_width) global.pvz_lawn_target_found = true;
            }
            pea_launch_ticks--;
            var _start_firing_animation = false;
            if (pea_launch_ticks <= 0) {
                pea_launch_ticks = max(1, 150 - irandom(14));
                _start_firing_animation = true;
            } else if (_kind == "repeater" && pea_launch_ticks == 25) {
                // Original Plant::UpdateShooter requests shot two at mLaunchCounter == 25.
                _start_firing_animation = true;
            }
            if (_start_firing_animation && global.pvz_lawn_target_found) {
                if (!is_undefined(head) && head.track_exists("anim_shooting")) {
                    var _shoot_rate = (_kind == "repeater") ? 45.0 : 35.0;
                    head.play("anim_shooting", ReanimLoop.PLAY_ONCE_AND_HOLD, 20, _shoot_rate);
                    anim_shoot_ticks = (_kind == "repeater") ? 26 : 33;
                }
            }
        }
        depth = -y;
    }
}

function pvz_lawn_plant_draw(_kind) {
    var _camera_x = global.pvz_lawn_camera_x;
    var _shadow = global.pvz_shadow_sprite;
    if (_shadow >= 0) {
        var _sw = sprite_get_width(_shadow);
        var _sh = sprite_get_height(_shadow);
        draw_sprite_ext(_shadow, 0, x + 39 - _sw * 0.5 - _camera_x, y + 68 - _sh * 0.5, 1.0, 1.0, 0, c_white, 1);
    } else {
        draw_set_color(make_color_rgb(66, 95, 40));
        draw_set_alpha(0.45);
        draw_ellipse(x + 8 - _camera_x, y + 61, x + 70 - _camera_x, y + 80, false);
        draw_set_alpha(1);
    }
    pvz_lawn_set_reanim_flash(body, eaten_flash_countdown, "plant");
    if (!is_undefined(head)) pvz_lawn_set_reanim_flash(head, eaten_flash_countdown, "plant");
    if (!is_undefined(blink)) pvz_lawn_set_reanim_flash(blink, eaten_flash_countdown, "plant");
    var _hovered_by_shovel = false;
    if (global.pvz_lawn_shovel_selected && !global.pvz_lawn_menu_open) {
        var _world_mouse_x = mouse_x + _camera_x;
        _hovered_by_shovel = point_in_rectangle(_world_mouse_x, mouse_y, x, y, x + 80, y + 80);
    }
    if (_hovered_by_shovel) {
        body.flash_color = c_white;
        body.flash_alpha = 196.0 / 255.0;
        if (!is_undefined(head)) { head.flash_color = c_white; head.flash_alpha = 196.0 / 255.0; }
        if (!is_undefined(blink)) { blink.flash_color = c_white; blink.flash_alpha = 196.0 / 255.0; }
    }
    var _plant_visual_x_offset = (_kind == "potato_mine") ? 12.0 : 0.0;
    var _plant_visual_y_offset = (_kind == "potato_mine") ? 12.0 : ((_kind == "chomper") ? 20.0 : 0.0);
    pvz_lawn_reanim_draw_camera(body, x + _plant_visual_x_offset, y + _plant_visual_y_offset, _camera_x);
    if (variable_instance_exists(id, "laddered") && laddered && variable_global_exists("pvz_zombie_ladder_sprite") && global.pvz_zombie_ladder_sprite >= 0) {
        // Native Zombie_ladder_5 image (GridItem::DrawLadder); drawn at the original grid-relative offset.
        draw_sprite_ext(global.pvz_zombie_ladder_sprite, 0, x + 25 - _camera_x, y - 4, 0.8, 0.8, 0, c_white, 1.0);
    }
    pvz_lawn_set_reanim_flash(body, eaten_flash_countdown, "plant");
    if (!is_undefined(head)) pvz_lawn_set_reanim_flash(head, eaten_flash_countdown, "plant");
    if (!is_undefined(blink)) pvz_lawn_set_reanim_flash(blink, eaten_flash_countdown, "plant");
}

function pvz_lawn_zombie_pick_bungee_target(_zid) {
    if (!instance_exists(_zid) || !variable_global_exists("pvz_lawn_grid")) return false;

    // Zombie::PickBungeeZombieTarget gives an eligible planted cell weight 10000
    // and an empty cell weight 1. Invalid plant cells and cells already targeted
    // by another Bungee are excluded, matching the original weighted grid picker.
    var _sunflower_count = 0;
    var _bungees_targeting_sunflowers = 0;
    for (var _c = 0; _c < PVZ_COLS; _c++) {
        for (var _r = 0; _r < pvz_lawn_active_rows(); _r++) {
            var _p = global.pvz_lawn_grid[# _c, _r];
            if (instance_exists(_p) && variable_instance_exists(_p, "plant_kind")
                && (_p.plant_kind == "sunflower" || _p.plant_kind == "twin_sunflower")) _sunflower_count++;
        }
    }
    with (obj_zombie_base) {
        if (id != _zid && zombie_kind == "bungee" && !dead && instance_exists(target_plant)
            && variable_instance_exists(target_plant, "plant_kind")
            && (target_plant.plant_kind == "sunflower" || target_plant.plant_kind == "twin_sunflower")) {
            _bungees_targeting_sunflowers++;
        }
    }
    var _allow_sunflower_target = !(_sunflower_count > 0 && _bungees_targeting_sunflowers == _sunflower_count - 1);
    var _choices = [];
    var _total_weight = 0;
    for (var _c = 0; _c < PVZ_COLS; _c++) {
        for (var _r = 0; _r < pvz_lawn_active_rows(); _r++) {
            var _p = global.pvz_lawn_grid[# _c, _r];
            var _weight = 1;
            if (instance_exists(_p)) {
                if (!variable_instance_exists(_p, "plant_kind") || !variable_instance_exists(_p, "plant_health") || _p.plant_health <= 0) continue;
                if (_p.plant_kind == "cob_cannon" || _p.plant_kind == "gravebuster" || _p.plant_kind == "grave_buster") continue;
                if (!_allow_sunflower_target && (_p.plant_kind == "sunflower" || _p.plant_kind == "twin_sunflower")) continue;
            }
            var _cell_targeted = false;
            with (obj_zombie_base) {
                if (id != _zid && zombie_kind == "bungee" && !dead && row == _r && bungee_target_col == _c) _cell_targeted = true;
            }
            if (_cell_targeted) continue;
            if (instance_exists(_p)) _weight = 10000;
            array_push(_choices, {col: _c, row: _r, plant: _p, weight: _weight});
            _total_weight += _weight;
        }
    }
    if (array_length(_choices) <= 0 || _total_weight <= 0) return false;

    var _pick = irandom(_total_weight - 1);
    var _chosen = _choices[0];
    for (var _i = 0; _i < array_length(_choices); _i++) {
        _chosen = _choices[_i];
        if (_pick < _chosen.weight) break;
        _pick -= _chosen.weight;
    }
    _zid.target_plant = instance_exists(_chosen.plant) ? _chosen.plant : noone;
    _zid.bungee_target_col = _chosen.col;
    _zid.row = _chosen.row;
    _zid.x = PVZ_GRID_X + _chosen.col * PVZ_CELL_W + 5;
    _zid.y = pvz_lawn_row_y(_zid.row, _zid.x, -30);
    _zid.base_y = _zid.y;
    _zid.body.x = _zid.x;
    _zid.body.y = _zid.y - _zid.altitude;
    return true;
}

function pvz_lawn_zombie_init(_kind) {
    zombie_kind = _kind;
    if (!variable_instance_exists(id, "intro_preview")) intro_preview = false;
    var _is_cone = (_kind == "conehead" || _kind == "ducky_tube_conehead");
    var _is_bucket = (_kind == "buckethead" || _kind == "ducky_tube_buckethead");
    var _is_ducky = string_pos("ducky_tube", _kind) == 1;
    var _is_garg = (_kind == "gargantuar" || _kind == "red_eye_gargantuar");
    var _is_vehicle = (_kind == "zomboni" || _kind == "catapult" || _kind == "bobsled_team");
    body_max_health = 270;
    if (_kind == "polevaulter" || _kind == "dancer" || _kind == "dolphin_rider" || _kind == "jackbox" || _kind == "pogo" || _kind == "ladder") body_max_health = 500;
    if (_kind == "yeti" || _kind == "zomboni") body_max_health = 1350;
    if (_kind == "bungee") body_max_health = 450;
    if (_kind == "catapult") body_max_health = 850;
    if (_kind == "gargantuar") body_max_health = 3000;
    if (_kind == "red_eye_gargantuar") body_max_health = 6000;
    if (_kind == "boss") body_max_health = 40000;
    body_health = body_max_health;
    has_object = _is_garg || _kind == "polevaulter" || _kind == "digger" || _kind == "yeti" || _kind == "pogo";
    armor_health = 0;
    if (_is_cone) armor_health = 370;
    else if (_is_bucket || _kind == "screendoor") armor_health = 1100;
    else if (_kind == "newspaper") armor_health = 150;
    else if (_kind == "football") armor_health = 1400;
    else if (_kind == "digger") armor_health = 100;
    else if (_kind == "ladder") armor_health = 500;
    else if (_kind == "bobsled_team") armor_health = 300;
    armor_kind = _is_cone ? "conehead" : (_is_bucket ? "buckethead" : _kind);
    armor_damage_index = 0;
    body_damage_index = 0;
    total_health = body_health + armor_health;
    has_head = true;
    has_arm = true;
    dead = false;
    just_got_shot = 0;
    chilled_countdown = 0;
    snowpea_debug_tint_state = -1;
    eating = false;
    target_plant = noone;
    bite_ticks = 0;
    groan_countdown = irandom_range(300, 400);
    garg_footstep_counter = irandom_range(35, 60);
    garg_death_thud_played = false;
    chew_anim_time = 0;
    death_ticks = 0;
    fade_ticks = -1;
    death_sound_played = false;
    mowered_ticks = 0;
    mowered_pose = undefined;
    headless_drain_counter = 0;
    pole_used = false;
    special_counter = 0;
    special_triggered = false;
    catapult_ammo = 5;
    catapult_shot_fired = false;
    backups_summoned = false;
    imp_thrown = false;
    imp_released = false;
    altitude = 0;
    flying_health = 0;
    vertical_velocity = 0;
    horizontal_velocity = 0;
    base_y = y;
    walks_backwards = false;
    boss_attack_index = -1;
    boss_target_row = 0;
    boss_age_ticks = 0;
    boss_stomp_counter = irandom_range(5500, 6500);
    boss_summon_counter = irandom_range(450, 550);
    boss_head_counter = irandom_range(4000, 5000);
    boss_phase_event_done = false;
    flag_part = undefined;
    sled_leader = noone;
    follower_index = 0;
    backup_dancer_leader = noone;
    bobsled_rider_ids = [];
    phase = "normal";
    move_speed = random_range(0.16, 0.22);
    var _aname = "Zombie";
    switch (_kind) {
        case "polevaulter": _aname = "Zombie_polevaulter"; break;
        case "newspaper": _aname = "Zombie_paper"; break;
        case "football": _aname = "Zombie_football"; break;
        case "dancer": _aname = "Zombie_disco"; break;
        case "backup_dancer": _aname = "Zombie_backup"; break;
        case "snorkel": _aname = "Zombie_snorkle"; break;
        case "dolphin_rider": _aname = "Zombie_dolphinrider"; break;
        case "zomboni": _aname = "Zombie_zamboni"; break;
        case "bobsled_team":
        case "bobsled_rider": _aname = "Zombie_bobsled"; break;
        case "catapult": _aname = "Zombie_catapult"; break;
        case "jackbox": _aname = "Zombie_jackbox"; break;
        case "balloon": _aname = "Zombie_balloon"; break;
        case "digger": _aname = "Zombie_digger"; break;
        case "pogo": _aname = "Zombie_pogo"; break;
        case "yeti": _aname = "Zombie_yeti"; break;
        case "bungee": _aname = "Zombie_bungi"; break;
        case "ladder": _aname = "Zombie_ladder"; break;
        case "gargantuar":
        case "red_eye_gargantuar": _aname = "Zombie_gargantuar"; break;
        case "imp": _aname = "Zombie_imp"; break;
        case "boss": _aname = "Zombie_boss"; break;
    }
    if (_kind == "polevaulter") {
        phase = "pre_vault"; move_speed = random_range(0.66, 0.68);
    } else if (_kind == "flag") move_speed = 0.45;
    else if (_kind == "football" || _kind == "jackbox" || _kind == "snorkel" || _kind == "digger") move_speed = random_range(0.66, 0.68);
    else if (_kind == "newspaper") phase = "newspaper_reading";
    else if (_kind == "dancer") { phase = "dancer_in"; move_speed = 0.45; special_counter = 300 + irandom(11); }
    else if (_kind == "backup_dancer") { phase = "backup_dancing"; move_speed = 0.45; special_counter = 90; }
    else if (_kind == "dolphin_rider") { body_max_health = 500; body_health = body_max_health; phase = "normal"; move_speed = random_range(0.89, 0.91); }
    else if (_kind == "zomboni") { move_speed = 0.05; special_counter = 0; }
    else if (_kind == "bobsled_team") { move_speed = 0.60; special_counter = 500; }
    else if (_kind == "catapult") { move_speed = random_range(0.38, 0.46); special_counter = 20; catapult_ammo = 5; }
    else if (_kind == "balloon") { phase = "balloon_flying"; move_speed = random_range(0.23, 0.37); altitude = 25; flying_health = 20; }
    else if (_kind == "digger") { phase = "digger_underground"; move_speed = 0.12; special_counter = 0; }
    else if (_kind == "pogo") { phase = "pogo_bouncing"; move_speed = 0.45; special_counter = irandom(79) + 1; }
    else if (_kind == "yeti") { move_speed = 0.4; special_counter = irandom_range(1500, 2000); }
    else if (_kind == "bungee") { phase = "bungee_dive"; altitude = 600 + irandom(150); move_speed = 0; }
    else if (_kind == "ladder") { phase = "ladder_carrying"; move_speed = random_range(0.79, 0.81); }
    else if (_is_garg) { move_speed = 0.18; }
    else if (_kind == "imp") { move_speed = random_range(0.23, 0.37); }
    else if (_kind == "boss") { phase = "boss_enter"; special_counter = 0; move_speed = 0; boss_attack_index = -1; }

    // These are separate overrides because their speed selection above is shared with other types.
    if (_kind == "jackbox") {
        phase = "jack_running";
        var _jack_distance = 450 + irandom(300);
        if (irandom(19) == 0) _jack_distance = max(1, round(_jack_distance / 3));
        special_counter = max(1, round((_jack_distance / max(move_speed, 0.01)) * 2));
    }
    if (_kind == "digger") { phase = "digger_underground"; move_speed = 0.12; special_counter = 0; walks_backwards = false; }
    if (_kind == "snorkel" && pvz_lawn_is_pool_row(row)) { phase = "snorkel_walking"; move_speed = random_range(0.66, 0.68); special_counter = 0; }
    if (_kind == "dolphin_rider" && pvz_lawn_is_pool_row(row)) { phase = "dolphin_walking"; move_speed = random_range(0.89, 0.91); special_counter = 0; }

    body = new Reanim(_aname, x, y);
    body.scale_x = 1.0; body.scale_y = 1.0; body.loop_type = ReanimLoop.LOOP;
    if (_kind == "bungee" && !intro_preview) {
        if (!pvz_lawn_zombie_pick_bungee_target(id)) {
            // A board Bungee requires an eligible plant target in the original game.
            instance_destroy(id);
            exit;
        }
    }
    glasses_dropped = false;
    has_tongue = ((_kind == "basic" || _kind == "flag" || _is_cone || _is_bucket || _is_ducky) && irandom(4) == 0);

    if (_kind == "polevaulter") {
        body.play("anim_run", ReanimLoop.LOOP, 0, 0);
        body.anim_rate = pvz_lawn_zombie_anim_rate(body, move_speed);
    } else {
        var _start_anim = "anim_walk";
        var _start_loop = ReanimLoop.LOOP;
        var _start_rate = 12.0;
        if (intro_preview && body.track_exists("anim_idle")) {
            if (irandom(3) > 0 && body.track_exists("anim_idle2")) _start_anim = "anim_idle2";
            else _start_anim = "anim_idle";
            _start_rate = random_range(12.0, 18.0);
        } else if (_kind == "newspaper") _start_anim = "anim_walk";
        else if (_kind == "dancer") { _start_anim = "anim_walk"; _start_rate = 18.0; }
        else if (_kind == "backup_dancer") { _start_anim = "anim_armraise"; _start_rate = 12.0; }
        else if (_kind == "zomboni") { _start_anim = "anim_drive"; _start_rate = 12.0; }
        else if (_kind == "bobsled_team") { _start_anim = "anim_push"; _start_rate = 30.0; }
        else if (_kind == "catapult") { _start_anim = "anim_walk"; _start_rate = 5.5; }
        else if (_kind == "balloon") { _start_anim = "anim_idle"; _start_rate = 12.0; }
        else if (_kind == "snorkel") { _start_anim = "anim_walk"; _start_rate = 12.0; }
        else if (_kind == "dolphin_rider") { _start_anim = "anim_walkdolphin"; _start_rate = 12.0; }
        else if (_kind == "digger") { _start_anim = "anim_dig"; _start_rate = 12.0; }
        else if (_kind == "pogo") { _start_anim = "anim_pogo"; _start_rate = 40.0; _start_loop = ReanimLoop.PLAY_ONCE_AND_HOLD; }
        else if (_kind == "bungee") { _start_anim = "anim_drop"; _start_rate = 24.0; }
        else if (_kind == "ladder") { _start_anim = "anim_ladderwalk"; _start_rate = 12.0; }
        else if (_is_garg) { _start_anim = "anim_walk"; _start_rate = 12.0; }
        else if (_kind == "boss") { _start_anim = "anim_enter"; _start_rate = 12.0; _start_loop = ReanimLoop.PLAY_ONCE_AND_HOLD; }
        else if (_kind == "imp") { _start_anim = "anim_walk"; _start_rate = 12.0; }
        // Keep the existing randomized standard-walk selection used by the original body reanimation.
        // Flag Zombie explicitly uses walk2 in Zombie::StartWalkAnim.
        if (!intro_preview && _aname == "Zombie" && (_kind == "basic" || _kind == "flag" || _kind == "conehead" || _kind == "buckethead" || _is_ducky)) {
            if (_kind == "flag") _start_anim = body.track_exists("anim_walk2") ? "anim_walk2" : "anim_walk";
            else _start_anim = (irandom(1) == 0 && body.track_exists("anim_walk2")) ? "anim_walk2" : "anim_walk";
        }
        if (body.track_exists(_start_anim)) body.play(_start_anim, _start_loop, 0, _start_rate);
        else body.play_all(_start_loop);
        if (_kind == "pogo") body.anim_time = 1.0;

        if (_aname == "Zombie") {
            body.set_tracks_hidden_by_prefix("anim_cone", !_is_cone);
            body.set_tracks_hidden_by_prefix("anim_bucket", !_is_bucket);
            body.set_tracks_hidden_by_prefix("anim_hair", !(_kind == "basic" || _kind == "flag" || _is_ducky));
            body.set_track_hidden("Zombie_duckytube", !_is_ducky);
            body.set_track_hidden("Zombie_whitewater", !_is_ducky);
            body.set_track_hidden("Zombie_whitewater2", !_is_ducky);
            var _door_equipped = (_kind == "screendoor");
            body.set_track_hidden("Zombie_innerarm_screendoor", !(_door_equipped || _kind == "flag"));
            body.set_track_hidden("anim_screendoor", !_door_equipped);
            body.set_track_hidden("Zombie_innerarm_screendoor_hand", !_door_equipped);
            body.set_track_hidden("Zombie_outerarm_screendoor", !_door_equipped);
            body.set_track_hidden("Zombie_flaghand", _kind != "flag");
            if (_door_equipped) {
                // SetupDoorArms(true): shield-specific arms are visible; ordinary arms are hidden.
                body.set_track_hidden("Zombie_outerarm_lower", true);
                body.set_track_hidden("Zombie_outerarm_hand", true);
                body.set_track_hidden("Zombie_outerarm_upper", true);
                body.set_track_hidden("anim_innerarm", true);
            }
            if (_kind == "flag") {
                // ZombieInitialize(ZOMBIE_FLAG): the flag pole attaches to its flag-holding hand;
                // hide the ordinary inner arm and keep the flag-specific inner-arm layer visible.
                body.set_track_hidden("anim_innerarm", true);
                body.set_track_hidden("Zombie_innerarm_screendoor", false);
            }
            body.set_track_hidden("Zombie_mustache", true);
        }
        if (_kind == "newspaper") body.set_track_hidden("Zombie_paper_paper", false);
        if (_kind == "football") body.set_track_hidden("zombie_football_helmet", false);
        if (_kind == "digger") body.set_track_hidden("Zombie_digger_dig", false);
        if (_kind == "ladder") body.set_track_hidden("Zombie_ladder_1", false);
        if (_kind == "balloon") body.set_track_hidden("balloon_pop", true);
        if (!intro_preview && _kind != "dancer" && _kind != "backup_dancer" && _kind != "zomboni" && _kind != "catapult" && _kind != "balloon" && _kind != "digger" && _kind != "pogo" && _kind != "bungee" && _kind != "ladder" && !_is_garg && _kind != "boss") {
            if (_kind == "newspaper") body.anim_rate = pvz_lawn_zombie_anim_rate(body, move_speed);
            else body.anim_rate = pvz_lawn_zombie_anim_rate(body, move_speed);
        }
    }
    body.set_tracks_hidden_by_prefix("anim_tongue", !has_tongue);
    if (_kind == "flag") {
        flag_part = new Reanim("Zombie_FlagPole", x, y);
        flag_part.play_all(ReanimLoop.LOOP); flag_part.anim_rate = 15.0;
        flag_part.attach_to(body, "Zombie_flaghand");
        body.frame_base_pose = 0;
    }
    if (_kind == "boss") { x = 0; y = 0; row = 0; }
    if (_kind == "bobsled_team") {
        body.set_track_hidden("Zombie_bobsled_body1", false);
        body.set_track_hidden("Zombie_bobsled_body2", false);
        // Original team consists of one sled leader and three individually damageable riders.
        for (var _fi = 0; _fi < 3; _fi++) {
            var _rider = instance_create_layer(x + 42 * (_fi + 1), y, "Instances", obj_zombie_bobsled_rider, {row: row});
            if (instance_exists(_rider)) { _rider.sled_leader = id; _rider.follower_index = _fi; array_push(bobsled_rider_ids, _rider); }
        }
    }
    // Original source's render rects are wider/taller for vehicles and Gargantuar; visual scale stays asset-native.
    pvz_lawn_reanim_set_tint(body, false, c_white);
    depth = -y - 31;
}

/// Capture the per-reanimation alpha tree so the zombie's fade also affects attached parts.
function pvz_lawn_reanim_capture_alpha(_reanim) {
    if (is_undefined(_reanim) || _reanim == noone || _reanim.def == undefined) return undefined;
    var _children = [];
    for (var _track = 0; _track < _reanim.track_count; _track++) {
        for (var _child_index = 0; _child_index < array_length(_reanim.attached[_track]); _child_index++) {
            var _child_state = pvz_lawn_reanim_capture_alpha(_reanim.attached[_track][_child_index]);
            if (!is_undefined(_child_state)) array_push(_children, _child_state);
        }
    }
    return { reanim: _reanim, alpha: _reanim.alpha, children: _children };
}

function pvz_lawn_reanim_apply_alpha(_state, _multiplier) {
    if (is_undefined(_state)) return;
    _state.reanim.alpha = _state.alpha * _multiplier;
    for (var _i = 0; _i < array_length(_state.children); _i++) {
        pvz_lawn_reanim_apply_alpha(_state.children[_i], _multiplier);
    }
}

function pvz_lawn_reanim_restore_alpha(_state) {
    if (is_undefined(_state)) return;
    _state.reanim.alpha = _state.alpha;
    for (var _i = 0; _i < array_length(_state.children); _i++) {
        pvz_lawn_reanim_restore_alpha(_state.children[_i]);
    }
}
/// Apply a true sprite tint to a Reanimation and all attached parts (head, arms, armor, etc.).
function pvz_lawn_reanim_set_tint(_reanim, _enabled, _color) {
    if (is_undefined(_reanim) || _reanim == noone || _reanim.def == undefined) return;
    _reanim.tint_enabled = _enabled;
    // Store white as well as disabling tint when chill expires. This makes the normal
    // appearance explicit instead of leaving a stale blue tint value on the reanimation.
    _reanim.tint_color = _enabled ? _color : c_white;
    // Chill is a blue tint, not a persistent highlight. The renderer's generic
    // extra-additive branch uses draw_sprite_pos (which does not accept vertex
    // colour), so enabling it adds a bright, untinted copy every frame and can
    // mask the normal hit flash. Keep that pass off; the real vertex-coloured
    // flash overlay below remains enabled by pvz_lawn_set_reanim_flash.
    _reanim.extra_additive_enabled = false;
    _reanim.extra_additive_color = c_black;
    for (var _track = 0; _track < _reanim.track_count; _track++) {
        for (var _child = 0; _child < array_length(_reanim.attached[_track]); _child++) {
            pvz_lawn_reanim_set_tint(_reanim.attached[_track][_child], _enabled, _color);
        }
    }
}

function pvz_lawn_zombie_draw(_kind) {
    if (is_undefined(body)) exit;
    // Keep the gameplay/root anchor (x,y) independent from the visual Reanimation offset.
    // Zombie::GetDrawPos raises the artwork, but Zombie::DrawShadow computes its position
    // from the zombie root, NOT the raised body draw position. Using _draw_y here lifted
    // the shadow with the artwork and put it away from the feet.
    var _draw_x = x - (_kind == "polevaulter" ? 6 : 0);
    var _altitude_draw = (variable_instance_exists(id, "altitude") ? altitude : 0);
    var _draw_y = y - (_kind == "polevaulter" ? 11 : 6) - _altitude_draw;
    if (_kind == "digger" && phase == "digger_underground") _draw_y = y + 10;
    if (_kind == "gargantuar" || _kind == "red_eye_gargantuar") _draw_y = y - 38;
    if (_kind == "bobsled_team" || _kind == "bobsled_rider") _draw_y = y - 12;
    if (_kind == "yeti") _draw_y = y - 20 - _altitude_draw;
    if (_kind == "zomboni" || _kind == "catapult") _draw_y = y - 13;
    if (_kind == "boss") { _draw_x = 0; _draw_y = 0; }
    body.x = _draw_x;
    body.y = _draw_y;
    // Exact daytime Board-lawn offsets from Zombie::DrawShadow:
    // normal reanimated zombie: x + 23, y + 92;
    // forward Pole Vaulter: x + 36, y + 11 + 92.
    // Draw the shadow centered at those root-relative coordinates, as TodDrawImageCenterScaledF does.
    var _house_winner_clip = global.pvz_lawn_lost_state != "" && global.pvz_lawn_lost_winner == id;
    var _saved_scissor = undefined;
    if (_house_winner_clip) {
        // gpu_set_scissor applies the clip immediately; restore the previous rectangle after drawing.
        _saved_scissor = gpu_get_scissor();
        var _house_clip_left = clamp(ceil(117.0 - global.pvz_lawn_camera_x), 0, room_width);
        gpu_set_scissor(_house_clip_left, 0, max(1, room_width - _house_clip_left), room_height);
    }
    var _shadow = global.pvz_shadow_sprite;
    if (_shadow >= 0) {
        var _sw = sprite_get_width(_shadow);
        var _sh = sprite_get_height(_shadow);
        // User-requested adjustment: 20 px left and 10 px up from the previous shadow position.
        var _shadow_cx = x + (_kind == "polevaulter" ? 36 : (_kind == "zomboni" || _kind == "catapult" ? 76 : 23)) + 26;
        var _shadow_cy = y + (_kind == "polevaulter" ? 103 : 92) + 18;
        if (_kind == "boss") _shadow_cx = 745;
        if (_kind != "balloon" && _kind != "bungee" && _kind != "pogo" && !(_kind == "imp" && phase == "imp_thrown")) draw_sprite_ext(_shadow, 0, _shadow_cx - _sw * 0.5 - global.pvz_lawn_camera_x, _shadow_cy - _sh * 0.5, (_kind == "gargantuar" || _kind == "red_eye_gargantuar" || _kind == "zomboni" || _kind == "catapult") ? 1.3 : 1.0, 1.0, 0, c_white, 1.0);
    }
    pvz_lawn_set_reanim_flash(body, just_got_shot, "zombie");
    // Only show the stronger blue while the Snow Pea chill/slow timer is active.
    // When the zombie regains normal speed, restore white tint on the body and attachments.
    var _chill_active = chilled_countdown > 0;
    var _snowpea_tint = _chill_active ? make_color_rgb(75, 75, 255) : c_white;
    pvz_lawn_reanim_set_tint(body, _chill_active, _snowpea_tint);
    var _snowpea_draw_state = _chill_active ? 1 : 0;
    if (!variable_instance_exists(id, "snowpea_debug_tint_state")) snowpea_debug_tint_state = -1;
    var _log_snowpea_tint_transition = (snowpea_debug_tint_state == -1 && _chill_active)
        || (snowpea_debug_tint_state != -1 && snowpea_debug_tint_state != _snowpea_draw_state);
    if (_log_snowpea_tint_transition) {
        pvz_lawn_snowpea_debug("TINT DRAW " + (_chill_active ? "ON" : "OFF") + ": zombie_id=" + string(id) + ", kind=" + string(zombie_kind) + ", chill_ticks=" + string(chilled_countdown) + ", body.tint_enabled=" + string(body.tint_enabled) + ", RGB=" + string(color_get_red(body.tint_color)) + "/" + string(color_get_green(body.tint_color)) + "/" + string(color_get_blue(body.tint_color)));
    }
    snowpea_debug_tint_state = _snowpea_draw_state;

    var _saved_mowered_overlay = undefined;
    if (phase == "mowered" && body.overlay != undefined) {
        _saved_mowered_overlay = body.overlay;
        var _screen_mowered_overlay = _saved_mowered_overlay;
        _screen_mowered_overlay[2] -= global.pvz_lawn_camera_x;
        body.overlay = _screen_mowered_overlay;
    }
    var _fade_alpha = 1.0;
    if (dead && fade_ticks >= 0) _fade_alpha = clamp(fade_ticks / 10.0, 0.0, 1.0);
    var _fade_alpha_state = undefined;
    if (_fade_alpha < 1.0) {
        _fade_alpha_state = pvz_lawn_reanim_capture_alpha(body);
        pvz_lawn_reanim_apply_alpha(_fade_alpha_state, _fade_alpha);
    }
    var _spotlight_active = (_kind == "dancer" || _kind == "backup_dancer")
        && phase != "dancer_in" && phase != "dancer_snapping" && phase != "normal" && phase != "dancer_hold"
        && !dead && global.pvz_lawn_lost_state == "";
    var _spot_color = c_white;
    if (_spotlight_active) {
        switch (floor(global.pvz_lawn_tick / 100) mod 5) {
            case 0: _spot_color = make_color_rgb(250, 250, 160); break;
            case 1: _spot_color = make_color_rgb(114, 234, 170); break;
            case 2: _spot_color = make_color_rgb(216, 126, 202); break;
            case 3: _spot_color = make_color_rgb(90, 110, 140); break;
            default: _spot_color = make_color_rgb(240, 90, 130); break;
        }
        if (global.pvz_fx_dancer_spotlight2 >= 0) draw_sprite_ext(global.pvz_fx_dancer_spotlight2, 0, _draw_x - 30 - global.pvz_lawn_camera_x, _draw_y + 60, 4, 4, 0, _spot_color, 1);
    }
    var _sled_front_sprite = -1;
    var _sled_back_sprite = -1;
    var _sled_draw_stage = 0;
    var _sled_alpha = 1.0;
    if (_kind == "bobsled_team") {
        // Zombie::DrawBobsledReanim draws independent sled images; the body reanimation itself only contains zombies.
        _sled_back_sprite = reanim_get_part_sprite("images/Zombie_bobsled_inside.png");
        if (phase == "bobsled_crashing") {
            _sled_draw_stage = 3;
            if (special_counter < 30) _sled_alpha = clamp(special_counter / 30.0, 0, 1);
        } else if (armor_health < 100) _sled_draw_stage = 2;
        else if (armor_health < 200) _sled_draw_stage = 1;
        var _sled_names = ["images/Zombie_bobsled1.png", "images/Zombie_bobsled2.png", "images/Zombie_bobsled3.png", "images/Zombie_bobsled4.png"];
        _sled_front_sprite = reanim_get_part_sprite(_sled_names[_sled_draw_stage]);
        if (_sled_draw_stage < 3 && _sled_back_sprite >= 0) draw_sprite_ext(_sled_back_sprite, 0, x - 76 - global.pvz_lawn_camera_x, _draw_y + 15, 1, 1, 0, c_white, 1.0);
    }
    pvz_lawn_reanim_draw_camera(body, _draw_x, _draw_y, global.pvz_lawn_camera_x);
    if (_kind == "bobsled_team" && _sled_front_sprite >= 0) draw_sprite_ext(_sled_front_sprite, 0, x - 76 - global.pvz_lawn_camera_x, _draw_y + 15, 1, 1, 0, c_white, _sled_alpha);
    if (_spotlight_active && global.pvz_fx_dancer_spotlight >= 0) draw_sprite_ext(global.pvz_fx_dancer_spotlight, 0, _draw_x - 30 - global.pvz_lawn_camera_x, _draw_y - 480, 4, 4, 0, _spot_color, 1);
    if (_kind == "bungee" && (phase == "bungee_dive" || phase == "bungee_grab" || phase == "bungee_rise") && instance_exists(target_plant)) {
        // DrawBungeeCord: a visible tether from the zombie's grab hand to the plant being lifted.
        var _cord_x1 = x + 60 - global.pvz_lawn_camera_x;
        var _cord_y1 = y - altitude + 64;
        var _cord_x2 = target_plant.x + 40 - global.pvz_lawn_camera_x;
        var _cord_y2 = target_plant.y + 8;
        draw_set_color(make_color_rgb(49, 40, 28));
        draw_line_width(_cord_x1, _cord_y1, _cord_x2, _cord_y2, 3);
        draw_set_color(make_color_rgb(210, 193, 158));
        draw_line_width(_cord_x1, _cord_y1, _cord_x2, _cord_y2, 1);
        draw_set_color(c_white);
    }
    if (!is_undefined(_fade_alpha_state)) pvz_lawn_reanim_restore_alpha(_fade_alpha_state);
    if (_saved_mowered_overlay != undefined) body.overlay = _saved_mowered_overlay;
    if (_house_winner_clip) gpu_set_scissor(_saved_scissor);
}


function pvz_lawn_font_parse_numbers(_text) {
    var _out = [];
    var _token = "";
    for (var _i = 1; _i <= string_length(_text); _i++) {
        var _ch = string_char_at(_text, _i);
        var _code = ord(_ch);
        if ((_code >= 48 && _code <= 57) || _ch == "-") {
            _token += _ch;
        } else if (_token != "") {
            array_push(_out, real(_token));
            _token = "";
        }
    }
    if (_token != "") array_push(_out, real(_token));
    return _out;
}

function pvz_lawn_native_font_info(_font_name) {
    if (!variable_global_exists("pvz_lawn_native_font_cache")) global.pvz_lawn_native_font_cache = {};
    var _cache = global.pvz_lawn_native_font_cache;
    if (variable_struct_exists(_cache, _font_name)) return variable_struct_get(_cache, _font_name);

    var _base = working_directory + "datafiles/fonts/" + _font_name;
    var _txt = _base + ".txt";
    var _atlas_path = _base + ".png";
    if (!file_exists(_atlas_path)) _atlas_path = working_directory + "datafiles/fonts/_" + _font_name + ".png";
    // The bundled source files include ContinuumBold14.txt and the original _ContinuumBold14.gif in Dropbox.
    // Accept GIF atlases too, so the exact source font can be copied in without editing this loader again.
    if (!file_exists(_atlas_path)) _atlas_path = _base + ".gif";
    if (!file_exists(_atlas_path)) _atlas_path = working_directory + "datafiles/fonts/_" + _font_name + ".gif";
    var _bad = { sprite: -1, chars: "", widths: [], rects: [], offsets: [], glyph_height: 17 };
    if (!file_exists(_atlas_path) || !file_exists(_txt)) {
        variable_struct_set(_cache, _font_name, _bad);
        return _bad;
    }

    var _atlas = sprite_add(_atlas_path, 1, false, false, 0, 0);
    if (_atlas < 0) {
        variable_struct_set(_cache, _font_name, _bad);
        return _bad;
    }

    var _chars = "";
    var _widths = [];
    var _rects = [];
    var _offsets = [];
    var _section = "";
    var _f = file_text_open_read(_txt);
    while (!file_text_eof(_f)) {
        var _line = file_text_readln(_f);
        if (string_pos("Define CharList", _line) > 0) { _section = "chars"; continue; }
        if (string_pos("Define WidthList", _line) > 0) { _section = "widths"; continue; }
        if (string_pos("Define RectList", _line) > 0) { _section = "rects"; continue; }
        if (string_pos("Define OffsetList", _line) > 0) { _section = "offsets"; continue; }
        if (string_pos("CreateLayer", _line) > 0) { _section = ""; continue; }

        if (_section == "chars") {
            // Parse PopCap's quoted character literals; both quote styles occur in the files.
            var _quoted = false;
            var _quote = "";
            var _char_token = "";
            for (var _ci = 1; _ci <= string_length(_line); _ci++) {
                var _c = string_char_at(_line, _ci);
                if (!_quoted) {
                    if (_c == "'" || _c == "\"") { _quoted = true; _quote = _c; _char_token = ""; }
                } else if (_c == "\\") {
                    // Font data writes the double-quote glyph as an escaped quote.
                    if (_ci < string_length(_line)) {
                        _ci++;
                        _char_token += string_char_at(_line, _ci);
                    }
                } else if (_c == _quote) {
                    _chars += _char_token;
                    _quoted = false;
                    _quote = "";
                    _char_token = "";
                } else {
                    _char_token += _c;
                }
            }
        } else if (_section != "") {
            var _nums = pvz_lawn_font_parse_numbers(_line);
            for (var _n = 0; _n < array_length(_nums); _n++) {
                if (_section == "widths") array_push(_widths, _nums[_n]);
                else if (_section == "rects") array_push(_rects, _nums[_n]);
                else if (_section == "offsets") array_push(_offsets, _nums[_n]);
            }
        }
    }
    file_text_close(_f);

    // Fallback charset for font tables that omit CharList or use a legacy variant.
    if (string_length(_chars) < 50) {
        _chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789~`!@#$%^&*()-_=+[{]};:'\",<.>/?Â¡Â¢Â£Â¥Â§Â©Â®Â¿Ã€ÃÃ‚ÃƒÃ„Ã…Ã†Ã‡ÃˆÃ‰ÃŠÃ‹ÃŒÃÃŽÃÃÃ‘Ã’Ã“Ã”Ã•Ã–Ã˜Ã™ÃšÃ›ÃœÃÃŸÃ Ã¡Ã¢Ã£Ã¤Ã¥Ã¦Ã§Ã¨Ã©ÃªÃ«Ã¬Ã­Ã®Ã¯Ã°Ã±Ã²Ã³Ã´ÃµÃ¶Ã¸Ã¹ÃºÃ»Ã¼Ã½Ã¿";
    }
    var _glyph_height = 17;
    for (var _ri = 3; _ri < array_length(_rects); _ri += 4) _glyph_height = max(_glyph_height, _rects[_ri]);
    var _info = { sprite: _atlas, chars: _chars, widths: _widths, rects: _rects, offsets: _offsets, glyph_height: _glyph_height };
    variable_struct_set(_cache, _font_name, _info);
    return _info;
}

function pvz_lawn_native_font_text_width(_font_name, _text, _scale) {
    var _info = pvz_lawn_native_font_info(_font_name);
    if (_info.sprite < 0 && _font_name != "DwarvenTodcraft12") {
        return pvz_lawn_native_font_text_width("DwarvenTodcraft12", _text, _scale);
    }
    if (_info.sprite < 0) return string_width(_text) * _scale;
    var _width = 0;
    for (var _i = 1; _i <= string_length(_text); _i++) {
        var _ch = string_char_at(_text, _i);
        if (_ch == " ") {
            _width += 4 * _scale;
        } else {
            var _index = string_pos(_ch, _info.chars);
            if (_index > 0 && _index <= array_length(_info.widths)) _width += _info.widths[_index - 1] * _scale;
            else _width += 7 * _scale;
        }
    }
    return _width;
}

function pvz_lawn_draw_text_native(_x, _y, _text, _font_name = "DwarvenTodcraft15", _scale = 0.80) {
    var _info = pvz_lawn_native_font_info(_font_name);
    if (_info.sprite < 0 && _font_name != "DwarvenTodcraft12") {
        pvz_lawn_draw_text_native(_x, _y, _text, "DwarvenTodcraft12", _scale);
        return;
    }
    if (_info.sprite < 0) {
        draw_text(_x, _y, _text);
        return;
    }

    var _str = string(_text);
    var _colour = draw_get_color();
    var _alpha = draw_get_alpha();
    var _width = pvz_lawn_native_font_text_width(_font_name, _str, _scale);
    var _height = _info.glyph_height * _scale;
    var _halign = draw_get_halign();
    var _valign = draw_get_valign();
    var _pen_x = _x;
    var _top_y = _y;

    if (_halign == fa_center) _pen_x -= _width * 0.5;
    else if (_halign == fa_right) _pen_x -= _width;
    if (_valign == fa_middle) _top_y -= _height * 0.5;
    else if (_valign == fa_bottom) _top_y -= _height;

    for (var _i = 1; _i <= string_length(_str); _i++) {
        var _ch = string_char_at(_str, _i);
        if (_ch == " ") {
            _pen_x += 4 * _scale;
            continue;
        }
        var _index = string_pos(_ch, _info.chars);
        if (_index > 0 && _index <= array_length(_info.widths)) {
            var _ri = (_index - 1) * 4;
            var _oi = (_index - 1) * 2;
            if (_ri + 3 < array_length(_info.rects)) {
                var _sx = _info.rects[_ri];
                var _sy = _info.rects[_ri + 1];
                var _sw = _info.rects[_ri + 2];
                var _sh = _info.rects[_ri + 3];
                var _ox = _oi < array_length(_info.offsets) ? _info.offsets[_oi] : 0;
                var _oy = (_oi + 1) < array_length(_info.offsets) ? _info.offsets[_oi + 1] : 0;
                if (_sw > 0 && _sh > 0) {
                    draw_sprite_part_ext(_info.sprite, 0, _sx, _sy, _sw, _sh,
                        _pen_x + _ox * _scale, _top_y + _oy * _scale,
                        _scale, _scale, _colour, _alpha);
                }
            }
            _pen_x += _info.widths[_index - 1] * _scale;
        } else {
            _pen_x += 7 * _scale;
        }
    }
}

function pvz_lawn_draw_text_ext_native(_x, _y, _text, _sep, _max_width, _font_name = "DwarvenTodcraft15", _scale = 0.80) {
    var _info = pvz_lawn_native_font_info(_font_name);
    if (_info.sprite < 0 && _font_name != "DwarvenTodcraft12") {
        pvz_lawn_draw_text_ext_native(_x, _y, _text, _sep, _max_width, "DwarvenTodcraft12", _scale);
        return;
    }
    if (_info.sprite < 0) {
        draw_text_ext(_x, _y, _text, _sep, _max_width);
        return;
    }

    var _old_halign = draw_get_halign();
    var _old_valign = draw_get_valign();
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    var _words = string_split(string(_text), " ");
    var _line = "";
    var _line_y = _y;
    var _line_height = _info.glyph_height * _scale + _sep;
    for (var _i = 0; _i < array_length(_words); _i++) {
        var _candidate = (_line == "") ? _words[_i] : _line + " " + _words[_i];
        if (_line != "" && pvz_lawn_native_font_text_width(_font_name, _candidate, _scale) > _max_width) {
            pvz_lawn_draw_text_native(_x, _line_y, _line, _font_name, _scale);
            _line_y += _line_height;
            _line = _words[_i];
        } else {
            _line = _candidate;
        }
    }
    if (_line != "") pvz_lawn_draw_text_native(_x, _line_y, _line, _font_name, _scale);

    draw_set_halign(_old_halign);
    draw_set_valign(_old_valign);
}/// Original PvZ BrianneTod12 bitmap font used by ToolTipWidget (USE_OLD_STYLE_TOOLTIP=false).
/// Character advances and atlas rectangles are taken from the supplied data/BrianneTod12.txt.
/// The atlas itself is installed from the supplied asset archive by Install_PvZ_Sounds.bat.
function pvz_lawn_bitmap_font_init() {
    if (variable_global_exists("pvz_lawn_bitmap_font_sprite") && global.pvz_lawn_bitmap_font_sprite >= 0) {
        return global.pvz_lawn_bitmap_font_sprite;
    }
    global.pvz_lawn_bitmap_font_sprite = -1;
    var _font_path = working_directory + "datafiles/fonts/_BrianneTod12.png";
    if (!file_exists(_font_path)) _font_path = working_directory + "datafiles/fonts/BrianneTod12.png";
    if (file_exists(_font_path)) {
        global.pvz_lawn_bitmap_font_sprite = sprite_add(_font_path, 1, false, false, 0, 0);
    }
    return global.pvz_lawn_bitmap_font_sprite;
}

function pvz_lawn_bitmap_text_width(_text, _scale) {
    return pvz_lawn_native_font_text_width("BrianneTod12", _text, _scale);
}

/// Full original BrianneTod12 atlas for all tooltip text; no hard-coded partial alphabet.
function pvz_lawn_bitmap_draw_text(_text, _center_x, _top_y, _colour, _scale) {
    draw_set_color(_colour);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    pvz_lawn_draw_text_native(_center_x, _top_y, _text, "BrianneTod12", _scale);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_set_alpha(1.0);
    return pvz_lawn_native_font_text_width("BrianneTod12", _text, _scale);
}
