extends CharacterBody3D

# signal handler
@onready var signal_handler = get_node("/root/AutoloadSignals")

# local signals
# signal delete_me

# Grabs the prebuilt AnimationTree 
@onready var PlayerAnimationTree = $AnimationTree.get_path()
@onready var animation_tree = get_node(PlayerAnimationTree)
@onready var playback = animation_tree.get("parameters/playback")

# Allows to pick your chracter's mesh from the inspector
@export_node_path("Node3D") var PlayerCharacterMesh: NodePath
@onready var player_mesh = get_node(PlayerCharacterMesh)

# enemy mechanics
@export var target_character_with_collisionshape3d : Node3D
@export var world_boundary : Area3D

# debugging flags
@export var spawn_target_pos: bool = false
@export var print_debug: bool = false

var target_last_position = Vector3()
var target_ever_seen = false
@onready var target_location_node = target_character_with_collisionshape3d.get_node("CollisionShape3D")
@onready var target = target_character_with_collisionshape3d
@onready var eyes = player_mesh.get_node("Eyes")
@onready var eyes_camera = player_mesh.get_node("Eyes/Camera3D")
@onready var player_camera = target_character_with_collisionshape3d.get_node("Camroot").get_node("h/v/Camera3D")
@onready var weapon = player_mesh.get_node("Weapon")
@onready var my_collision_shape = self.get_node("CollisionShape3D")

# Gamplay mechanics and Inspector tweakables
@export var gravity = 9.8
@export var jump_force = 9
@export var walk_speed = 1.3
@export var run_speed = 5.5
@export var dash_power = 12 # Controls roll and big attack speed boosts
@export var view_range = 30
@export var shoot_range = 10
@export var max_scale_slap = 3
@export var slap_multiplier = 100
@export var slap_drag = 0.1

@onready var shoot_timer = get_node("Walk With Rifle/Weapon/BulletRateTimer")
@onready var shoot_freeze_timer = get_node("ShootingFreezeTimer")
@onready var scale_slap_timer = get_node("ScaleSlapTimer")
var shoot_ready = true
var scale_slap_ready = true
var rnd_generator = RandomNumberGenerator.new()

@export var max_health = 10;
var current_health = max_health;

# Animation node names
var roll_node_name = "Roll"
var idle_node_name = "Idle"
var walk_node_name = "Walk"
var run_node_name = "Run"
var jump_node_name = "Jump"
var attack1_node_name = "Attack1"
var attack2_node_name = "Attack2"
var bigattack_node_name = "BigAttack"
var rollattack_node_name = "RollAttack"

# Condition States
var is_shooting = bool()
var is_attacking = bool()
var is_rolling = bool()
var is_walking = bool()
var is_running = bool()
var hit_recently = bool()
var is_dead = bool()

# Physics values
var direction = Vector3()
var horizontal_velocity = Vector3()
var aim_turn = float()
var movement = Vector3()
var vertical_velocity = Vector3()
var slap_velocity = Vector3()
var movement_speed = int()
var angular_acceleration = int()
var acceleration = int()

func _ready(): # Camera based Rotation
	# var player_script = get_node("PlayerTemplate")
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	shoot_freeze_timer.timeout.connect(_on_shoot_freeze_timer_timeout)
	scale_slap_timer.timeout.connect(_on_scale_slap_timer_timeout)
	world_boundary.body_exited.connect(_on_exit_world_boundary)
	
	if not spawn_target_pos:
		$TargetPosDebugMarker.visible = false

func get_slap_force():
	if scale_slap_ready and self.scale[0] >= max_scale_slap:
		print("Enemy will get slapped")
		var slap_force_base = Vector3(1, 1, 0)
		var rnd_angle = rnd_generator.randf() * TAU
		var slap_force = slap_force_base.rotated(Vector3.UP, rnd_angle) * self.scale
		slap_force *= slap_multiplier
		scale_slap_ready = false
		scale_slap_timer.start()
		return slap_force
	return Vector3.ZERO
		
func shoot():
	var direction = target_location_node.global_position - self.global_position
	var distance_to_target = direction.length()
	if distance_to_target < shoot_range:
		player_mesh.rotation.y = atan2(direction.x, direction.z) - rotation.y
		var shoot_source = weapon.global_position
		var shoot_target = target_location_node.global_position
		var result = collider_ray(shoot_source, shoot_target)
		
		if not result.is_empty():
			if result.collider == target:
				if shoot_ready:
					is_shooting = true
					shoot_ready = false
					signal_handler.emit_signal("player_shot")
					shoot_timer.start()
					shoot_freeze_timer.start()
			
