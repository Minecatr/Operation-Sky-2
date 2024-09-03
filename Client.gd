extends Node
class_name PlayerInput

var input_dir: Vector2 = Vector2.ZERO
var jumping: bool = false
var sprinting: bool = false
var no_selected_item: bool = false

@onready var parent = get_parent()
@onready var camera = $'../Camera3D'

@export_range(0.0, 1100.0) var MOUSE_SENSITIVITY := 0.1
const MOUSE_SENSITIVITY_MIN := 0.01
const MOUSE_SENSITIVITY_MAX := 1.0

var pause : bool = false
var inventory : bool = false
# Called when the node enters the scene tree for the first time.
func _ready():
	#NetworkTime.before_tick_loop.connect(_gather)
	if multiplayer.get_unique_id()==parent.name.to_int():
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	var mouse_sens := remap(MOUSE_SENSITIVITY, 0.0, 1100.0, MOUSE_SENSITIVITY_MIN, MOUSE_SENSITIVITY_MAX)
	if multiplayer.get_unique_id()==parent.name.to_int():
		if Input.is_action_just_pressed('pause') and !inventory:
			pause = !pause
			get_tree().root.get_child(5).get_node('CanvasLayer').get_node('HUD').get_node('Pause').visible = pause
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause else Input.MOUSE_MODE_CAPTURED
		if (Input.is_action_just_pressed('inventory') and !pause) or (Input.is_action_just_pressed('pause') and inventory):
			inventory = !inventory
			get_tree().root.get_child(5).get_node('CanvasLayer').get_node('HUD').get_node('Inventory').visible = inventory
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if inventory else Input.MOUSE_MODE_CAPTURED
		if !pause and !inventory:
			if event is InputEventMouseMotion:
				#parent.rotation.y = wrapf(camera_rot.y - event.relative.x * MOUSE_SENSITIVITY, -PI, PI)
				#camera.rotation.x = clamp(camera_rot.x - event.relative.y * MOUSE_SENSITIVITY, -PI/2, PI/2)
				#event.velocity
				parent.recieve_camera.rpc(-deg_to_rad(event.screen_relative.x * mouse_sens),-deg_to_rad(event.screen_relative.y * mouse_sens))

#func _gather():
func _process(_delta):
	if not is_multiplayer_authority():
		return
	if multiplayer.get_unique_id()==parent.name.to_int():
		if not pause:
			input_dir = Input.get_vector('left','right','forward','backward')
			jumping = Input.is_action_pressed('jump') 
			sprinting = Input.is_action_pressed('sprint')
			if (Input.is_action_just_pressed('interact') or (Input.is_action_just_pressed('shoot') and no_selected_item and !inventory)) and $'../Camera3D/Interact'.get_collider() and $'../Camera3D/Interact'.get_collider().is_in_group('interact'):
				get_parent().interact.rpc_id(1,$'../Camera3D/Interact'.get_collider().get_path())
			for n in range(1,6): # Hotbar
				if Input.is_action_just_pressed(str(n)):
					get_parent().hotbar_input.rpc(n)

@rpc('call_local','any_peer')
func hotbar_select(selected_item, type):
	if multiplayer.get_remote_sender_id() != 1: return
	for slot in get_tree().root.get_node('World/CanvasLayer/HUD/Hotbar').get_children():
		slot.modulate = Color(1,1,1,0.5)
	if selected_item != -1 and get_tree().root.get_node('World/CanvasLayer/HUD/Hotbar').get_child_count() >= selected_item:
		get_tree().root.get_node('World/CanvasLayer/HUD/Hotbar').get_child(selected_item-1).modulate = Color(1,1,1,1)
	get_tree().root.get_node('World/CanvasLayer/HUD/Crosshair').texture = load('res://assets/crosshairs/crosshair_'+str(type)+'.svg')
	#else:
		#get_tree().root.get_node('World/CanvasLayer/HUD/Crosshair').texture = load('res://assets/crosshairs/crosshair_0.svg')
@rpc('call_local','any_peer')
func modify_hotbar(selected_item, item):
	if multiplayer.get_remote_sender_id() != 1: return
	get_tree().root.get_node('World/CanvasLayer/HUD/Hotbar').get_child(selected_item).texture = load('res://assets/item-icons/'+item+'.svg')

@rpc('call_local','any_peer')
func modify_healthbar(health):
	if multiplayer.get_remote_sender_id() != 1: return
	var healthbar = get_tree().root.get_node('World/CanvasLayer/HUD/Quickbar/HBoxContainer/HealthBar')
	healthbar.value = health
	healthbar.get_node('Label').text = str(health)+'∕100'
