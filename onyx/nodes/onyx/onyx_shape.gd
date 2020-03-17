tool
extends CSGMesh

# /////////////////////////////////////////////////////////////////////////////
# INFO
# A container-type that allows for the generation of many different kinds of CSG shapes
# with customizable UVs, interactive handles, auto-updating origin points and other
# handy features.
#
# Add new generators by subclassing OnyxGenerator.

# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# INTERFACE (the important bits)

# - - func activate_node() - - 
# To save on load times when loading scenes, not all of the components
# required to modify the shape will be immediately loaded.  Use this function when performing
# cross-node interactions to ensure that it is fully ready to handle them.


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# STATICS

# The name given to the generator child.
const GENERATOR_NODE_NAME = "**GENERATOR NODE**"

# The name given to hollow objects
const HOLLOW_OBJECT_NAME = "**HOLLOW ONYX OBJECT**"

# The name for the node used to preview non-union boolean modes.
const BOOLEAN_PREVIEW_OBJECT_NAME = "Boolean Preview"

# The generator types.
enum ShapeType {
	BOX, 
# 	ROUNDED_BOX,
# 	CYLINDER,
# 	SPHERE,
# 	WEDGE,
# 	STAIRS,
# 	RAMP,
#
#	# Placeholders for future releases
#	STAR,
#	CAPSULE,
# 	DONUT,
# 	TUBE_BOX,
# 	HALF_SPHERE,
}

# The dictionary used to find the script for each ShapeType.
const GENERATOR_SCRIPTS = {
	ShapeType.BOX : "res://addons/onyx/nodes/onyx/onyx_box.gd",
}

# ////////////////////////////////////
# PUBLIC
# Made public through property lists 

# Used to select different shapes.
export(ShapeType) var shape = ShapeType.BOX  setget switch_generator

var uv_scale = Vector2(1.0, 1.0)
var flip_uvs_horizontally = false
var flip_uvs_vertically = false


# ////////////////////////////////////
# PRIVATE

# Used for managing geometric data in a more convenient way than in-built Godot types.
var _onyx_mesh = OnyxMesh.new()

# The currently selected shape generator, delegates all shape properties, control
# points and mesh building.
var _generator : Spatial

# Used to display the properties that the active shape generator makes available.
var _gen_property_list : Dictionary = {}

# Used to store the properties of the active shape generator for future scene loads.
var _gen_property_values : Dictionary = {}

# If true, this node is currently selected in the editor
var is_selected : bool = false


# //////////////////
# HOLLOW MODE

# Enables and disables hollow mode
var hollow_enable : bool = false

# The object that if set, will be used to hollow out the main shape.
var hollow_object : CSGMesh = null

# Storage object for the hollow mesh, used during runtime.
var hollow_mesh : Mesh

# Hollow object material storage.
var hollow_material : Material


# //////////////////
# BOOLEAN PREVIEW

# A node created in edit-mode to visualize shapes involved in boolean operations.
var boolean_preview_node = null



# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# INITIALIZATION


# Global initialisation
func _enter_tree():
	
	print("[OnyxShape] ", self.get_name() , " - _enter_tree()")
	
	# Required to build hollow data before the scene loads
	if Engine.editor_hint == false:
		_build_runtime_hollow_object()


# Called when the node enters the scene tree for the first time.
func _ready():
	
	print("[OnyxShape] ", self.get_name() , " - _ready()")
	
	if Engine.editor_hint == true:
		
		# If this is null, we can assume this node was just created and need
		# to setup the generator and mesh anew.
		if mesh == null:
			create_generator_data()
		
		# If not, we just need to recover the properties.
		else:
			load_generator_data()
		
		# TODO - Add boolean previews back later.
#		create_boolean_preview()
		
		# If hollow mode is on, initialize the data for it.
		if hollow_enable == true:
			_create_hollow_object()


