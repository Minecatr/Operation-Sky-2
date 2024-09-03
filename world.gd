extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/VBoxContainer/Server/AddressEntry
@onready var upnp_toggle = $CanvasLayer/MainMenu/VBoxContainer/UpnpToggle
@onready var port_entry = $CanvasLayer/MainMenu/VBoxContainer/Server/PortEntry
@onready var hud = $CanvasLayer/HUD
@onready var health_bar = $CanvasLayer/HUD/Quickbar/HBoxContainer/HealthBar
@onready var health_label = $CanvasLayer/HUD/Quickbar/HBoxContainer/HealthBar/Label

@onready var stat_template = preload('res://assets/templates/inventory_stat.tscn')
@onready var quick_stat_template = preload('res://assets/templates/quick_stat.tscn')
@onready var upgrade_template = preload('res://assets/templates/upgrade.tscn')

@onready var stats_ui = $CanvasLayer/HUD/Inventory/Stats/MarginContainer/GridContainer
@onready var quick_ui = $CanvasLayer/HUD/Quickbar/HBoxContainer
@onready var upgrades_ui = $CanvasLayer/HUD/Inventory/Upgrades/Upgrades/MarginContainer/GridContainer

@onready var upgrade_desciption_ui = $CanvasLayer/HUD/Inventory/Upgrades/MarginContainer/RichTextLabel

@export var stats_color = {
	'Points': Color(1,1,1),
	'Wood': Color(0.67,0.33,0.13),
	'Stone': Color(0.5,0.5,0.5),
	'Food': Color(1,0.13,0.5),
	'Gold': Color(1,0.75,0.25),
	'Sand': Color(1,0.88,0.63),
	'Cactus': Color(0.25,0.5,0.19),
	'Dirt': Color(0.64,0.41,0.32),
	'Coal': Color(0.25,0.25,0.25),
	'Glass': Color(0.75,1,1)
}
@export var stats_emoji = {
	'Points': '⚪',
	'Wood': '🪵',
	'Stone': '🪨',
	'Food': '🍒',
	'Gold': '🟡',
	'Sand': '⌛',
	'Cactus': '🌵',
	'Dirt': '🟤',
	'Coal': '⚫',
	'Glass': '🪟'
}
@export var upgrade_cost = {
	'Multi': 3,
	'Speed': 1,
	'Plate Size': 1
}
@export var upgrade_value = {
	'Multi': 0,
	'Speed': 0,
	'Plate Size': 0
}
@export var upgrade_type = {
	'Multi': 'Points',
	'Speed': 'Points',
	'Plate Size': 'Points'
}
@export var upgrade_description = {
	'default': '## Description\nShows the\ndescription of\nthe upgrade you\nare hovering over.',
	'Multi': '## Description\nMultiplies the\nnumber of\npoints you get\nby clicking on\nthe source.',
	'Speed': '## Description\nDecreases the\ntime it\ntakes for the\nsource to\nregenerate.',
	'Plate Size': '## Description\nIncreases the\nplate size by 1\nmeter in each\ndirection.'
}

var suffixes = ["", "k", "M", "G", "T", "P", "E", "Z", "Y"]

const PLAYER = preload("res://player.tscn")
var enet_peer = ENetMultiplayerPeer.new()
var reparent_queue : Array

func _unhandled_input(_event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	if Input.is_action_just_pressed("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_host_button_pressed():
	main_menu.hide()
	hud.show()
	
	enet_peer.create_server(port_entry.value)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	add_player(multiplayer.get_unique_id())
	if upnp_toggle.button_pressed:
		upnp_setup()

func _on_join_button_pressed():
	main_menu.hide()
	hud.show()
	
	enet_peer.create_client(address_entry.text, port_entry.value)
	multiplayer.multiplayer_peer = enet_peer

func add_player(peer_id):
	var player = PLAYER.instantiate()
	player.name = str(peer_id)
	add_child(player)
	update_upgrades.rpc_id(peer_id,upgrade_value,upgrade_cost,upgrade_type)
	update_stats.rpc_id(peer_id,get_node(str(peer_id)).stats)
	update_world.rpc_id(peer_id,upgrade_value['Plate Size'])

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Discover Failed! Error %s" % discover_result)

	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), "UPNP Invalid Gateway!")

	var map_result = upnp.add_port_mapping(port_entry.value)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Port Mapping Failed! Error %s" % map_result)
	
	print("Success! Join Address: %s" % upnp.query_external_address())
	
