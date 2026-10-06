class_name LoadBalancer
extends Device
## Forwards each arriving request to one of its downstream devices.
## With nothing connected, requests are dropped.

enum Strategy { ROUND_ROBIN, LEAST_CONNECTIONS }
const STRATEGY_NAMES := ["round robin", "least connections"]

@export var strategy := Strategy.ROUND_ROBIN

var forwarded := 0
var dropped := 0

var _next := 0 ## Round robin position.

@onready var _label: Label3D = $Label3D


func _ready() -> void:
	connections_changed.connect(_refresh)
	_refresh()


func receive(request: Request) -> void:
	var to := _pick()
	if to == null:
		dropped += 1
		request_dropped.emit(self, request.payload)
		request.queue_free()
	else:
		forwarded += 1
		send(request, to)
	_refresh()


func _pick() -> Device:
	# Skip empty or deleted entries, so a broken reference can't swallow traffic.
	var targets: Array[Device] = []
	for d in downstream:
		if is_instance_valid(d):
			targets.append(d)
	if targets.is_empty():
		return null
	match strategy:
		Strategy.LEAST_CONNECTIONS:
			var best: Device = targets[0]
			for d in targets:
				if _load_of(d) < _load_of(best):
					best = d
			return best
		_:
			_next %= targets.size()
			var d := targets[_next]
			_next += 1
			return d


## How busy a device is; only servers report load for now.
func _load_of(d: Device) -> int:
	return d.current_load() if d is Server else 0


func _refresh() -> void:
	_label.text = "Load Balancer\n%s, %d connected\nforwarded %d   dropped %d" % [
		STRATEGY_NAMES[strategy], downstream.size(), forwarded, dropped,
	]
