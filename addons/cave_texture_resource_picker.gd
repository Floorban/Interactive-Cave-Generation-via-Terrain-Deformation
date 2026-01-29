@tool
extends VBoxContainer
class_name TextureArrayEditor

@export var textures: Array[Texture2D] = []

func _ready():
	_rebuild_ui()

func _rebuild_ui():
	# Clear old children
	for c in get_children():
		c.queue_free()
	
	for i in range(textures.size()):
		var hbox = HBoxContainer.new()
		var tex_preview = TextureRect.new()
		tex_preview.texture = textures[i]
		tex_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		tex_preview.size = Vector2(512,512)
		hbox.add_child(tex_preview)

		var btn = Button.new()
		btn.text = "Change"
		btn.pressed.connect(Callable(self, "_on_pick_texture").bind(i))
		hbox.add_child(btn)

		add_child(hbox)
		hbox.add_theme_constant_override("speration", 200)
	
	var add_btn = Button.new()
	add_btn.text = "Add Texture"
	add_btn.pressed.connect(self._on_add_texture)
	add_child(add_btn)

func _on_add_texture():
	textures.append(null)
	_rebuild_ui()

func _on_pick_texture(idx):
	var file_dialog = EditorFileDialog.new()
	file_dialog.mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.filters = ["*.png ; PNG Texture", "*.jpg ; JPG Texture", "*.webp ; WEBP Texture"]
	file_dialog.connect("file_selected", Callable(self, "_on_file_selected").bind(idx))
	add_child(file_dialog)
	file_dialog.popup_centered()

func _on_file_selected(path: String, idx: int) -> void:
	var tex := load(path) as Texture2D
	textures[idx] = tex
	_rebuild_ui()
