tool
extends CSGMesh

class_name OnyxBase

# ////////////////////////////////////////////////////////////
# INFO
# Base class for all Onyx-type nodes, provides fundamental functionality.


# ////////////////////////////////////////////////////////////
# PROPERTIES

# CORE //////////////

# The plugin this node belongs to
var plugin

# The face set script, used for managing geometric data.
var onyx_mesh = OnyxMesh.new()

# The last-created array mesh (used by the Gizmo for visualization)
var array_mesh = null

# The handle points that will be used to resize the mesh (NOT built in the format required by the gizmo)
var handles : Dictionary = {}

# Old handle points that are saved every time a handle has finished moving.
var old_handle_data : Dictionary = {}

# The offset of the origin relative to the rest of the mesh.
var origin_offset = Vector3(0, 0, 0)

# Used to decide whether to update the geometry.  Enables parents to be moved without forcing updates.
var local_tracked_pos = Vector3(0, 0, 0)

# If true, this node is currently selected.
var is_selected = false

# HOLLOW MODE //////////////

# Enables and disables hollow mode
var hollow_enable = false

# The object that if set, will be used to hollow out the main shape.
var hollow_onyx_object

# The set of margins to be stored
var hollow_margin_values = {}

# The amount all hollow margins are set to initially
const default_hollow_margin = 0.1

# If true, this very onyx object is a hollow object, required to bypass certain checks.
var is_hollow_object = false

# BEVELS //////////////

#export(float) var bevel_size = 0.2 setget update_bevel_size
#enum BevelTarget {Y_AXIS, X_AXIS, Z_AXIS}
#export(BevelTarget) var bevel_target = BevelTarget.Y_AXIS setget update_bevel_target


# UVS //////////////

var uv_scale = Vector2(1.0, 1.0)
var flip_uvs_horizontally = false
var flip_uvs_vertically = false


# ////////////////////////////////////////////////////////////
# SET/GETTERS

func _get_property_list():
	print("PROPERTY LIST GET")
	var props = [
		{
			"name" : "uv_options/uv_scale",
			"type" : TYPE_VECTOR2,
		},
		
		{
			"name" : "uv_options/flip_uvs_horizontally",
			"type" : TYPE_BOOL,
		},
		
		{
			"name" : "uv_options/flip_uvs_vertically",
			"type" : TYPE_BOOL,
		},
		
		{
			"name" : "hollow_mode/enable_hollow_mode",
			"type" : TYPE_BOOL,
		},
	]
	
	# search through every handle and grab their names, then put them into a new property
	for handle_name in hollow_margin_values.keys():
		props.append(
			{
				"name" : "hollow_mode/" + handle_name + "_margin",
				"type" : TYPE_REAL,
			}
		)
	
	return props

func _set(property, value):
	match property:
		# UVs
		"uv_options/uv_scale":
			uv_scale = value
		"uv_options/flip_uvs_horizontally":
			flip_uvs_horizontally = value
		"uv_options/flip_uvs_vertically":
			flip_uvs_vertically = value
		
		# Hollow Mode
		"hollow_mode/enable_hollow_mode":
			update_hollow_enable(value)
			return
	
	# Hollow Mode Margins
	if property.begins_with("hollow_mode/"):
		var property_name = property.replace("hollow_mode/", "")
		property_name = property_name.replace("_margin", "")
		
		hollow_margin_values[property_name] = value
	
	generate_geometry()


func _get(property):
	match property:
		# UVs
		"uv_options/uv_scale":
			return uv_scale
		"uv_options/flip_uvs_horizontally":
			return flip_uvs_horizontally
		"uv_options/flip_uvs_vertically":
			return flip_uvs_vertically
		
		# Hollow Mode
		"hollow_mode/enable_hollow_mode":
			return hollow_enable
	
	# Hollow Mode Margins
	if property.begins_with("hollow_mode/"):
		var property_name = property.replace("hollow_mode/", "")
		property_name = property_name.replace("_margin", "")
		
		return hollow_margin_values[property_name]



# ////////////////////////////////////////////////////////////
# FUNCTIONS

# Global initialisation
func _enter_tree():
	
	print("_ENTER_TREE...")
	
	# If this is being run in the editor, sort out the gizmo.
	if Engine.editor_hint == true:
		
		# load plugin
		plugin = get_node("/root/EditorNode/Onyx")
		
		# this used to mean something, not anymore though
