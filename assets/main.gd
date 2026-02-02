extends Node

var config_file : ConfigFile
var start : Room

const ISLE_OF_FLESH : String = "res://assets/levels/isle_of_flesh.cfg"
const EMPTY_LEVEL : String = "res://assets/levels/empty.cfg"
const DOCS : String = "res://assets/documentation.txt"

const LEVEL_DIR : String = "user://levels/"
const ASSET_DIR : String = "res://assets/levels/"
const NL := "\n"
const T := "\t"
const LINE_WIDTH : int = 66 ## Characters per line in output.

@onready var flags := Flags.new()
@onready var inventory := Inventory.new()
@onready var current_level := Level.new()
@onready var output_name : Label = %OutputName
@onready var output : Label = %Output
@onready var quit_button: Button = %QuitButton
@onready var options_container: VBoxContainer = %OptionsContainer
@onready var file_dialog: PanelContainer = %FileDialog
@onready var file_display_v_box: VBoxContainer = %FileDisplayVBox
@onready var close_files_button: Button = %CloseFilesButton
@onready var load_button: Button = %LoadButton
@onready var view_docs: Button = %ViewDocs
@onready var open_folder_button: Button = %OpenFolderButton
@onready var refresh_button: Button = %RefreshButton
@onready var docs: RichTextLabel = %Docs
@onready var close_docs: Button = %CloseDocs
@onready var docs_container: PanelContainer = %DocsContainer


###

class Flags:
	var flag_dict : Dictionary[String, bool] = {
		"dead" : false
	}
	func set_flag(flag : String, val : bool = true) -> bool:
		if found(flag): 
			flag_dict[flag] = val
			return true
		return false
	func found(flag : String) -> bool:
		return flag in flag_dict.keys()
	func at(flag : String) -> bool:
		if not found(flag): return false
		else: return flag_dict[flag]
	func clear(): flag_dict.clear()

func set_true(flag : String) -> void:
	flags.set_flag(flag, true)
	return

func set_false(flag : String) -> void:
	flags.set_flag(flag, false)
	return

###

class Inventory:
	var inv_dict : Dictionary[String, int]
	func add(item : String, num : int = 1) -> void:
		if found(item):
			inv_dict[item] += num
		else: inv_dict[item] = num
	func remove(item : String, num : int = 1) -> bool:
		if count(item) >= num:
			inv_dict[item] -= num
			return true
		return false
	func found(item : String) -> bool:
		return item in inv_dict.keys()
	func count(item : String) -> int:
		if found(item): return inv_dict[item]
		else: return 0
	func _to_string() -> String:
		var s := "INVENTORY:" + NL
		for item : String in inv_dict:
			s += item + " x" + str(count(item)) + NL
		return s
	func clear(): inv_dict.clear()

func add(item : String, val : int = 1) -> void:
	inventory.add(item, val)
	print(inventory)
	return

func remove(item : String, val : int = 1) -> bool:
	return inventory.remove(item, val)

###

class Level:
	var rooms : Dictionary[String, Room]
	func add(room : Room): rooms[room.id] = room
	func _to_string() -> String:
		var s : String = ""
		for id in rooms: s += str(get_room(id)) + NL
		return s
	func get_room(id : String) -> Room: return rooms.get(id)
	func get_start() -> String: return rooms.keys()[0]
	func is_empty() -> bool: 
		return rooms.size() == 0
	#func clear(): rooms.clear()
	func list_rooms():
		print("ROOMS:[")
		for room in rooms: print(rooms[room].id)
		print("]")

