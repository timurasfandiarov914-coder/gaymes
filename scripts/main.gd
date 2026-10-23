extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const JOYSTICK_SCRIPT: Script = preload("res://scripts/joystick.gd")
const STREAM_Z := -19.5

var player: SurvivalPlayer
var inventory_label: Label
var objective_label: Label
var objective_title: Label
var message_label: Label
var message_panel: Panel
var _message_timer := 0.0
var _campfire_count := 0
var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _stat_bars: Dictionary = {}
var _stat_values: Dictionary = {}
var _water_ripples: Array[MeshInstance3D] = []
var _world_time := 0.0

func _ready() -> void:
	_rng.seed = 29102026
	_build_materials()
	_build_sky()
	_build_ground()
	_build_river_and_bridge()
	_build_distant_ridge()
	_spawn_forest()
	_spawn_ground_detail()
	_spawn_resources()
	_spawn_player()
	_build_hud()
	_set_message("Дикий край. Осмотрись и собери ресурсы для первого костра.")

func _process(delta: float) -> void:
	_world_time += delta
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			if is_instance_valid(message_label):
				message_label.text = ""
			if is_instance_valid(message_panel):
				message_panel.visible = false
	for index in range(_water_ripples.size()):
		var ripple := _water_ripples[index]
		if is_instance_valid(ripple):
			ripple.position.x += delta * (0.18 + float(index % 4) * 0.05)
			if ripple.position.x > 102.0:
				ripple.position.x = -102.0
			ripple.rotation.y = sin(_world_time * 0.24 + float(index)) * 0.035

func _build_materials() -> void:
	_materials["ground"] = _material(Color("#587344"))
	_materials["grass"] = _material(Color("#708c50"))
	_materials["grass_detail"] = _material(Color("#7c984f"))
	_materials["path"] = _material(Color("#84764f"))
	_materials["sand"] = _material(Color("#a99363"))
	_materials["wood"] = _material(Color("#876044"))
	_materials["bark"] = _material(Color("#604531"))
	_materials["birch"] = _material(Color("#ded8bd"))
	_materials["bark_mark"] = _material(Color("#4b4a3b"))
	_materials["leaf1"] = _material(Color("#315c3c"))
	_materials["leaf2"] = _material(Color("#47744a"))
	_materials["leaf3"] = _material(Color("#63854e"))
	_materials["stone"] = _material(Color("#a2aaa1"))
	_materials["stone_dark"] = _material(Color("#66756c"))
	_materials["mountain1"] = _material(Color("#566b50"))
	_materials["mountain2"] = _material(Color("#71805a"))
	_materials["water"] = _material(Color("#347986"), 0.42, Color("#214f5a"), 0.01)
	_materials["water_glint"] = _material(Color("#a8d2cc", 0.28), 0.48, Color("#548f91"))
	_materials["berry"] = _material(Color("#d84f55"), 0.65, Color("#751b30"))
	_materials["fire"] = _material(Color("#ff9b35"), 0.4, Color("#ff712d"))

