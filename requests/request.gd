class_name Request
extends Area3D
## One request travelling to a Device. On arrival it hands itself to the device's receive().
## When a server finishes it, the same object becomes the response and flies back the way
## it came (through every device it passed) to where it appeared in the sky.
##
## Looks: GETs are blue spheres, POSTs orange cubes. Size shows which way the data goes:
## a GET is small going in and large coming back; a POST is large going in, a small ack back.

signal response_returned(payload: Dictionary) ## Reached the sky; the round trip is complete.

const LOOKS := {
	"GET": {"color": Color(0.3, 0.65, 1.0), "size": 0.16, "shape": "sphere"},
	"POST": {"color": Color(1.0, 0.55, 0.15), "size": 0.24, "shape": "box"},
	"GET_response": {"color": Color(0.6, 0.85, 1.0), "size": 0.26, "shape": "sphere"},
	"POST_response": {"color": Color(1.0, 0.8, 0.5), "size": 0.12, "shape": "box"},
}

static var _meshes := {} ## Built once per look and shared by every request.
static var _materials := {}

@export var speed := 3.0
var target: Device
var payload := {"id": 0, "type": "GET"}
var origin := Vector3.ZERO ## Where it appeared; the response flies back here.
var hops: Array[Device] = [] ## Every device it arrived at, in order. hops[0] is the source.
var is_response := false

var _return_path: Array[Device] = [] ## Devices still to pass through on the way back.


func _ready() -> void:
	_apply_look()


func _process(delta: float) -> void:
	if is_response:
		_process_response(delta)
		return
	if not is_instance_valid(target):
		queue_free()
		return
	if _move_toward(target.global_position, delta):
		# Latency starts when the request first reaches a device (the source), not when it
		# appears: how far it fell isn't something the player can fix.
		if not payload.has("sent_at"):
			payload["sent_at"] = _now()
		hops.append(target)
		var device := target
		target = null # Arrive once; the device decides what happens next.
		device.receive(self)


## Hides it and stops it moving while it waits in a server's queue.
func park() -> void:
	visible = false
	set_process(false)


## Turns it into the response and starts it back along the path it came.
func respond() -> void:
	is_response = true
	visible = true
	set_process(true)
	_return_path = hops.duplicate()
	_return_path.pop_back() # The device that answered; we're already there.
	_return_path.reverse()
	if _return_path.is_empty():
		_mark_finished() # The answering device was the source.
	_apply_look()


func _process_response(delta: float) -> void:
	while not _return_path.is_empty() and not is_instance_valid(_return_path[0]):
		_return_path.pop_front() # A device on the way back was sold; skip it.
	var destination := origin if _return_path.is_empty() else _return_path[0].global_position
	if not _move_toward(destination, delta):
		return
	if _return_path.is_empty():
		_mark_finished() # In case the source vanished before we passed it.
		response_returned.emit(payload)
		queue_free()
	elif _return_path.pop_front() == hops[0]:
		_mark_finished()


## Latency stops when the response leaves the source, the edge of the player's system.
## The flight back up varies with spawn position, like the fall, so it doesn't count.
func _mark_finished() -> void:
	if not payload.has("finished_at"):
		payload["finished_at"] = _now()


## Moves one step toward a point; returns true on arrival.
func _move_toward(point: Vector3, delta: float) -> bool:
	var to := point - global_position
	var step := speed * delta
	if to.length() <= step:
		global_position = point
		return true
	global_position += to.normalized() * step
	return false


func _apply_look() -> void:
	var key: String = payload.get("type", "GET") + ("_response" if is_response else "")
	if key not in _meshes:
		_build_look(key)
	$MeshInstance3D.mesh = _meshes[key]
	$MeshInstance3D.material_override = _materials[key]


static func _build_look(key: String) -> void:
	var look: Dictionary = LOOKS.get(key, LOOKS["GET"])
	var size: float = look.size
	if look.shape == "box":
		var box := BoxMesh.new()
		box.size = Vector3.ONE * size
		_meshes[key] = box
	else:
		var sphere := SphereMesh.new()
		sphere.radius = size / 2.0
		sphere.height = size
		_meshes[key] = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = look.color
	mat.emission_enabled = true
	mat.emission = look.color * 0.6
	_materials[key] = mat


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