# Used to perform some basic deallocation where necessary
func _exit_tree():
	
	print("[OnyxShape] ", self.get_name() , " - _exit_tree()")

	# Trigger this to ensure nothing is left behind.
	if Engine.editor_hint == true:
		
		editor_deselect()
		update_gizmo() # just a test, idk
		gizmo.control_points.clear()
		
		_gen_property_list.clear()
		_gen_property_values.clear()
		
		if _generator != null:
			_generator.disconnect("shape_properties_updated", self, "update_all_geometry")
			_generator.disconnect("hollow_properties_updated", self, "_update_hollow_geometry")
			_generator.disconnect("property_list_changed", self, "update_gen_property_lists")
			_generator.disconnect("request_origin_move", self, "_move_origin")
			_generator.disconnect("request_origin_change", self, "_replace_origin")
		
			remove_child(_generator)
			_generator.free()

	return
	
# This was used, maybe itll be used later
#func _notification(what):
#
#	if Engine.editor_hint == true:
#		if what == Spatial.NOTIFICATION_TRANSFORM_CHANGED:
#			if _generator != null:
#				_generator.owner_global_transform = self.global_transform

#func _editor_transform_changed():
#	pass


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# SET/GETTERS
# If you're watching this Godot developers.... this is nice and all for 
# advanced usage but... why.

func _get_property_list():
#	print("[Onyx] ", self.get_name() , " - _get_property_list()")
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
		
		# HOLLOW PRIVATE STORAGE /////
		
		{
			"name" : "hollow_mode/hollow_material",
			"type" : TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "Material"
		},
		
		{
			"name" : "hollow_mode/hollow_mesh",
			"type" : TYPE_OBJECT,
			"usage" : PROPERTY_USAGE_STORAGE,
		},
		
		# GEN PRIVATE STORAGE /////
		
		{
			"name" : "_gen_property_list",
			"type" : TYPE_DICTIONARY,
			"usage" : PROPERTY_USAGE_STORAGE,
		},
	]
	
	# Load properties from the current generator
	for property in _gen_property_list.values():
		props.append(property)
	
	
	
	return props

func _set(property, value):
#	print("[OnyxShape] ", self.get_name() , " - _set() : ", property, " ", value)
	
	# Same-value catcher.
	var old_value = self.get(property)
	if old_value != null:
		if old_value == value:
#			print("Same value assignment, BAIIIII")
			return
	
	match property:
		
		# Super-class properties /////
		"material":
			material = value
#			_update_geometry()
			return
		
		"operation":
			operation = value
#			_update_geometry()
			return
		
		# Saved internal properties /////
		
		
		# UVs /////
		
		"uv_options/uv_scale":
			uv_scale = value
			_update_geometry()
			return
			
		"uv_options/flip_uvs_horizontally":
			flip_uvs_horizontally = value
			_update_geometry()
			return
			
		"uv_options/flip_uvs_vertically":
			flip_uvs_vertically = value
			_update_geometry()
			return
		
		# Hollow Mode /////
		
		"hollow_mode/enable_hollow_mode":
			_update_hollow_enable(value)
			return
			
		"hollow_mode/hollow_material":
			_update_hollow_material(value)
			return
			
		"hollow_mode/hollow_mesh":
			hollow_mesh = value
			return
		
		# Generator /////
		
		"_gen_property_list":
			_gen_property_list = value
			return
	
	
	# Match with a generator property and save internally
	
	if _gen_property_list.has(property):
		print("attempting to set property...", property, value)
		
		if _generator != null:
			print("...succeeded!")
			_generator.set(property, value)
			
		
		else:
			_gen_property_values[property] = value
			print("...no generator, setting property values!")


func _get(property):
#	print("[OnyxShape] ", self.get_name() , " - _get() : ", property)
	match property:
		
		# Saved internal properties
		
		# UVs /////
		
		"uv_options/uv_scale":
			return uv_scale
		"uv_options/flip_uvs_horizontally":
			return flip_uvs_horizontally
		"uv_options/flip_uvs_vertically":
			return flip_uvs_vertically
		
		# Hollow Mode /////
		
		"hollow_mode/enable_hollow_mode":
			return hollow_enable
		"hollow_mode/hollow_material":
			return hollow_material
		"hollow_mode/hollow_mesh":
			return hollow_mesh
		
		# Generator /////
		
		"_gen_property_list":
			return _gen_property_list
	
	
	# Match with a generator property
	
	if _gen_property_list.has(property):
		print("attempting to get property...", property)
		
		if _generator != null:
			print("...succeeded!")
			return _generator.get(property)