func _ready():
	update_upgrade_description('default')
	for stat_name in stats_color.keys():
		var template = stat_template.instantiate()
		template.name = stat_name
		template.get_node("Type").text = stat_name
		template.get_node("Color").modulate = stats_color[stat_name]
		stats_ui.add_child(template)
		var template2 = quick_stat_template.instantiate()
		template2.name = stat_name
		template2.get_node("Color").modulate = stats_color[stat_name]
		template2.hide()
		quick_ui.add_child(template2)
	for upgrade_name in upgrade_cost.keys():
		var template = upgrade_template.instantiate()
		template.name = upgrade_name
		template.get_node('Purchase').text = upgrade_name
		template.get_node('Cost').text = stats_emoji[upgrade_type[upgrade_name]]+str(upgrade_cost[upgrade_name])
		upgrades_ui.add_child(template)
		
	for i in range(0,5):
		var augc = load("res://items/aug.tscn").instantiate()
		augc.name = "aug"+str(i)
		augc.position = Vector3(randi_range(-2,2),5,randi_range(-2,2))
		add_child(augc)

func update_upgrade_description(upgrade_name):
	upgrade_desciption_ui.markdown_text = upgrade_description[upgrade_name]

@rpc('any_peer','call_local')
func upgrade(upgrade_name):
	var player = multiplayer.get_remote_sender_id()
	if multiplayer.is_server():
		if get_node(str(player)).stats[upgrade_type[upgrade_name]] >= upgrade_cost[upgrade_name]:
			get_node(str(player)).stats[upgrade_type[upgrade_name]] -= upgrade_cost[upgrade_name]
			upgrade_value[upgrade_name] += 1
			upgrade_cost[upgrade_name] = ceil(upgrade_cost[upgrade_name]*1.3)
			update_upgrades.rpc(upgrade_value,upgrade_cost,upgrade_type)
			update_stats.rpc_id(player,get_node(str(player)).stats)
			if upgrade_name == 'Plate Size':
				update_world.rpc(upgrade_value['Plate Size'])

@rpc('authority','call_local')
func update_upgrades(upgrade_value_server,upgrade_cost_server,upgrade_type_server):
	for upgrade_button in upgrades_ui.get_children():
		upgrade_button.get_node('Upgrades').text = str(upgrade_value_server[upgrade_button.name])
		upgrade_button.get_node('Cost').text = stats_emoji[upgrade_type_server[upgrade_button.name]]+str(upgrade_cost_server[upgrade_button.name])

@rpc('authority','call_local')
func update_stats(stats):
	for stat in stats_ui.get_children():
		stat.get_node("Amount").text = str(stats[stat.name])
	for stat in quick_ui.get_children():
		if stat.name == 'HealthBar': continue
		if stats[stat.name] == 0:
			stat.hide()
		else:
			var amount = stats[stat.name]
			var exponent = str(floor(amount/10)).length()/3
			if exponent > 0:
				stat.get_node("Amount").text = str(floor(amount/pow(1000,exponent)))+suffixes[exponent]
			else:
				stat.get_node("Amount").text = str(amount)
			stat.show()

@rpc('authority','call_local')
func update_world(plate_size_server):
	$Island/MeshInstance3D.mesh.size = Vector3(4+(2*plate_size_server),0.5,4+(2*plate_size_server))
	$Island/CollisionShape3D.shape.size = Vector3(4+(2*plate_size_server),0.5,4+(2*plate_size_server))
