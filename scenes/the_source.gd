extends StaticBody3D

@onready var timer = $Timer
@onready var animation_player = $AnimationPlayer

var timer_active = false

@rpc('authority','call_local')
func interact(player):
	if !timer_active:
		if multiplayer.is_server():
			timer.wait_time = 10.0/(float(get_parent().upgrade_value['Speed'])+2.0)
			get_parent().get_node(str(player)).stats['Points'] += get_parent().upgrade_value['Multi']+1
			get_parent().update_stats.rpc_id(player,get_parent().get_node(str(player)).stats)
			timer.start()
		timer_active = true
		animation_player.play("hit")

@rpc('authority','call_local')
func end_animation():
	animation_player.play_backwards("hit")
	timer_active = false

func _on_timer_timeout() -> void:
	end_animation.rpc()
