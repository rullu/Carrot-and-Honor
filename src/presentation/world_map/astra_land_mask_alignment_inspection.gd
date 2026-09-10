extends Node3D


const LAND_MASK_PATH := "res://assets/world_map/astra/source/FCAH_Features_Playable_4096x2304_RGBA.png"
const LAND_MASK_SHA256 := "33ba99ef3bdf988746a4f3ed4326cc0d923730e35c05869e14a0bb5c6581a7a0"
const EXPECTED_REGION_COUNT := 576
const VERTEX_SPACING := 12.20703125
const IMPORT_ORIGIN := Vector2(-25000.0, -14062.5)
const FULL_VIEW_SIZE := 34000.0
const MIN_VIEW_SIZE := 700.0
const MAX_VIEW_SIZE := 36000.0
const OBLIQUE_OFFSET := Vector3(0.0, 18000.0, 22000.0)
const TOP_DOWN_OFFSET := Vector3(0.0, 30000.0, 0.01)

const ALIGNMENT_ANCHORS := [
	["Nirafielia", Vector2(1869.612, 1367.356), Vector2(-2171.484375, 2634.9609375)],
	["Mengia", Vector2(2920.828, 1847.948), Vector2(10660.7421875, 8501.5625)],
	["Milpalcou", Vector2(1543.66, 1121.9), Vector2(-6150.390625, -361.328125)],
	["Taria", Vector2(899.964, 1100.092), Vector2(-14008.0078125, -627.5390625)],
	["Drest", Vector2(2209.116, 1419.26), Vector2(1972.8515625, 3268.5546875)],
	["Mackebia", Vector2(3307.516, 605.18), Vector2(15381.0546875, -6668.9453125)],
	["Trosovis", Vector2(1439.372, 1092.364), Vector2(-7423.4375, -721.875)],
	["Cavempil", Vector2(1918.412, 1830.012), Vector2(-1575.78125, 8282.6171875)],
]

@onready var terrain: Terrain3D = $Terrain3D
@onready var camera: Camera3D = $InspectionCamera
@onready var mode_label: Label = $DiagnosticsUI/Panel/Margin/Rows/Mode
@onready var view_label: Label = $DiagnosticsUI/Panel/Margin/Rows/View

var _camera_target := Vector3.ZERO
var _top_down := false
var _mode := 0
var _mask_image: Image


func _ready() -> void:
	_mask_image = Image.load_from_file(ProjectSettings.globalize_path(LAND_MASK_PATH))
	if _mask_image.is_empty():
		push_error("Could not load the Astra playable land-mask crop.")
		get_tree().quit(1)
		return
	var mask_texture := ImageTexture.create_from_image(_mask_image)
	terrain.material.set_shader_param(&"land_mask", mask_texture)
	terrain.set_camera(camera)
	camera.current = true
	_update_camera()
	_set_mode(0)
	print(
		"Astra land-mask inspection ready: Terrain3D %s, %d regions, mask %s"
		% [terrain.version, terrain.data.get_regions_active().size(), _mask_image.get_size()]
	)

	var validation_output := _get_validation_output()
	if not validation_output.is_empty():
		await _run_validation(validation_output)


func _process(delta: float) -> void:
	var direction := Input.get_vector(
		&"map_move_left", &"map_move_right", &"map_move_up", &"map_move_down"
	)
	if direction.is_zero_approx():
		return
	var pan_speed := camera.size * 0.65
	_camera_target.x = clampf(
		_camera_target.x + direction.x * pan_speed * delta, -24500.0, 24500.0
	)
	_camera_target.z = clampf(
		_camera_target.z + direction.y * pan_speed * delta, -13500.0, 13500.0
	)
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(camera.size * 0.82)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(camera.size * 1.22)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				_set_mode(0)
			KEY_2:
				_set_mode(1)
			KEY_3:
				_set_mode(2)
			KEY_V:
				_top_down = not _top_down
				_update_camera()
			KEY_F:
				_camera_target = Vector3.ZERO
				camera.size = FULL_VIEW_SIZE
				_update_camera()


func _set_mode(mode: int) -> void:
	_mode = mode
	terrain.material.set_shader_param(&"diagnostic_mode", _mode)
	match _mode:
		0:
			mode_label.text = "1  COMBINED: yellow boundary | magenta mask-land below sea | cyan terrain-land outside mask"
		1:
			mode_label.text = "2  TERRAIN: neutral Terrain3D relief plus translucent zero-height sea plane"
		2:
			mode_label.text = "3  MASK: green R-channel land | dark sea | yellow 2-sample boundary stroke"


