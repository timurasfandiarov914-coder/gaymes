extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const JOYSTICK_SCRIPT: Script = preload("res://scripts/joystick.gd")

var player: SurvivalPlayer
var stats_label: Label
var inventory_label: Label
var objective_label: Label
var message_label: Label
var _message_timer := 0.0
var _campfire_count := 0
var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}

func _ready() -> void:
	_rng.seed = 29102026
	_build_materials()
	_build_sky()
	_build_ground()
	_build_river_and_bridge()
	_build_distant_ridge()
	_spawn_forest()
	_spawn_resources()
	_spawn_player()
	_build_hud()
	_set_message("Дикий край. Собери ресурсы и поставь первый костёр.")

func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0 and is_instance_valid(message_label):
			message_label.text = ""

func _build_materials() -> void:
	_materials["ground"] = _material(Color("#627c4a"))
	_materials["grass"] = _material(Color("#7c9657"))
	_materials["wood"] = _material(Color("#71503a"))
	_materials["bark"] = _material(Color("#59412f"))
	_materials["leaf1"] = _material(Color("#315c3c"))
	_materials["leaf2"] = _material(Color("#47744a"))
	_materials["stone"] = _material(Color("#858c89"))
	_materials["stone_dark"] = _material(Color("#59645e"))
	_materials["water"] = _material(Color("#5aabb8"), 0.22)
	_materials["berry"] = _material(Color("#c34e4b"))
	_materials["fire"] = _material(Color("#ff9b35"), 0.4, Color("#ff712d"))

func _material(color: Color, roughness: float = 1.0, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
	return mat

func _build_sky() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#56819a")
	sky_material.sky_horizon_color = Color("#d6d9be")
	sky_material.ground_bottom_color = Color("#45594b")
	sky_material.ground_horizon_color = Color("#a4b39a")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b9c8aa")
	environment.ambient_light_energy = 0.72
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47.0, -28.0, 0.0)
	sun.light_color = Color("#ffe5bd")
	sun.light_energy = 1.15
	sun.shadow_enabled = false
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
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = ground_mesh.size
	collision.shape = ground_shape
	body.add_child(collision)
	add_child(body)
	for i in range(28):
		var patch := MeshInstance3D.new()
		var patch_mesh := SphereMesh.new()
		patch_mesh.radius = _rng.randf_range(1.8, 5.0)
		patch_mesh.height = patch_mesh.radius * 0.55
		patch.mesh = patch_mesh
		patch.material_override = _materials["grass"] if i % 3 == 0 else _materials["ground"]
		patch.position = Vector3(_rng.randf_range(-95, 95), -0.1, _rng.randf_range(-95, 95))
		patch.scale = Vector3(1.0, 0.22, _rng.randf_range(0.7, 1.5))
		add_child(patch)

func _build_river_and_bridge() -> void:
	var water := MeshInstance3D.new()
	water.name = "ColdStreamVisual"
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 190.0)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	water.mesh = plane
	water.material_override = _materials["water"]
	water.position = Vector3(15.0, 0.035, 0.0)
	add_child(water)

	var water_area := Area3D.new()
	water_area.name = "DrinkableStream"
	water_area.position = Vector3(15.0, 0.8, 0.0)
	water_area.collision_layer = 2
	water_area.collision_mask = 0
	water_area.set_meta("kind", "water")
	var water_shape := CollisionShape3D.new()
	var water_box := BoxShape3D.new()
	water_box.size = Vector3(12.0, 2.4, 190.0)
	water_shape.shape = water_box
	water_area.add_child(water_shape)
	add_child(water_area)

	for plank_index in range(9):
		var z := -10.0 + float(plank_index) * 0.75
		var plank := StaticBody3D.new()
		plank.position = Vector3(15.0, 0.3, z)
		var plank_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(15.0, 0.22, 0.65)
		plank_mesh.mesh = box
		plank_mesh.material_override = _materials["wood"]
		plank.add_child(plank_mesh)
		var plank_collision := CollisionShape3D.new()
		var plank_shape := BoxShape3D.new()
		plank_shape.size = box.size
		plank_collision.shape = plank_shape
		plank.add_child(plank_collision)
		add_child(plank)

