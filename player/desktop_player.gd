extends Node3D
## Desktop stand-in for the XR player, for testing without a headset.
## WASD to move, Q/E or the left/right arrows to turn, hold Shift to move faster,
## and hold the right mouse button to look around. The cursor stays free so you
## can still click the store and part cards.

@export var speed := 3.0 ## Metres per second.
@export var sprint_multiplier := 2.0
@export var turn_speed := 90.0 ## Degrees per second for Q/E and the arrow keys.
@export var mouse_sensitivity := 0.25 ## Degrees per pixel while holding the right mouse button.

@onready var _camera: Camera3D = $Camera3D


func _process(delta: float) -> void:
	var turn := _axis(KEY_Q, KEY_E) + _axis(KEY_LEFT, KEY_RIGHT)
	rotate_y(deg_to_rad(turn * turn_speed * delta))

	var input := Vector3(_axis(KEY_D, KEY_A), 0.0, _axis(KEY_S, KEY_W) + _axis(KEY_DOWN, KEY_UP))
	if input == Vector3.ZERO:
		return
	var move := transform.basis * input
	move.y = 0.0 # Walk on the floor, whatever the camera's pitch.
	var current_speed := speed * (sprint_multiplier if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	position += move.normalized() * current_speed * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		_camera.rotation.x = clampf(_camera.rotation.x - deg_to_rad(event.relative.y * mouse_sensitivity), deg_to_rad(-85.0), deg_to_rad(85.0))


## 1 when the first key is held, -1 for the second, 0 for neither or both.
func _axis(positive: Key, negative: Key) -> float:
	return float(Input.is_physical_key_pressed(positive)) - float(Input.is_physical_key_pressed(negative))
