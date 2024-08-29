extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera = $Camera3D
@onready var hotbar = $Camera3D/Hotbar
@export var client : PlayerInput
@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer

const WALK = 3.0
const SPRINT = 5.0
const JUMP_VELOCITY = 4.5
const ACCELERATION = 10.0
const AIR_ACCELERATION = 2.0

var health = 100
var spawn_position = Vector3(randf_range(-1.0,1.0),10,randf_range(-1.0,1.0))

var stats = {
	'Points': 0,
	'Wood': 0,
	'Stone': 0,
	'Food': 0,
	'Gold': 0,
	'Sand': 0,
	'Cactus': 0,
	'Dirt': 0,
	'Coal': 0,
	'Glass': 0
}
#var mouse_rotation_amount_hack = 0

var inventory : Array[Item]
var inventory_slots = 5
@export var selected_item = -1

@onready var DEBUG_BUILD = OS.is_debug_build()

@rpc("authority", "call_local")
func inventory_append(item):
	item = item if item is Item else Item.deserialize(item)
	inventory.append(item)
	var item_instance = load('res://items/'+item._name+'.tscn').instantiate()
	item_instance.item = item
	item_instance.freeze = true
	item_instance.get_node("CollisionShape3D").disabled = true
	item_instance.position = Vector3(0,0,0)
	item_instance.rotation = Vector3(0,0,0)
	hotbar.add_child(item_instance)
	#if 1==name.to_int():
	client.modify_hotbar.rpc_id(name.to_int(),item_instance.get_index(),item._name)
	select_item()

func select_item():
	for item in hotbar.get_children():
		item.hide()
	if selected_item != -1 and hotbar.get_child_count() >= selected_item:
		hotbar.get_child(selected_item-1).show()
		client.no_selected_item = false
	else:
		client.no_selected_item = true
	#if 1==name.to_int():
	client.hotbar_select.rpc_id(name.to_int(),selected_item, 8 if inventory.size() < selected_item or selected_item == -1 else inventory[selected_item-1]._type)

func _ready():
	await get_tree().process_frame
	client.set_multiplayer_authority(name.to_int())
	rollback_synchronizer.process_settings()
	
	if multiplayer.is_server():
		inventory_append.rpc(Item.serialize(Item.new('sword',[],2)))
		inventory_append.rpc(Item.serialize(Item.new('hammer',[],4)))
		inventory_append.rpc(Item.serialize(Item.new('wrench',[],7)))
		position = spawn_position
		$TickInterpolator.teleport()
		multiplayer.peer_connected.connect(func(id):
			for item in inventory:
				var serialized = Item.serialize(item)
				inventory_append.rpc_id(id,serialized)
		)

func _rollback_tick(delta, _tick, _is_fresh):
	var acceleration = ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var speed = SPRINT if client.sprinting else WALK
	var direction = (transform.basis * Vector3(client.input_dir.x, 0, client.input_dir.y)).normalized()
	var target_velocity = direction * speed
	
	#mouse_rotation_amount_hack = 0
	if !is_on_floor():
		velocity.y -= gravity * delta
	if is_on_floor() and client.jumping:
		velocity.y = JUMP_VELOCITY

	velocity = Vector3(
		lerp(velocity.x, target_velocity.x, delta * acceleration),
		velocity.y,
		lerp(velocity.z, target_velocity.z, delta * acceleration))
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	#state.apply_central_force(velocity)
	#rotation.y += mouse_rotation_amount_hack
	#mouse_rotation_amount_hack = 0

func _process(_delta):
	if multiplayer.is_server():
		if position.y < -50:
			change_health.rpc(-1)
		if DEBUG_BUILD and Input.is_action_pressed('cheat'):
			for stat in stats:
				stats[stat] += 100
			get_tree().root.get_child(5).update_stats(stats)

@rpc("authority","call_local")
func change_health(amount):
	if amount > 0 and health < 100:
		health = clamp(health+amount,0,100)
	elif amount < 0:
		health += amount
	if health <= 0:
		health = 100
		velocity = Vector3.ZERO
		position = spawn_position
		$TickInterpolator.teleport()
	var healthbar = get_tree().root.get_child(5).get_node('CanvasLayer').get_node('HUD').get_node('Quickbar').get_node('HBoxContainer').get_node('HealthBar')
	healthbar.value = health
	healthbar.get_node('Label').text = str(health)+'∕100'

@rpc("any_peer", "call_local")
func interact(interactable):
	if multiplayer.is_server():
		if get_tree().root.get_child(0).get_node(interactable):
			var item_object = get_tree().root.get_child(0).get_node(interactable)
			if item_object.is_in_group('item') and inventory.size() < inventory_slots and position.distance_to(item_object.position) <= 2:
				var item = Item.serialize(item_object.item)
				item_interact.rpc(item, interactable)
			elif !item_object.is_in_group('item'):
				item_object.interact.rpc(name.to_int())

@rpc("authority", "call_local")
func item_interact(item, item_object_path):
	var item_object = get_tree().root.get_child(0).get_node(item_object_path)
	item_object.queue_free()
	inventory_append(item)

@rpc("any_peer", "call_local")
func hotbar_input(input):
	if selected_item != input:
		selected_item = clamp(input, 1, inventory_slots)
		select_item()
	else:
		selected_item = -1
		select_item()

@rpc("any_peer", "call_local")
func recieve_camera(y,x):
	rotate_y(y)
	#mouse_rotation_amount_hack = y
	camera.rotate_x(x)
	camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
