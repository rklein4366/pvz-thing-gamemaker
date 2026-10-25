/// scr_reanim
/// Player for PopCap "reanim" skeletal animations, ported from Sexy.TodLib/Reanimator.cpp.
///
/// Data comes from tools/convert_reanim.py (datafiles/reanim/<Name>.json + datafiles/parts/...).
/// A reanim is a list of tracks. Every track has one entry per frame: position, skew, scale,
/// image-frame (-1 = hidden) and alpha. "anim_*" tracks carry no image: the frames where they
/// are visible define a named animation range (see GetFramesForLayer in the source).
///
/// Source functions mirrored here:
///   Reanimation::Update, GetFrameTime, GetTransformAtTime, GetCurrentTransform,
///   BlendTransform, StartBlend, PlayReanim, SetFramesForLayer, GetFramesForLayer,
///   MatrixFromTransform and DrawTrack (matrix part).

enum ReanimLoop {
    LOOP,
    LOOP_FULL_LAST_FRAME,
    PLAY_ONCE,
    PLAY_ONCE_FULL_LAST_FRAME,
    PLAY_ONCE_AND_HOLD,
    PLAY_ONCE_FULL_LAST_FRAME_AND_HOLD
}

/// indices into a transform array
#macro RT_X 0
#macro RT_Y 1
#macro RT_KX 2
#macro RT_KY 3
#macro RT_SX 4
#macro RT_SY 5
#macro RT_FRAME 6
#macro RT_ALPHA 7
#macro RT_IMG 8

/// 2x3 affine matrices are stored as [m00, m01, m02, m10, m11, m12] (same names as SexyMatrix3).
/// Points transform as: x' = m00*x + m01*y + m02,  y' = m10*x + m11*y + m12.
function mat2_identity() {
    return [1, 0, 0, 0, 1, 0];
}

/// SexyMatrix3Multiply(m, l, r): m = l * r   (r is applied first)
function mat2_mul(_l, _r) {
    return [
        _l[0] * _r[0] + _l[1] * _r[3],  _l[0] * _r[1] + _l[1] * _r[4],  _l[0] * _r[2] + _l[1] * _r[5] + _l[2],
        _l[3] * _r[0] + _l[4] * _r[3],  _l[3] * _r[1] + _l[4] * _r[4],  _l[3] * _r[2] + _l[4] * _r[5] + _l[5]
    ];
}

function mat2_inverse(_m) {
    var _det = _m[0] * _m[4] - _m[1] * _m[3];
    if (abs(_det) < 0.0000001) return mat2_identity();
    return [
         _m[4] / _det, -_m[1] / _det, (_m[1] * _m[5] - _m[4] * _m[2]) / _det,
        -_m[3] / _det,  _m[0] / _det, (_m[3] * _m[2] - _m[0] * _m[5]) / _det
    ];
}

/// Reanimation::MatrixFromTransform
function mat2_from_transform(_xf) {
    var _kx = -degtorad(_xf[RT_KX]);
    var _ky = -degtorad(_xf[RT_KY]);
    return [
         cos(_kx) * _xf[RT_SX], sin(_ky) * _xf[RT_SY], _xf[RT_X],
        -sin(_kx) * _xf[RT_SX], cos(_ky) * _xf[RT_SY], _xf[RT_Y]
    ];
}

function reanim_init() {
    if (variable_global_exists("reanim_defs")) return;
    global.reanim_defs = ds_map_create();      // reanim name -> definition struct
    global.reanim_sprites = ds_map_create();   // part image path -> sprite index (-1 = missing)
}

