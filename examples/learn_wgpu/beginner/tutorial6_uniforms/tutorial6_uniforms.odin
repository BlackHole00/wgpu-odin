package tutorial6_uniforms

// Core
import "core:fmt"
import la "core:math/linalg"

// Package
import "../../../../utils/shaders"
import wgpu "../../../../wrapper"
import "../../../common"
import "../tutorial5_textures/texture"

OPEN_GL_TO_WGPU_MATRIX :: common.OPEN_GL_TO_WGPU_MATRIX

// Framework
import app "../../../framework/application"
import "../../../framework/application/events"
import "../../../framework/renderer"

Vertex :: struct {
	position:   [3]f32,
	tex_coords: [2]f32,
}

Camera :: struct {
	eye:     la.Vector3f32,
	target:  la.Vector3f32,
	up:      la.Vector3f32,
	aspect:  f32,
	fovYRad: f32,
	znear:   f32,
	zfar:    f32,
}

Camera_Uniform :: struct {
	view_proj: la.Matrix4f32,
}

Camera_Controller :: struct {
	speed:               f32,
	is_up_pressed:       bool,
	is_down_pressed:     bool,
	is_forward_pressed:  bool,
	is_backward_pressed: bool,
	is_left_pressed:     bool,
	is_right_pressed:    bool,
}

State :: struct {
	using _:            common.State_Base,
	diffuse_bind_group: wgpu.Bind_Group,
	camera:             Camera,
	camera_controller:  Camera_Controller,
	camera_uniform:     Camera_Uniform,
	camera_buffer:      wgpu.Buffer,
	camera_bind_group:  wgpu.Bind_Group,
	render_pipeline:    wgpu.Render_Pipeline,
	num_indices:        u32,
	vertex_buffer:      wgpu.Buffer,
	index_buffer:       wgpu.Buffer,
}

Error :: common.Error

EXAMPLE_TITLE :: "Tutorial 6 - Uniforms"

