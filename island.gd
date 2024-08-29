extends StaticBody3D

@export var spread: int = 32
@export var startHeight: int = 0
# Called when the node enters the scene tree for the first time.
func _ready():
	if multiplayer.is_server():
		randomize()
		position = Vector3(randi_range(-spread*4,spread*4),startHeight,randi_range(-spread*4,spread*4))