#		set_notify_local_transform(true)
#		set_notify_transform(true)
#		set_ignore_transform_notification(false)

# Called when the node enters the scene tree for the first time.
func _ready():
	
	print("_READY...")
	
	if Engine.editor_hint == true:
		if mesh == null:
			print("building kit")
			build_handles()
			generate_geometry()
			refresh_handle_data()
		
		# If we have an operation that ain't Addition, we need to render the preview mesh so we need handles anyway.  wupwup.
		elif operation != 0:
			build_handles()
			generate_geometry()
			refresh_handle_data()
		
		# Ensure the old_handles variable match the current handles we have for undo/redo.
		old_handle_data = get_control_data()

# This was used, but there's no reason for it to be here.
#func _notification(what):
#
#	if what == Spatial.NOTIFICATION_TRANSFORM_CHANGED:
#
#		# check that transform changes are local only
#		if local_tracked_pos != translation:
#			local_tracked_pos = translation
#			call_deferred("_editor_transform_changed")
#
#func _editor_transform_changed():
#	pass
#


# ////////////////////////////////////////////////////////////
# MESH BUILDING AND RENDERING

func generate_geometry(fix_to_origin_setting = false):
	print("generate_geometry() - Override this function!")
	pass

func get_gizmo_mesh() -> Array:
	
	if operation == 0:
		return []
	
	var material
	
	if operation == 1:
		material = "res://addons/onyx/materials/wireframes/onyx_wireframe_int.material"
	elif operation == 2:
		material = "res://addons/onyx/materials/wireframes/onyx_wireframe_sub.material"
	
	return [array_mesh, material]

func render_onyx_mesh():
	
	generate_hollow_shape()
	
	# Optional UV Modifications
	var tf_vec = uv_scale
	if tf_vec.x == 0:
		tf_vec.x = 0.0001
	if tf_vec.y == 0:
		tf_vec.y = 0.0001
	
#	if self.invert_faces == true:
#		tf_vec.x = tf_vec.x * -1.0
	if flip_uvs_vertically == true:
		tf_vec.y = tf_vec.y * -1.0
	if flip_uvs_horizontally == true:
		tf_vec.x = tf_vec.x * -1.0
	
	onyx_mesh.multiply_uvs(tf_vec)
	
	# Create new mesh
	array_mesh = onyx_mesh.render_surface_geometry(material)
	var helper = MeshDataTool.new()
	var mesh = Mesh.new()
	
	# Set the new mesh
	helper.create_from_surface(array_mesh, 0)
	helper.commit_to_surface(mesh)
	set_mesh(mesh)
	

# ////////////////////////////////////////////////////////////
# HOLLOW MODE FUNCTIONS

# The margin options available in Hollow mode, using a list of the control names to setup margins for
func get_hollow_margins() -> Array:
	return []

# An override-able function used to determine how margins apply to handles
func apply_hollow_margins(controls: Dictionary):
	pass

func generate_hollow_margins():
	
	hollow_margin_values.clear()
	var handle_names = get_hollow_margins()
	for handle_name in handle_names:
		hollow_margin_values[handle_name] = default_hollow_margin
		
	
func update_hollow_enable(value):
	
	# if true, get the current class and instance it 
	if value == true:
		# This workaround is used to get the exact sub-class of the current script for instancing.
		var script_file_path = get_script().get_path()
		hollow_onyx_object = load(script_file_path).new()
		
		print("assigning hollow object")
		hollow_onyx_object.name == "Hollow Onyx Object"
		hollow_onyx_object.is_hollow_object = true
		add_child(hollow_onyx_object)
		
		print("performing setup")
		print(hollow_onyx_object.handles)
		hollow_onyx_object.operation = 2
		hollow_onyx_object.build_handles()
		hollow_onyx_object.generate_geometry()
		hollow_onyx_object.refresh_handle_data()
		
		hollow_enable = true
		
		# build the margins and FORCE PROPERTY LIST UPDATES
		generate_hollow_margins()
		# ???
		
		# generate shape
		generate_hollow_shape()
	
	# if not, remove object
	else:
		remove_child(hollow_onyx_object)
		
		if hollow_onyx_object != null:
			hollow_onyx_object.queue_free()
			
		hollow_margin_values.clear()
		hollow_enable = false

