@tool
extends Control

# --- GitHub repo settings ---
var OWNER := ""
var REPO := ""
var BRANCH := "main"
const TOKEN_URL := "Gitfetcher/Token"
const TREE_URL := "https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1"

# --- HTTP + download state ---
var http: HTTPRequest
var all_files := []          # all files in the repo
var files_to_download := []  # queue of files to download
var current_index := 0
var editor_interface: EditorInterface
var settings: EditorSettings


# --- UI elements (set up in scene) ---
@onready var error_label: Label = $ScrollContainer/VBoxContainer/Error
@onready var owner_edit: LineEdit = $ScrollContainer/VBoxContainer/RepoDetails/Owner
@onready var branch_edit: LineEdit = $ScrollContainer/VBoxContainer/RepoDetails/Branch
@onready var repo_edit: LineEdit = $ScrollContainer/VBoxContainer/RepoDetails/Repo
@onready var token_edit: LineEdit = $ScrollContainer/VBoxContainer/HBoxContainer2/Token
@onready var file_list: ItemList = $ScrollContainer/VBoxContainer/FileList
@onready var clear_button: Button = $ScrollContainer/VBoxContainer/HBoxContainer/ClearButton
@onready var refresh_button: Button = $ScrollContainer/VBoxContainer/HBoxContainer/RefreshButton
@onready var download_button: Button = $ScrollContainer/VBoxContainer/DownloadButton
@onready var download_all_button: Button = $ScrollContainer/VBoxContainer/DownloadAllButton
@onready var token_button: CheckButton = $ScrollContainer/VBoxContainer/HBoxContainer2/TokenButton 

func set_editor_interface(ei: EditorInterface) -> void:
	editor_interface = ei
	
func _toggle_token(toggled_on:bool) -> void:
	token_edit.visible = toggled_on
	
func token_changed(new_token:String) -> void:
	settings.set_setting(TOKEN_URL, new_token.strip_edges())
	print("GitHub token saved (editor-only)")
	
func owner_changed(new_owner:String) -> void:
	OWNER = new_owner
	print(new_owner)
	
func branch_changed(new_branch:String) -> void:
	BRANCH = new_branch
	print(new_branch)
	
func repo_changed(new_repo:String) -> void:
	REPO = new_repo
	print(new_repo)
	
func _ready() -> void:
	if not Engine.is_editor_hint():
		return
		
	settings = EditorInterface.get_editor_settings()
	
	settings.set_setting(TOKEN_URL, "")
	
	token_edit.text_changed.connect(token_changed)
	owner_edit.text_changed.connect(owner_changed)
	branch_edit.text_changed.connect(branch_changed)
	repo_edit.text_changed.connect(repo_changed)
	
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	
	token_button.toggled.connect(_toggle_token)
	clear_button.pressed.connect(_clear_file_list)
	refresh_button.pressed.connect(_refresh_file_list)
	download_button.pressed.connect(_download_selected_files)
	download_all_button.pressed.connect(_download_all_files)
	
	download_button.disabled = true
	download_all_button.disabled = true

func _clear_file_list() -> void:
	all_files.clear()
	file_list.clear()

func _parse_github_url(url: String) -> Dictionary:
	var result := {
		"owner": "",
		"repo": "",
		"branch": "main"
	}
	
	url = url.strip_edges()
	
	# Remove protocol
	if url.begins_with("https://"):
		url = url.substr(8)
	elif url.begins_with("http://"):
		url = url.substr(7)
	
	# Remove domain
	if url.begins_with("github.com/"):
		url = url.substr(11)
	
	# Remove trailing .git
	if url.ends_with(".git"):
		url = url.substr(0, url.length() - 4)
	
	var parts := url.split("/", false)
	
	if parts.size() < 2:
		return result
	
	result.owner = parts[0]
	result.repo = parts[1]
	
	# Detect branch
	if parts.size() >= 4:
		if parts[2] == "tree" or parts[2] == "blob":
			result.branch = parts[3]
	
	return result

func _on_repo_url_pasted(text: String):
		
	var info = _parse_github_url(text)
	
	if text == "":
		error_label.text = ""
		return 
	if info.owner == "" or info.repo == "":
		error_label.text = "Invalid GitHub URL"
		return
	else:
		error_label.text = ""
	
	
	owner_edit.text = info.owner
	owner_edit.text_changed.emit(info.owner)
	repo_edit.text = info.repo
	repo_edit.text_changed.emit(info.repo)
	branch_edit.text = info.branch
	branch_edit.text_changed.emit(info.branch)


# --- Step 1: Refresh repo tree ---
func _refresh_file_list() -> void:
	all_files.clear()
	if BRANCH == "" or REPO == "" or OWNER == "":
		error_label.text = str("ERROR: EITHER NO BRANCH OR REPO OR OWNER FILLED")
		return
	else:
		error_label.text = ""
	
	var headers := []
	
	var token = settings.get_setting(TOKEN_URL)
	if token != "":
		headers.append("Authorization: Bearer %s" % token)
		
	headers.append("User-Agent: Godot-Editor-Addon")
		
	print("Requesting repo tree...")
	http.request(TREE_URL % [OWNER, REPO, BRANCH],headers)

# --- Step 2: Handle HTTP responses ---
func _on_request_completed(result, response_code, headers, body) -> void:
	if response_code != 200:
		push_error("HTTP error: %d" % response_code)
		return
	
	var text = body.get_string_from_utf8()
	
	if all_files.is_empty():
		_parse_tree(text)
	else:
		_save_current_file(body)

# --- Step 3: Parse GitHub tree JSON (all files) ---
func _parse_tree(json_text: String) -> void:
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
			
	
	
	print("Files found:", all_files)
	
	download_button.disabled = all_files.is_empty()
	download_all_button.disabled = all_files.is_empty()

# --- Step 4: Download selected files ---
func _download_selected_files() -> void:
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
func _download_all_files() -> void:
	if all_files.is_empty():
		print("No files to download. Refresh first!")
		return
	
	files_to_download.clear()
	files_to_download = all_files.duplicate() # copy all files
	current_index = 0
	_download_next()

# --- Step 6: Sequential download ---
func _download_next() -> void:
	if current_index >= files_to_download.size():
		print("All downloads complete!")
		if editor_interface:
			editor_interface.get_resource_filesystem().scan()
		return
	
	var path = files_to_download[current_index]
	
	var token = settings.get_setting(TOKEN_URL)
	
	var headers := []
	if token != "":
		headers.append("Authorization: Bearer %s" % token)
	headers.append("User-Agent: Godot-Editor-Addon")
	
	var raw_url = "https://raw.githubusercontent.com/%s/%s/%s/%s" % [OWNER, REPO, BRANCH, path]
	print("Downloading:", path)
	http.request(raw_url,headers)

# --- Step 7: Save downloaded file ---
func _save_current_file(body: PackedByteArray) -> void:
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