class Room:
	var name : String
	var id : String
	var desc : String
	var desc_cond : Dictionary
	var options : Array[Option]
	func _init(_name : String, _id : String, _desc : String, _desc_cond : Dictionary, _options : Array[Option]) -> void:
		name = _name
		id = _id
		desc = set_desc_width(_desc)
		desc_cond = set_desc_cond_width(_desc_cond)
		options = _options
		return
	func _to_string() -> String:
		var s := ""
		s += name + " [" + id + "]" + NL + desc + NL
		for option : Option in options: s += NL + "Option: " + str(option)
		return s
	func display() -> String:
		return name + NL + desc
	func set_desc_width(_desc : String) -> String:
		var s = ""
		var i : int = 0
		for c in _desc:
			if i >= LINE_WIDTH and c in " \t\n":
				s += NL
				i = 0
			else: 
				s += c
				i += 1
		return s
	func set_desc_cond_width(dc : Dictionary) -> Dictionary:
		var new_dict : Dictionary
		for key in dc:
			new_dict[key] = set_desc_width(dc[key])
		return new_dict

class Option:
	var text : String = ""
	var actions : Array[Action]
	var goes_to : String = ""
	var conditions : Array
	func _init(_text : String, _goes_to : String, _actions, _conditions) -> void:
		text = _text
		goes_to = _goes_to.to_lower()
		set_actions(_actions)
		conditions = _conditions
		return
	func set_actions(_actions) -> void:
		for a in _actions:
			var action := Action.new(a)
			actions.append(action)
		return
	func _to_string() -> String:
		var s : String = ""
		s += '"' + text + '"' + NL + (("goto: " + goes_to + NL) if goes_to else "")
		for action : Action in actions: s += NL + "Action: " + str(action)
		for condition in conditions: s += NL + "Condition: " + condition
		return s

class Action:
	var callable : String = ""
	var args : Array = []
	func run() -> Variant:
		return callv(callable, args)
	func _init(_action : Array) -> void:
		callable = _action[0]
		args = _action.slice(1)
		return
	func _to_string() -> String:
		var s := ""
		s += callable
		for arg in args: s += ", " + str(arg)
		return s
###

func _ready() -> void:
	file_dialog.hide()
	quit_button.pressed.connect(quit)
	close_files_button.pressed.connect(file_dialog.hide)
	close_docs.pressed.connect(docs_container.hide)
	load_button.pressed.connect(_on_load_file_pressed)
	open_folder_button.pressed.connect(show_level_dir)
	refresh_button.pressed.connect(_on_load_file_pressed)
	add_docs()
	view_docs.pressed.connect(docs_container.show)
	docs.text = FileAccess.open(DOCS, FileAccess.READ).get_as_text()
	#play_level(ISLE_OF_FLESH)
	play_level(EMPTY_LEVEL)

func show_level_dir() -> void:
	OS.shell_show_in_file_manager(ProjectSettings.globalize_path(LEVEL_DIR))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"): quit()

func play_level(level : String):
	print("Now loading " + level.get_file())
	inventory.clear()
	flags.clear()
	current_level = read_level(level)
	
	if not current_level or current_level.is_empty():
		output.text = "Select a level to begin."
	else: goto(current_level.get_start())

func read_level(level : String) -> Level:
	config_file = ConfigFile.new()
	var l := Level.new()
	if config_file.load(level) != OK: 
		printerr("Unable to load " + level.get_file())
		return null
	var rooms : PackedStringArray = config_file.get_sections()
	for room_id : String in rooms:
		var room_name : String = config_file.get_value(room_id, "name", "")
		var room_desc : String = config_file.get_value(room_id, "desc", "")
		var room_desc_cond : Dictionary = config_file.get_value(room_id, "desc_cond", {})
		#room_desc = get_conditional_desc(room_desc, room_desc_cond)
		var options : Array[Option]
		var op_values = null
		if "options" in config_file.get_section_keys(room_id):
			op_values = config_file.get_value(room_id, "options")
		for op in op_values if op_values else []:
			var text = op.get("text", "Default Text")
			var goes_to = op.get("goto", room_id)
			var actions = op.get("actions", [])
			var conditions = op.get("conditions", [])
			var option := Option.new(text, goes_to, actions, conditions)
			options.append(option)
		var room := Room.new(room_name, room_id, room_desc, room_desc_cond, options)
		l.add(room)
	return l

