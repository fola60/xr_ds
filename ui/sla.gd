extends Node3D
## Floating SLA board. A 2D UI drawn in the SubViewport is shown on the Screen quad.
## It reads GameState every frame; nothing else talks to it.

const OK_COLOR := Color(0.3, 0.9, 0.4)
const FAIL_COLOR := Color(1.0, 0.3, 0.3)

@onready var _viewport: SubViewport = $SubViewport
@onready var _screen: MeshInstance3D = $Screen
@onready var _coins: Label = $SubViewport/Panel/VBoxContainer/CoinsLabel
@onready var _rows: VBoxContainer = $SubViewport/Panel/VBoxContainer


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _viewport.get_texture() # What the SubViewport renders.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Not affected by lighting, like a real screen.
	_screen.material_override = mat


func _process(_delta: float) -> void:
	if GameState.run_over:
		_coins.text = "RUN OVER   Coins: %d" % GameState.coins
	else:
		_coins.text = "Coins: %d   (+%d last minute)" % [GameState.coins, GameState.coins_per_minute]
	for p in GameState.percentiles:
		_show_percentile(p)


func _show_percentile(p: int) -> void:
	var row := _rows.get_node("P%dRow" % p)
	var label: Label = row.get_node("Label")
	var bar: ProgressBar = row.get_node("Bar")
	var target: float = GameState.sla_targets[p]
	var value: float = GameState.percentiles[p]
	var shown := "%.1fs" % value if is_finite(value) else "dropped"
	label.text = "p%d   %s / %.1fs" % [p, shown, target]
	bar.max_value = target * 2.0 # Half full = exactly on target.
	bar.value = minf(value, bar.max_value)
	bar.modulate = OK_COLOR if value <= target else FAIL_COLOR
