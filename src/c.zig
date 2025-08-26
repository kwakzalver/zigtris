const Standard = @import("std");

const C = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});

pub const SDL = struct {
    pub const Color = C.SDL_Color;
    pub const CreateRenderer = C.SDL_CreateRenderer;
    pub const CreateTextureFromSurface = C.SDL_CreateTextureFromSurface;
    pub const CreateWindow = C.SDL_CreateWindow;
    pub const Delay = C.SDL_Delay;
    pub const DestroyRenderer = C.SDL_DestroyRenderer;
    pub const DestroySurface = C.SDL_DestroySurface;
    pub const DestroyTexture = C.SDL_DestroyTexture;
    pub const DestroyWindow = C.SDL_DestroyWindow;
    pub const Event = C.SDL_Event;
    pub const FRect = C.SDL_FRect;
    pub const GetError = C.SDL_GetError;
    pub const GetKeyboardState = C.SDL_GetKeyboardState;
    pub const IOFromConstMem = C.SDL_IOFromConstMem;
    pub const Init = C.SDL_Init;
    pub const Log = C.SDL_Log;
    pub const PollEvent = C.SDL_PollEvent;
    pub const Quit = C.SDL_Quit;
    pub const RenderClear = C.SDL_RenderClear;
    pub const RenderFillRect = C.SDL_RenderFillRect;
    pub const RenderPresent = C.SDL_RenderPresent;
    pub const RenderTexture = C.SDL_RenderTexture;
    pub const Renderer = C.SDL_Renderer;
    pub const Scancode = C.SDL_Scancode;
    pub const SetRenderDrawColor = C.SDL_SetRenderDrawColor;
    pub const Texture = C.SDL_Texture;

    pub const EVENT_QUIT = C.SDL_EVENT_QUIT;
    pub const EVENT_WINDOW_RESIZED = C.SDL_EVENT_WINDOW_RESIZED;
    pub const INIT_VIDEO = C.SDL_INIT_VIDEO;
    pub const SCANCODE_1 = C.SDL_SCANCODE_1;
    pub const SCANCODE_2 = C.SDL_SCANCODE_2;
    pub const SCANCODE_3 = C.SDL_SCANCODE_3;
    pub const SCANCODE_4 = C.SDL_SCANCODE_4;
    pub const SCANCODE_A = C.SDL_SCANCODE_A;
    pub const SCANCODE_BACKSPACE = C.SDL_SCANCODE_BACKSPACE;
    pub const SCANCODE_COUNT = C.SDL_SCANCODE_COUNT;
    pub const SCANCODE_D = C.SDL_SCANCODE_D;
    pub const SCANCODE_DOWN = C.SDL_SCANCODE_DOWN;
    pub const SCANCODE_ESCAPE = C.SDL_SCANCODE_ESCAPE;
    pub const SCANCODE_F1 = C.SDL_SCANCODE_F1;
    pub const SCANCODE_F2 = C.SDL_SCANCODE_F2;
    pub const SCANCODE_F3 = C.SDL_SCANCODE_F3;
    pub const SCANCODE_F4 = C.SDL_SCANCODE_F4;
    pub const SCANCODE_LEFT = C.SDL_SCANCODE_LEFT;
    pub const SCANCODE_R = C.SDL_SCANCODE_R;
    pub const SCANCODE_RCTRL = C.SDL_SCANCODE_RCTRL;
    pub const SCANCODE_RIGHT = C.SDL_SCANCODE_RIGHT;
    pub const SCANCODE_SPACE = C.SDL_SCANCODE_SPACE;
    pub const SCANCODE_TAB = C.SDL_SCANCODE_TAB;
    pub const SCANCODE_UP = C.SDL_SCANCODE_UP;
    pub const WINDOW_OPENGL = C.SDL_WINDOW_OPENGL;
    pub const WINDOW_RESIZABLE = C.SDL_WINDOW_RESIZABLE;
    pub const WINDOW_VULKAN = C.SDL_WINDOW_VULKAN;
};

pub const TTF = struct {
    pub const CloseFont = C.TTF_CloseFont;
    pub const Font = C.TTF_Font;
    pub const Init = C.TTF_Init;
    pub const OpenFontIO = C.TTF_OpenFontIO;
    pub const Quit = C.TTF_Quit;
    pub const RenderText_Blended = C.TTF_RenderText_Blended;
};