# Used to prevent weird "disappearances" of the plugin.  smh...
func get_plugin():
	if Engine.editor_hint == true:
		return get_node("/root/EditorNode/Onyx")
	else:
		return null


# /////////////////////////////////////////////////////////////////////////////
# /////////////////////////////////////////////////////////////////////////////
# PRIVATE FUNCTIONS

# /////////////////////////////////////////////////////////////////////////////
# NODE ACTIVATION

# To save on load times when loading scenes, not all of the components
# required to modify the shape will be immediately loaded.  Use this function when the node
# is selected or when performing cross-node interactions to ensure that it is fully ready 
# to handle them.
#
func activate_node():
	
	if Engine.editor_hint == false || is_inside_tree() == false:
		return
	
	if _generator != null:
		return
	
	print("[OnyxShape] ", self.get_name() , " - activate_node() : ")
	
	# Make a new generator
	var script = load(GENERATOR_SCRIPTS[shape])
	_generator = script.new()
	_generator.name = GENERATOR_NODE_NAME
	self.add_child(_generator)
	print("New generator - ", _generator)
	
	# Send property list data
	_load_genenerator_properties()
	_rebuild_genenerator_property_values()
	
	# Connect signals
	_generator.connect("shape_properties_updated", self, "update_all_geometry")
	_generator.connect("hollow_properties_updated", self, "_update_hollow_geometry")
	_generator.connect("property_list_changed", self, "update_gen_property_lists")
	_generator.connect("request_origin_move", self, "_move_origin")
	_generator.connect("request_origin_change", self, "_replace_origin")
	
	# !! No need to generate mesh data, will already be present from a scene load
	
	# Update gizmo and editor property menu
	update_gizmo()
	property_list_changed_notify()

# /////////////////////////////////////////////////////////////////////////////
# GENERATOR LIFETIME FUNCTIONS

# Creates new generator data when the node is first created.
# This function should only be triggered when the node is first created.
func create_generator_data():

	if Engine.editor_hint == false || is_inside_tree() == false:
		return
	
	print("[OnyxShape] ", self.get_name() , " - create_generator_data() : ")
	
	# Make a new generator
	var script = load(GENERATOR_SCRIPTS[shape])
	_generator = script.new()
	_generator.name = GENERATOR_NODE_NAME
	self.add_child(_generator)

	# Get property lists
	_gen_property_list = _generator.get_shape_properties()
	_rebuild_genenerator_property_values()
#
#	# Connect signals
	_generator.connect("shape_properties_updated", self, "update_all_geometry")
	_generator.connect("hollow_properties_updated", self, "_update_hollow_geometry")
	_generator.connect("property_list_changed", self, "update_gen_property_lists")
	_generator.connect("request_origin_move", self, "_move_origin")
	_generator.connect("request_origin_change", self, "_replace_origin")

	# Create mesh data
	_update_geometry()
	_update_hollow_geometry()

	# Update Gizmo and Editor Property List
	update_gizmo()
	property_list_changed_notify()

	use_collision = true
	


# Populates the generator with the currently saved property data.  
# Used on scene loads.
#
# TODO - Decide if this needs to still exist.
#
func load_generator_data():

	if Engine.editor_hint == false || is_inside_tree() == false:
			return
	
	print("[OnyxShape] ", self.get_name() , " - load_generator_data() : ")
	
	
	

