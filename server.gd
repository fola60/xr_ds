class_name Server
extends Device
## A backend server. Arriving requests join a queue and are handled one at a time.
## A server that is down, or whose queue is full, drops what arrives.

signal request_handled(server: Server, payload: Dictionary)

@export var server_name := "Server"
@export var color := Color(0.3, 0.7, 1.0)
@export var process_time := 0.4 ## Seconds to handle one request.
@export var max_queue := 8 ## Requests that arrive beyond this are dropped.

var alive := true
var in_flight := 0 ## Requests sent here that haven't arrived yet.
var queue: Array[Dictionary] = []
var handled := 0
var dropped := 0

var _work_timer := 0.0
var _material := StandardMaterial3D.new()

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _label: Label3D = $Label3D


func _ready() -> void:
	_mesh.material_override = _material
	_refresh()


func _process(delta: float) -> void:
	if not alive or queue.is_empty():
		_work_timer = 0.0
		return
	_work_timer += delta
	if _work_timer >= process_time:
		_work_timer -= process_time
		var payload: Dictionary = queue.pop_front()
		handled += 1
		request_handled.emit(self, payload)
		_refresh()


## Outstanding work: requests on the way here plus requests waiting in the queue.
func current_load() -> int:
	return in_flight + queue.size()


func set_alive(value: bool) -> void:
	alive = value
	if not alive:
		dropped += queue.size()
		queue.clear()
	_refresh()


func receive(req: Request) -> void:
	in_flight -= 1
	var payload: Dictionary = req.payload
	req.queue_free()

	if not alive or queue.size() >= max_queue:
		dropped += 1
		request_dropped.emit(self, payload)
		_flash_dropped()
	else:
		queue.append(payload)
	_refresh()


func _refresh() -> void:
	if alive:
		# Get brighter as the queue fills up.
		_material.albedo_color = color.lerp(Color.WHITE, float(queue.size()) / max_queue * 0.6)
	else:
		_material.albedo_color = Color(0.15, 0.15, 0.15)
	_label.text = "%s%s\nqueue %d/%d   in flight %d\nhandled %d   dropped %d" % [
		server_name, "" if alive else "  (DOWN)",
		queue.size(), max_queue, in_flight, handled, dropped,
	]


func _flash_dropped() -> void:
	_material.albedo_color = Color.RED
	var tween := create_tween()
	tween.tween_interval(0.1)
	tween.tween_callback(_refresh)
