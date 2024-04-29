const std = @import("std");
const math = std.math;
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
var prng = std.rand.DefaultPrng.init(0);
var xoshiro = prng.random();

//const Dir = enum(u32) {
//   vbit = 0b0010,
//   hbit = 0b1000,
//   up = 0b0010,
//   down = 0b0011,
//   left = 0b1000,
//   right = 0b1100,
//   upup = 0b0010_0010,
//   downdown = 0b0011_0011,
//   leftleft = 0b1000_1000,
//   rightright = 0b1100_1100,
//   upright = 0b0010_1100,
//   upleft = 0b0010_1000,
//   downright = 0b0011_1100,
//   downleft = 0b0011_1000,
//   leftup = 0b1000_0010,
//   leftdown = 0b1000_0011,
//   rightup = 0b1100_0010,
//   rightdown = 0b1100_0011,
//};

//XXX: Active Bit 0b10
const KeyState = enum(u2) { off = 0b00, up = 0b01, pressed = 0b10, held = 0b11 };

const Key = enum { up, down, left, right, confirm };

const k_keys_num: usize = @typeInfo(Key).Enum.fields.len;

var g_key_states: [k_keys_num]KeyState = undefined;

const g_key_map = [k_keys_num]usize{
    c.SDL_SCANCODE_UP,
    c.SDL_SCANCODE_DOWN,
    c.SDL_SCANCODE_LEFT,
    c.SDL_SCANCODE_RIGHT,
    c.SDL_SCANCODE_RETURN,
};

const k_screen_width: i32 = 320;
const k_screen_height: i32 = 200;

var g_window: ?*c.SDL_Window = null;
var g_renderer: ?*c.SDL_Renderer = null;
var g_texture: ?*c.SDL_Texture = null;

var g_quit: bool = false;

var g_point = c.SDL_Point{ .x = 0, .y = 0 };

//XXX: Engine

fn key_get(i: Key) bool {
    switch (g_key_states[@intFromEnum(i)]) {
        KeyState.held, KeyState.pressed => {
            return true;
        },
        else => {
            return false;
        },
    }
}

fn key_state_update(i: usize, is_down: bool) void {
    switch (g_key_states[i]) {
        KeyState.held, KeyState.pressed => {
            if (is_down) {
                g_key_states[i] = KeyState.held;
            } else {
                g_key_states[i] = KeyState.up;
            }
        },
        KeyState.off, KeyState.up => {
            if (is_down) {
                g_key_states[i] = KeyState.pressed;
            } else {
                g_key_states[i] = KeyState.off;
            }
        },
    }
}

fn events_process() void {
    c.SDL_PumpEvents();
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event) != 0) {
        switch (event.type) {
            c.SDL_QUIT => {
                g_quit = true;
                break;
            },
            c.SDL_WINDOWEVENT => {
                if (event.window.event == c.SDL_WINDOWEVENT_CLOSE) {
                    g_quit = true;
                }
                break;
            },
            else => {
                break;
            },
        }
    }

    var keys_num: i32 = undefined;
    //const key_state: [*c]const u8 = c.SDL_GetKeyboardState(&keys_num);
    const key_state = c.SDL_GetKeyboardState(&keys_num);

    for (0..k_keys_num) |i| {
        const scancode: usize = g_key_map[i];
        var is_down: bool = false;
        //if (scancode and scancode < keys_num) {
        if (scancode < keys_num) {
            //is_down |= (0 != key_state[scancode]);
            is_down = is_down or (0 != key_state[scancode]);
        }
        key_state_update(i, is_down);
    }
}

fn game_update() void {
    if (key_get(Key.up)) {
        g_point.y -= 1;
    }
    if (key_get(Key.down)) {
        g_point.y += 1;
    }
    if (key_get(Key.left)) {
        g_point.x -= 1;
    }
    if (key_get(Key.right)) {
        g_point.x += 1;
    }
}