# Called as a SET/GETTER by generator_type to change the generator being used
func switch_generator(new_value):

	if shape == new_value:
		return
	
	if Engine.editor_hint == false || is_inside_tree() == false:
		return
	
	print("[OnyxShape] ", self.get_name() , " - switch_generator() : ")
	
	shape = new_value

	# TODO - Work out how to handle undo/redo states here
	
	
	# Drop current property backups
	_gen_property_list.clear()
	
	# Ask the generator what aspects of itself we should preserve for the next one
	var old_shape_aspects = _generator.get_shape_aspects()
	
	# Free the generator and associated properties
	_generator.disconnect("shape_properties_updated", self, "update_all_geometry")
	_generator.disconnect("hollow_properties_updated", self, "_update_hollow_geometry")
	_generator.disconnect("property_list_changed", self, "update_gen_property_lists")
	_generator.disconnect("request_origin_move", self, "_move_origin")
	_generator.disconnect("request_origin_change", self, "_replace_origin")
	remove_child(_generator)
	_generator.free()
	
	_gen_property_list.clear()
	
	# Make a new generator
	var script = load(GENERATOR_SCRIPTS[shape])
	_generator = script.new()
	_generator.name = GENERATOR_NODE_NAME
	self.add_child(_generator)
	
	# Modify property lists based on previously saved aspects
	_generator.set_shape_aspects(old_shape_aspects)
	
	# Get property lists
	_gen_property_list = _generator.get_shape_properties()
	_rebuild_genenerator_property_values()
	
	# Connect signals
	_generator.connect("shape_properties_updated", self, "update_all_geometry")
	_generator.connect("hollow_properties_updated", self, "_update_hollow_geometry")
	_generator.connect("property_list_changed", self, "update_gen_property_lists")
	_generator.connect("request_origin_move", self, "_move_origin")
	_generator.connect("request_origin_change", self, "_replace_origin")
	
	# Create mesh data
	_update_geometry()
	_update_hollow_geometry()
	
	# Update gizmo and editor property menu
	update_gizmo()
	property_list_changed_notify()


# /////////////////////////////////////////////////////////////////////////////
# GENERATOR PROPERTIES


# Builds a list of saved generator values.
# Should only be used when a generator is created for the first time.
func _rebuild_genenerator_property_values():
	
	if Engine.editor_hint == false || is_inside_tree() == false:
		return

	_gen_property_values.clear()
	
	var i = 0
	var keys = _gen_property_list.keys()
	
	while i < keys.size():
		var property = keys[i]
		var value = _generator.get(property)
		
		_gen_property_values[property] = value
		i += 1


# Feeds the generator all the properties that OnyxShape currently has saved.
func _load_genenerator_properties():
	
	if Engine.editor_hint == false || is_inside_tree() == false:
		return
	
	var i = 0
	var values = _gen_property_values.values()
	var keys = _gen_property_values.keys()
	
	while i < keys.size():
		var property = keys[i]
		var value = values[i]
		
		_generator.set(property, value)
		i += 1


# /////////////////////////////////////////////////////////////////////////////
# SIGNAL FUNCTIONS


# Triggered when the shape_properties_updated signal is received from the generator.
func update_all_geometry():
	
	print("[OnyxShape] ", self.get_name() , " - update_all_geometry()")
	
	_update_geometry()
	_update_hollow_geometry()

# Triggered when the property_list_changed signal is received from the generator. 
func update_gen_property_lists():
	_gen_property_list = _generator.get_shape_properties()
	_rebuild_genenerator_property_values()


# /////////////////////////////////////////////////////////////////////////////
# MESH UPDATERS

# Fetches up-to-date mesh data from the generator.
func _update_geometry():

	if Engine.editor_hint == false:
		return
	
	print("[OnyxShape] ", self.get_name() , " - _update_geometry()")
	
	# Get the geometry from the generator.
	var new_onyx_mesh = _generator.update_geometry()
	
	# Optional UV Modifications
	var transform_vec = uv_scale
	if transform_vec.x == 0:
		transform_vec.x = 0.0001
	if transform_vec.y == 0:
		transform_vec.y = 0.0001
	
	if flip_uvs_vertically == true:
		transform_vec.y = transform_vec.y * -1.0
	if flip_uvs_horizontally == true:
		transform_vec.x = transform_vec.x * -1.0
	
	new_onyx_mesh.multiply_uvs(transform_vec)
	
	# Create new mesh
	var array_mesh = new_onyx_mesh.render_surface_geometry(material)
	var helper = MeshDataTool.new()
	var mesh = Mesh.new()
	
	# Set the new mesh
	helper.create_from_surface(array_mesh, 0)
	helper.commit_to_surface(mesh)
	set_mesh(mesh)
	
	update_boolean_preview()
	update_gizmo()