init :: proc() -> (state: ^State, err: Error) {
	state = new(State) or_return
	defer if err != nil do free(state)

	app_properties := app.Default_Properties
	app_properties.title = EXAMPLE_TITLE
	app.init(app_properties) or_return
	defer if err != nil do app.deinit()

	state.gpu = renderer.init() or_return
	defer if err != nil do renderer.deinit(state)

	// Load our tree image to texture
	diffuse_texture := texture.texture_from_image(
		&state.device,
		&state.queue,
		"assets/learn_wgpu/tutorial5/happy-tree.png",
	) or_return
	defer texture.texture_destroy(&diffuse_texture)

	texture_bind_group_layout := wgpu.device_create_bind_group_layout(
		&state.device,
		&{
			label = "TextureBindGroupLayout",
			entries = {
				{
					binding = 0,
					visibility = {.Fragment},
					type = wgpu.Texture_Binding_Layout {
						multisampled = false,
						view_dimension = .D2,
						sample_type = .Float,
					},
				},
				{
					binding = 1,
					visibility = {.Fragment},
					type = wgpu.Sampler_Binding_Layout{type = .Filtering},
				},
			},
		},
	) or_return
	defer wgpu.bind_group_layout_release(&texture_bind_group_layout)

	state.diffuse_bind_group = wgpu.device_create_bind_group(
		&state.device,
		&wgpu.Bind_Group_Descriptor {
			label = "diffuse_bind_group",
			layout = texture_bind_group_layout.ptr,
			entries = {
				{binding = 0, resource = diffuse_texture.view.ptr},
				{binding = 1, resource = diffuse_texture.sampler.ptr},
			},
		},
	) or_return
	defer if err != nil do wgpu.bind_group_release(&state.diffuse_bind_group)

	state.camera = {
		{0.0, 1.0, 2.0},
		{0.0, 0.0, 0.0},
		{0.0, 1.0, 0.0},
		cast(f32)state.config.width / cast(f32)state.config.height,
		// math.PI / 4,
		cast(f32)la.to_radians(45.0),
		0.1,
		100.0,
	}

	state.camera_controller = new_camera_controller(0.2)

	state.camera_uniform = new_camera_uniform()
	update_view_proj(&state.camera_uniform, &state.camera)

	state.camera_buffer = wgpu.device_create_buffer_with_data(
		&state.device,
		&wgpu.Buffer_Data_Descriptor {
			label = "Camera Buffer",
			contents = wgpu.to_bytes(state.camera_uniform.view_proj),
			usage = {.Uniform, .Copy_Dst},
		},
	) or_return
	defer if err != nil do wgpu.buffer_release(&state.camera_buffer)

	camera_bind_group_layout := wgpu.device_create_bind_group_layout(
		&state.device,
		&{
			label = "camera_bind_group_layout",
			entries = {
				{
					binding = 0,
					visibility = {.Vertex},
					type = wgpu.Buffer_Binding_Layout{type = .Uniform, has_dynamic_offset = false},
				},
			},
		},
	) or_return
	defer wgpu.bind_group_layout_release(&camera_bind_group_layout)

	state.camera_bind_group = wgpu.device_create_bind_group(
		&state.device,
		&wgpu.Bind_Group_Descriptor {
			label = "camera_bind_group",
			layout = camera_bind_group_layout.ptr,
			entries = {
				{
					binding = 0,
					resource = wgpu.Buffer_Binding {
						buffer = state.camera_buffer.ptr,
						size = wgpu.WHOLE_SIZE,
					},
				},
			},
		},
	) or_return
	defer if err != nil do wgpu.bind_group_release(&state.camera_bind_group)

	render_pipeline_layout := wgpu.device_create_pipeline_layout(
		&state.device,
		&{
			label = "Render Pipeline Layout",
			bind_group_layouts = {texture_bind_group_layout.ptr, camera_bind_group_layout.ptr},
		},
	) or_return
	defer wgpu.pipeline_layout_release(&render_pipeline_layout)

	vertex_buffer_layout := wgpu.Vertex_Buffer_Layout {
		array_stride = size_of(Vertex),
		step_mode    = .Vertex,
		attributes   = {
			{offset = 0, shader_location = 0, format = .Float32x3},
			{
				offset = cast(u64)offset_of(Vertex, tex_coords),
				shader_location = 1,
				format = .Float32x2,
			},
		},
	}

	SHADER_SRC: string : #load("./shader.wgsl", string)
	COMBINED_SHADER_SRC :: shaders.SRGB_TO_LINEAR_WGSL + SHADER_SRC
	shader_module := wgpu.device_create_shader_module(
		&state.device,
		&{source = COMBINED_SHADER_SRC},
	) or_return
	defer wgpu.shader_module_release(&shader_module)

	render_pipeline_descriptor := wgpu.Render_Pipeline_Descriptor {
		label = "Render Pipeline",
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
		&state.device,
		&render_pipeline_descriptor,
	) or_return
	defer if err != nil do wgpu.render_pipeline_release(&state.render_pipeline)

	vertices := []Vertex {
		{position = {-0.0868241, 0.49240386, 0.0}, tex_coords = {0.4131759, 0.00759614}}, // A
		{position = {-0.49513406, 0.06958647, 0.0}, tex_coords = {0.0048659444, 0.43041354}}, // B
		{position = {-0.21918549, -0.44939706, 0.0}, tex_coords = {0.28081453, 0.949397}}, // C
		{position = {0.35966998, -0.3473291, 0.0}, tex_coords = {0.85967, 0.84732914}}, // D
		{position = {0.44147372, 0.2347359, 0.0}, tex_coords = {0.9414737, 0.2652641}}, // E
	}

	indices: []u16 = {0, 1, 4, 1, 2, 4, 2, 3, 4}

	state.num_indices = cast(u32)len(indices)

	state.vertex_buffer = wgpu.device_create_buffer_with_data(
		&state.device,
		&wgpu.Buffer_Data_Descriptor {
			label = "Vertex Buffer",
			contents = wgpu.to_bytes(vertices),
			usage = {.Vertex},
		},
	) or_return
	defer if err != nil do wgpu.buffer_release(&state.vertex_buffer)

	state.index_buffer = wgpu.device_create_buffer_with_data(
		&state.device,
		&wgpu.Buffer_Data_Descriptor {
			label = "Index Buffer",
			contents = wgpu.to_bytes(indices),
			usage = {.Index},
		},
	) or_return

	state.render_pass_desc = common.create_render_pass_descriptor(
		EXAMPLE_TITLE + " Render Pass",
		wgpu.color_srgb_to_linear(wgpu.Color{0.1, 0.2, 0.3, 1.0}),
	) or_return

	state.color_attachment = &state.render_pass_desc.color_attachments[0]

	return
}

deinit :: proc(using state: ^State) {
	delete(render_pass_desc.color_attachments)
	wgpu.buffer_release(&index_buffer)
	wgpu.buffer_release(&vertex_buffer)
	wgpu.render_pipeline_release(&render_pipeline)
	wgpu.bind_group_release(&camera_bind_group)
	wgpu.bind_group_release(&diffuse_bind_group)
	wgpu.buffer_release(&camera_buffer)
	renderer.deinit(gpu)
	app.deinit()
	free(state)
}

update :: proc(using state: ^State) -> (err: Error) {
	update_camera_controller(&camera_controller, &camera)
	update_view_proj(&camera_uniform, &camera)

	wgpu.queue_write_buffer(&queue, camera_buffer.ptr, 0, wgpu.to_bytes(camera_uniform.view_proj))

	return
}