func target_assumed_position():
	var _target_in_viewport = target_in_viewport() 
	var _target_in_range = target_in_range() 
	var _target_not_hidden_by_object = target_not_hidden_by_object() 
	
	if _target_in_range and _target_in_viewport and _target_not_hidden_by_object:
		target_ever_seen = true
		target_last_position = target.global_position
	
	$TargetPosDebugMarker.global_position = target_last_position
	
	if target_ever_seen:
		return target_last_position
	else:
		return self.global_position

func direction_towards_target():
	if hit_recently:
		hit_recently = false
		return (target.global_position - self.global_position).normalized()
	var direction = target_assumed_position() - self.global_position
	return direction

func target_in_range():
	var distance = target_location_node.global_position - self.eyes.global_position
	return distance.length() < view_range

func target_in_viewport():
	return eyes_camera.is_position_in_frustum(target_location_node.global_position)

func collider_ray(from, to):
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to, 1, [self])
	query.set_collide_with_areas(true)
	
	return space_state.intersect_ray(query)

func target_not_hidden_by_object():
	var from = self.eyes.global_position
	var to = target_location_node.global_position
	
	var result = collider_ray(from, to)
	if (result):
		if result.collider == target:
			return true
		else:
			return false
	else:
		_print("No collisions at all! query is null")
		return true
		
func delete_if_outside_world_boundary():
	var overlaps = world_boundary.get_overlapping_areas()
	print(world_boundary.overlaps_body(my_collision_shape))
	if not world_boundary.overlaps_body(my_collision_shape):
		print("Enemy killed")
		# queue_free()
			
func sprint_and_roll():
## Dodge button input with dash and interruption to basic actions
	pass
	#if Input.is_action_just_pressed("sprint"):
		#if !roll_node_name in playback.get_current_node() and !jump_node_name in playback.get_current_node() and !bigattack_node_name in playback.get_current_node():
			#$DashTimer.start()
		#
	#if Input.is_action_just_released("sprint") and !$DashTimer.is_stopped():
		#$DashTimer.stop()
		#playback.start(roll_node_name) #"start" not "travel" to speedy teleport to the roll!
		#horizontal_velocity = direction * dash_power
		#is_rolling = true
		

		
func attack1(): # If not doing other things, start attack1
	pass
	#if (idle_node_name in playback.get_current_node() or walk_node_name in playback.get_current_node()) and is_on_floor():
		#if Input.is_action_just_pressed("attack"):
			#if (is_attacking == false):
				#playback.travel(attack1_node_name)
				
func attack2(): # If attack1 is animating, combo into attack 2
	pass
	#if attack1_node_name in playback.get_current_node(): # Big Attack if sprinting, adds a dash
		#if Input.is_action_just_pressed("attack"):
			#playback.travel(attack2_node_name)
			
func attack3(): # If attack2 is animating, combo into attack 3. This is a template.
	pass
	#if attack2_node_name in playback.get_current_node(): 
		#if Input.is_action_just_pressed("attack"):
			#pass #no current animation, but add it's playback here!
	
func rollattack(): # If attack pressed while rolling, do a special attack afterwards.
	pass
	#if roll_node_name in playback.get_current_node(): 
		#if Input.is_action_just_pressed("attack"):
			#playback.travel(rollattack_node_name) #change this animation for a different attack
			
func bigattack(): # If attack pressed while springing, do a special attack
	pass
	#if run_node_name in playback.get_current_node(): # Big Attack if sprinting, adds a dash
		#if Input.is_action_just_pressed("attack"):
			#horizontal_velocity = direction * dash_power
			#playback.travel(bigattack_node_name) #Add and Change this animation node for a different attack

func _scaled(value, scale=self.scale):
	return scale * value
	
func _on_shoot_timer_timeout():
	_print("Ready to shoot")
	shoot_ready = true

func _on_shoot_freeze_timer_timeout():
	is_shooting = false
	
func _on_scale_slap_timer_timeout():
	scale_slap_ready = true

func _on_exit_world_boundary(object):
	if object == self:
		print("Enemy killed!")
		self.queue_free()

func _print(str):
	if print_debug:
		print(str)

