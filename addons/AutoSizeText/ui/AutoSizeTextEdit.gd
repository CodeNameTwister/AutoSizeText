@tool
# # # # # # # # # # # # # # # # # # # # # # # # # # #
# Twister
#
# AutoSize TextEdit.
# # # # # # # # # # # # # # # # # # # # # # # # # # #
class_name AutoSizeTextEdit
extends TextEdit

@export_tool_button("FORCE REFRESH")
var refresh_button: Callable = _on_change_rect

## String value of the TextEdit.
@export_multiline var _text: String = "":
	set(txt):
		_text = txt
		if auto_split_text:
			_split_txt()
		else:
			set(&"text", _text)

## Enable auto size text function.
@export var enable_auto_resize: bool = true:
	set(value):
		enable_auto_resize = value
		if is_node_ready():
			set_deferred(&"_text", _text)

## This cut allows you to cut the string if the width limit is exceeded and works if the minimum size is reached.
@export var auto_split_text: bool = false:
	set(value):
		auto_split_text = value
		if is_node_ready():
			set_deferred(&"_text", _text)

@export_group("Auto Font Size")

## Min text size to reach
@export_range(1, 512) var min_size: int = 8:
	set(new_min):
		min_size = min(max(1, new_min), max_size)
		if is_node_ready():
			_on_change_rect()

## Max text size to reach
@export_range(1, 512) var max_size: int = 38:
	set(new_max):
		max_size = max(min_size, min(new_max, 512))
		if is_node_ready():
			_on_change_rect()

# TODO: implement @export_group("Font Step Size")

# Taking custom _char offset prevent text clip by rect
const OFFSET_BY: String = "_"
var _processing_flag: bool = false


## Set text to TextEdit with auto size function.
func set_auto_size_text(new_text: String) -> void:
	_text = new_text

	
## Get original text setted from TextEdit auto size.
func get_auto_size_text() -> String:
	return _text

	
func _validate_property(property: Dictionary) -> void:
	if property.name == "text":
		property.usage = PROPERTY_USAGE_NONE

		
func _split_txt() -> void:
	if _text.is_empty():return

	var offset: float = 0.0
	var txt: PackedStringArray = _text.split('\n', true, 0)

	var character_size: int = get(&"theme_override_font_sizes/font_size")
	if character_size < 2 and character_size != min_size:
		character_size = max(min_size, min(16, max_size))


	var font: Font = get(&"theme_override_fonts/font")
	if null == font:
		font = get_theme_default_font()

	offset = size.x - font.get_string_size(OFFSET_BY, HORIZONTAL_ALIGNMENT_LEFT, -1, character_size, TextServer.JUSTIFICATION_NONE,TextServer.DIRECTION_AUTO,TextServer.ORIENTATION_HORIZONTAL).x

	var new_text: String = ""
	for character: String in txt:
		if character.is_empty():
			new_text += '\n'
			continue
			
		var size_offset: Vector2 = font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, character_size, TextServer.JUSTIFICATION_NONE,TextServer.DIRECTION_AUTO,TextServer.ORIENTATION_HORIZONTAL)
		
		if offset < size_offset.x:
			var split: PackedStringArray  = character.split()
			var current_character: String = ""
			var final: String             = ""
			
			for _char: String in split:
				if "\n" == _char:
					final += current_character + _char
					current_character = ""
					continue
				
				size_offset = font.get_string_size(current_character + "- " + _char , HORIZONTAL_ALIGNMENT_LEFT, -1, character_size, TextServer.JUSTIFICATION_NONE,TextServer.DIRECTION_AUTO,TextServer.ORIENTATION_HORIZONTAL)
				
				if offset < size_offset.x:
					final += current_character + "- " + "\n" + _char
					current_character = ""
				else:
					current_character += _char
				
			new_text += '\n' + final + current_character
		else:
			new_text += '\n' + character

	set(&"text",new_text.strip_edges())

	
func _set(property: StringName, _value: Variant) -> bool:
	if property == &"text" or property == &"placeholder_text":
		_on_change_rect.call_deferred()
		
	return false

	
func _force_update() -> void:
	_text = _text


func _ready() -> void:
	item_rect_changed.connect(_force_update)
	_force_update.call_deferred()

	
func _on_change_rect() -> void:
	if _processing_flag:
		return
	
	_processing_flag = true
	
	if !enable_auto_resize:
		set(&"theme_override_font_sizes/font_size", max_size)
		set_deferred(&"_processing_flag", false)
		return

	var font: Font = get(&"theme_override_fonts/font")
	var character_size: int = max_size
	var font_size_x: float = 0.0
	var offset: float = 0.0

	#region kick_falls
	
	var use_placeholder: bool = false
	var current_text: String = text
	
	if current_text.is_empty():
		if placeholder_text.is_empty():
			return
			
		current_text = placeholder_text
		use_placeholder = true

	if null == font:
		font = get_theme_default_font()
		
	#endregion

	var txt: PackedStringArray = current_text.split('\n', true, 0)
	for character: String in txt:
		var size_offset: Vector2 = font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, character_size, TextServer.JUSTIFICATION_NONE,TextServer.DIRECTION_AUTO,TextServer.ORIENTATION_HORIZONTAL)
		font_size_x = maxf(font_size_x, size_offset.x)

	offset = size.x - font.get_string_size(OFFSET_BY, HORIZONTAL_ALIGNMENT_LEFT, -1, character_size, TextServer.JUSTIFICATION_NONE,TextServer.DIRECTION_AUTO,TextServer.ORIENTATION_HORIZONTAL).x

	if use_placeholder:
		# HACK: Lines updated response by text only
		text = placeholder_text

	# Refresh rect
	set(&"theme_override_font_sizes/font_size", character_size)
	while offset < font_size_x or get_line_count() > get_visible_line_count():
		character_size = character_size - 1

		if character_size < min_size:
			character_size = min_size
			break

		font_size_x = 0.0
		for character: String in txt:
			var size_offset: Vector2 = font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, character_size, TextServer.JUSTIFICATION_NONE,TextServer.DIRECTION_AUTO,TextServer.ORIENTATION_HORIZONTAL)
			font_size_x = maxf(font_size_x, size_offset.x)
		
		offset = size.x - font.get_string_size(OFFSET_BY, HORIZONTAL_ALIGNMENT_LEFT, -1, character_size, TextServer.JUSTIFICATION_NONE,TextServer.DIRECTION_AUTO,TextServer.ORIENTATION_HORIZONTAL).x

		# Refresh rect
		set(&"theme_override_font_sizes/font_size", character_size)

	# Set final result
	set(&"theme_override_font_sizes/font_size", character_size)

	if use_placeholder:
		# Restore
		text = ""
	
	set_deferred(&"_processing_flag", false)
