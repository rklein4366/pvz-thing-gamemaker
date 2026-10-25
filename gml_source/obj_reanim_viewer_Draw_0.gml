/// obj_reanim_viewer : Draw
draw_clear(make_color_rgb(70, 120, 50));

if (body != undefined) {
    body.scale_x = zoom;
    body.scale_y = zoom;
    gpu_set_texfilter(true);          // smooth rotated/scaled parts like the original 3D-accelerated path
    body.draw();
    gpu_set_texfilter(false);
}

// origin cross
draw_set_color(c_white);
draw_set_alpha(0.5);
draw_line(cam_x - 10, cam_y, cam_x + 10, cam_y);
draw_line(cam_x, cam_y - 10, cam_x, cam_y + 10);
draw_set_alpha(1);

// HUD
var _anim_name = "(default)";
if (anim_sel > 0) {
    var _a = anims[anim_sel - 1];
    _anim_name = _a.name + "  frames " + string(_a.start) + ".." + string(_a.start + _a.count - 1);
}
draw_set_color(c_white);
draw_text(10, 10, "Reanim " + string(sel + 1) + "/" + string(array_length(names)) + ": " + names[sel]);
draw_text(10, 30, "Animation: " + _anim_name + (layered ? "   [head attached to body]" : ""));
if (body != undefined) {
    draw_text(10, 50, "zoom " + string_format(zoom, 1, 2) + "x   frame " + string_format(body.frame_start + body.anim_time * max(body.frame_count - 1, 0), 3, 2)
        + "   rate " + string_format(body.anim_rate, 2, 1) + " fps   loops " + string(body.loop_count) + (paused ? "   PAUSED" : ""));
}
draw_text(10, room_height - 76, "Up/Down: reanim (PgUp/PgDn x10)   Left/Right: animation (blends 20 ticks)");
draw_text(10, room_height - 56, "Mouse wheel: zoom at cursor   Drag / WASD: move camera   Z/X: zoom   C or Home: reset camera");
draw_text(10, room_height - 36, "Space: pause   L: head layering (pea-style plants)   R: restart   Esc: quit");
draw_text(10, room_height - 16, "Raw reanims show every variant at once (cone, bucket, door ...); the game hides them per type in code.");
