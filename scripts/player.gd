extends CharacterBody3D
class_name SurvivalPlayer

signal stats_changed(health: float, hunger: float, thirst: float, stamina: float)
signal inventory_changed(inventory: Dictionary)
signal message_requested(text: String)
signal craft_requested

const WALK_SPEED := 4.1
const RUN_SPEED := 6.3
const LOOK_SENSITIVITY := 0.0032
const MAX_INTERACT_DISTANCE := 3.5

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var move_vector := Vector2.ZERO
var run_enabled := false
var health := 100.0
var hunger := 100.0
var thirst := 100.0
var stamina := 100.0
var inventory := {"branch": 0, "stone": 0, "berry": 0}
var _look_touch_id := -1
var _last_look_position := Vector2.ZERO
var _status_timer := 0.0

func _ready() -> void:
	add_to_group("player")
	if not OS.has_feature("android"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_emit_state()

func _physics_process(delta: float) -> void:
	var keyboard := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keyboard.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keyboard.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		keyboard.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		keyboard.y -= 1.0
	var movement := move_vector
	if keyboard.length_squared() > 0.01:
		movement = keyboard.normalized()
	var direction := (global_basis * Vector3(movement.x, 0.0, -movement.y)).normalized()
	var sprinting := run_enabled and stamina > 1.0 and movement.length_squared() > 0.01
	var speed := RUN_SPEED if sprinting else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	if sprinting:
		stamina = maxf(0.0, stamina - 13.0 * delta)
	else:
		stamina = minf(100.0, stamina + 18.0 * delta)
	hunger = maxf(0.0, hunger - 0.055 * delta)
	thirst = maxf(0.0, thirst - 0.11 * delta)
	if hunger <= 0.0 or thirst <= 0.0:
		health = maxf(0.0, health - 2.5 * delta)
	_status_timer += delta
	if _status_timer >= 0.5:
		_status_timer = 0.0
		_emit_state()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_by(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				interact()
			KEY_F:
				eat_berry()
			KEY_B:
				craft_requested.emit()
			KEY_SHIFT:
				run_enabled = not run_enabled
				message_requested.emit("Бег: %s" % ("включён" if run_enabled else "выключен"))
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var viewport_size := get_viewport().get_visible_rect().size
			if event.position.x > viewport_size.x * 0.48 and event.position.y < viewport_size.y * 0.76:
				_look_touch_id = event.index
				_last_look_position = event.position
		elif event.index == _look_touch_id:
			_look_touch_id = -1
	elif event is InputEventScreenDrag and event.index == _look_touch_id:
		var delta_position: Vector2 = event.position - _last_look_position
		_last_look_position = event.position
		look_by(delta_position)

func look_by(delta_position: Vector2) -> void:
	rotate_y(-delta_position.x * LOOK_SENSITIVITY)
	head.rotate_x(-delta_position.y * LOOK_SENSITIVITY)
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(-82.0), deg_to_rad(82.0))

func set_move_vector(value: Vector2) -> void:
	move_vector = value.limit_length(1.0)

func toggle_run() -> void:
	run_enabled = not run_enabled
	message_requested.emit("Бег: %s" % ("включён" if run_enabled else "выключен"))

func interact() -> void:
	var from := camera.global_position
	var to := from + (-camera.global_basis.z * MAX_INTERACT_DISTANCE)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		message_requested.emit("Здесь пока нечего использовать.")
		return
	var target := hit.get("collider") as Area3D
	if target == null or not target.has_meta("kind"):
		message_requested.emit("Здесь пока нечего использовать.")
		return
	match String(target.get_meta("kind")):
		"resource":
			var item_id := String(target.get_meta("item_id"))
			var display_name := String(target.get_meta("display_name"))
			inventory[item_id] = int(inventory.get(item_id, 0)) + int(target.get_meta("amount", 1))
			target.queue_free()
			inventory_changed.emit(inventory.duplicate())
			message_requested.emit("Собрано: " + display_name)
		"water":
			thirst = minf(100.0, thirst + 34.0)
			hunger = minf(100.0, hunger + 1.0)
			stats_changed.emit(health, hunger, thirst, stamina)
			message_requested.emit("Ты напился из ручья.")
		"fire":
			stamina = minf(100.0, stamina + 40.0)
			health = minf(100.0, health + 5.0)
			stats_changed.emit(health, hunger, thirst, stamina)
			message_requested.emit("Перед костром стало теплее.")
		_:
			message_requested.emit("Неизвестный объект.")

func eat_berry() -> void:
	if int(inventory["berry"]) <= 0:
		message_requested.emit("Ягоды закончились. Ищи кусты.")
		return
	inventory["berry"] = int(inventory["berry"]) - 1
	hunger = minf(100.0, hunger + 22.0)
	thirst = minf(100.0, thirst + 4.0)
	inventory_changed.emit(inventory.duplicate())
	stats_changed.emit(health, hunger, thirst, stamina)
	message_requested.emit("Съедена лесная ягода.")

func request_campfire() -> void:
	craft_requested.emit()

func spend_for_campfire() -> bool:
	if int(inventory["branch"]) < 3 or int(inventory["stone"]) < 2:
		message_requested.emit("Для костра нужны 3 ветки и 2 камня.")
		return false
	inventory["branch"] = int(inventory["branch"]) - 3
	inventory["stone"] = int(inventory["stone"]) - 2
	inventory_changed.emit(inventory.duplicate())
	return true

func _emit_state() -> void:
	stats_changed.emit(health, hunger, thirst, stamina)