func _material(color: Color, roughness: float = 1.0, emission: Color = Color.BLACK, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if color.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
	return mat

func _build_sky() -> void:
	var world := WorldEnvironment.new()
	world.name = "ForestAtmosphere"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#426f88")
	sky_material.sky_horizon_color = Color("#a9c3b8")
	sky_material.sky_curve = 0.18
	sky_material.ground_bottom_color = Color("#42553e")
	sky_material.ground_horizon_color = Color("#96aa8d")
	sky_material.ground_curve = 0.14
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#a8b99f")
	environment.ambient_light_energy = 0.58
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#a8b9a5")
	environment.fog_density = 0.0026
	environment.fog_sky_affect = 0.35
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "LateMorningSun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("#f1dfbd")
	sun.light_energy = 0.88
	sun.shadow_enabled = true
	sun.shadow_blur = 1.35
	sun.shadow_opacity = 0.78
	sun.directional_shadow_max_distance = 85.0
	add_child(sun)

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "ForestFloor"
	body.position.y = -0.5
	var mesh := MeshInstance3D.new()
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(220.0, 1.0, 220.0)
	mesh.mesh = ground_mesh
	mesh.material_override = _materials["ground"]
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = ground_mesh.size
	collision.shape = ground_shape
	body.add_child(collision)
	add_child(body)

	# A softly blended trail ribbon uses vertex colours instead of a heavy terrain shader.
	var path := MeshInstance3D.new()
	path.name = "WornForestTrail"
	var trail_mesh := ArrayMesh.new()
	var trail_vertices := PackedVector3Array()
	var trail_normals := PackedVector3Array()
	var trail_colors := PackedColorArray()
	var trail_indices := PackedInt32Array()
	var trail_rows := 22
	var trail_columns := 11
	var trail_start_z := 0.35
	var trail_end_z := STREAM_Z + 7.1
	var trail_color: Color = (_materials["path"] as StandardMaterial3D).albedo_color
	var ground_color: Color = (_materials["ground"] as StandardMaterial3D).albedo_color
	for row in range(trail_rows):
		var progress := float(row) / float(trail_rows - 1)
		var z := lerpf(trail_start_z, trail_end_z, progress)
		var half_width := 2.05 + sin(progress * PI * 2.0) * 0.16 + sin(progress * PI * 5.0) * 0.07
		var curve_x := sin(progress * PI * 2.0) * 0.24 + sin(progress * PI * 4.0) * 0.06
		var end_fade := clampf(minf(progress / 0.14, (1.0 - progress) / 0.14), 0.0, 1.0)
		end_fade = end_fade * end_fade * (3.0 - 2.0 * end_fade)
		for column in range(trail_columns):
			var lateral := lerpf(-1.0, 1.0, float(column) / float(trail_columns - 1))
			var edge := clampf((absf(lateral) - 0.48) / 0.52, 0.0, 1.0)
			edge = edge * edge * (3.0 - 2.0 * edge)
			var vertex_color := trail_color.lerp(ground_color, edge)
			vertex_color = ground_color.lerp(vertex_color, end_fade)
			trail_vertices.append(Vector3(curve_x + lateral * half_width, 0.014, z))
			trail_normals.append(Vector3.UP)
			trail_colors.append(vertex_color)
	for row in range(trail_rows - 1):
		for column in range(trail_columns - 1):
			var a := row * trail_columns + column
			var b := a + 1
			var c := (row + 1) * trail_columns + column
			var d := c + 1
			trail_indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var trail_arrays: Array = []
	trail_arrays.resize(Mesh.ARRAY_MAX)
	trail_arrays[Mesh.ARRAY_VERTEX] = trail_vertices
	trail_arrays[Mesh.ARRAY_NORMAL] = trail_normals
	trail_arrays[Mesh.ARRAY_COLOR] = trail_colors
	trail_arrays[Mesh.ARRAY_INDEX] = trail_indices
	trail_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trail_arrays)
	var trail_material := StandardMaterial3D.new()
	trail_material.vertex_color_use_as_albedo = true
	trail_material.roughness = 1.0
	path.mesh = trail_mesh
	path.material_override = trail_material
	path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(path)

	# Irregular grassy clearings break up the flat colour without heavy textures.
	for i in range(24):
		var patch := MeshInstance3D.new()
		var patch_mesh := SphereMesh.new()
		patch_mesh.radius = _rng.randf_range(2.0, 5.5)
		patch_mesh.height = patch_mesh.radius * 0.075
		patch_mesh.radial_segments = 7
		patch_mesh.rings = 3
		patch.mesh = patch_mesh
		patch.material_override = _materials["grass"] if i % 3 == 0 else _materials["ground"]
		patch.position = Vector3(_rng.randf_range(-65.0, 65.0), 0.015, _rng.randf_range(-70.0, 70.0))
		patch.scale = Vector3(1.0, 1.0, _rng.randf_range(0.75, 1.65))
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(patch)