func show_options(options : Array[Option]) -> void:
	var buttons := options_container.get_children()
	for i in range(len(buttons)):
		var button : Button = buttons[i]
		reset_signal(button.pressed)
		if i < options.size():
			var option : Option = options[i]
			button.text = option.text
			
			button.visible = true
			for condition in option.conditions:
				if not check_condition(condition): button.visible = false
			
			for action : Action in option.actions:
				if not has_method(action.callable): printerr("No method found: " + action.callable)
				else:
					button.pressed.connect(func(): callv(action.callable, action.args))
			if option.goes_to != "": button.pressed.connect(goto.bind(option.goes_to))
		else:
			button.visible = false
	return

func check_condition(condition : Array) -> bool:
	var num_args : int = condition.size()
	match num_args:
		1: return flags.at(condition[0]) # Checks if a flag is t/f
		2:
			if condition[0] in ["have", "has"]:
				return compare(condition[1], ">", 0)
			elif condition[0] in ["not", "have_not"]:
				return compare(condition[1], "=", 0)
			elif typeof(condition[1]) == TYPE_BOOL: return flags.at(condition[0]) == condition[1]
		3:
			printerr("invalid condition: " + str(condition))
			return false
		4:
			if condition[0] == "compare":
				return compare.callv(condition.slice(1))
			else: return false
	return true

func get_conditional_desc(desc : String, desc_cond : Dictionary) -> String:
	if desc_cond.is_empty(): return desc
	var s : String = desc
	for key : Array in desc_cond:
		var to_add := true
		for condition in key:
			if not check_condition(condition):
				to_add = false
				break
		if to_add: s += desc_cond[key]
	return s

func compare(item : String, operator : String = ">", num : int = 0) -> bool:
	var count : int = inventory.count(item)
	var result : bool = false
	
	match operator:
		"<": result = (count < num)
		">": result = (count > num)
		"<=": result = (count <= num)
		">=": result = (count >= num)
		"=", "==": result = (count == num)
		"!", "!=": result = (count != num)
	print(item + operator + str(num) + ": " + str(result))
	return result

func reset_signal(s : Signal) -> void:
	for connection in s.get_connections():
		s.disconnect(connection["callable"])

func quit(): get_tree().quit()

func goto(room_id : String) -> void:
	var room : Room = current_level.get_room(room_id)
	if not room: 
		printerr("No room with id " + room_id + ".")
		return
	output_name.text = room.name
	output.text = get_conditional_desc(room.desc, room.desc_cond)
	show_options(room.options)
	return

#func increment(var_name : String, i : int = 1) -> void:
	#print(var_name + " " + str(self.get(var_name)))
	#self.set(var_name, self.get(var_name) + i)
	#print(var_name + " " + str(self.get(var_name)))
	#return
	#
#func decrement(var_name : String, i : int = -1) -> void:
	#if i > 0: i *= -1 # Ensure negative value
	#increment(var_name, i)


func add_docs():
	#var file := FileAccess.open(DOCS, FileAccess.READ)
	#var docs := file.get_as_text()
	#file.close()
	return

func _on_load_file_pressed():
	for child in file_display_v_box.get_children(): child.queue_free()
	file_dialog.show()
	var files : Array[String] = []
	for directory : String in [LEVEL_DIR, ASSET_DIR]:
		var dir := DirAccess.open(directory)
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".cfg"):
				var full_path = ProjectSettings.globalize_path(directory).path_join(file_name)
				files.append(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	for file : String in files:
		var title := file.get_file().get_basename().replace("_", " ").capitalize()
		var button := Button.new()
		button.text = title
		button.name = title
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(play_level.bind(file))
		button.pressed.connect(file_dialog.hide)
		file_display_v_box.add_child(button)
