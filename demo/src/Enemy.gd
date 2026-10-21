extends CharacterBody3D
## Enemy that chases a target using NavigationAgent3D.
## Works with a plain Node3D parent (no parent script required).

const RETARGET_COOLDOWN: float = 1.0
const GRAVITY: float = 30.0

@export var MOVE_SPEED: float = 4.0
## Drag the Player here. If left empty, the first node in group "player" is used.
@export var target: Node3D
## Optional: drag your Terrain3D node here to stop the enemy falling through
## the terrain if it has no collision.
@export var terrain: Terrain3D

var nav_agent: NavigationAgent3D
var _retarget_timer: float = RETARGET_COOLDOWN


func _ready() -> void:
	_ensure_children()
	nav_agent.velocity_computed.connect(_on_velocity_computed)


## Creates the NavigationAgent3D / CollisionShape3D / mesh if they were not added in the editor.
func _ensure_children() -> void:
	nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav_agent == null:
		nav_agent = NavigationAgent3D.new()
		nav_agent.name = "NavigationAgent3D"
		add_child(nav_agent)

	var has_shape := false
	var has_mesh := false
	for child in get_children():
		if child is CollisionShape3D:
			has_shape = true
		elif child is MeshInstance3D:
			has_mesh = true

	if not has_shape:
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.4
		capsule.height = 1.8
		shape.shape = capsule
		shape.position.y = 0.9
		add_child(shape)

	if not has_mesh:
		var mesh_instance := MeshInstance3D.new()
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = 0.4
		capsule_mesh.height = 1.8
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.15, 0.15)
		capsule_mesh.material = mat
		mesh_instance.mesh = capsule_mesh
		mesh_instance.position.y = 0.9
		add_child(mesh_instance)


func _process(p_delta: float) -> void:
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Node3D

	_retarget_timer += p_delta
	if _retarget_timer > RETARGET_COOLDOWN and target:
		# Don't reset the target position every frame. It triggers an A* search, which is expensive.
		_retarget_timer = 0.0
		nav_agent.set_target_position(target.global_position)


func is_on_nav_mesh() -> bool:
	var closest_point := NavigationServer3D.map_get_closest_point(nav_agent.get_navigation_map(), global_position)
	return global_position.distance_squared_to(closest_point) < nav_agent.path_max_distance ** 2


func _physics_process(p_delta: float) -> void:
	if nav_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var next_path_position: Vector3 = nav_agent.get_next_path_position()
		var direction := next_path_position - global_position
		direction.y = 0.0
		var velocity_xz := direction.normalized() * MOVE_SPEED
		velocity.x = velocity_xz.x
		velocity.z = velocity_xz.z

		# Face the direction of travel
		if direction.length_squared() > 0.001:
			var look_target := global_position + direction
			look_at(look_target, Vector3.UP)

	velocity.y -= GRAVITY * p_delta

	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(velocity)
	else:
		_on_velocity_computed(velocity)

	# Ensure enemy doesn't fall through terrain when collision is absent
	if terrain and terrain.data:
		var height: float = terrain.data.get_height(global_position)
		if not is_nan(height) and global_position.y < height:
			global_position.y = height
			velocity.y = 0.0


func _on_velocity_computed(p_safe_velocity: Vector3) -> void:
	velocity.x = p_safe_velocity.x
	velocity.z = p_safe_velocity.z
	move_and_slide()