func _build_river_and_bridge() -> void:
	# The stream now crosses the player's forward view instead of hiding off to one side.
	for shore_z in [STREAM_Z - 6.1, STREAM_Z + 6.1]:
		var shore := MeshInstance3D.new()
		var shore_mesh := PlaneMesh.new()
		shore_mesh.size = Vector2(220.0, 2.2)
		shore.mesh = shore_mesh
		shore.material_override = _materials["sand"]
		shore.position = Vector3(0.0, 0.018, shore_z)
		add_child(shore)

	var water := MeshInstance3D.new()
	water.name = "ColdForestStream"
	var plane := PlaneMesh.new()
	plane.size = Vector2(220.0, 10.3)
	water.mesh = plane
	water.material_override = _materials["water"]
	water.position = Vector3(0.0, 0.032, STREAM_Z)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	for index in range(28):
		var glint := MeshInstance3D.new()
		var glint_mesh := PlaneMesh.new()
		glint_mesh.size = Vector2(_rng.randf_range(0.45, 1.7), _rng.randf_range(0.025, 0.075))
		glint.mesh = glint_mesh
		glint.material_override = _materials["water_glint"]
		glint.position = Vector3(_rng.randf_range(-96.0, 96.0), 0.052, STREAM_Z + _rng.randf_range(-4.7, 4.7))
		glint.rotation_degrees.y = _rng.randf_range(-12.0, 12.0)
		glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glint)
		_water_ripples.append(glint)

	var water_area := Area3D.new()
	water_area.name = "DrinkableStream"
	water_area.position = Vector3(0.0, 0.8, STREAM_Z)
	water_area.collision_layer = 2
	water_area.collision_mask = 0
	water_area.set_meta("kind", "water")
	var water_shape := CollisionShape3D.new()
	var water_box := BoxShape3D.new()
	water_box.size = Vector3(220.0, 2.4, 10.3)
	water_shape.shape = water_box
	water_area.add_child(water_shape)
	add_child(water_area)

	# A small timber footbridge, with planks, support beams and handrails.
	for plank_index in range(13):
		var z := STREAM_Z - 5.0 + float(plank_index) * 0.82
		var plank := StaticBody3D.new()
		plank.position = Vector3(0.0, 0.22, z)
		var plank_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.1, 0.18, 0.78)
		plank_mesh.mesh = box
		plank_mesh.material_override = _materials["wood"] if plank_index % 3 != 0 else _materials["bark"]
		plank.add_child(plank_mesh)
		var plank_collision := CollisionShape3D.new()
		var plank_shape := BoxShape3D.new()
		plank_shape.size = box.size
		plank_collision.shape = plank_shape
		plank.add_child(plank_collision)
		add_child(plank)

	for side in [-1.0, 1.0]:
		var beam := StaticBody3D.new()
		beam.position = Vector3(side * 1.48, 0.36, STREAM_Z)
		var beam_mesh := MeshInstance3D.new()
		var beam_box := BoxMesh.new()
		beam_box.size = Vector3(0.16, 0.28, 10.3)
		beam_mesh.mesh = beam_box
		beam_mesh.material_override = _materials["wood"]
		beam.add_child(beam_mesh)
		var beam_collision := CollisionShape3D.new()
		var beam_shape := BoxShape3D.new()
		beam_shape.size = beam_box.size
		beam_collision.shape = beam_shape
		beam.add_child(beam_collision)
		add_child(beam)

		for post_index in range(5):
			var post := MeshInstance3D.new()
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.17, 0.9, 0.17)
			post.mesh = post_mesh
			post.material_override = _materials["bark"]
			post.position = Vector3(side * 1.48, 0.62, STREAM_Z - 4.6 + float(post_index) * 2.3)
			add_child(post)

		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.14, 0.14, 10.0)
		rail.mesh = rail_mesh
		rail.material_override = _materials["wood"]
		rail.position = Vector3(side * 1.48, 1.02, STREAM_Z)
		add_child(rail)

func _build_distant_ridge() -> void:
	# Angular low-poly peaks replace the oversized spherical shapes on the horizon.
	var peaks: Array[Vector4] = [
		Vector4(-82.0, -92.0, 29.0, 20.0),
		Vector4(-53.0, -102.0, 36.0, 25.0),
		Vector4(-21.0, -108.0, 24.0, 17.0),
		Vector4(10.0, -111.0, 34.0, 24.0),
		Vector4(44.0, -100.0, 28.0, 20.0),
		Vector4(77.0, -90.0, 31.0, 22.0)
	]
	for index in range(peaks.size()):
		var peak := MeshInstance3D.new()
		var mountain := CylinderMesh.new()
		mountain.top_radius = _rng.randf_range(0.0, 1.7)
		mountain.bottom_radius = peaks[index].z
		mountain.height = peaks[index].w
		mountain.radial_segments = 6 if index % 2 == 0 else 7
		peak.mesh = mountain
		peak.material_override = _materials["mountain1"] if index % 2 == 0 else _materials["mountain2"]
		peak.position = Vector3(peaks[index].x, peaks[index].w * 0.46, peaks[index].y)
		peak.rotation_degrees.y = float(index * 17)
		peak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(peak)

func _spawn_forest() -> void:
	# Trees near the player frame the trail but deliberately leave the centre open.
	var foreground: Array[Vector4] = [
		Vector4(-11.0, -7.0, 0.78, 0.0),
		Vector4(11.0, -8.0, 0.8, 1.0),
		Vector4(-14.0, -12.0, 1.0, 0.0),
		Vector4(15.0, -13.0, 0.95, 2.0),
		Vector4(-8.0, -14.0, 0.96, 1.0),
		Vector4(8.0, -14.5, 1.05, 0.0),
		Vector4(-20.0, -19.0, 1.35, 2.0),
		Vector4(22.0, -20.0, 1.25, 0.0),
		Vector4(-12.0, -27.0, 1.05, 1.0),
		Vector4(13.0, -31.0, 1.1, 0.0),
		Vector4(-30.0, -8.0, 1.4, 0.0),
		Vector4(31.0, -12.0, 1.35, 2.0)
	]
	for tree_data in foreground:
		_spawn_tree(Vector3(tree_data.x, 0.0, tree_data.y), tree_data.z, int(tree_data.w))

	var spawned := 0
	while spawned < 92:
		var x := _rng.randf_range(-76.0, 76.0)
		var z := _rng.randf_range(-84.0, 70.0)
		var clear := true
		if Vector2(x, z).length() < 8.0:
			clear = false
		if absf(x) < 4.6 and z < 0.0 and z > STREAM_Z - 5.5:
			clear = false
		if absf(z - STREAM_Z) < 6.2 and absf(x) < 5.0:
			clear = false
		if clear:
			_spawn_tree(Vector3(x, 0.0, z), _rng.randf_range(0.72, 1.42), -1)
			spawned += 1