func _build_distant_ridge() -> void:
	for i in range(12):
		var ridge := MeshInstance3D.new()
		var rock := SphereMesh.new()
		rock.radius = _rng.randf_range(8.0, 15.0)
		rock.height = rock.radius * 1.45
		ridge.mesh = rock
		ridge.material_override = _materials["stone_dark"]
		var side := -1.0 if i % 2 == 0 else 1.0
		ridge.position = Vector3(side * _rng.randf_range(80, 103), rock.radius * 0.5 - 0.5, _rng.randf_range(-85, 85))
		ridge.scale = Vector3(1.1, 1.4, _rng.randf_range(0.75, 1.25))
		add_child(ridge)

func _spawn_forest() -> void:
	for i in range(64):
		var x := _rng.randf_range(-92.0, 92.0)
		var z := _rng.randf_range(-92.0, 92.0)
		if Vector2(x, z).length() < 10.0 or absf(x - 15.0) < 10.0:
			continue
		_spawn_tree(Vector3(x, 0.0, z), _rng.randf_range(0.75, 1.3))

func _spawn_tree(pos: Vector3, scale_factor: float) -> void:
	var trunk := StaticBody3D.new()
	trunk.position = pos
	var trunk_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.16
	cylinder.bottom_radius = 0.28
	cylinder.height = 2.25
	cylinder.radial_segments = 6
	trunk_mesh.mesh = cylinder
	trunk_mesh.material_override = _materials["bark"]
	trunk_mesh.position.y = 1.12 * scale_factor
	trunk_mesh.scale = Vector3.ONE * scale_factor
	trunk.add_child(trunk_mesh)
	var trunk_collision := CollisionShape3D.new()
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.27 * scale_factor
	trunk_shape.height = 2.2 * scale_factor
	trunk_collision.shape = trunk_shape
	trunk_collision.position.y = 1.1 * scale_factor
	trunk.add_child(trunk_collision)
	add_child(trunk)
	for crown_index in range(3):
		var crown := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = (1.25 - float(crown_index) * 0.12) * scale_factor
		cone.height = 2.1 * scale_factor
		cone.radial_segments = 6
		crown.mesh = cone
		crown.material_override = _materials["leaf1"] if crown_index % 2 == 0 else _materials["leaf2"]
		crown.position = pos + Vector3(0.0, (2.3 + float(crown_index) * 0.9) * scale_factor, 0.0)
		add_child(crown)

func _spawn_resources() -> void:
	for i in range(30):
		_spawn_resource("branch", _random_ground_position(), 1, "Ветка")
	for i in range(22):
		_spawn_resource("stone", _random_ground_position(), 1, "Камень")
	for i in range(14):
		_spawn_resource("berry", _random_ground_position(), 2, "Лесные ягоды")

