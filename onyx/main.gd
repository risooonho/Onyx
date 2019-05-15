tool
extends EditorPlugin

# ////////////////////////////////////////////////////////////
# PROPERTIES

# Core node types
const OnyxCube = preload("./nodes/onyx/onyx_cube.gd")
const OnyxCylinder = preload("./nodes/onyx/onyx_cylinder.gd")
const OnyxSphere = preload("./nodes/onyx/onyx_sphere.gd")
const OnyxWedge = preload("./nodes/onyx/onyx_wedge.gd")
const OnyxRamp = preload("./nodes/onyx/onyx_ramp.gd")
const OnyxRoundedRect = preload("./nodes/onyx/onyx_rounded_cube.gd")
const OnyxStairs = preload("./nodes/onyx/onyx_stairs.gd")

const FluxArea  = preload("./nodes/flux/flux_area.gd")
const FluxCollider  = preload("./nodes/flux/flux_collider.gd")

const ResTest = preload('./nodes/res_test.gd')

const NodeHandlerList = [OnyxCube, OnyxCylinder, OnyxSphere, OnyxWedge, OnyxRoundedRect, OnyxStairs, OnyxRamp, FluxArea, FluxCollider]
const NodeStrings = ['OnyxCube', 'OnyxCylinder', 'OnyxSphere', 'OnyxWedge', 'OnyxRoundedRect', 'OnyxStairs', 'FluxArea', 'FluxCollider']

# Gizmo types
const OnyxGizmoPlugin = preload("res://addons/Onyx/gizmos/onyx_gizmo_plugin.gd")
var gizmo_plugin : OnyxGizmoPlugin


# Wireframe material types
const WireframeCollision_Selected = Color(1, 1, 0, 0.8)
const WireframeCollision_Unselected = Color(1, 1, 0, 0.1)

const WireframeUtility_Selected = Color(0, 1, 1, 0.6)
const WireframeUtility_Unselected = Color(0, 1, 1, 0.05)


# Selection management
var currently_selected_node = null

# ////////////////////////////////////////////////////////////
# FUNCTIONS

func _enter_tree():
	
	#print("ONYX enter_tree")
	
	# Give this node a name so any other node can access it using "node/EditorNode/Onyx"
	name = "Onyx"
	
    # Initialization of the plugin goes here
	gizmo_plugin = OnyxGizmoPlugin.new(self)
	add_spatial_gizmo_plugin(gizmo_plugin)
	print(gizmo_plugin)
	
	# onyx types
	add_custom_type("OnyxCube", "CSGMesh", preload("./nodes/onyx/onyx_cube.gd"), preload("res://addons/onyx/ui/nodes/onyx_block.png"))
	add_custom_type("OnyxCylinder", "CSGMesh", preload("./nodes/onyx/onyx_cylinder.gd"), preload("res://addons/onyx/ui/nodes/onyx_block.png"))
	add_custom_type("OnyxSphere", "CSGMesh", preload("./nodes/onyx/onyx_sphere.gd"), preload("res://addons/onyx/ui/nodes/onyx_block.png"))
	add_custom_type("OnyxWedge", "CSGMesh", preload("./nodes/onyx/onyx_wedge.gd"), preload("res://addons/onyx/ui/nodes/onyx_block.png"))
	add_custom_type("OnyxRamp", "CSGMesh", preload("./nodes/onyx/onyx_ramp.gd"), preload("res://addons/onyx/ui/nodes/onyx_block.png"))
	add_custom_type("OnyxRoundedCube", "CSGMesh", preload("./nodes/onyx/onyx_rounded_cube.gd"), preload("res://addons/onyx/ui/nodes/onyx_block.png"))
	add_custom_type("OnyxStairs", "CSGMesh", preload("./nodes/onyx/onyx_stairs.gd"), preload("res://addons/onyx/ui/nodes/onyx_block.png"))
	
	# flux types
	#add_custom_type("FluxArea", "CSGCombiner", preload("./nodes/flux/flux_area.gd"), preload("res://addons/onyx/ui/nodes/onyx_sprinkle.png"))
	#add_custom_type("FluxCollider", "StaticBody", preload("./nodes/flux/flux_collider.gd"), preload("res://addons/onyx/ui/nodes/onyx_fence.png"))
	
	# debug types
	#add_custom_type("ResTest", "CSGMesh",preload('./nodes/res_test.gd'), preload("res://addons/onyx/ui/nodes/onyx_fence.png"))
	
	# Add custom signals for providing GUI click input.
	add_user_signal("onyx_viewport_clicked", [{"camera": TYPE_OBJECT} , {"event": TYPE_OBJECT}] )
	


# ////////////////////////////////////////////////////////////
# EDITOR SELECTION

# Used to tell Godot that we want to handle these objects when they're selected.
func handles(object):
	
	#print("ONYX handles")
	
	for handled_object in NodeHandlerList:
		if object is handled_object:
			return true
#
	return false
	
	
# Returns a boolean when one of your handled object types is either selected or deselected.
# Calls a custom function to setup custom functionality.
func make_visible(is_visible):
	
	#print("ONYX make_visible")
	
	# If the node we had is no longer visible and we were given no other nodes,
	# we have to deselect it just to be careful.
	if currently_selected_node != null && is_visible == false:
		currently_selected_node.editor_deselect()
		currently_selected_node = null
	

# Receives the objects we have allowed to handle under the handles(object) function.
# Calls a custom function to setup custom functionality.
func edit(object):
	
	#print("ONYX edit")
	
	currently_selected_node = object
	currently_selected_node.editor_select()
	
	
# ////////////////////////////////////////////////////////////
# CUSTOM UI

# Adds a toolbar to the spatial toolbar area.
func add_toolbar(control_path):
	var new_control = load(control_path).instance()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, new_control)
	return new_control
	
	
# Removes a toolbar to the spatial toolbar area.
func remove_toolbar(control):
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, control)


# Forwards 3D View screen inputs to you whenever you use the handles(object) function
# to tell Godot that you're handling a selected node.
func forward_spatial_gui_input(camera, ev):
	emit_signal("onyx_viewport_clicked", camera, ev)
	
	

# No idea what this did, not part of the EditorPlugin API atm
#func bind_event(ev):
#	print(ev)


func _exit_tree():
    # Clean-up of the plugin goes here
	for string in NodeStrings:
		remove_custom_type(string)
	remove_spatial_gizmo_plugin(gizmo_plugin)
	pass
	
	