func _spawn_tree(pos: Vector3, scale_factor: float, tree_kind: int = -1) -> void:
	var kind := tree_kind if tree_kind >= 0 else _rng.randi_range(0, 2)
	var tree := Node3D.new()
	tree.name = "ForestTree"
	tree.position = pos
	tree.scale = Vector3.ONE * scale_factor
	add_child(tree)

	var trunk_height := _rng.randf_range(2.35, 3.1)
	var trunk_radius := _rng.randf_range(0.16, 0.22)
	var trunk_body := StaticBody3D.new()
	trunk_body.position.y = trunk_height * 0.5
	tree.add_child(trunk_body)

	var trunk_mesh := MeshInstance3D.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = trunk_radius * 0.62
	trunk.bottom_radius = trunk_radius
	trunk.height = trunk_height
	trunk.radial_segments = 6
	trunk_mesh.mesh = trunk
	trunk_mesh.material_override = _materials["birch"] if kind == 2 else _materials["bark"]
	trunk_body.add_child(trunk_mesh)

	var trunk_collision := CollisionShape3D.new()
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = trunk_radius
	trunk_shape.height = trunk_height
	trunk_collision.shape = trunk_shape
	trunk_body.add_child(trunk_collision)

	if kind == 2:
		for band_index in range(4):
			var band := MeshInstance3D.new()
			var band_mesh := CylinderMesh.new()
			band_mesh.top_radius = trunk_radius * 0.68
			band_mesh.bottom_radius = trunk_radius * 0.75
			band_mesh.height = 0.075
			band_mesh.radial_segments = 6
			band.mesh = band_mesh
			band.material_override = _materials["bark_mark"]
			band.position.y = -trunk_height * 0.5 + 0.42 + float(band_index) * 0.52
			trunk_body.add_child(band)

	if kind == 0:
		for crown_index in range(3):
			var crown := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = (1.55 - float(crown_index) * 0.19)
			cone.height = 2.75
			cone.radial_segments = 7
			crown.mesh = cone
			crown.material_override = _materials["leaf1"] if crown_index % 2 == 0 else _materials["leaf2"]
			crown.position.y = trunk_height - 0.45 + float(crown_index) * 1.0
			tree.add_child(crown)
	else:
		var canopy_count := 3 if kind == 1 else 2
		for canopy_index in range(canopy_count):
			var canopy := MeshInstance3D.new()
			var canopy_mesh := SphereMesh.new()
			canopy_mesh.radius = _rng.randf_range(1.25, 1.7)
			canopy_mesh.height = _rng.randf_range(2.2, 2.9)
			canopy_mesh.radial_segments = 7
			canopy_mesh.rings = 4
			canopy.mesh = canopy_mesh
			canopy.material_override = _materials["leaf2"] if canopy_index % 2 == 0 else _materials["leaf3"]
			var side_offset := 0.0 if canopy_index == 0 else (0.72 if canopy_index % 2 == 1 else -0.72)
			canopy.position = Vector3(side_offset, trunk_height + 0.25 + (0.35 if canopy_index > 0 else 0.0), 0.0)
			tree.add_child(canopy)