fn game_draw() !void {
    //XXX: Drawing a white background
    if (c.SDL_SetRenderDrawColor(g_renderer, 255, 255, 255, 255) != 0) {
        c.SDL_Log("Unable to set color for the rendering target: %s", c.SDL_GetError());
        return error.SDLSetRenderDrawColorFailed;
    }
    if (c.SDL_RenderFillRect(g_renderer, &(c.SDL_Rect){ .x = 0, .y = 0, .w = k_screen_width, .h = k_screen_height }) != 0) {
        c.SDL_Log("Unable to fill a rectangle on the current rendering target: %s", c.SDL_GetError());
        return error.SDLRenderFillRectFailed;
    }

    //XXX: Drawing a red square
    if (c.SDL_SetRenderDrawColor(g_renderer, 255, 0, 0, 255) != 0) {
        c.SDL_Log("Unable to set color for the rendering target: %s", c.SDL_GetError());
        return error.SDLSetRenderDrawColorFailed;
    }
    if (c.SDL_RenderFillRect(g_renderer, &(c.SDL_Rect){ .x = g_point.x, .y = g_point.y, .w = 64, .h = 64 }) != 0) {
        c.SDL_Log("Unable to fill a rectangle on the current rendering target: %s", c.SDL_GetError());
        return error.SDLRenderFillRectFailed;
    }
}

fn frame_present() !void {
    c.SDL_RenderPresent(g_renderer);
    if (c.SDL_SetRenderDrawColor(g_renderer, 0, 0, 0, 255) != 0) {
        c.SDL_Log("Unable to set color for the rendering target: %s", c.SDL_GetError());
        return error.SDLSetRenderDrawColorFailed;
    }
    if (c.SDL_RenderClear(g_renderer) != 0) {
        c.SDL_Log("Unable to clear the rendering target: %s", c.SDL_GetError());
        g_quit = true;
        return error.SDLRenderClearFailed;
    }
}

fn game_init() void {}

pub fn main() !void {
    //XXX: The whole SDL init

    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitFailed;
    }
    defer c.SDL_Quit();

    //XXX: Using SDL_WINDOW_UTILITY to force the window floating on tiling window managers
    g_window = c.SDL_CreateWindow("Zig SDL2 boilerplate", c.SDL_WINDOWPOS_UNDEFINED, c.SDL_WINDOWPOS_UNDEFINED, k_screen_width, k_screen_height, c.SDL_WINDOW_ALLOW_HIGHDPI | c.SDL_WINDOW_UTILITY | c.SDL_WINDOW_RESIZABLE) orelse
        {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLCreateWindowFailed;
    };
    defer c.SDL_DestroyWindow(g_window);

    g_renderer = c.SDL_CreateRenderer(g_window, -1, c.SDL_RENDERER_PRESENTVSYNC) orelse
        {
        c.SDL_Log("Unable to create renderer: %s", c.SDL_GetError());
        return error.SDLCreateRendererFailed;
    };
    defer c.SDL_DestroyRenderer(g_renderer);

    if (c.SDL_RenderSetIntegerScale(g_renderer, c.SDL_TRUE) != 0) {
        c.SDL_Log("Unable to force integer scale: %s", c.SDL_GetError());
        //XXX: Not sure if execution should stop because of that
        //return error.SDLRenderSetIntegerScaleFailed;
    }

    //XXX: Making sure that the aspect ratio is kept when resizing
    if (c.SDL_RenderSetLogicalSize(g_renderer, k_screen_width, k_screen_height) != 0) {
        c.SDL_Log("Unable to set independent resolution for rendering: %s", c.SDL_GetError());
        //XXX: Not sure if execution should stop because of that
        //return error.SDLRenderSetLogicalSizeFailed;
    }

    game_init();

    //XXX: Game loop
    while (!g_quit) {
        events_process();
        game_update();
        try game_draw();
        try frame_present();
    }
}
