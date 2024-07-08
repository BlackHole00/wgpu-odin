package tutorial4_buffer_challenge

// Core
import "core:fmt"
import "core:math"

// Package
import wgpu "../../../../wrapper"
import "./../../../../utils/shaders"
import "./../../../common"

// Framework
import app "../../../framework/application"
import "../../../framework/application/events"
import "../../../framework/renderer"

Vertex :: struct {
	position: [3]f32,
	color:    [3]f32,
}

State :: struct {
	using _:                 common.State_Base,
	render_pipeline:         wgpu.Render_Pipeline,
	vertex_buffer:           wgpu.Buffer,
	index_buffer:            wgpu.Buffer,
	num_indices:             u32,
	num_challenge_indices:   u32,
	challenge_vertex_buffer: wgpu.Buffer,
	challenge_index_buffer:  wgpu.Buffer,
	use_complex:             bool,
}

Error :: common.Error

EXAMPLE_TITLE :: "Tutorial 4 - Buffers"

init :: proc() -> (state: ^State, err: Error) {
	state = new(State) or_return
	defer if err != nil do free(state)

	app_properties := app.Default_Properties
	app_properties.title = EXAMPLE_TITLE
	app.init(app_properties) or_return
	defer if err != nil do app.deinit()

	state.gpu = renderer.init() or_return
	defer if err != nil do renderer.deinit(state)

	// Use the same shader from the Tutorial 4 - Buffers
	SHADER_SRC: string : #load("./../tutorial4_buffer/shader.wgsl", string)
	COMBINED_SHADER_SRC :: shaders.SRGB_TO_LINEAR_WGSL + SHADER_SRC
	shader_module := wgpu.device_create_shader_module(
		state.device,
		{source = COMBINED_SHADER_SRC},
	) or_return
	defer wgpu.shader_module_release(shader_module)

	render_pipeline_layout := wgpu.device_create_pipeline_layout(
		state.device,
		{label = EXAMPLE_TITLE + " Render Pipeline Layout"},
	) or_return
	defer wgpu.pipeline_layout_release(render_pipeline_layout)

	vertex_buffer_layout := wgpu.Vertex_Buffer_Layout {
		array_stride = size_of(Vertex),
		step_mode    = .Vertex,
		attributes   = {
			{offset = 0, shader_location = 0, format = .Float32x3},
			{offset = cast(u64)offset_of(Vertex, color), shader_location = 1, format = .Float32x3},
		},
	}

	render_pipeline_descriptor := wgpu.Render_Pipeline_Descriptor {
		label = EXAMPLE_TITLE + " Render Pipeline",
		layout = render_pipeline_layout.ptr,
		vertex = {
			module = shader_module.ptr,
			entry_point = "vs_main",
			buffers = {vertex_buffer_layout},
		},
		fragment = &{
			module = shader_module.ptr,
			entry_point = "fs_main",
			targets = {
				{
					format = state.config.format,
					blend = &wgpu.Blend_State_Replace,
					write_mask = wgpu.Color_Write_Mask_All,
				},
			},
		},
		primitive = {topology = .Triangle_List, front_face = .CCW, cull_mode = .Back},
		depth_stencil = nil,
		multisample = {count = 1, mask = ~u32(0), alpha_to_coverage_enabled = false},
	}

	state.render_pipeline = wgpu.device_create_render_pipeline(
		state.device,
		render_pipeline_descriptor,
	) or_return
	defer if err != nil do wgpu.render_pipeline_release(state.render_pipeline)

	// vertices := []Vertex{
	//     {position = {0.0, 0.5, 0.0}, color = {1.0, 0.0, 0.0}},
	//     {position = {-0.5, -0.5, 0.0}, color = {0.0, 1.0, 0.0}},
	//     {position = {0.5, -0.5, 0.0}, color = {0.0, 0.0, 1.0}},
	// }

	vertices := []Vertex {
		{position = {-0.0868241, 0.49240386, 0.0}, color = {0.5, 0.0, 0.5}}, // A
		{position = {-0.49513406, 0.06958647, 0.0}, color = {0.5, 0.0, 0.5}}, // B
		{position = {-0.21918549, -0.44939706, 0.0}, color = {0.5, 0.0, 0.5}}, // C
		{position = {0.35966998, -0.3473291, 0.0}, color = {0.5, 0.0, 0.5}}, // D
		{position = {0.44147372, 0.2347359, 0.0}, color = {0.5, 0.0, 0.5}}, // E
	}

	indices: []u16 = {0, 1, 4, 1, 2, 4, 2, 3, 4}

	// num_vertices = cast(u32)len(vertices)
	state.num_indices = cast(u32)len(indices)

	state.vertex_buffer = wgpu.device_create_buffer_with_data(
		state.device,
		wgpu.Buffer_Data_Descriptor {
			label = EXAMPLE_TITLE + " Vertex Buffer",
			contents = wgpu.to_bytes(vertices),
			usage = {.Vertex},
		},
	) or_return
	defer if err != nil do wgpu.buffer_release(state.vertex_buffer)

	state.index_buffer = wgpu.device_create_buffer_with_data(
		state.device,
		wgpu.Buffer_Data_Descriptor {
			label = EXAMPLE_TITLE + " Index Buffer",
			contents = wgpu.to_bytes(indices),
			usage = {.Index},
		},
	) or_return
	defer if err != nil do wgpu.buffer_release(state.index_buffer)

	num_vertices :: 100
	angle := math.PI * 2.0 / f32(num_vertices)
	challenge_verts: [num_vertices]Vertex

	for i := 0; i < num_vertices; i += 1 {
		theta := angle * f32(i)
		theta_sin, theta_cos := math.sincos_f64(f64(theta))

		challenge_verts[i] = Vertex {
			position = {0.5 * f32(theta_cos), -0.5 * f32(theta_sin), 0.0},
			color    = {(1.0 + f32(theta_cos)) / 2.0, (1.0 + f32(theta_sin)) / 2.0, 1.0},
		}
	}

	num_triangles :: num_vertices - 2
	challenge_indices: [num_triangles * 3]u16
	{
		index := 0
		for i := u16(1); i < num_triangles + 1; i += 1 {
			challenge_indices[index] = i + 1
			challenge_indices[index + 1] = i
			challenge_indices[index + 2] = 0
			index += 3
		}
	}

	state.num_challenge_indices = cast(u32)len(challenge_indices)

	state.challenge_vertex_buffer = wgpu.device_create_buffer_with_data(
		state.device,
		wgpu.Buffer_Data_Descriptor {
			label = EXAMPLE_TITLE + " Vertex Buffer",
			contents = wgpu.to_bytes(challenge_verts[:]),
			usage = {.Vertex},
		},
	) or_return
	defer if err != nil do wgpu.buffer_release(state.challenge_vertex_buffer)

	state.challenge_index_buffer = wgpu.device_create_buffer_with_data(
		state.device,
		wgpu.Buffer_Data_Descriptor {
			label = EXAMPLE_TITLE + " Index Buffer",
			contents = wgpu.to_bytes(challenge_indices[:]),
			usage = {.Index},
		},
	) or_return

	state.render_pass_desc = common.create_render_pass_descriptor(
		EXAMPLE_TITLE + " Render Pass",
		wgpu.color_srgb_color_to_linear(wgpu.Color{0.1, 0.2, 0.3, 1.0}),
	) or_return

	state.color_attachment = &state.render_pass_desc.color_attachments[0]

	return
}