func _spawn_ground_detail() -> void:
	# MultiMesh keeps the little bits of grass cheap enough for a phone GPU.
	var tuft_mesh := CylinderMesh.new()
	tuft_mesh.top_radius = 0.0
	tuft_mesh.bottom_radius = 0.105
	tuft_mesh.height = 0.42
	tuft_mesh.radial_segments = 3
	var tuft_multi := MultiMesh.new()
	tuft_multi.transform_format = MultiMesh.TRANSFORM_3D
	tuft_multi.mesh = tuft_mesh
	tuft_multi.instance_count = 1800
	for i in range(tuft_multi.instance_count):
		var x := _rng.randf_range(-47.0, 47.0)
		var z := _rng.randf_range(-48.0, 35.0)
		if absf(x) < 3.2 and z < 0.0 and z > STREAM_Z - 4.0:
			x += 5.0 if x >= 0.0 else -5.0
		if absf(z - STREAM_Z) < 5.9:
			z += 7.0 if z >= STREAM_Z else -7.0
		var scale := _rng.randf_range(0.55, 1.4)
		var transform := Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(scale, scale, scale)), Vector3(x, 0.15 * scale, z))
		tuft_multi.set_instance_transform(i, transform)
	var tufts := MultiMeshInstance3D.new()
	tufts.name = "MeadowGrass"
	tufts.multimesh = tuft_multi
	tufts.material_override = _materials["grass_detail"]
	tufts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tufts)

	# Low-poly shrub clusters add variation without one scene node per bush.
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 0.42
	bush_mesh.height = 0.62
	bush_mesh.radial_segments = 6
	bush_mesh.rings = 3
	var bush_multi := MultiMesh.new()
	bush_multi.transform_format = MultiMesh.TRANSFORM_3D
	bush_multi.use_colors = true
	bush_multi.mesh = bush_mesh
	bush_multi.instance_count = 125
	var bush_tints: Array[Color] = [Color("#315c3c"), Color("#47744a"), Color("#63854e")]
	for i in range(bush_multi.instance_count):
		var bush_x := 0.0
		var bush_z := 0.0
		var valid_bush_position := false
		for attempt in range(45):
			bush_x = _rng.randf_range(-43.0, 43.0)
			bush_z = _rng.randf_range(-45.0, 30.0)
			if Vector2(bush_x, bush_z).length() < 8.0:
				continue
			if absf(bush_z - STREAM_Z) < 6.6:
				continue
			if bush_z > -15.0 and bush_z < 1.2 and absf(bush_x) < 3.6:
				continue
			valid_bush_position = true
			break
		if not valid_bush_position:
			continue
		var bush_scale_x := _rng.randf_range(0.65, 1.2)
		var bush_scale_y := _rng.randf_range(0.72, 0.96)
		var bush_scale_z := _rng.randf_range(0.65, 1.25)
		var bush_basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(bush_scale_x, bush_scale_y, bush_scale_z))
		var bush_transform := Transform3D(bush_basis, Vector3(bush_x, 0.31 * bush_scale_y, bush_z))
		bush_multi.set_instance_transform(i, bush_transform)
		bush_multi.set_instance_color(i, bush_tints[_rng.randi_range(0, bush_tints.size() - 1)])
	var bush_instance := MultiMeshInstance3D.new()
	bush_instance.name = "ForestShrubs"
	bush_instance.multimesh = bush_multi
	var bush_material := StandardMaterial3D.new()
	bush_material.vertex_color_use_as_albedo = true
	bush_material.roughness = 1.0
	bush_instance.material_override = bush_material
	bush_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bush_instance)

	var pebble_mesh := SphereMesh.new()
	pebble_mesh.radius = 0.28
	pebble_mesh.height = 0.22
	pebble_mesh.radial_segments = 5
	pebble_mesh.rings = 3
	var pebble_multi := MultiMesh.new()
	pebble_multi.transform_format = MultiMesh.TRANSFORM_3D
	pebble_multi.mesh = pebble_mesh
	pebble_multi.instance_count = 90
	for i in range(pebble_multi.instance_count):
		var x := _rng.randf_range(-38.0, 38.0)
		var z := _rng.randf_range(-34.0, 30.0)
		if absf(x) < 4.0 and z < 0.0 and z > STREAM_Z - 5.0:
			x += 5.0 if x >= 0.0 else -5.0
		var scale := _rng.randf_range(0.22, 0.78)
		pebble_multi.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(scale * 1.3, scale * 0.7, scale)), Vector3(x, 0.06 * scale, z)))
	var pebbles := MultiMeshInstance3D.new()
	pebbles.name = "ScatteredPebbles"
	pebbles.multimesh = pebble_multi
	pebbles.material_override = _materials["stone_dark"]
	pebbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pebbles)

func _spawn_resources() -> void:
	# A few pickups start within sight and walking distance; the rest reward exploring.
	var starter_branches: Array[Vector2] = [
		Vector2(-3.4, -3.8), Vector2(4.2, -5.8), Vector2(-5.3, -8.7),
		Vector2(5.4, -10.2), Vector2(-1.8, -12.4), Vector2(8.2, -4.1)
	]
	var starter_stones: Array[Vector2] = [
		Vector2(3.0, -3.0), Vector2(-6.2, -5.0), Vector2(6.8, -8.6),
		Vector2(-3.5, -13.1), Vector2(10.0, -15.0)
	]
	var starter_berries: Array[Vector2] = [
		Vector2(-7.2, -3.2), Vector2(7.4, -6.2), Vector2(-9.0, -12.0)
	]
	for point in starter_branches:
		_spawn_resource("branch", Vector3(point.x, 0.0, point.y), 1, "Ветка")
	for point in starter_stones:
		_spawn_resource("stone", Vector3(point.x, 0.0, point.y), 1, "Камень")
	for point in starter_berries:
		_spawn_resource("berry", Vector3(point.x, 0.0, point.y), 2, "Лесные ягоды")

	for i in range(24):
		_spawn_resource("branch", _random_ground_position(), 1, "Ветка")
	for i in range(18):
		_spawn_resource("stone", _random_ground_position(), 1, "Камень")
	for i in range(11):
		_spawn_resource("berry", _random_ground_position(), 2, "Лесные ягоды")