# Internal function for updating the hollow mesh
func _update_hollow_geometry():
	
	print("[OnyxShape] ", self.get_name() , " - _update_hollow_mesh()")
	
	if Engine.editor_hint == false || hollow_object == null || hollow_enable == false:
		return
	
	# Get the geometry from the generator.
	var new_onyx_mesh = _generator.update_hollow_geometry()
	
	# Optional UV Modifications
	var transform_vec = uv_scale
	if transform_vec.x == 0:
		transform_vec.x = 0.0001
	if transform_vec.y == 0:
		transform_vec.y = 0.0001
	
	if flip_uvs_vertically == true:
		transform_vec.y = transform_vec.y * -1.0
	if flip_uvs_horizontally == true:
		transform_vec.x = transform_vec.x * -1.0
	
	new_onyx_mesh.multiply_uvs(transform_vec)
	
	# Create new mesh
	var array_mesh = new_onyx_mesh.render_surface_geometry(hollow_material)
	var helper = MeshDataTool.new()
	var mesh = Mesh.new()
	
	# Set the new mesh
	helper.create_from_surface(array_mesh, 0)
	helper.commit_to_surface(mesh)
	hollow_object.set_mesh(mesh)
	hollow_mesh = mesh
	
	update_gizmo()


# Used to create a node used for previewing the mesh when using a non-union boolean mode.
func create_boolean_preview():
	
	if Engine.editor_hint == false || is_inside_tree() == false:
		return
	
	boolean_preview_node = MeshInstance.new()
	boolean_preview_node.set_name(BOOLEAN_PREVIEW_OBJECT_NAME)
	add_child(boolean_preview_node)
	
	update_boolean_preview()


# Used to render the boolean preview.
func update_boolean_preview():
	
	if Engine.editor_hint == false || is_inside_tree() == false :
		return
	
	# If we have a boolean preview, decide what to do.
	if boolean_preview_node != null:
		
		if operation == 0:
			boolean_preview_node.visible = false
#			print("Boolean preview hidden")
			return
			
		else:
			boolean_preview_node.visible = true
			var boolean_material = null
			
			if operation == 1:
				boolean_material = load("res://addons/onyx/materials/wireframes/onyx_wireframe_int.material")
			elif operation == 2:
				boolean_material = load("res://addons/onyx/materials/wireframes/onyx_wireframe_sub.material")
			
			# Set the new mesh using the current mesh
			var helper = MeshDataTool.new()
			var boolean_mesh = Mesh.new()
			helper.create_from_surface(mesh, 0)
			helper.set_material(boolean_material)
			helper.commit_to_surface(boolean_mesh)
			
			boolean_preview_node.set_mesh(boolean_mesh)
			
#			print("Boolean preview rendered")


# /////////////////////////////////////////////////////////////////////////////
# HOLLOW MAINTENANCE FUNCTIONS

# Updates the hollow_enable property.
func _update_hollow_enable(value):
	
	if Engine.editor_hint == false:
		return
	
	# If we're not yet inside the tree, set the value and return.
	if is_inside_tree() == false:
		hollow_enable = value
		return
	
	# REMEMBER THAT SAVING A SCENE CAUSES PROPERTIES TO BE RE-APPLIED, INSURANCE POLICY
	if hollow_enable == value:
		return
	
	print("[Onyx] ", self.get_name() , " - _update_hollow_enable()")
	
	hollow_enable = value
	
	# if true, get the current class and instance it 
	if value == true:
		_create_hollow_object()
	else:
		_delete_hollow_object()
		


# Setter for hollow materials
func _update_hollow_material(value):
	
	if Engine.editor_hint == false || hollow_material == value:
		return
		
	hollow_material = value
	
	if hollow_object != null:
		hollow_object.material = value


# Creates the hollow object, won't generate new mesh data if it doesn't have to.
func _create_hollow_object():
		
	print("[Onyx] ", self.get_name() , " - _create_hollow_object()")
	
	# REMEMBER THAT RE-SAVING A SCRIPT CAUSES IT TO BE RELOADED, MUST HAVE INSURANCE POLICY
	if Engine.editor_hint == false || hollow_object != null:
