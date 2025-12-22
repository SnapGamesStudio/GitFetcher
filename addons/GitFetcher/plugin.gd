@tool
extends EditorPlugin

var dock: Control

func _enter_tree():
	dock = load("res://addons/GitFetcher/GitFetcher.tscn").instantiate()
	# Pass editor interface to dock
	if "set_editor_interface" in dock:
		dock.set_editor_interface(get_editor_interface())
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	print("Downloader Plugin loaded")

func _exit_tree():
	remove_control_from_docks(dock)
	dock.queue_free()
