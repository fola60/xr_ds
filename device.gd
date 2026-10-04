class_name Device
extends Node3D
## Base class for anything requests can be sent to: servers, load balancers, later databases.
## Devices connect to the devices they forward requests to (their downstream).
## For now connections are set in the inspector or with connect_to(); cables will call these later.

signal connections_changed
signal request_dropped(device: Device, payload: Dictionary)

@export var downstream: Array[Device] = [] ## Devices this one can forward requests to.


func connect_to(other: Device) -> void:
	if other != self and other not in downstream:
		downstream.append(other)
		connections_changed.emit()


func disconnect_from(other: Device) -> void:
	if other in downstream:
		downstream.erase(other)
		connections_changed.emit()


## Called by a request when it arrives. Subclasses decide what happens to it.
func receive(request: Request) -> void:
	push_error("%s can't handle requests" % name)
	request.queue_free()


## Sends a request to a device. It travels there from wherever it is now.
## Static so non-devices (like the client) can use it too: Device.send(req, server).
static func send(request: Request, to: Device) -> void:
	request.target = to
	if to is Server:
		to.in_flight += 1