/// Loads one part image (cached). Origin is top-left because the source places images by top-left.
function reanim_get_part_sprite(_path) {
    reanim_init();
    if (ds_map_exists(global.reanim_sprites, _path)) return global.reanim_sprites[? _path];
    var _file = working_directory + "parts/" + _path;
    if (!file_exists(_file)) _file = working_directory + "datafiles/parts/" + _path;
    var _spr = -1;
    if (file_exists(_file)) {
        _spr = sprite_add(_file, 1, false, false, 0, 0);
    } else {
        show_debug_message("reanim: missing part image " + _file);
    }
    global.reanim_sprites[? _path] = _spr;
    return _spr;
}

/// Loads (and caches) a reanim definition. @returns {Struct|Undefined}
function reanim_get_def(_name) {
    reanim_init();
    if (ds_map_exists(global.reanim_defs, _name)) return global.reanim_defs[? _name];

    var _file = working_directory + "reanim/" + _name + ".json";
    if (!file_exists(_file)) _file = working_directory + "datafiles/reanim/" + _name + ".json";
    if (!file_exists(_file)) {
        show_debug_message("reanim: definition not found " + _file);
        return undefined;
    }
    var _buf = buffer_load(_file);
    var _raw = json_parse(buffer_read(_buf, buffer_text));
    buffer_delete(_buf);

    var _def = {
        name: _name,
        fps: _raw.fps,
        tracks: _raw.tracks,
        texts: _raw.texts,
        lookup: {},
        sprites: [],
        frame_count: 0
    };
    var _tc = array_length(_def.tracks);
    if (_tc > 0) _def.frame_count = array_length(_def.tracks[0].t); // GetTransformAtTime asserts every track has the same length
    for (var i = 0; i < _tc; i++) {
        var _key = string_lower(_def.tracks[i].name);
        if (!variable_struct_exists(_def.lookup, _key)) variable_struct_set(_def.lookup, _key, i); // FindTrackIndex returns the first match
    }
    for (var j = 0; j < array_length(_raw.imgs); j++) {
        array_push(_def.sprites, reanim_get_part_sprite(_raw.imgs[j]));
    }
    global.reanim_defs[? _name] = _def;
    return _def;
}

/// @returns {Array<String>} every converted reanim name
function reanim_load_index() {
    var _index_file = working_directory + "reanim/_index.json";
    if (!file_exists(_index_file)) _index_file = working_directory + "datafiles/reanim/_index.json";
    var _buf = buffer_load(_index_file);
    var _arr = json_parse(buffer_read(_buf, buffer_text));
    buffer_delete(_buf);
    return _arr;
}

/// Named animation ranges of a definition (the visible span of each "anim_*" track).
/// @returns {Array<Struct>} [{name, start, count}]
function reanim_anim_list(_def) {
    var _out = [];
    for (var i = 0; i < array_length(_def.tracks); i++) {
        var _n = _def.tracks[i].name;
        if (string_pos("anim_", string_lower(_n)) != 1) continue;
        var _t = _def.tracks[i].t;
        var _s = -1, _e = -1;
        for (var f = 0; f < array_length(_t); f++) {
            if (_t[f][RT_FRAME] >= 0) { if (_s < 0) _s = f; _e = f; }
        }
        if (_s >= 0) array_push(_out, { name: _n, start: _s, count: _e - _s + 1 });
    }
    return _out;
}