func _physics_process(delta):
	if is_dead:
		return
	rollattack()
	bigattack()
	attack1()
	attack2()
	attack3()
	sprint_and_roll()
	shoot()
	
	var on_floor = is_on_floor() # State control for is jumping/falling/landing
	# var h_rot = $Camroot/h.global_transform.basis.get_euler().y
	
	angular_acceleration = 10
	acceleration = 15

	if is_walking:
		movement_speed = walk_speed
	elif is_running:
		movement_speed = run_speed
	else:
		movement_speed = 0
		
	# Gravity mechanics and prevent slope-sliding
	if not is_on_floor(): 
		vertical_velocity += Vector3.DOWN * gravity * 2 * delta
	else: 
		#vertical_velocity = -get_floor_normal() * gravity w/ 3
		vertical_velocity = Vector3.DOWN * gravity / 10
	
	# Defining attack state: Add more attacks animations here as you add more!
	# TODO: add shooting animation here to replace timeout
	if (attack1_node_name in playback.get_current_node()) or (attack2_node_name in playback.get_current_node()) or (rollattack_node_name in playback.get_current_node()) or (bigattack_node_name in playback.get_current_node()): 
		is_attacking = true
	else: 
		is_attacking = false

# Giving BigAttack some Slide
	if bigattack_node_name in playback.get_current_node(): 
		acceleration = 3

	# Defining Roll state and limiting movment during rolls
	if roll_node_name in playback.get_current_node(): 
		is_rolling = true
		acceleration = 2
		angular_acceleration = 2
	else: 
		is_rolling = false
		
	direction = direction_towards_target()
	
	# TODO: Running rule, idle rule
	if is_shooting:
		_print("Enemy shooting")
		is_walking = false
		is_running = false
	else:
		_print("Enemy walking")
		is_walking = true
		is_running = true
	
	if direction.length() < 0.1:
		_print("Enemy at assumed target, stopping")
		is_walking = false
		is_running = false
		direction = Vector3.ZERO
	
	if is_running:
		movement_speed = run_speed
	elif is_walking:
		movement_speed = walk_speed
	else:
		movement_speed = 0
	
	#else: # Normal turn movement mechanics
	player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, atan2(direction.x, direction.z) - rotation.y, delta * angular_acceleration)
	
	# Movment mechanics with limitations during rolls/attacks
	if ((is_attacking == true) or (is_rolling == true)): 
		horizontal_velocity = horizontal_velocity.lerp(direction.normalized() * .01 , acceleration * delta)
	else: # Movement mechanics without limitations 
		horizontal_velocity = horizontal_velocity.lerp(direction.normalized() * _scaled(movement_speed), acceleration * delta)
	
	# The Physics Sauce. Movement, gravity and velocity in a perfect dance.
	velocity.z = horizontal_velocity.z + vertical_velocity.z
	velocity.x = horizontal_velocity.x + vertical_velocity.x
	velocity.y = vertical_velocity.y
	
	# get slapped
	slap_velocity = get_slap_force() + (1 - slap_drag * delta) * slap_velocity 
	velocity += slap_velocity
	
	move_and_slide()

	# killed?
	# delete_if_outside_world_boundary()
	
	# viewport debugging
	if Input.is_action_pressed("show_enemy_viewport"):
		eyes_camera.make_current()
	else:
		player_camera.make_current()
		
	# ========= State machine controls =========
	# The booleans of the on_floor, is_walking etc, trigger the 
	# advanced conditions of the AnimationTree, controlling animation paths
	
	# on_floor manages jumps and falls
	animation_tree["parameters/conditions/IsOnFloor"] = on_floor
	animation_tree["parameters/conditions/IsInAir"] = !on_floor
	# Moving and running respectively
	animation_tree["parameters/conditions/IsWalking"] = is_walking
	animation_tree["parameters/conditions/IsNotWalking"] = !is_walking
	animation_tree["parameters/conditions/IsRunning"] = is_running
	animation_tree["parameters/conditions/IsNotRunning"] = !is_running
	# Attacks and roll don't use these boolean conditions, instead
	# they use "travel" or "start" to one-shot their animations.
	
	
func hit(damage: float):
	hit_recently = true
	current_health = clamp(current_health - damage, 0, max_health)
	print("Health: ", current_health, "/", max_health, " after ", damage, " damage")
	if current_health <= 0:
		is_dead = true
		playback.travel("Death")
		await get_tree().create_timer(30).timeout
		queue_free()
