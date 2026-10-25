/// obj_reanim_viewer : Step
var _ticks = logic_clock_steps();
if (!paused && body != undefined) {
    repeat (_ticks) body.update();   // children (the head) are updated by their parent
}

if (keyboard_check_pressed(vk_down))     switch_reanim(1);
if (keyboard_check_pressed(vk_up))       switch_reanim(-1);
if (keyboard_check_pressed(vk_pagedown)) switch_reanim(10);
if (keyboard_check_pressed(vk_pageup))   switch_reanim(-10);
if (keyboard_check_pressed(vk_right))    select_anim(1);
if (keyboard_check_pressed(vk_left))     select_anim(-1);
if (keyboard_check_pressed(vk_space))    paused = !paused;
if (keyboard_check_pressed(ord("R")))    { anim_sel = 0; rebuild(); }
if (keyboard_check_pressed(ord("L")) && can_layer) { layered = !layered; anim_sel = 0; rebuild(); }

// ---- camera ----
if (mouse_wheel_up())   zoom_at(1.15, mouse_x, mouse_y);       // wheel: zoom toward the cursor
if (mouse_wheel_down()) zoom_at(1 / 1.15, mouse_x, mouse_y);
if (keyboard_check(ord("Z"))) zoom_at(1.02, room_width * 0.5, room_height * 0.5);
if (keyboard_check(ord("X"))) zoom_at(1 / 1.02, room_width * 0.5, room_height * 0.5);
if (mouse_check_button(mb_left) || mouse_check_button(mb_middle) || mouse_check_button(mb_right)) {
    cam_x += mouse_x - prev_mx;                                // drag to pan
    cam_y += mouse_y - prev_my;
}
prev_mx = mouse_x;
prev_my = mouse_y;
var _pan = 400 * delta_time / 1000000;                         // WASD pan, 400 px/s
if (keyboard_check(ord("A"))) cam_x += _pan;
if (keyboard_check(ord("D"))) cam_x -= _pan;
if (keyboard_check(ord("W"))) cam_y += _pan;
if (keyboard_check(ord("S"))) cam_y -= _pan;
if (keyboard_check_pressed(ord("C")) || keyboard_check_pressed(vk_home)) reset_camera();
if (body != undefined) { body.x = cam_x; body.y = cam_y; }
if (keyboard_check_pressed(vk_escape))   game_end();
