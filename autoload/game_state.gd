extends Node

const LATENCY_WINDOW := 60.0 ## Seconds of latency history used for percentiles.
const FAIL_LIMIT := 30.0 ## Seconds the p50 target can fail before the run ends.
const MINUTE_BONUS := 20 ## Coins per percentile target met at each minute check.
const MINUTE_PENALTY := 10 ## Coins lost per percentile target missed at each minute check.
const RECALC_INTERVAL := 0.25 ## Seconds between percentile recalculations.

## SLA target per percentile, in seconds of latency (landing on the source to leaving it).
## Defaults suit a single base server: an idle request takes 0.4 s and each one queued ahead
## adds 0.4 s, so p50 allows ~1 queued and p99 ~5; a full 8-slot queue fails everything.
## Levels can pass their own targets to start_run().
const DEFAULT_SLA_TARGETS := {50: 1.0, 75: 1.4, 90: 1.8, 95: 2.1, 99: 2.5}
var sla_targets := DEFAULT_SLA_TARGETS.duplicate()
## Live latency per percentile, in seconds, recalculated over LATENCY_WINDOW.
var percentiles := {50: 0.0, 75: 0.0, 90: 0.0, 95: 0.0, 99: 0.0}

var coins := 0
var coins_per_minute := 0 ## Earned during the last minute, for the board.
var latency_samples: Array[Vector2] = [] ## x = time recorded, y = latency in seconds.

var next_check_in := 60.0 ## Seconds until the next minute bonus/penalty check.
var p50_failing_for := 0.0 ## Seconds the p50 target has been failing in a row.
var run_over := false

var _minute_earnings := 0
var _recalc_timer := 0.0


func _enter_tree() -> void:
	# Servers can appear at any time (scene load, bought mid-run), so watch the whole tree.
	# Connected here, not in _ready: at startup the main scene's nodes enter the tree
	# before this autoload's _ready runs, so _ready would miss them.
	get_tree().node_added.connect(_on_node_added)


## Resets everything for a fresh run. Levels call this when they load, including on restart.
func start_run(targets := DEFAULT_SLA_TARGETS, starting_coins := 0) -> void:
	sla_targets = targets.duplicate()
	for p in percentiles:
		percentiles[p] = 0.0
	coins = starting_coins
	coins_per_minute = 0
	latency_samples.clear()
	next_check_in = 60.0
	p50_failing_for = 0.0
	run_over = false
	_minute_earnings = 0
	_recalc_timer = 0.0


func _process(delta: float) -> void:
	if run_over:
		return

	_recalc_timer += delta
	if _recalc_timer >= RECALC_INTERVAL:
		_recalc_timer = 0.0
		_update_percentiles()

	if percentiles[50] > sla_targets[50]:
		p50_failing_for += delta
		if p50_failing_for >= FAIL_LIMIT:
			run_over = true
	else:
		p50_failing_for = 0.0

	next_check_in -= delta
	if next_check_in <= 0.0:
		next_check_in += 60.0
		_minute_check()


func _on_node_added(node: Node) -> void:
	if node is Device:
		node.request_dropped.connect(_on_request_dropped)
	if node is Request:
		node.response_returned.connect(_on_response_returned)


## Paid when the response reaches the sky, using the latency measured inside the system.
func _on_response_returned(payload: Dictionary) -> void:
	var latency := float(payload.get("finished_at", _now())) - float(payload.get("sent_at", _now()))
	latency_samples.append(Vector2(_now(), latency))
	var pay := _pay_for(latency)
	coins += pay
	_minute_earnings += pay


func _on_request_dropped(_device: Device, _payload: Dictionary) -> void:
	# A dropped request never finishes, so it counts as slower than any target.
	latency_samples.append(Vector2(_now(), INF))


## Faster requests pay more.
func _pay_for(latency: float) -> int:
	if latency <= sla_targets[50]:
		return 10
	if latency <= sla_targets[99]:
		return 5
	return 1


func _update_percentiles() -> void:
	var now := _now()
	latency_samples = latency_samples.filter(func(s: Vector2) -> bool: return now - s.x <= LATENCY_WINDOW)
	if latency_samples.is_empty():
		for p in percentiles:
			percentiles[p] = 0.0
		return
	var sorted: Array = latency_samples.map(func(s: Vector2) -> float: return s.y)
	sorted.sort()
	for p in percentiles:
		percentiles[p] = sorted[int(p / 100.0 * (sorted.size() - 1))]


func _minute_check() -> void:
	for p in percentiles:
		coins += MINUTE_BONUS if percentiles[p] <= sla_targets[p] else -MINUTE_PENALTY
	coins_per_minute = _minute_earnings
	_minute_earnings = 0


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
