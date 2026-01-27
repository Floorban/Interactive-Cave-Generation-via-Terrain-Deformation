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
	add_control_to_dock(DOCK_SLOT_RIGHT_BR, panel)

func _exit_tree() -> void:
	remove_control_from_docks(panel)
	panel.queue_free()
