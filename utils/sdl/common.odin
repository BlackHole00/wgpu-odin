package wgpu_utils_sdl

// Core
import "core:fmt"

// Vendor
import sdl "vendor:sdl2"

// Package
import wgpu "../../wrapper"

// Setup surface information
default_surface_descriptor := wgpu.Surface_Descriptor {
    Android_Native_Window = nil,
    Html_Selector         = nil,
    Metal_Layer           = nil,
    Wayland_Surface       = nil,
    Windows_HWND          = nil,
    Xcb_Window            = nil,
    Xlib_Window           = nil,
}

get_sys_info :: proc(window: ^sdl.Window) -> (sdl.SysWMinfo, wgpu.Error_Type) {
    wm_info: sdl.SysWMinfo
    sdl.GetVersion(&wm_info.version)

    if !sdl.GetWindowWMInfo(window, &wm_info) {
        fmt.eprintf("ERROR: Could not obtain SDL WM info from window.\n")
        return {}, .Internal
    }

    return wm_info, .No_Error
}
