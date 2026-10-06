class_name ShopItem
extends Resource
## One thing on the store wall: a device (a scene that appears on the delivery pad)
## or a server part (a card that lands on the table).

@export var display_name := "" ## Leave empty for parts to use the part's name.
@export var price := 0 ## For devices. Parts use their own price.
@export var scene: PackedScene ## Set for devices.
@export var part: ServerPart ## Set for parts.


func get_price() -> int:
	return part.price if part else price


func label() -> String:
	if display_name.is_empty() and part:
		return part.display_name
	return display_name


## Devices are delivered to the pad; parts go on the table.
func is_large() -> bool:
	return part == null
