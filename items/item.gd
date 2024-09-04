class_name Item

var _name: String = 'item'
var _properties: Array = []
var _type: int = 0

func _init(name: String, properties: Array, type: int) -> void:
	_name = name
	_properties = properties
	_type = type

func _set(_property, _value):
	object_changed.emit(Item.serialize(self))
	return null

signal object_changed(serialized)

static func serialize(item: Item) -> Dictionary:
	var return_dict := {
		"name": item._name,
		"properties": item._properties,
		"type": item._type
	}
	return return_dict
		
static func deserialize(itemDict: Dictionary) -> Item:
	var item := Item.new(itemDict.name,itemDict.properties,itemDict.type)
	itemDict.erase("name")
	itemDict.erase("properties")
	itemDict.erase("type")
	return item