func generate_hollow_shape():
	
	if hollow_enable == false:
		return
	
	# duplicate and set control data so the shapes mimic each other
	var parent_control_data = get_control_data()
	hollow_onyx_object.set_control_data(parent_control_data)
	
	# Now modify the controls on an individual basis.
	apply_hollow_margins(hollow_onyx_object.handles)
	hollow_onyx_object.apply_handle_attributes()
	hollow_onyx_object.generate_geometry()

# ////////////////////////////////////////////////////////////
# HANDLE GENERATION FUNCTIONS

func update_origin_position(new_location = null):
	print("update_origin_position() - Override this function!")
	pass

func build_handles():
	print("build_handles() - Override this function!")
	pass

func refresh_handle_data():
	print("refresh_handle_data() - Override this function!")
	pass

func update_handle_from_gizmo(control):
	print("update_handle_from_gizmo(control) - Override this function!")
	pass

func apply_handle_attributes():
	print("apply_handle_attributes() - Override this function!")
	pass

func balance_handles():
	print("balance_handles() - Override this function!")
	pass

# ////////////////////////////////////////////////////////////
# HANDLE MANAGEMENT FUNCTIONS

# Used when an object is selected for the handles to be built.
func handle_build():
	
	if Engine.editor_hint == true:
		build_handles()
		refresh_handle_data()
		old_handle_data = get_control_data()

# Used when an object is deselected to clear the handle info.
func handle_clear():
	
	gizmo.control_points.clear()
	handles.clear()
	

# Notifies the node that a handle has changed.
func handle_change(control):
	
	update_handle_from_gizmo(control)
	generate_geometry()
	

# Called when a handle has stopped being dragged.
# NOTE - This should only finish committing information, restore_state will finalize movement and other opeirations.
func handle_commit(control):
	
	update_handle_from_gizmo(control)
	apply_handle_attributes()
	
	update_origin_position()
	generate_geometry()
	
	# store current handle points as the old ones, so they can be used later
	# as an undo point before the next commit.
	old_handle_data = get_control_data()

func get_gizmo_control_points() -> Array:
	return handles.values()

# ////////////////////////////////////////////////////////////
# STATE MANAGEMENT

# Returns a list of handle data from each handle.
func get_control_data() -> Dictionary:
	
	var result = {}
	for control in handles.values():
		result[control.control_name] = control.get_control_data()
	
	return result

# Changes all current handle data with a previously set list of handle data.
func set_control_data(data : Dictionary):
	
	for data_key in data.keys():
		handles[data_key].set_control_data(data[data_key])
		

# ////////////////////////////////////////////////////////////
# UNDO/REDO STATES
# Returns a state that can be used to undo or redo a previous change to the shape.
func get_gizmo_redo_state(control_point):
	var saved_translation = global_transform.origin
	return [get_control_data(), saved_translation]
	
	# If it has this method, it will have an origin setting.  This must then be preserved.
	update_origin_position()
	
	# store current handle points as the old ones, so they can be used later
	# as an undo point before the next commit.
	old_handle_data = get_control_data()


# Returns a state specifically for undo functions in SnapGizmo.
func get_gizmo_undo_state(control_point):
	var saved_translation = global_transform.origin
	return [old_handle_data.duplicate(false), saved_translation]


# Restores the state of the shape to a previous given state.
func restore_state(state):
	
	var new_handles = state[0]
	var stored_location = state[1]
	
#	print("RESTORING STATE -", state)
	
	set_control_data(new_handles)
	old_handle_data = new_handles.duplicate(true)
	apply_handle_attributes()
	
	update_origin_position(stored_location)
	balance_handles()
	
	generate_geometry()
	
#	if hollow_onyx_object != null:
#		hollow_onyx_object.set_control_data(new_handles)
#		hollow_onyx_object.apply_handle_attributes()
#		hollow_onyx_object.set_translation(Vector3(0, 0, 0))
	

# ////////////////////////////////////////////////////////////
# EDITOR SELECTION

func editor_select():
	is_selected = true
	handle_build()
	
	
func editor_deselect():
	is_selected = false
	handle_clear()
	


# ////////////////////////////////////////////////////////////
# CHILD MANAGEMENT
func translate_children(translation):
	
	for child in get_children():
		child.global_translate(translation)