render :: proc(using state: ^State) -> (err: Error) {
	frame := renderer.get_current_texture_frame(gpu) or_return
	if skip_frame do return
	defer wgpu.texture_release(&frame.texture)

	view := wgpu.texture_create_view(&frame.texture) or_return
	defer wgpu.texture_view_release(&view)

	encoder := wgpu.device_create_command_encoder(&device) or_return
	defer wgpu.command_encoder_release(&encoder)

	color_attachment.view = view.ptr
	render_pass := wgpu.command_encoder_begin_render_pass(&encoder, &render_pass_desc)
	defer wgpu.render_pass_encoder_release(&render_pass)

	wgpu.render_pass_encoder_set_pipeline(&render_pass, render_pipeline.ptr)
	wgpu.render_pass_encoder_set_bind_group(&render_pass, 0, diffuse_bind_group.ptr)
	wgpu.render_pass_encoder_set_bind_group(&render_pass, 1, camera_bind_group.ptr)
	wgpu.render_pass_encoder_set_vertex_buffer(&render_pass, 0, vertex_buffer.ptr)
	wgpu.render_pass_encoder_set_index_buffer(
		&render_pass,
		index_buffer.ptr,
		.Uint16,
		0,
		wgpu.WHOLE_SIZE,
	)
	wgpu.render_pass_encoder_draw_indexed(&render_pass, num_indices)
	wgpu.render_pass_encoder_end(&render_pass) or_return

	command_buffer := wgpu.command_encoder_finish(&encoder) or_return
	defer wgpu.command_buffer_release(&command_buffer)

	wgpu.queue_submit(&queue, command_buffer.ptr)
	wgpu.surface_present(&surface)

	return
}

resize_surface :: proc(using state: ^State, size: app.Physical_Size) -> (err: Error) {
	camera.aspect = cast(f32)size.width / cast(f32)size.height
	update_view_proj(&camera_uniform, &camera)
	wgpu.queue_write_buffer(
		&queue,
		camera_buffer.ptr,
		0,
		wgpu.to_bytes(camera_uniform.view_proj),
	) or_return

	renderer.resize_surface(gpu, {size.width, size.height}) or_return

	return
}

handle_events :: proc(using state: ^State) -> (should_quit: bool, err: Error) {
	event: events.Event
	for app.poll_event(&event) {
		#partial switch &ev in event {
		case events.Quit_Event:
			return true, nil
		case events.Key_Press_Event:
			#partial switch ev.key {
			case .Space:
				state.camera_controller.is_up_pressed = true
			case .Lshift:
				state.camera_controller.is_down_pressed = true
			case .W:
				state.camera_controller.is_forward_pressed = true
			case .A:
				state.camera_controller.is_left_pressed = true
			case .S:
				state.camera_controller.is_backward_pressed = true
			case .D:
				state.camera_controller.is_right_pressed = true
			}
		case events.Key_Release_Event:
			#partial switch ev.key {
			case .Space:
				state.camera_controller.is_up_pressed = false
			case .Lshift:
				state.camera_controller.is_down_pressed = false
			case .W:
				state.camera_controller.is_forward_pressed = false
			case .A:
				state.camera_controller.is_left_pressed = false
			case .S:
				state.camera_controller.is_backward_pressed = false
			case .D:
				state.camera_controller.is_right_pressed = false
			}
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
		if err = update(state); err != nil do break main_loop
		if err = render(state); err != nil do break main_loop
	}

	fmt.println("Exiting...")
}

build_view_projection_matrix :: proc(camera: ^Camera) -> la.Matrix4f32 {
	projection := la.matrix4_perspective_f32(
		camera.fovYRad,
		camera.aspect,
		camera.znear,
		camera.zfar,
	)
	view := la.matrix4_look_at_f32(eye = camera.eye, centre = camera.target, up = camera.up)
	// return la.mul(projection, view)
	return OPEN_GL_TO_WGPU_MATRIX * projection * view
}

new_camera_uniform :: proc() -> Camera_Uniform {
	return {la.MATRIX4F32_IDENTITY}
}

update_view_proj :: proc(self: ^Camera_Uniform, camera: ^Camera) {
	self.view_proj = build_view_projection_matrix(camera)
}

new_camera_controller :: proc(speed: f32) -> Camera_Controller {
	return {speed = speed}
}

update_camera_controller :: proc(using self: ^Camera_Controller, camera: ^Camera) {
	forward := camera.target - camera.eye
	forward_norm := la.normalize(forward)
	forward_mag := la.length(forward)

	// Prevents glitching when the camera gets too close to the center of the scene.
	if is_forward_pressed && forward_mag > speed {
		camera.eye += forward_norm * speed
	}

	if is_backward_pressed {
		camera.eye -= forward_norm * speed
	}

	right := la.cross(forward_norm, camera.up)

	// Redo radius calc in case the forward/backward is pressed.
	forward = camera.target - camera.eye
	forward_mag = la.length(forward)

	if is_right_pressed {
		camera.eye = camera.target - la.normalize(forward + right * speed) * forward_mag
	}

	if is_left_pressed {
		camera.eye = camera.target - la.normalize(forward - right * speed) * forward_mag
	}
}