func _random_ground_position() -> Vector3:
	var x := 0.0
	var z := 0.0
	for attempt in range(60):
		x = _rng.randf_range(-58.0, 58.0)
		z = _rng.randf_range(-62.0, 56.0)
		var valid := Vector2(x, z).length() > 8.0
		if absf(x) < 4.3 and z < 0.0 and z > STREAM_Z - 5.5:
			valid = false
		if absf(z - STREAM_Z) < 5.8 and absf(x) < 4.0:
			valid = false
		if valid:
			break
	return Vector3(x, 0.0, z)

func _spawn_resource(item_id: String, pos: Vector3, amount: int, display_name: String) -> void:
	var area := Area3D.new()
	area.name = "Pickup_" + item_id
	area.position = pos
	area.collision_layer = 2
	area.collision_mask = 0
	area.set_meta("kind", "resource")
	area.set_meta("item_id", item_id)
	area.set_meta("amount", amount)
	area.set_meta("display_name", display_name)
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.05
	collision.shape = sphere
	collision.position.y = 0.95
	area.add_child(collision)

	if item_id == "branch":
		var mesh := MeshInstance3D.new()
		var stick := CylinderMesh.new()
		stick.top_radius = 0.025
		stick.bottom_radius = 0.06
		stick.height = 1.15
		stick.radial_segments = 5
		mesh.mesh = stick
		mesh.material_override = _materials["wood"]
		mesh.position = Vector3(0.0, 0.18, 0.0)
		mesh.rotation_degrees = Vector3(14.0, _rng.randf_range(0.0, 360.0), 68.0)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		area.add_child(mesh)
	elif item_id == "stone":
		var mesh := MeshInstance3D.new()
		var stone := SphereMesh.new()
		stone.radius = 0.31
		stone.height = 0.4
		stone.radial_segments = 6
		stone.rings = 4
		mesh.mesh = stone
		mesh.material_override = _materials["stone"]
		mesh.position.y = 0.22
		mesh.scale = Vector3(1.0, 0.68, 0.82)
		area.add_child(mesh)
	else:
		var bush := MeshInstance3D.new()
		var bush_mesh := SphereMesh.new()
		bush_mesh.radius = 0.46
		bush_mesh.height = 0.67
		bush_mesh.radial_segments = 7
		bush_mesh.rings = 4
		bush.mesh = bush_mesh
		bush.material_override = _materials["leaf2"]
		bush.position.y = 0.39
		area.add_child(bush)
		for leaf_index in range(3):
			var leaf := MeshInstance3D.new()
			var leaf_mesh := SphereMesh.new()
			leaf_mesh.radius = 0.25
			leaf_mesh.height = 0.36
			leaf_mesh.radial_segments = 6
			leaf_mesh.rings = 3
			leaf.mesh = leaf_mesh
			leaf.material_override = _materials["leaf3"]
			leaf.position = Vector3(cos(float(leaf_index) * TAU / 3.0) * 0.28, 0.42, sin(float(leaf_index) * TAU / 3.0) * 0.28)
			area.add_child(leaf)
		for berry_index in range(5):
			var berry := MeshInstance3D.new()
			var berry_mesh := SphereMesh.new()
			berry_mesh.radius = 0.115
			berry_mesh.height = 0.15
			berry_mesh.radial_segments = 6
			berry_mesh.rings = 3
			berry.mesh = berry_mesh
			berry.material_override = _materials["berry"]
			var angle := float(berry_index) * TAU / 5.0
			berry.position = Vector3(cos(angle) * 0.3, 0.53 + float(berry_index % 2) * 0.16, sin(angle) * 0.3)
			area.add_child(berry)
	add_child(area)

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as SurvivalPlayer
	add_child(player)
	player.global_position = Vector3(0.0, 0.1, 0.0)
	player.stats_changed.connect(_update_stats)
	player.inventory_changed.connect(_update_inventory)
	player.message_requested.connect(_set_message)
	player.craft_requested.connect(_craft_campfire)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Compact translucent panels reserve separate spaces for survival, objective and inventory.
	var stats_panel := _create_panel(root, "SurvivalPanel")
	stats_panel.position = Vector2(20.0, 18.0)
	stats_panel.size = Vector2(360.0, 154.0)
	var stats_heading := _make_label(stats_panel, "СОСТОЯНИЕ", Vector2(15.0, 7.0), Vector2(325.0, 20.0), 14, Color("#c4d8b3"))
	stats_heading.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	stats_heading.add_theme_constant_override("shadow_offset_x", 1)
	stats_heading.add_theme_constant_override("shadow_offset_y", 1)
	_add_stat_row(stats_panel, "health", "ЗДОРОВЬЕ", 31.0, Color("#d66c62"))
	_add_stat_row(stats_panel, "hunger", "СЫТОСТЬ", 59.0, Color("#e1b45d"))
	_add_stat_row(stats_panel, "thirst", "ЖАЖДА", 87.0, Color("#70c4d2"))
	_add_stat_row(stats_panel, "stamina", "ВЫНОСЛИВОСТЬ", 115.0, Color("#9acb72"))

	var objective_panel := _create_panel(root, "ObjectivePanel")
	objective_panel.anchor_left = 0.5
	objective_panel.anchor_right = 0.5
	objective_panel.offset_left = -210.0
	objective_panel.offset_right = 210.0
	objective_panel.offset_top = 18.0
	objective_panel.offset_bottom = 112.0
	objective_title = _make_label(objective_panel, "ЗАДАЧА 01  /  ПЕРВЫЙ ЛАГЕРЬ", Vector2(17.0, 8.0), Vector2(386.0, 22.0), 13, Color("#e4c98d"))
	objective_label = _make_label(objective_panel, "Собери 3 ветки и 2 камня,\nзатем поставь костёр", Vector2(17.0, 32.0), Vector2(386.0, 52.0), 17, Color("#f3f2e4"))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var inventory_panel := _create_panel(root, "InventoryPanel")
	inventory_panel.anchor_left = 1.0
	inventory_panel.anchor_right = 1.0
	inventory_panel.offset_left = -286.0
	inventory_panel.offset_right = -20.0
	inventory_panel.offset_top = 18.0
	inventory_panel.offset_bottom = 112.0
	var inventory_heading := _make_label(inventory_panel, "РЮКЗАК", Vector2(15.0, 8.0), Vector2(235.0, 22.0), 13, Color("#c4d8b3"))
	inventory_label = _make_label(inventory_panel, "", Vector2(15.0, 32.0), Vector2(238.0, 52.0), 15, Color("#f3f2e4"))
	inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	message_panel = _create_panel(root, "MessagePanel")
	message_panel.anchor_left = 0.5
	message_panel.anchor_right = 0.5
	message_panel.anchor_top = 0.68
	message_panel.anchor_bottom = 0.68
	message_panel.offset_left = -275.0
	message_panel.offset_right = 275.0
	message_panel.offset_top = -38.0
	message_panel.offset_bottom = 38.0
	message_panel.visible = false
	message_label = _make_label(message_panel, "", Vector2(18.0, 8.0), Vector2(514.0, 60.0), 18, Color("#fff5dc"))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_add_crosshair(root)

	var joystick: Control = Control.new()
	joystick.name = "MoveJoystick"
	joystick.anchor_left = 0.0
	joystick.anchor_top = 0.36
	joystick.anchor_right = 0.44
	joystick.anchor_bottom = 1.0
	joystick.set_script(JOYSTICK_SCRIPT)
	joystick.offset_left = 0.0
	joystick.offset_top = 0.0
	joystick.offset_right = 0.0
	joystick.offset_bottom = 0.0
	joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(joystick)
	joystick.vector_changed.connect(player.set_move_vector)

	_add_action_button(root, "БЕГ", 20.0, player.toggle_run)
	_add_action_button(root, "ЯГОДЫ", 140.0, player.eat_berry)
	_add_action_button(root, "ВЗЯТЬ", 260.0, player.interact)
	_add_action_button(root, "КОСТЁР", 380.0, player.request_campfire)
	_update_stats(100.0, 100.0, 100.0, 100.0)
	_update_inventory(player.inventory)

