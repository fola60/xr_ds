class_name Server
extends Device
## A backend server. Arriving requests wait in a queue; each CPU core works on one at a time.
## A server that is down, or whose queue is full, drops what arrives.
## Its stats come from its parts: the default (base) server has a 1-core 1 GHz CPU and 1 GB RAM.

signal request_handled(server: Server, payload: Dictionary)

const WORK_PER_REQUEST := 0.4 ## Seconds one request takes on a 1 GHz core.
const QUEUE_PER_GB := 8 ## Queue slots per GB of RAM.

@export var server_name := "Server"
@export var color := Color(0.3, 0.7, 1.0)
@export var cpu: CPUPart = preload("res://parts/cpu_1core_1ghz.tres")
@export var ram: RAMPart = preload("res://parts/ram_1gb.tres")

var process_time: float: ## Seconds to handle one request, from the CPU clock.
	get: return WORK_PER_REQUEST / cpu.clock_ghz
var max_queue: int: ## Requests that can wait before new ones are dropped, from RAM.
	get: return ram.gb * QUEUE_PER_GB

var alive := true
var in_flight := 0 ## Requests sent here that haven't arrived yet.
var queue: Array[Request] = [] ## Waiting for a free core (parked: hidden and still).
var handled := 0
var dropped := 0

var _working: Array[Dictionary] = [] ## Being processed: {"request": Request, "left": seconds}.
var _material := StandardMaterial3D.new()

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _label: Label3D = $Label3D


func _ready() -> void:
	_mesh.material_override = _material
	_refresh()


func _process(delta: float) -> void:
	if not alive:
		return
	var changed := false
	while _working.size() < cpu.cores and not queue.is_empty():
		_working.append({"request": queue.pop_front(), "left": process_time})
		changed = true
	for i in range(_working.size() - 1, -1, -1):
		_working[i].left -= delta
		if _working[i].left <= 0.0:
			var req: Request = _working[i].request
			_working.remove_at(i)
			handled += 1
			request_handled.emit(self, req.payload)
			req.respond() # It flies back as the response; GameState pays when it reaches the sky.
			changed = true
	if changed:
		_refresh()


## Swaps in a new part and returns the one it replaced (for the player's hand or the bin).
func install(part: ServerPart) -> ServerPart:
	var old: ServerPart = null
	if part is CPUPart:
		old = cpu
		cpu = part
	elif part is RAMPart:
		old = ram
		ram = part
	while queue.size() > max_queue: # Less RAM than before: what no longer fits is dropped.
		_drop(queue.pop_back())
	_refresh()
	return old


## Coins per minute for this server's parts.
func parts_upkeep() -> int:
	return cpu.upkeep + ram.upkeep


## Outstanding work: on the way here, waiting, and being processed.
func current_load() -> int:
	return in_flight + queue.size() + _working.size()


func set_alive(value: bool) -> void:
	alive = value
	if not alive:
		for req in queue:
			_drop(req)
		for job in _working:
			_drop(job.request)
		queue.clear()
		_working.clear()
	_refresh()


func receive(req: Request) -> void:
	in_flight -= 1
	if not alive or queue.size() >= max_queue:
		_drop(req)
		_flash_dropped()
	else:
		req.park()
		queue.append(req)
	_refresh()


func _drop(req: Request) -> void:
	dropped += 1
	request_dropped.emit(self, req.payload)
	req.queue_free()


func _refresh() -> void:
	if alive:
		# Get brighter as the queue fills up.
		_material.albedo_color = color.lerp(Color.WHITE, float(queue.size()) / max_queue * 0.6)
	else:
		_material.albedo_color = Color(0.15, 0.15, 0.15)
	_label.text = "%s%s\n%d-core %.1f GHz, %d GB\nqueue %d/%d   working %d/%d\nhandled %d   dropped %d" % [
		server_name, "" if alive else "  (DOWN)",
		cpu.cores, cpu.clock_ghz, ram.gb,
		queue.size(), max_queue, _working.size(), cpu.cores, handled, dropped,
	]


func _flash_dropped() -> void:
	_material.albedo_color = Color.RED
	var tween := create_tween()
	tween.tween_interval(0.1)
	tween.tween_callback(_refresh)
