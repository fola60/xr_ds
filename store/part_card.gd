class_name PartCard
extends Node3D
## A bought server part, as a card the player can carry to a server and install.
## Installing swaps parts: the card then holds the part that came out, ready to sell or reuse.
## For desktop testing, clicking a card installs it in the nearest server; the XR hand
## interaction will call install_into() the same way.

@export var part: ServerPart


func _ready() -> void:
	_refresh()
	$ClickArea.input_event.connect(_on_click_area_input)


## Installs this card's part in a server. The card takes the part that was removed.
func install_into(server: Server) -> void:
	var old := server.install(part)
	if old == null:
		queue_free()
		return
	part = old
	_refresh()


func _refresh() -> void:
	$Label3D.text = part.display_name if part else "?"


func _nearest_server() -> Server:
	var best: Server = null
	for d in get_tree().get_nodes_in_group("devices"):
		if d is Server and (best == null or global_position.distance_to(d.global_position) < global_position.distance_to(best.global_position)):
			best = d
	return best


func _on_click_area_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var server := _nearest_server()
		if server:
			install_into(server)
