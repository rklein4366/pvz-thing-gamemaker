/// scr_core
/// Fixed-timestep logic clock.
///
/// The original game runs one logic update every 10 ms (SexyAppBase::mFrameTime = 10),
/// i.e. 100 updates per second. Every counter in the source (plant recharge 750 = 7.5 s,
/// Sunflower production 2500 = 25 s, reanim SECONDS_PER_UPDATE = 0.01 ...) is expressed in
/// those ticks. We keep GameMaker's room speed at 60 for drawing and run logic at 100 Hz
/// through an accumulator, so every number from the C++ source can be used unchanged.

#macro LOGIC_HZ 100
#macro LOGIC_STEP_SECONDS 0.01
#macro LOGIC_MAX_CATCHUP 8

function logic_clock_init() {
    global.logic_acc = 0;
}

/// @returns {Real} how many 10 ms logic ticks to run during this GameMaker Step
function logic_clock_steps() {
    global.logic_acc += delta_time / 1000000;
    var _n = 0;
    while (global.logic_acc >= LOGIC_STEP_SECONDS && _n < LOGIC_MAX_CATCHUP) {
        global.logic_acc -= LOGIC_STEP_SECONDS;
        _n++;
    }
    if (_n >= LOGIC_MAX_CATCHUP) global.logic_acc = 0; // too far behind (window drag, breakpoint): drop the backlog
    return _n;
}
