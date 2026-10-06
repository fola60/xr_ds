extends Node3D
## Sends a request to target every time the Timer fires.

@export var request_scene: PackedScene
@export var target: Device


func _on_timer_timeout() -> void:
	var req: Request = request_scene.instantiate()
	add_child(req)
	req.origin = global_position # Responses come back to the client.
	Device.send(req, target)