func _random_ground_position() -> Vector3:
	var x := 0.0
	var z := 0.0
	for attempt in range(30):
		x = _rng.randf_range(-82.0, 82.0)
		z = _rng.randf_range(-82.0, 82.0)
		if Vector2(x, z).length() > 9.0 and absf(x - 15.0) > 9.0:
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
	sphere.radius = 0.9
	collision.shape = sphere
	collision.position.y = 0.65
	area.add_child(collision)

	if item_id == "branch":
		var mesh := MeshInstance3D.new()
		var stick := CylinderMesh.new()
		stick.top_radius = 0.035
		stick.bottom_radius = 0.055
		stick.height = 0.95
		stick.radial_segments = 5
		mesh.mesh = stick
		mesh.material_override = _materials["wood"]
		mesh.position = Vector3(0.0, 0.22, 0.0)
		mesh.rotation_degrees.z = 68.0
		area.add_child(mesh)
	elif item_id == "stone":
		var mesh := MeshInstance3D.new()
		var stone := SphereMesh.new()
		stone.radius = 0.28
		stone.height = 0.42
		mesh.mesh = stone
		mesh.material_override = _materials["stone"]
		mesh.position.y = 0.22
		mesh.scale = Vector3(1.0, 0.65, 0.8)
		area.add_child(mesh)
	else:
		var bush := MeshInstance3D.new()
		var bush_mesh := SphereMesh.new()
		bush_mesh.radius = 0.4
		bush_mesh.height = 0.6
		bush.mesh = bush_mesh
		bush.material_override = _materials["leaf2"]
		bush.position.y = 0.38
		area.add_child(bush)
		for berry_index in range(4):
			var berry := MeshInstance3D.new()
			var berry_mesh := SphereMesh.new()
			berry_mesh.radius = 0.12
			berry_mesh.height = 0.16
			berry.mesh = berry_mesh
			berry.material_override = _materials["berry"]
			berry.position = Vector3(cos(float(berry_index) * TAU / 4.0) * 0.26, 0.54 + float(berry_index % 2) * 0.14, sin(float(berry_index) * TAU / 4.0) * 0.26)
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

	stats_label = Label.new()
	stats_label.position = Vector2(24.0, 16.0)
	stats_label.size = Vector2(610.0, 44.0)
	stats_label.add_theme_font_size_override("font_size", 23)
	stats_label.add_theme_color_override("font_color", Color("#f5f4dc"))
	root.add_child(stats_label)

	inventory_label = Label.new()
	inventory_label.position = Vector2(24.0, 55.0)
	inventory_label.size = Vector2(610.0, 40.0)
	inventory_label.add_theme_font_size_override("font_size", 20)
	inventory_label.add_theme_color_override("font_color", Color("#e1e7cf"))
	root.add_child(inventory_label)

	objective_label = Label.new()
	objective_label.anchor_left = 0.5
	objective_label.anchor_right = 0.5
	objective_label.offset_left = -250.0
	objective_label.offset_right = 250.0
	objective_label.offset_top = 18.0
	objective_label.offset_bottom = 64.0
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 22)
	objective_label.add_theme_color_override("font_color", Color("#fff4ce"))
	objective_label.text = "ЦЕЛЬ: собери 3 ветки и 2 камня, поставь костёр"
	root.add_child(objective_label)

	message_label = Label.new()
	message_label.anchor_left = 0.5
	message_label.anchor_right = 0.5
	message_label.anchor_top = 0.68
	message_label.anchor_bottom = 0.68
	message_label.offset_left = -300.0
	message_label.offset_right = 300.0
	message_label.offset_top = -30.0
	message_label.offset_bottom = 30.0
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 25)
	message_label.add_theme_color_override("font_color", Color("#fff4ce"))
	root.add_child(message_label)

	var joystick: Variant = Control.new()
	joystick.name = "MoveJoystick"
	joystick.anchor_left = 0.0
	joystick.anchor_top = 0.36
	joystick.anchor_right = 0.44
	joystick.anchor_bottom = 1.0
	joystick.set_script(JOYSTICK_SCRIPT)
	joystick_script_setup(joystick)
	root.add_child(joystick)
	joystick.vector_changed.connect(player.set_move_vector)

	_add_action_button(root, "БЕГ", 16.0, player.toggle_run)
	_add_action_button(root, "ЯГОДЫ", 128.0, player.eat_berry)
	_add_action_button(root, "ВЗЯТЬ", 240.0, player.interact)
	_add_action_button(root, "КОСТЁР", 352.0, player.request_campfire)
	_update_stats(100.0, 100.0, 100.0, 100.0)
	_update_inventory(player.inventory)

func joystick_script_setup(control: Control) -> void:
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	control.mouse_filter = Control.MOUSE_FILTER_STOP

func _add_action_button(parent: Control, caption: String, right_margin: float, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_right = -right_margin
	button.offset_left = -(right_margin + 100.0)
	button.offset_top = -100.0
	button.offset_bottom = -24.0
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color("#f8f5e6"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#243f35")
	normal.set_corner_radius_all(9)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = Color("#97b08a")
	button.add_theme_stylebox_override("normal", normal)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color("#456b4d")
	pressed.set_corner_radius_all(9)
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(callback)
	parent.add_child(button)

func _update_stats(hp: float, food: float, water: float, energy: float) -> void:
	if is_instance_valid(stats_label):
		stats_label.text = "ЗДОРОВЬЕ %d   СЫТОСТЬ %d   ЖАЖДА %d   СИЛЫ %d" % [roundi(hp), roundi(food), roundi(water), roundi(energy)]

func _update_inventory(inv: Dictionary) -> void:
	if is_instance_valid(inventory_label):
		inventory_label.text = "Ветки: %d   Камни: %d   Ягоды: %d" % [int(inv.get("branch", 0)), int(inv.get("stone", 0)), int(inv.get("berry", 0))]

func _set_message(text: String) -> void:
	if is_instance_valid(message_label):
		message_label.text = text
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
	objective_label.text = "ЦЕЛЬ ВЫПОЛНЕНА: лагерь готов" if _campfire_count == 1 else "ЛАГЕРЬ: костров поставлено %d/3" % _campfire_count
	_set_message("Костёр готов. Нажми ВЗЯТЬ, глядя на него, чтобы согреться.")

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