func _create_panel(parent: Control, panel_name: String) -> Panel:
	var panel := Panel.new()
	panel.name = panel_name
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#122a25", 0.84)
	style.border_color = Color("#9dbb92", 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(15)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.20)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 2.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel

func _make_label(parent: Control, text_value: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.3))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _add_stat_row(parent: Panel, stat_key: String, caption: String, y: float, tint: Color) -> void:
	var name_label := _make_label(parent, caption, Vector2(14.0, y), Vector2(104.0, 20.0), 13, Color("#dfe6d7"))
	var bar := ProgressBar.new()
	bar.position = Vector2(122.0, y + 7.0)
	bar.size = Vector2(164.0, 8.0)
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#2b4137")
	background.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	var value_label := _make_label(parent, "100", Vector2(294.0, y), Vector2(47.0, 20.0), 14, Color("#f4f1e4"))
	_stat_bars[stat_key] = bar
	_stat_values[stat_key] = value_label

func _add_crosshair(parent: Control) -> void:
	var horizontal := ColorRect.new()
	horizontal.position = Vector2(-5.0, -1.0)
	horizontal.size = Vector2(10.0, 2.0)
	horizontal.color = Color("#f2f0dc", 0.82)
	horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vertical := ColorRect.new()
	vertical.position = Vector2(-1.0, -5.0)
	vertical.size = Vector2(2.0, 10.0)
	vertical.color = Color("#f2f0dc", 0.82)
	vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crosshair := Control.new()
	crosshair.name = "AimReticle"
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = 0.0
	crosshair.offset_right = 0.0
	crosshair.offset_top = 0.0
	crosshair.offset_bottom = 0.0
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(crosshair)
	crosshair.add_child(horizontal)
	crosshair.add_child(vertical)