deinit :: proc(using state: ^State) {
	delete(render_pass_desc.color_attachments)
	wgpu.buffer_release(challenge_index_buffer)
	wgpu.buffer_release(challenge_vertex_buffer)
	wgpu.buffer_release(index_buffer)
	wgpu.buffer_release(vertex_buffer)
	wgpu.render_pipeline_release(render_pipeline)
	renderer.deinit(gpu)
	app.deinit()
	free(state)
}

render :: proc(using state: ^State) -> (err: Error) {
	frame := renderer.get_current_texture_frame(gpu) or_return
	if skip_frame do return
	defer renderer.release_current_texture_frame(gpu)

	view := wgpu.texture_create_view(frame.texture) or_return
	defer wgpu.texture_view_release(view)

	encoder := wgpu.device_create_command_encoder(device) or_return
	defer wgpu.command_encoder_release(encoder)

	color_attachment.view = view.ptr
	render_pass := wgpu.command_encoder_begin_render_pass(encoder, render_pass_desc)
	defer wgpu.render_pass_release(render_pass)

	wgpu.render_pass_set_pipeline(render_pass, render_pipeline.ptr)

	if use_complex {
		wgpu.render_pass_set_vertex_buffer(render_pass, 0, challenge_vertex_buffer.ptr)
		wgpu.render_pass_set_index_buffer(render_pass, challenge_index_buffer.ptr, .Uint16)
		wgpu.render_pass_draw_indexed(render_pass, {0, num_challenge_indices})
	} else {
		wgpu.render_pass_set_vertex_buffer(render_pass, 0, vertex_buffer.ptr)
		wgpu.render_pass_set_index_buffer(render_pass, index_buffer.ptr, .Uint16)
		wgpu.render_pass_draw_indexed(render_pass, {0, num_indices})
	}

	wgpu.render_pass_end(render_pass) or_return

	command_buffer := wgpu.command_encoder_finish(encoder) or_return
	defer wgpu.command_buffer_release(command_buffer)

	wgpu.queue_submit(queue, command_buffer.ptr)
	wgpu.surface_present(surface)

	return
}

resize_surface :: proc(using state: ^State, size: app.Physical_Size) -> (err: Error) {
	renderer.resize_surface(gpu, {size.width, size.height}) or_return
	return
}

handle_events :: proc(using state: ^State) -> (should_quit: bool, err: Error) {
	event: events.Event
	for app.poll_event(&event) {
		#partial switch ev in event {
		case events.Quit_Event:
			return true, nil
		case events.Key_Press_Event:
			if ev.key == .Space do state.use_complex = true
		case events.Key_Release_Event:
			if ev.key == .Space do state.use_complex = false
		case events.Framebuffer_Resize_Event:
			if err = resize_surface(state, {ev.width, ev.height}); err != nil {
				return true, err
			}
		}
	}

	return
}

main :: proc() {
	state, state_err := init()
	if state_err != nil do return
	defer deinit(state)

	fmt.printf("Entering main loop...\n\n")

	main_loop: for {
		should_quit, err := handle_events(state)
		if should_quit || err != nil do break main_loop
		if err = render(state); err != nil do break main_loop
	}

	fmt.println("Exiting...")
}
