extends Control

signal vector_changed(value: Vector2)

var _active_touch := -1
var _value := Vector2.ZERO
var _radius := 62.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)

func _base_center() -> Vector2:
	return Vector2(minf(124.0, size.x * 0.30), size.y - 124.0)

func _draw() -> void:
	var center := _base_center()
	draw_circle(center, _radius + 8.0, Color(0.05, 0.10, 0.08, 0.34))
	draw_arc(center, _radius, 0.0, TAU, 48, Color(0.76, 0.84, 0.70, 0.62), 3.0, true)
	draw_circle(center + _value * _radius, 29.0, Color(0.87, 0.91, 0.78, 0.88))
	draw_arc(center + _value * _radius, 29.0, 0.0, TAU, 36, Color(0.12, 0.20, 0.14, 0.85), 2.0, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_touch == -1 and event.position.distance_to(_base_center()) <= _radius * 1.8:
			_active_touch = event.index
			_update_from_position(event.position)
			accept_event()
		elif not event.pressed and event.index == _active_touch:
			_active_touch = -1
			_set_value(Vector2.ZERO)
			accept_event()
	elif event is InputEventScreenDrag and event.index == _active_touch:
		_update_from_position(event.position)
		accept_event()

func _update_from_position(pos: Vector2) -> void:
	var offset := pos - _base_center()
	_set_value(offset.limit_length(_radius) / _radius)

func _set_value(value: Vector2) -> void:
	_value = value
	vector_changed.emit(Vector2(_value.x, -_value.y))
	queue_redraw()
