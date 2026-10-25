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
        case "image_snowpea_particles": return "SnowPea_particles.png";
        case "image_snowpea_puff": return "SnowPea_puff.png";
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
    var _end = real(_end_text);
    return [_start, _end, max(0.001, _time)];
}

function pvz_lawn_particle_find_image_path(_base) {
    var _paths = [
        working_directory + "datafiles/particles/" + _base,
        working_directory + "particles/" + _base,
        working_directory + "datafiles/pvzfx/" + _base,
        working_directory + "pvzfx/" + _base,
        working_directory + "datafiles/images/" + _base,
        working_directory + "images/" + _base,
        working_directory + "datafiles/parts/images/" + _base
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
        var _frame_width = max(1, floor(_sheet_width / _frame_count));
        // Use the original Resources manifest's DIRTSMALL 8x2 layout instead of guessing from cell aspect ratio.
        var _row_count = max(1, pvz_lawn_particle_image_rows(_image_id));
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
        var _scale_range = pvz_lawn_particle_xml_range(pvz_lawn_particle_xml_tag(_block, "ParticleScale", "[1 1]"), 1, 1);
        var _scale_end_range = [_scale_range[0], _scale_range[1]];
        var _scale_second = pvz_lawn_particle_xml_second_range(pvz_lawn_particle_xml_tag(_block, "ParticleScale", ""));
        if (array_length(_scale_second) >= 2) _scale_end_range = _scale_second;

        var _particle_alpha_raw = pvz_lawn_particle_xml_tag(_block, "ParticleAlpha", "1");
        var _particle_alpha_range = pvz_lawn_particle_xml_range(_particle_alpha_raw, 1, 1);
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
            particle_scale_min: max(0.01, _scale_range[0]),
            particle_scale_max: max(0.01, _scale_range[1]),
            particle_scale_end_min: max(0.01, _scale_end_range[0]),
            particle_scale_end_max: max(0.01, _scale_end_range[1]),
            particle_alpha: clamp(_particle_alpha_range[0], 0, 1),
            particle_fade_start: pvz_lawn_particle_xml_fade_start(_particle_alpha_raw, 0.9),
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
    var _x = _emitter_id.fx_xml_origin_x;
    var _y = _emitter_id.fx_xml_origin_y;
    if (_cfg.emitter_type == "box") {
        _x += random_range(_cfg.offset_x_min, _cfg.offset_x_max);
        _y += random_range(_cfg.offset_y_min, _cfg.offset_y_max);
    } else if (_cfg.emitter_type == "circle") {
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
    var _scale_start = random_range(_cfg.particle_scale_min, _cfg.particle_scale_max);
    var _scale_end = random_range(_cfg.particle_scale_end_min, _cfg.particle_scale_end_max);
    var _spin = random_range(_cfg.spin_min, _cfg.spin_max) / 100.0;
    var _system_alpha = _cfg.system_alpha;
    var _system_fade_tick = _cfg.system_duration * _cfg.system_fade_start;
    if (_emitter_id.fx_xml_age >= _system_fade_tick) {
        _system_alpha *= clamp((_cfg.system_duration - _emitter_id.fx_xml_age) / max(1, _cfg.system_duration - _system_fade_tick), 0, 1);
    }
    var _fade_start = round(_life * _cfg.particle_fade_start);
    var _initial_angle = _cfg.random_launch_spin ? random(360) : 0;
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
        fx_frame_count: _cfg.image_frames,
        fx_alpha_mult: _cfg.particle_alpha * _system_alpha,
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
function pvz_lawn_spawn_particle(_name, _x, _y) {
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
            fx_xml_initial_active: _initial
        });
        if (instance_exists(_emitter)) _started = true;
    }
    return _started;
}
