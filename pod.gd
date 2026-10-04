extends MeshInstance3D


# Called when the node enters the scene tree for the first time.
@onready var server = $"../Area3D/MeshInstance3D"
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	self.position.x += 0.02 if server.position.x > self.position.x else -0.02
	self.position.y += 0.02 if server.position.y > self.position.y else -0.02
	self.position.z += 0.02 if server.position.z > self.position.z else -0.02
	pass
