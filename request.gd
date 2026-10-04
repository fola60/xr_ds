class_name Request
extends Area3D
## One request travelling to a Device. On arrival it hands itself to the device's receive().

@export var speed := 3.0
var target: Device
var payload := {"id": 0, "type": "GET"}


func _ready() -> void:
	payload["sent_at"] = Time.get_ticks_msec() / 1000.0 # GameState measures latency from here.


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	var to := target.global_position - global_position
	var step := speed * delta
	if to.length() <= step:
		global_position = target.global_position
		var device := target
		target = null # Arrive once; the device decides what happens next.
		device.receive(self)
	else:
		global_position += to.normalized() * step


func set_color(color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	$MeshInstance3D.material_override = mat