func _add_action_button(parent: Control, caption: String, right_margin: float, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_right = -right_margin
	button.offset_left = -(right_margin + 108.0)
	button.offset_top = -96.0
	button.offset_bottom = -22.0
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("#f5f4e8"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#1c342a"))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#17372e", 0.94)
	normal.set_corner_radius_all(14)
	normal.set_border_width_all(1)
	normal.border_color = Color("#b7cda4", 0.78)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.2)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0.0, 2.0)
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#315642", 0.98)
	hover.border_color = Color("#d3e7b5")
	button.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#c0d89b")
	pressed.border_color = Color("#e0ecc9")
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(callback)
	parent.add_child(button)

func _update_stats(hp: float, food: float, water: float, energy: float) -> void:
	_set_stat("health", hp)
	_set_stat("hunger", food)
	_set_stat("thirst", water)
	_set_stat("stamina", energy)

func _set_stat(stat_key: String, value: float) -> void:
	if _stat_bars.has(stat_key):
		var bar := _stat_bars[stat_key] as ProgressBar
		bar.value = clampf(value, 0.0, 100.0)
	if _stat_values.has(stat_key):
		var label := _stat_values[stat_key] as Label
		label.text = str(roundi(value))

func _update_inventory(inv: Dictionary) -> void:
	if is_instance_valid(inventory_label):
		inventory_label.text = "Ветки   %d\nКамни   %d     Ягоды   %d" % [int(inv.get("branch", 0)), int(inv.get("stone", 0)), int(inv.get("berry", 0))]

func _set_message(text_value: String) -> void:
	if is_instance_valid(message_label):
		message_label.text = text_value
	if is_instance_valid(message_panel):
		message_panel.visible = text_value != ""
	_message_timer = 3.2

func _craft_campfire() -> void:
	if not player.spend_for_campfire():
		return
	if _campfire_count >= 3:
		_set_message("В этой демоверсии можно поставить до 3 костров.")
		player.inventory["branch"] = int(player.inventory["branch"]) + 3
		player.inventory["stone"] = int(player.inventory["stone"]) + 2
		player.inventory_changed.emit(player.inventory.duplicate())
		return
	_campfire_count += 1
	var place_position := player.global_position - player.global_basis.z * 2.4
	place_position.y = 0.0
	_spawn_campfire(place_position)
	objective_title.text = "ЛАГЕРЬ  /  КОСТЁР %d ИЗ 3" % _campfire_count
	objective_label.text = "Первый огонь горит.\nМожно исследовать долину дальше." if _campfire_count == 1 else "Лагерь расширяется.\nКостров поставлено: %d/3" % _campfire_count
	_set_message("Костёр готов. Посмотри на него и нажми «ВЗЯТЬ», чтобы согреться.")

func _spawn_campfire(pos: Vector3) -> void:
	var fire_area := Area3D.new()
	fire_area.name = "Campfire"
	fire_area.position = pos
	fire_area.collision_layer = 2
	fire_area.collision_mask = 0
	fire_area.set_meta("kind", "fire")
	var collider := CollisionShape3D.new()
	var radius := SphereShape3D.new()
	radius.radius = 1.3
	collider.shape = radius
	collider.position.y = 0.6
	fire_area.add_child(collider)
	for angle in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
		var log := MeshInstance3D.new()
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = 0.09
		log_mesh.bottom_radius = 0.11
		log_mesh.height = 0.9
		log_mesh.radial_segments = 5
		log.mesh = log_mesh
		log.material_override = _materials["wood"]
		log.position = Vector3(cos(angle) * 0.16, 0.13, sin(angle) * 0.16)
		log.rotation.z = PI / 2.0
		log.rotation.y = angle
		fire_area.add_child(log)
	var flame := MeshInstance3D.new()
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 0.0
	flame_mesh.bottom_radius = 0.24
	flame_mesh.height = 0.8
	flame_mesh.radial_segments = 5
	flame.mesh = flame_mesh
	flame.material_override = _materials["fire"]
	flame.position.y = 0.65
	fire_area.add_child(flame)
	var light := OmniLight3D.new()
	light.position.y = 0.8
	light.light_color = Color("#ff9b4b")
	light.light_energy = 1.1
	light.omni_range = 6.0
	light.shadow_enabled = false
	fire_area.add_child(light)
	add_child(fire_area)
