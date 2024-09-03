extends Control


func _on_drop_pressed() -> void:
	get_node('../../../../../../..').drop_stat.rpc_id(1,name)
