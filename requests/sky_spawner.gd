class_name SkySpawner
extends Node3D
## Drops requests from random points in the sky onto the source device.
## Levels (and later the endless-mode director) control traffic with rate, ramp_to(),
## burst(), get_share and source. The spawner never knows which level it's in.

@export var source: Device ## Where all traffic goes. Changing it is like repointing DNS.
@export var request_scene: PackedScene = preload("res://requests/request.tscn")
@export var rate := 1.0 ## Average requests per second.
@export_range(0.0, 1.0) var get_share := 1.0 ## Fraction that are GETs; the rest are POSTs.
@export var spawn_radius := 2.0 ## Metres around the source.
@export var spawn_height := 3.0 ## Metres above the source. Later: from the room's ceiling.

var spawned := 0

var _next_in := 0.0
var _ramp: Tween


func _process(delta: float) -> void:
	if source == null or rate <= 0.0:
		return
	_next_in -= delta
	while _next_in <= 0.0:
		_spawn()
		_next_in += _interval()


## Changes the rate smoothly over the given number of seconds.
func ramp_to(new_rate: float, seconds: float) -> void:
	if _ramp:
		_ramp.kill()
	_ramp = create_tween()
	_ramp.tween_property(self, "rate", new_rate, seconds)


## Drops a clump of requests at once, for spike events.
func burst(count: int) -> void:
	for i in count:
		_spawn()


## Random gaps with the right average, so traffic clumps the way real traffic does.
## That clumping is why queues form before a server is fully loaded.
func _interval() -> float:
	return -log(1.0 - randf()) / rate


func _spawn() -> void:
	if source == null:
		return
	var req: Request = request_scene.instantiate()
	req.payload = {"id": spawned, "type": "GET" if randf() < get_share else "POST"}
	spawned += 1
	add_child(req)
	var angle := randf() * TAU
	var r := spawn_radius * sqrt(randf()) # sqrt spreads points evenly over the circle.
	req.global_position = source.global_position + Vector3(cos(angle) * r, spawn_height, sin(angle) * r)
	req.origin = req.global_position
	Device.send(req, source)
