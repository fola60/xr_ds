extends Node3D
## Level 1: one server, GET requests only.
## Teaches that a server has limited capacity: when requests arrive faster than it can
## process them, a queue forms and latency rises, and p99 shows it before p50.
## The fix taught is vertical scaling (a faster CPU); the level ends by showing that
## one machine has a ceiling, which sets up level 2 (more servers and a load balancer).

enum Beat { WARM_UP, QUEUE, UPGRADE, CEILING, COMPLETE, FAILED }

const PROMPTS := {
	Beat.WARM_UP: "Requests fall from the sky onto your server.\nEvery response that makes it back earns coins.",
	Beat.QUEUE: "Traffic is rising. Watch the server's queue\nand the p99 row on the SLA board.",
	Beat.UPGRADE: "p99 is red: some requests wait in the queue,\neven though most (p50) are still fast.\nBuy the faster CPU from the store, then install it.",
	Beat.CEILING: "Faster CPU: each request takes half as long,\nso the queue drains. But traffic keeps growing...",
}

@export var warm_up_rate := 0.5 ## Requests per second at the start.
@export var warm_up_time := 25.0
@export var queue_rate := 2.6 ## Just over what a base server handles (2.5/s).
@export var queue_ramp_time := 60.0
@export var ceiling_rate := 6.0 ## Past what the 2 GHz server handles (5/s).
@export var ceiling_ramp_time := 60.0
@export var ceiling_hold := 20.0 ## Seconds after hitting the ceiling before the level completes.
@export var p99_red_delay := 3.0 ## How long p99 must stay red before a beat reacts to it.

var beat := Beat.WARM_UP

var _time_in_beat := 0.0
var _p99_red_for := 0.0
var _starting_ghz := 0.0
var _ceiling_hit := false

@onready var _spawner: SkySpawner = $SkySpawner
@onready var _server: Server = $Server
@onready var _prompt: Label3D = $Prompt


func _ready() -> void:
	GameState.start_run()
	_starting_ghz = _server.cpu.clock_ghz
	_spawner.get_share = 1.0 # GET only in level 1.
	_spawner.rate = warm_up_rate
	_enter(Beat.WARM_UP)


func _process(delta: float) -> void:
	if beat == Beat.COMPLETE or beat == Beat.FAILED:
		return
	if GameState.run_over:
		_enter(Beat.FAILED)
		return

	_time_in_beat += delta
	_p99_red_for = _p99_red_for + delta if GameState.percentiles[99] > GameState.sla_targets[99] else 0.0
	var p99_red := _p99_red_for >= p99_red_delay

	match beat:
		Beat.WARM_UP:
			if _time_in_beat >= warm_up_time:
				_enter(Beat.QUEUE)
		Beat.QUEUE:
			# Move on when p99 breaks, or after the ramp anyway in case traffic was kind.
			if p99_red or _time_in_beat >= queue_ramp_time + 20.0:
				_enter(Beat.UPGRADE)
		Beat.UPGRADE:
			if _server.cpu.clock_ghz > _starting_ghz:
				_enter(Beat.CEILING)
		Beat.CEILING:
			if not _ceiling_hit and _time_in_beat > 15.0 and (p99_red or _time_in_beat >= ceiling_ramp_time):
				_ceiling_hit = true
				_time_in_beat = 0.0
				_prompt.text = "p99 is red again. Even the fastest CPU has a limit:\none machine can only do so much.\nNext: more servers."
			elif _ceiling_hit and _time_in_beat >= ceiling_hold:
				_enter(Beat.COMPLETE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene() # _ready calls GameState.start_run(), so stats reset.


func _enter(next: Beat) -> void:
	beat = next
	_time_in_beat = 0.0
	if next in PROMPTS:
		_prompt.text = PROMPTS[next]
	match next:
		Beat.QUEUE:
			_spawner.ramp_to(queue_rate, queue_ramp_time)
		Beat.UPGRADE:
			_spawner.ramp_to(_spawner.rate, 0.01) # Hold traffic steady until the player upgrades.
		Beat.CEILING:
			_spawner.ramp_to(ceiling_rate, ceiling_ramp_time)
		Beat.COMPLETE:
			_spawner.ramp_to(0.0, 0.01)
			_prompt.text = "Level complete!  Coins: %d\nPress R to play again." % GameState.coins
		Beat.FAILED:
			_spawner.ramp_to(0.0, 0.01)
			_prompt.text = "Run over: p50 missed its target for 30 seconds,\nso half your requests were too slow.\nPress R to try again."
