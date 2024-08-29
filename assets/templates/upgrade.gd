extends Control

func _on_purchase_pressed() -> void:
	get_node('../../../../../../../..').upgrade.rpc_id(1,name,multiplayer.get_unique_id())
func _on_purchase_mouse_entered() -> void:
	get_node('../../../../../../../..').update_upgrade_description(name)
func _on_purchase_mouse_exited() -> void:
	get_node('../../../../../../../..').update_upgrade_description('default')
