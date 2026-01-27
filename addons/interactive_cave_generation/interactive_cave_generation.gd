@tool
extends EditorPlugin

var panel
const GENERATION_PANEL = preload("uid://bp5sc7sxk6dmv")

func _enable_plugin() -> void:
	# Add autoloads here.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here.
	pass

func _enter_tree() -> void:
	panel = GENERATION_PANEL.instantiate()
	#panel.undo_rodo = get_undo_redo()
	add_control_to_dock(DOCK_SLOT_LEFT_BL, panel)

func _exit_tree() -> void:
	remove_control_from_docks(panel)
	panel.queue_free()