func _set_zoom(new_size: float) -> void:
	camera.size = clampf(new_size, MIN_VIEW_SIZE, MAX_VIEW_SIZE)


func _update_camera() -> void:
	if _top_down:
		camera.position = _camera_target + TOP_DOWN_OFFSET
		camera.look_at(_camera_target, Vector3.FORWARD)
		view_label.text = "View: TOP-DOWN (north is screen top)"
	else:
		camera.position = _camera_target + OBLIQUE_OFFSET
		camera.look_at(_camera_target, Vector3.UP)
		view_label.text = "View: OBLIQUE (north is screen top)"


func _get_validation_output() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--validation-output="):
			return argument.trim_prefix("--validation-output=")
	return ""


func _run_validation(output_directory: String) -> void:
	var failures: Array[String] = []
	if _mask_image.get_size() != Vector2i(4096, 2304):
		failures.append("The playable mask crop is not 4096x2304.")
	if _mask_image.get_format() != Image.FORMAT_RGBA8:
		failures.append("The playable mask crop is not RGBA8.")
	if _mask_image.has_mipmaps():
		failures.append("The runtime mask image unexpectedly contains mipmaps.")
	if FileAccess.get_sha256(LAND_MASK_PATH) != LAND_MASK_SHA256:
		failures.append("The project-local mask crop does not match the validated SHA-256.")
	if terrain.version != "1.0.2":
		failures.append("Unexpected Terrain3D version: %s" % terrain.version)
	if terrain.region_size != 128:
		failures.append("Unexpected Terrain3D region size: %d" % terrain.region_size)
	if not is_equal_approx(terrain.vertex_spacing, VERTEX_SPACING):
		failures.append("Unexpected Terrain3D vertex spacing: %s" % terrain.vertex_spacing)
	if terrain.data.get_regions_active().size() != EXPECTED_REGION_COUNT:
		failures.append(
			"Expected %d terrain regions, found %d."
			% [EXPECTED_REGION_COUNT, terrain.data.get_regions_active().size()]
		)
	_validate_anchor_mapping(failures)

	DirAccess.make_dir_recursive_absolute(output_directory)
	_top_down = true
	camera.size = 28125.0
	_camera_target = Vector3.ZERO
	_update_camera()
	_set_mode(0)
	await _save_view(output_directory.path_join("astra_mask_alignment_combined_top_down.png"), failures)
	_set_mode(2)
	await _save_view(output_directory.path_join("astra_mask_alignment_mask_top_down.png"), failures)
	_top_down = false
	camera.size = FULL_VIEW_SIZE
	_update_camera()
	_set_mode(1)
	await _save_view(output_directory.path_join("astra_mask_alignment_terrain_oblique.png"), failures)

	if failures.is_empty():
		var result_file := FileAccess.open(
			output_directory.path_join("astra_mask_alignment_validation_result.txt"), FileAccess.WRITE
		)
		result_file.store_string(
			"ASTRA_LAND_MASK_ALIGNMENT_VALIDATION_PASS\n"
			+ "mask_sha256=%s\n" % LAND_MASK_SHA256
			+ "terrain_regions=%d\n" % terrain.data.get_regions_active().size()
			+ "anchors=8/8\n"
		)
		print("ASTRA_LAND_MASK_ALIGNMENT_VALIDATION_PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	get_tree().quit(1)


func _validate_anchor_mapping(failures: Array[String]) -> void:
	for anchor: Array in ALIGNMENT_ANCHORS:
		var sample: Vector2 = anchor[1]
		var expected_world: Vector2 = anchor[2]
		# Manifest anchors use continuous source coordinates. Its exported raster
		# sample coordinate is x * 1.6 - 0.5, so +0.5 recovers that position.
		var actual_world := IMPORT_ORIGIN + (sample + Vector2(0.5, 0.5)) * VERTEX_SPACING
		if not actual_world.is_equal_approx(expected_world):
			failures.append(
				"Anchor %s maps to %s; expected %s." % [anchor[0], actual_world, expected_world]
			)


func _save_view(path: String, failures: Array[String]) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.save_png(path) != OK:
		failures.append("Could not save validation image: %s" % path)
