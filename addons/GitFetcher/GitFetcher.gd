@tool
extends Control

# --- GitHub repo settings ---
var OWNER := "SnapGamesStudio"
var REPO := "Gallery"
var BRANCH := "main"
const TREE_URL := "https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1"

# --- HTTP + download state ---
var http: HTTPRequest
var all_files := []          # all files in the repo
var files_to_download := []  # queue of files to download
var current_index := 0
var editor_interface: EditorInterface

# --- UI elements (set up in scene) ---
@onready var error_label: Label = $VBoxContainer/Error
@onready var owner_edit: LineEdit = $VBoxContainer/RepoDetails/Owner
@onready var branch_edit: LineEdit = $VBoxContainer/RepoDetails/Branch
@onready var repo_edit: LineEdit = $VBoxContainer/RepoDetails/Repo
@onready var file_list: ItemList = $VBoxContainer/FileList
@onready var refresh_button: Button = $VBoxContainer/RefreshButton
@onready var download_button: Button = $VBoxContainer/DownloadButton
@onready var download_all_button: Button = $VBoxContainer/DownloadAllButton

func set_editor_interface(ei: EditorInterface) -> void:
	editor_interface = ei
	
func owner_changed(new_owner:String):
	OWNER = new_owner
	
func branch_changed(new_branch:String):
	BRANCH = new_branch
	
func repo_changed(new_repo:String):
	REPO = new_repo
	
func _ready():
	if not Engine.is_editor_hint():
		return
		
	owner_edit.text_changed.connect(owner_changed)
	branch_edit.text_changed.connect(branch_changed)
	repo_edit.text_changed.connect(repo_changed)
	
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	
	refresh_button.pressed.connect(_refresh_file_list)
	download_button.pressed.connect(_download_selected_files)
	download_all_button.pressed.connect(_download_all_files)
	
	download_button.disabled = true
	download_all_button.disabled = true

# --- Step 1: Refresh repo tree ---
func _refresh_file_list():
	all_files.clear()
	if BRANCH == "" or REPO == "" or OWNER == "":
		error_label.text = str("ERROR: EITHER NO BRANCH OR REPO OR OWNER FILLED")
		return
	else:
		error_label.text = ""
	print("Requesting repo tree...")
	http.request(TREE_URL % [OWNER, REPO, BRANCH])

# --- Step 2: Handle HTTP responses ---
func _on_request_completed(result, response_code, headers, body):
	if response_code != 200:
		push_error("HTTP error: %d" % response_code)
		return
	
	var text = body.get_string_from_utf8()
	
	if all_files.is_empty():
		_parse_tree(text)
	else:
		_save_current_file(body)

# --- Step 3: Parse GitHub tree JSON (all files) ---
func _parse_tree(json_text: String):
	var data = JSON.parse_string(json_text)
	if data == null:
		push_error("Failed to parse tree JSON")
		return
	
	all_files.clear()
	file_list.clear()
	
	for item in data["tree"]:
		if item["type"] == "blob":
			var path: String = item["path"]
			
			if path.ends_with(".import"):
					continue
			elif path.ends_with(".uid"):
				continue
			elif path.ends_with("project.godot"):
				continue

			all_files.append(path)
			file_list.add_item(path)
	
	print("Files found:", all_files.size())
	
	download_button.disabled = all_files.is_empty()
	download_all_button.disabled = all_files.is_empty()

# --- Step 4: Download selected files ---
func _download_selected_files():
	var selected_indices = file_list.get_selected_items()
	if selected_indices.is_empty():
		print("No files selected")
		return
	
	files_to_download.clear()
	for i in selected_indices:
		files_to_download.append(all_files[i])
	
	current_index = 0
	_download_next()

# --- Step 5: Download all files ---
func _download_all_files():
	if all_files.is_empty():
		print("No files to download. Refresh first!")
		return
	
	files_to_download.clear()
	files_to_download = all_files.duplicate() # copy all files
	current_index = 0
	_download_next()

# --- Step 6: Sequential download ---
func _download_next():
	if current_index >= files_to_download.size():
		print("All downloads complete!")
		if editor_interface:
			editor_interface.get_resource_filesystem().scan()
		return
	
	var path = files_to_download[current_index]
	var raw_url = "https://raw.githubusercontent.com/%s/%s/%s/%s" % [OWNER, REPO, BRANCH, path]
	print("Downloading:", path)
	http.request(raw_url)

# --- Step 7: Save downloaded file ---
func _save_current_file(body: PackedByteArray):
	var path = files_to_download[current_index]
	var local_path = "res://" + path
	
	# Ensure folder exists
	DirAccess.make_dir_recursive_absolute(local_path.get_base_dir())
	
	var file = FileAccess.open(local_path, FileAccess.WRITE)
	file.store_buffer(body)
	file.close()
	
	print("Saved:", local_path)
	current_index += 1
	
	# Start next download
	_download_next()