#			print("Hollow object already found, returning!")
		return
	
	if has_node(HOLLOW_OBJECT_NAME):
		hollow_object = self.get_node(HOLLOW_OBJECT_NAME)
		return
	
	# Build the node
	hollow_object = CSGMesh.new()
	hollow_object.set_name(HOLLOW_OBJECT_NAME)
	add_child(hollow_object)
	
	# Check for mesh before generating one
	if hollow_mesh != null:
		hollow_object.set_mesh(hollow_mesh)
	else:
		_update_hollow_geometry()
	
	# Set the origin and operation mode
	_generator.get_hollow_origin()
	hollow_object.operation = 2
	
	# If the parent has a material, let the child inherit it.
	if hollow_material != null:
		hollow_object.material = hollow_material
	elif material != null:
		hollow_material = self.material
	
	print("new hollow object - ", hollow_object)


# Deletes the hollow object node and defaults all hollow data.
func _delete_hollow_object():
	
	print("[Onyx] ", self.get_name() , " - _delete_hollow_data()")
	
	remove_child(hollow_object)
		
	if hollow_object != null:
		hollow_object.queue_free()
		
	hollow_enable = false
	hollow_object = null
	hollow_mesh = null
	
	print("deleted hollow object - ", hollow_object)


# Creates a hollow object node when it is loaded at runtime.
func _build_runtime_hollow_object():
	
	print("[Onyx] ", self.get_name() , " - _build_runtime_hollow_object()")
	
	if Engine.editor_hint == false:
		if hollow_mesh != null:
			
			print("buildin dat hollow - ", hollow_mesh)
			hollow_object = CSGMesh.new()
			hollow_object.set_name(HOLLOW_OBJECT_NAME)
			add_child(hollow_object)
			
			hollow_object.operation = 2
			hollow_object.material = hollow_material
			hollow_object.set_mesh(hollow_mesh)
			
			print(hollow_object.mesh)

# ////////////////////////////////////////////////////////////
# GIZMO INTERFACE

# Used by ControlPointGizmo to get the currently active set of control points.
func get_gizmo_control_points() -> Array:
	
	if _generator != null:
		return _generator.active_controls.values()
	else:
		return []



# ////////////////////////////////////////////////////////////
# ORIGIN AUTO-UPDATE FUNCTIONS

# Called when the origin position anchoring switches using the
# difference in movement required to change position.
#
# Only trigger from a signal.
func _move_origin(movement_vec : Vector3):
	
	print("[OnyxShape] ", self.get_name() , " - _move_origin()")
	
	var global_t = self.global_transform
	
	var new_loc = self.global_transform.xform(self.translation + movement_vec)
	var old_loc = self.global_transform.xform(self.translation)
	var new_translation = new_loc - old_loc
	#print("MOVING LOCATION: ", old_loc, " -> ", new_loc)
	#print("TRANSLATION: ", new_translation)
	
	# set it
	global_translate(new_translation)
	translate_children(new_translation * -1)
	
	if boolean_preview_node != null:
		boolean_preview_node.set_translation(Vector3(0, 0, 0))
	


# Called when the shape has changed and the origin needs to move
# into the correct position, using the movement difference.
#
# Only trigger from a signal.
func _replace_origin(new_loc : Vector3):
	
	print("[OnyxShape] ", self.get_name() , " - _move_origin()")

	var old_loc = self.global_transform.origin
	var new_translation = new_loc - old_loc
	
	# set it
	global_translate(new_translation)
	translate_children(new_translation * -1)
	
	if boolean_preview_node != null:
		boolean_preview_node.set_translation(Vector3(0, 0, 0))
	


# ////////////////////////////////////////////////////////////
# EDITOR SELECTION

func editor_select():
	if Engine.editor_hint == true:
		is_selected = true
		activate_node()
		_generator.build_controls()
		_generator.editor_select()
	
	
func editor_deselect():
	if Engine.editor_hint == true:
		is_selected = false
		
		if _generator != null:
			_generator.clear_controls()
			_generator.editor_deselect()


# ////////////////////////////////////////////////////////////
# CHILD MANAGEMENT
func translate_children(translation):
	
#	print("[Onyx] ", self.get_name() , " - translate_children()")
	
	for child in get_children():
		if child.name != _generator.name:
			child.global_translate(translation)
