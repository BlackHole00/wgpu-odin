package main

// Core
import "core:fmt"
import "core:log"
import "core:mem"

when #config(INFO_EXAMPLE, false) {
    import sample "./info"
} else when #config(TRIANGLE_EXAMPLE, false) || #config(TRIANGLE_MSAA_EXAMPLE, false) {
    import sample "./triangle"
} else when #config(SIMPLE_COMPUTE, false) {
    import sample "./simple_compute"
} else {
    import sample "./triangle"
}

main :: proc() {
    context.logger = log.create_console_logger(.Debug)
    defer log.destroy_console_logger(context.logger)

    ta: mem.Tracking_Allocator
    mem.tracking_allocator_init(&ta, context.allocator)
    defer mem.tracking_allocator_destroy(&ta)
    context.allocator = mem.tracking_allocator(&ta)

    defer if len(ta.allocation_map) > 0 {
        fmt.eprintln()
        for _, v in ta.allocation_map {
            fmt.eprintf("%v - leaked %v bytes\n", v.location, v.size)
        }
    }

    sample.start()
}
