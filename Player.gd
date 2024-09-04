extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera := $Camera3D
@onready var hotbar := $Camera3D/BoneAttachment3D/Hotbar
@export var client : PlayerInput
@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer

@export var WALK := 3.0
@export var SPRINT := 5.0
@export var JUMP_VELOCITY := 4.5
@export var ACCELERATION := 10.0
@export var AIR_ACCELERATION := 2.0

@onready var root := get_tree().root
@onready var player_id := name.to_int()
@onready var is_server := multiplayer.is_server()

var health := 100
var spawn_position := Vector3(randf_range(-1.0,1.0),10,randf_range(-1.0,1.0))

var stats := {
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

var inventory : Array[Item]
var inventory_slots := 5
@export var selected_item := -1

@onready var DEBUG_BUILD := OS.is_debug_build()
var teleporting: bool = false

@rpc("authority", "call_local")
func inventory_append(item: Variant) -> void:
	var item_deserialized: Item = item if item is Item else Item.deserialize(item)
	inventory.append(item_deserialized)
	var item_instance: Node3D = load('res://items/'+item_deserialized._name+'.tscn').instantiate()
	item_instance.item = item_deserialized
	item_instance.freeze = true
	item_instance.get_node("CollisionShape3D").disabled = true
	item_instance.position = Vector3(0,0,0)
	item_instance.rotation = Vector3(0,0,0)
	hotbar.add_child(item_instance)
	client.modify_hotbar.rpc_id(player_id,item_instance.get_index(),item_deserialized._name)
	select_item()

func select_item() -> void:
	for item in hotbar.get_children():
		item.hide()
	if selected_item != -1 and hotbar.get_child_count() >= selected_item:
		hotbar.get_child(selected_item-1).show()
		client.no_selected_item = false
	else:
		client.no_selected_item = true
	client.hotbar_select.rpc_id(player_id,selected_item, 8 if inventory.size() < selected_item or selected_item == -1 else inventory[selected_item-1]._type)

func _ready():
	if multiplayer.get_unique_id() == player_id:
		# Hide the client's player, but still cast a shadow
		$Walking/Skeleton3D/Ch20.transparency = 1.0
		
	await get_tree().process_frame
	client.set_multiplayer_authority(player_id)
	rollback_synchronizer.process_settings()
	
	if is_server:
		inventory_append.rpc(Item.serialize(Item.new('sword',[],2)))
		inventory_append.rpc(Item.serialize(Item.new('hammer',[],4)))
		inventory_append.rpc(Item.serialize(Item.new('wrench',[],7)))
		position = spawn_position
		$TickInterpolator.teleport()
		multiplayer.peer_connected.connect(func(id: int):
			for item in inventory:
				var serialized := Item.serialize(item)
				inventory_append.rpc_id(id,serialized)
		)

func _rollback_tick(delta: float, _tick: int, _is_fresh: bool) -> void:
	if teleporting:
		velocity = Vector3.ZERO
		position = spawn_position
		teleporting = false
		$TickInterpolator.teleport()
		return
	_force_update_is_on_floor()
	var acceleration := ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var speed := SPRINT if client.sprinting else WALK
	var direction := (transform.basis * Vector3(client.input_dir.x, 0, client.input_dir.y).normalized()).normalized()
	var target_velocity := direction * speed
	
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

func _force_update_is_on_floor() -> void:
	var old_velocity := velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity

func _process(_delta: float) -> void:
	var horizontal_velocity := Vector2(velocity.x, velocity.z)
	var speed := (SPRINT if client.sprinting else WALK)
	$Walking/AnimationTree.set("parameters/Walk/walkblend/blend_amount", -Vector2(global_basis.z.x, global_basis.z.z).dot(horizontal_velocity)/speed)
	$Walking/AnimationTree.set("parameters/Walk/DirectionBlend/blend_amount",  Vector2(global_basis.x.x, global_basis.x.z).dot(horizontal_velocity)/speed)
	var running_amount := clampf(remap(horizontal_velocity.length(), WALK, SPRINT, 0.0, 1.1), 0.0, 1.0)
	$Walking/AnimationTree.set("parameters/Walk/WalkRun/blend_amount", running_amount)
	
	if is_server:
		if position.y < -50:
			set_health.rpc_id(1, health-1)
		if DEBUG_BUILD and Input.is_action_pressed('cheat'):
			for stat in stats:
				stats[stat] += 100
			root.get_node('World').update_stats(stats)

@rpc("authority","call_local")
func set_health(new_health):
	if is_server and !teleporting:
		health = clamp(new_health,0,100)
		if health == 0:
			teleporting = true
			health = 100
	client.modify_healthbar.rpc_id(player_id,health)

@rpc("any_peer", "call_local")
func interact(interactable):
	if is_server:
		var item_object := root.get_node('World').get_node(interactable)
		if item_object:
			var in_group := item_object.is_in_group('item')
			if in_group and inventory.size() < inventory_slots and position.distance_to(item_object.position) <= 2.0:
				var item := Item.serialize(item_object.item)
				item_interact.rpc(item, interactable)
			elif not in_group:
				item_object.interact.rpc(player_id)

@rpc("authority", "call_local")
func item_interact(item: Variant, item_object_path: String) -> void:
	var item_object := root.get_node('World').get_node(item_object_path)
	item_object.queue_free()
	inventory_append(item)

@rpc("any_peer", "call_local")
func hotbar_input(input: int) -> void:
	if selected_item != input:
		selected_item = clamp(input, 1, inventory_slots)
		select_item()
	else:
		selected_item = -1
		select_item()

@rpc("any_peer", "call_local")
func recieve_camera(y: float, x: float) -> void:
	rotate_y(y)
	#mouse_rotation_amount_hack = y
	camera.rotate_x(x)
	camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
