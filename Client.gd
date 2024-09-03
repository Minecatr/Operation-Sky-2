extends Node
class_name PlayerInput

var input_dir: Vector2 = Vector2.ZERO
var jumping: bool = false
var sprinting: bool = false
var no_selected_item: bool = false

@onready var parent := get_parent()
@onready var root := get_tree().root
@onready var camera := $'../Camera3D'

@export_range(0.0, 1100.0) var MOUSE_SENSITIVITY := 0.1
const MOUSE_SENSITIVITY_MIN := 0.01
const MOUSE_SENSITIVITY_MAX := 1.0

var pause: bool = false
var inventory: bool = false

@onready var is_client := multiplayer.get_unique_id() == parent.name.to_int()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# stop the raycast from colliding with the player it belongs to
	$'../Camera3D/Interact'.add_exception(parent)
		
	# is server
	if is_client:
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	var mouse_sens := remap(MOUSE_SENSITIVITY, 0.0, 1100.0, MOUSE_SENSITIVITY_MIN, MOUSE_SENSITIVITY_MAX)
	if is_client:
		if Input.is_action_just_pressed('pause') and !inventory:
			pause = !pause
			root.get_child(5).get_node('CanvasLayer').get_node('HUD').get_node('Pause').visible = pause
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause else Input.MOUSE_MODE_CAPTURED
		if (Input.is_action_just_pressed('inventory') and !pause) or (Input.is_action_just_pressed('pause') and inventory):
			inventory = !inventory
			root.get_child(5).get_node('CanvasLayer').get_node('HUD').get_node('Inventory').visible = inventory
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory else Input.MOUSE_MODE_CAPTURED
		if !pause and !inventory:
			if event is InputEventMouseMotion:
				parent.recieve_camera.rpc(-deg_to_rad(event.screen_relative.x * mouse_sens),-deg_to_rad(event.screen_relative.y * mouse_sens))

func _process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if is_client:
		if not pause:
			input_dir = Input.get_vector('left','right','forward','backward')
			jumping = Input.is_action_pressed('jump') 
			sprinting = Input.is_action_pressed('sprint')
			
			var shoot_select := (Input.is_action_just_pressed('shoot') and no_selected_item and !inventory)
			var collider: Node3D = $'../Camera3D/Interact'.get_collider()
			if (Input.is_action_just_pressed('interact') or shoot_select) and collider and collider.is_in_group('interact'):
				parent.interact.rpc_id(1,$'../Camera3D/Interact'.get_collider().get_path())
			for n in range(1,6): # Hotbar
				if Input.is_action_just_pressed(str(n)):
					parent.hotbar_input.rpc(n)

@rpc('call_local','any_peer')
func hotbar_select(selected_item: int, type: float):
	if multiplayer.get_remote_sender_id() != 1: return
	var hotbar := root.get_node('World/CanvasLayer/HUD/Hotbar')
	for slot in hotbar.get_children():
		slot.modulate = Color(1,1,1,0.5)
	if selected_item != -1 and hotbar.get_child_count() >= selected_item:
		hotbar.get_child(selected_item-1).modulate = Color(1,1,1,1)
	root.get_node('World/CanvasLayer/HUD/Crosshair').texture = load('res://assets/crosshairs/crosshair_'+str(type)+'.svg')
	#else:
		#get_tree().root.get_node('World/CanvasLayer/HUD/Crosshair').texture = load('res://assets/crosshairs/crosshair_0.svg')
@rpc('call_local','any_peer')
func modify_hotbar(selected_item: int, item: String):
	if multiplayer.get_remote_sender_id() != 1: return
	get_tree().root.get_node('World/CanvasLayer/HUD/Hotbar').get_child(selected_item).texture = load('res://assets/item-icons/'+item+'.svg')

@rpc('call_local','any_peer')
func modify_healthbar(health: int):
	if multiplayer.get_remote_sender_id() != 1: return
	var healthbar := get_tree().root.get_node('World/CanvasLayer/HUD/Quickbar/HBoxContainer/HealthBar')
	healthbar.value = health
	healthbar.get_node('Label').text = str(health)+'∕100'