/// One playing reanimation. Mirrors the C++ class "Reanimation".
/// Call update() once per 10 ms logic tick (see logic_clock_steps) and draw() from a Draw event.
function Reanim(_name, _x, _y) constructor {
    def = reanim_get_def(_name);
    x = _x;
    y = _y;
    scale_x = 1;              // mOverlayMatrix scale (OverrideScale)
    scale_y = 1;
    alpha = 1;                // whole-reanim alpha multiplier
    flash_alpha = 0;          // source-style hurt overlay, 0..1
    flash_color = c_white;
    dead = false;
    anim_time = 0;            // 0..1 position inside [frame_start, frame_start + frame_count)
    last_anim_time = -1;
    loop_count = 0;
    loop_type = ReanimLoop.PLAY_ONCE;   // default in ReanimatorTrackInstance/Reanimation constructor
    frame_start = 0;
    frame_count = 0;
    anim_rate = 12;           // frames per second
    track_count = 0;
    blend_counter = [];       // per track: remaining blend ticks
    blend_time = [];
    blend_xf = [];            // per track: pose captured by start_blend()
    track_alpha = [];         // per track alpha multiplier (mTrackColor.mAlpha)
    track_truncate = [];      // mTruncateDisappearingFrames (defaults to true in the source)
    track_sprite_override = [];  // mImageOverride: sprite index or -1
    track_hidden = [];        // RENDER_GROUP_HIDDEN: track is skipped entirely (with its attachments)
    attached = [];            // per track: array of child Reanims attached to that track
    attached_back = [];       // per track: true = child drawn before the track (mRenderInBack)
    frame_base_pose = -1;     // mFrameBasePose (-1 = use frame_start, -2 = NO_BASE_POSE)
    overlay = undefined;      // matrix set by a parent attachment; replaces x/y/scale when set

    if (def != undefined) {
        anim_rate = def.fps;
        frame_count = def.frame_count;
        track_count = array_length(def.tracks);
        for (var i = 0; i < track_count; i++) {
            array_push(blend_counter, 0);
            array_push(blend_time, 0);
            array_push(blend_xf, undefined);
            array_push(track_alpha, 1);
            array_push(track_truncate, true);
            array_push(track_sprite_override, -1);
            array_push(track_hidden, false);
            array_push(attached, []);
            array_push(attached_back, false);
        }
    }

    /// @returns {Real} track index or -1 (case-insensitive like stricmp in the source)
    find_track = function(_track_name) {
        var _key = string_lower(_track_name);
        if (variable_struct_exists(def.lookup, _key)) return variable_struct_get(def.lookup, _key);
        return -1;
    };

    track_exists = function(_track_name) {
        return find_track(_track_name) >= 0;
    };

    /// Reanimation::GetFramesForLayer + SetFramesForLayer
    set_frames_for_layer = function(_track_name) {
        anim_time = (anim_rate >= 0) ? 0 : 0.9999999;
        last_anim_time = -1;
        var _ti = find_track(_track_name);
        if (_ti < 0) {
            show_debug_message("reanim: track not found: " + _track_name);
            frame_start = 0;
            frame_count = def.frame_count;
            return;
        }
        var _t = def.tracks[_ti].t;
        var _n = array_length(_t);
        var _s = 0, _c = 1;
        for (var i = 0; i < _n; i++) {
            if (_t[i][RT_FRAME] >= 0) { _s = i; break; }
        }
        for (var j = _s; j < _n; j++) {
            if (_t[j][RT_FRAME] >= 0) _c = j - _s + 1;
        }
        frame_start = _s;
        frame_count = _c;
    };

    /// Reanimation::PlayReanim
    play = function(_track_name, _loop, _blend_ticks = 0, _rate = 0) {
        if (_blend_ticks > 0) start_blend(_blend_ticks);
        if (_rate != 0) anim_rate = _rate;
        loop_type = _loop;
        loop_count = 0;
        set_frames_for_layer(_track_name);
    };

    /// Plays the entire timeline (no layer), like a freshly initialised Reanimation.
    play_all = function(_loop) {
        loop_type = _loop;
        loop_count = 0;
        anim_time = 0;
        last_anim_time = -1;
        frame_start = 0;
        frame_count = def.frame_count;
    };

    /// Reanimation::GetFrameTime -> [frame_before, frame_after, fraction]
    get_frame_time = function() {
        var _fc;
        if (loop_type == ReanimLoop.PLAY_ONCE_FULL_LAST_FRAME || loop_type == ReanimLoop.LOOP_FULL_LAST_FRAME
            || loop_type == ReanimLoop.PLAY_ONCE_FULL_LAST_FRAME_AND_HOLD) _fc = frame_count;
        else _fc = frame_count - 1;
        var _pos = frame_start + anim_time * _fc;
        var _before = floor(_pos);
        var _frac = _pos - _before;
        var _after;
        if (_before >= frame_start + frame_count - 1) {
            _before = frame_start + frame_count - 1;
            _after = _before;
        } else {
            _after = _before + 1;
        }
        return [_before, _after, _frac];
    };

    /// Reanimation::GetCurrentTransform (includes blending). Returns [x,y,kx,ky,sx,sy,frame,alpha,img]
    get_current_transform = function(_ti, _ft = undefined) {
        if (_ft == undefined) _ft = get_frame_time();
        var _t = def.tracks[_ti].t;
        var _a = _t[_ft[0]];
        var _b = _t[_ft[1]];
        var _f = _ft[2];

        // GetTransformAtTime
        var _frame = _a[RT_FRAME];
        if (_a[RT_FRAME] != -1 && _b[RT_FRAME] == -1 && _f > 0 && track_truncate[_ti]) _frame = -1;
        var _r = [
            lerp(_a[RT_X],  _b[RT_X],  _f),
            lerp(_a[RT_Y],  _b[RT_Y],  _f),
            lerp(_a[RT_KX], _b[RT_KX], _f),
            lerp(_a[RT_KY], _b[RT_KY], _f),
            lerp(_a[RT_SX], _b[RT_SX], _f),
            lerp(_a[RT_SY], _b[RT_SY], _f),
            _frame,
            lerp(_a[RT_ALPHA], _b[RT_ALPHA], _f),
            _a[RT_IMG]
        ];

        // BlendTransform. NOTE: the decompiled repo has a bug in the skew wrap loops
        // ("aSkewX2 = theTransform1.mSkewX  // (aSkewX2 -= 360.0f)"); the intended
        // behaviour in the comment (+/-360) is used here.
        if (round(_frame) >= 0 && blend_counter[_ti] > 0) {
            var _bf = blend_counter[_ti] / blend_time[_ti];
            var _o = blend_xf[_ti];
            var _kx2 = _o[RT_KX], _ky2 = _o[RT_KY];
            while (_kx2 > _r[RT_KX] + 180) _kx2 -= 360;
            while (_kx2 < _r[RT_KX] - 180) _kx2 += 360;
            while (_ky2 > _r[RT_KY] + 180) _ky2 -= 360;
            while (_ky2 < _r[RT_KY] - 180) _ky2 += 360;
            _r[RT_X]     = lerp(_r[RT_X],     _o[RT_X],     _bf);
            _r[RT_Y]     = lerp(_r[RT_Y],     _o[RT_Y],     _bf);
            _r[RT_SX]    = lerp(_r[RT_SX],    _o[RT_SX],    _bf);
            _r[RT_SY]    = lerp(_r[RT_SY],    _o[RT_SY],    _bf);
            _r[RT_ALPHA] = lerp(_r[RT_ALPHA], _o[RT_ALPHA], _bf);
            _r[RT_KX]    = lerp(_r[RT_KX],    _kx2,         _bf);
            _r[RT_KY]    = lerp(_r[RT_KY],    _ky2,         _bf);
        }
        return _r;
    };

    /// Reanimation::StartBlend: remember the current pose so the next animation fades from it
    start_blend = function(_ticks) {
        var _ft = get_frame_time();
        for (var i = 0; i < track_count; i++) {
            var _xf = get_current_transform(i, _ft);
            if (round(_xf[RT_FRAME]) >= 0) {
                blend_xf[i] = _xf;
                blend_time[i] = _ticks;
                blend_counter[i] = _ticks;
            }
        }
    };

    /// Reanimation::Update - call once per 10 ms logic tick
    update = function() {
        if (frame_count == 0 || dead) return;
        last_anim_time = anim_time;
        anim_time += LOGIC_STEP_SECONDS * anim_rate / frame_count;

        if (anim_rate > 0) {
            switch (loop_type) {
                case ReanimLoop.LOOP:
                case ReanimLoop.LOOP_FULL_LAST_FRAME:
                    while (anim_time >= 1) { loop_count++; anim_time -= 1; }
                    break;
                case ReanimLoop.PLAY_ONCE:
                case ReanimLoop.PLAY_ONCE_FULL_LAST_FRAME:
                    if (anim_time >= 1) { loop_count = 1; anim_time = 1; dead = true; }
                    break;
                case ReanimLoop.PLAY_ONCE_AND_HOLD:
                case ReanimLoop.PLAY_ONCE_FULL_LAST_FRAME_AND_HOLD:
                    if (anim_time >= 1) { loop_count = 1; anim_time = 1; }
                    break;
            }
        } else {
            switch (loop_type) {
                case ReanimLoop.LOOP:
                case ReanimLoop.LOOP_FULL_LAST_FRAME:
                    while (anim_time < 0) { loop_count++; anim_time += 1; }
                    break;
                case ReanimLoop.PLAY_ONCE:
                case ReanimLoop.PLAY_ONCE_FULL_LAST_FRAME:
                    if (anim_time < 0) { loop_count = 1; anim_time = 0; dead = true; }
                    break;
                case ReanimLoop.PLAY_ONCE_AND_HOLD:
                case ReanimLoop.PLAY_ONCE_FULL_LAST_FRAME_AND_HOLD:
                    if (anim_time < 0) { loop_count = 1; anim_time = 0; }
                    break;
            }
        }

        for (var i = 0; i < track_count; i++) {
            if (blend_counter[i] > 0) blend_counter[i]--;
            if (array_length(attached[i]) > 0) {
                // AttachmentUpdateAndSetMatrix: children follow this track, then advance themselves
                var _m = get_attachment_overlay_matrix(i);
                for (var c = 0; c < array_length(attached[i]); c++) {
                    attached[i][c].overlay = _m;
                    attached[i][c].update();
                }
            }
        }
    };

    /// mOverlayMatrix: position + scale, or the matrix a parent attachment assigned.
    get_overlay_matrix = function() {
        if (overlay != undefined) return overlay;
        return [scale_x, 0, x, 0, scale_y, y];
    };

    /// Reanimation::GetTrackBasePoseMatrix: the track's own transform at the base-pose frame.
    get_track_base_pose_matrix = function(_ti) {
        if (frame_base_pose == -2) return mat2_identity();
        var _bp = (frame_base_pose == -1) ? frame_start : frame_base_pose;
        var _f = def.tracks[_ti].t[_bp];
        return mat2_from_transform([_f[RT_X], _f[RT_Y], _f[RT_KX], _f[RT_KY], _f[RT_SX], _f[RT_SY], _f[RT_FRAME], _f[RT_ALPHA], _f[RT_IMG]]);
    };

    /// Reanimation::GetAttachmentOverlayMatrix = Overlay * Track(now) * inverse(Track(base pose))
    get_attachment_overlay_matrix = function(_ti) {
        var _m = mat2_mul(get_overlay_matrix(), mat2_from_transform(get_current_transform(_ti)));
        return mat2_mul(_m, mat2_inverse(get_track_base_pose_matrix(_ti)));
    };

    /// Reanimation::AttachToAnotherReanimation(parent, track): this reanim is drawn by (and moves with)
    /// the given track of the parent. Only draw() the parent afterwards.
    attach_to = function(_parent, _track_name) {
        var _ti = _parent.find_track(_track_name);
        if (_ti < 0 || _parent.track_count <= 0) return;
        if (_parent.frame_base_pose == -1) _parent.frame_base_pose = _parent.frame_start;
        array_push(_parent.attached[_ti], self);
        overlay = _parent.get_attachment_overlay_matrix(_ti);
    };

    /// Reanimation::SetBasePoseFromAnim
    set_base_pose_from_anim = function(_track_name) {
        var _ti = find_track(_track_name);
        if (_ti < 0) return;
        var _t = def.tracks[_ti].t;
        var _s = 0;
        for (var i = 0; i < array_length(_t); i++) { if (_t[i][RT_FRAME] >= 0) { _s = i; break; } }
        frame_base_pose = _s;
    };

    /// Reanimation::AssignRenderGroupToTrack (hidden = RENDER_GROUP_HIDDEN)
    set_track_hidden = function(_track_name, _hidden) {
        var _ti = find_track(_track_name);
        if (_ti >= 0) track_hidden[_ti] = _hidden;
    };

    /// Reanimation::AssignRenderGroupToPrefix
    set_tracks_hidden_by_prefix = function(_prefix, _hidden) {
        var _p = string_lower(_prefix);
        var _n = string_length(_p);
        for (var i = 0; i < track_count; i++) {
            if (string_copy(string_lower(def.tracks[i].name), 1, _n) == _p) track_hidden[i] = _hidden;
        }
    };

    /// Reanimation::ShowOnlyTrack
    show_only_track = function(_track_name) {
        var _k = string_lower(_track_name);
        for (var i = 0; i < track_count; i++) {
            track_hidden[i] = (string_lower(def.tracks[i].name) != _k);
        }
    };

    /// Reanimation::DrawRenderGroup / DrawTrack. Tracks are drawn in file order; attached children
    /// are drawn right after the track they are attached to.
    /// Each part image has its top-left at local (0,0). Screen = Overlay * Track * p.
    draw = function() {
        if (dead || def == undefined || frame_count == 0) return;
        var _ft = get_frame_time();
        var _o = get_overlay_matrix();
        for (var i = 0; i < track_count; i++) {
            if (track_hidden[i]) continue;

            var _nc = array_length(attached[i]);
            if (_nc > 0 && attached_back[i]) {
                for (var c = 0; c < _nc; c++) attached[i][c].draw();
            }

            var _xf = get_current_transform(i, _ft);
            if (round(_xf[RT_FRAME]) >= 0) {
                var _al = _xf[RT_ALPHA] * track_alpha[i] * alpha;
                var _spr = track_sprite_override[i];
                if (_spr == -1) {
                    var _img = _xf[RT_IMG];
                    if (_img >= 0) _spr = def.sprites[_img];   // anim_* marker tracks have no image
                }
                if (_spr != -1 && round(_al * 255) > 0) {
                    var _m = mat2_mul(_o, mat2_from_transform(_xf));
                    var _w = sprite_get_width(_spr);
                    var _h = sprite_get_height(_spr);
                    // corners (0,0) (w,0) (w,h) (0,h) -> screen
                    var _x1 = _m[2];
                    var _y1 = _m[5];
                    var _x2 = _m[0] * _w + _m[2];
                    var _y2 = _m[3] * _w + _m[5];
                    var _x4 = _m[1] * _h + _m[2];
                    var _y4 = _m[4] * _h + _m[5];
                    var _x3 = _x2 + (_x4 - _x1);
                    var _y3 = _y2 + (_y4 - _y1);
                    draw_sprite_pos(_spr, 0, _x1, _y1, _x2, _y2, _x3, _y3, _x4, _y4, _al);
                    // PvZ source-style additive hurt flash.
                    if (flash_alpha > 0) {
                        gpu_set_blendmode(bm_add);
                        draw_set_color(flash_color);
                        draw_sprite_pos(_spr, 0, _x1, _y1, _x2, _y2, _x3, _y3, _x4, _y4, clamp(_al * flash_alpha, 0, 1));
                        gpu_set_blendmode(bm_normal);
                        draw_set_color(c_white);
                    }
                }
            }

            if (_nc > 0 && !attached_back[i]) {
                for (var c2 = 0; c2 < _nc; c2++) attached[i][c2].draw();
            }
        }
    };
}
