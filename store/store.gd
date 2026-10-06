class_name Store
extends Node3D
## The shop: a wall of items to buy, a delivery pad in front of it where everything bought
## appears (devices in the middle, part cards around the edge), and a bin for selling. Each level sets which items are enabled.
## For desktop testing, items on the wall can be clicked with the mouse; the XR pointer will call buy().

signal purchased(item: ShopItem, thing: Node3D)

const CARD_SCENE := preload("res://store/part_card.tscn")
const COLUMNS := 3
const BUTTON_SIZE := Vector3(0.9, 0.38, 0.04)
const SELL_BACK := 0.5 ## Fraction of the price returned when selling.
const PAD_CLEAR_RADIUS := 0.7 ## Metres; a device closer than this blocks delivery.
const MESSAGE_TIME := 2.0

const ENABLED_COLOR := Color(0.15, 0.5, 0.25)
const UNAFFORDABLE_COLOR := Color(0.32, 0.32, 0.32)
const LOCKED_COLOR := Color(0.12, 0.12, 0.12)

@export var catalog: Array[ShopItem] = [] ## Everything shown on the wall.
@export var enabled: Array[ShopItem] = [] ## What this level lets the player buy; the rest show as locked.
@export var spawn_height := 0.5 ## How far above the pad a delivered device appears.

var _buttons := {} ## ShopItem -> {"material": StandardMaterial3D, "label": Label3D}
var _message := ""
var _message_left := 0.0

@onready var _items: Node3D = $Wall/Items
@onready var _header: Label3D = $Wall/Header
@onready var _slots: Node3D = $Pad/Slots
@onready var _pad: Node3D = $Pad


func _ready() -> void:
	get_viewport().physics_object_picking = true # Lets the mouse click wall items.
	for i in catalog.size():
		var button := _make_button(catalog[i])
		var col := i % COLUMNS
		var row := i / COLUMNS
		button.position = Vector3((col - (COLUMNS - 1) / 2.0) * (BUTTON_SIZE.x + 0.1), -row * (BUTTON_SIZE.y + 0.08), 0)
		_items.add_child(button)


func _process(delta: float) -> void:
	_message_left -= delta
	_header.text = "STORE   Coins: %d" % GameState.coins
	if _message_left > 0.0:
		_header.text += "\n" + _message
	for item: ShopItem in _buttons:
		var b: Dictionary = _buttons[item]
		if item not in enabled:
			b.material.albedo_color = LOCKED_COLOR
			b.label.text = "%s\nLOCKED" % item.label()
		else:
			var affordable := GameState.coins >= item.get_price()
			b.material.albedo_color = ENABLED_COLOR if affordable else UNAFFORDABLE_COLOR
			b.label.text = "%s\n%d coins" % [item.label(), item.get_price()]


## Buys an item if it's enabled, affordable and there's room to deliver it.
func buy(item: ShopItem) -> bool:
	if item not in enabled:
		return _fail("Locked")
	if GameState.coins < item.get_price():
		return _fail("Not enough coins")

	var thing: Node3D
	if item.is_large():
		if not _pad_clear():
			return _fail("Delivery pad blocked")
		thing = item.scene.instantiate()
		get_parent().add_child(thing)
		thing.global_position = _pad.global_position + Vector3.UP * spawn_height
	else:
		var slot := _free_slot()
		if slot == null:
			return _fail("Pad full")
		thing = CARD_SCENE.instantiate()
		thing.part = item.part
		slot.add_child(thing)

	GameState.coins -= item.get_price()
	purchased.emit(item, thing)
	return true


## Sells a device or part card back for part of what it cost. The bin will call this
## when something is dropped in.
func sell(thing: Node3D) -> void:
	var value := 0
	if thing is PartCard:
		value = thing.part.price
	elif thing is Device:
		for item in catalog:
			if item.scene and item.scene.resource_path == thing.scene_file_path:
				value = item.get_price()
		if thing is Server:
			value += thing.cpu.price + thing.ram.price
		for d in get_tree().get_nodes_in_group("devices"):
			d.disconnect_from(thing) # So nothing keeps sending to it.
	GameState.coins += int(value * SELL_BACK)
	thing.queue_free()


func _make_button(item: ShopItem) -> Area3D:
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = BUTTON_SIZE
	area.add_child(shape)

	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = BUTTON_SIZE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Reads like a screen, whatever the lighting.
	mesh.material_override = material
	area.add_child(mesh)

	var label := Label3D.new()
	label.position.z = BUTTON_SIZE.z / 2 + 0.005
	label.pixel_size = 0.004
	label.font_size = 18
	label.outline_size = 4
	area.add_child(label)

	area.input_event.connect(_on_button_input.bind(item))
	_buttons[item] = {"material": material, "label": label}
	return area


func _on_button_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int, item: ShopItem) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		buy(item)


func _pad_clear() -> bool:
	for d: Node3D in get_tree().get_nodes_in_group("devices"):
		var offset := d.global_position - _pad.global_position
		offset.y = 0.0
		if offset.length() < PAD_CLEAR_RADIUS:
			return false
	return true


func _free_slot() -> Node3D:
	for slot: Node3D in _slots.get_children():
		if slot.get_child_count() == 0:
			return slot
	return null


func _fail(message: String) -> bool:
	_message = message
	_message_left = MESSAGE_TIME
	return false
