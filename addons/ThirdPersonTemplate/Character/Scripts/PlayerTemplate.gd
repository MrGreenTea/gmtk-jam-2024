extends CharacterBody3D

signal target_shot(target_collider)
@onready var signal_handler = get_node("/root/AutoloadSignals")
signal target_hit(target_collider)

# Grabs the prebuilt AnimationTree 
@onready var PlayerAnimationTree = $AnimationTree.get_path()
@onready var animation_tree = get_node(PlayerAnimationTree)
@onready var playback = animation_tree.get("parameters/playback")

# Allows to pick your chracter's mesh from the inspector
@export_node_path("Node3D") var PlayerCharacterMesh: NodePath
@onready var player_mesh = get_node(PlayerCharacterMesh)

@onready var crosshair = $Crosshair

# Gamplay mechanics and Inspector tweakables
@export var gravity = 9.8
@export var jump_force = 9
@export var walk_speed = 1.3
@export var run_speed = 5.5
@export var dash_power = 12 # Controls roll and big attack speed boosts
@export var scale_rate = 1.01
@export var scale_rate_shoot = 1.01
@export var scale_rate_hit_enemy = 0.98
@export var hp_max = 25
@onready var hp_cur = hp_max
@export var shots_per_second = 2
# start with a high enough number
var time_since_last_shot = 1 / shots_per_second + 1

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
var is_attacking = bool()
var is_rolling = bool()
var is_walking = bool()
var is_running = bool()

# Physics values
var direction = Vector3()
var horizontal_velocity = Vector3()
var aim_turn = float()
var movement = Vector3()
var vertical_velocity = Vector3()
var movement_speed = int()
var angular_acceleration = int()
var acceleration = int()

var prev_camera_offset = Vector3()

enum WEAPON_MODE { SHRINK, GROW }
var weapon_mode: WEAPON_MODE = WEAPON_MODE.SHRINK

func _ready(): # Camera based Rotation
	direction = Vector3.BACK.rotated(Vector3.UP, $Camroot/h.global_transform.basis.get_euler().y)
	if animation_tree.anim_player == null:
		animation_tree.anim_player = player_mesh.get_node("AnimationPlayer")
		
	signal_handler.connect("player_shot", _on_player_shot)
	$Health.max_value = hp_max
	$Health.value = hp_cur
	
func _input(event): # All major mouse and button input events
	if event is InputEventMouseMotion:
		aim_turn = -event.relative.x * 0.015 # animates player with mouse movement while aiming 
	
	if event.is_action_pressed("aim"): # Aim button triggers a strafe walk and camera mechanic
		direction = $Camroot/h.global_transform.basis.z

func sprint_and_roll():
## Dodge button input with dash and interruption to basic actions
	if Input.is_action_just_pressed("sprint"):
		if !roll_node_name in playback.get_current_node() and !jump_node_name in playback.get_current_node() and !bigattack_node_name in playback.get_current_node():
			$DashTimer.start()
		
	if Input.is_action_just_released("sprint") and !$DashTimer.is_stopped():
		$DashTimer.stop()
		playback.start(roll_node_name) #"start" not "travel" to speedy teleport to the roll!
		horizontal_velocity = direction * dash_power
		is_rolling = true
		
func shoot():
	var shooting = Input.is_action_pressed("attack")
	if shooting and time_since_last_shot >= 1 / shots_per_second:
		time_since_last_shot = 0
		self.scale *= scale_rate_shoot
		
		var camera_camera = $Camroot/h/v/Camera3D
		var ch_pos = crosshair.position + crosshair.size * 0.5
		var ray_from = camera_camera.project_ray_origin(ch_pos)
		var ray_dir = camera_camera.project_ray_normal(ch_pos)

		var col = get_parent().get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray_from, ray_from + ray_dir * 1000, 0b11, [self]))
		if not col.is_empty():
			var shoot_target = col.position
			var target_collider = col["collider"]
			target_hit.emit(col)
			target_shot.emit(col)
			var collider_name = target_collider.name
			
			print("Hit! ", target_collider)
			if (not "Floor" in collider_name) and target_collider is ScalableRigidBody3D:
				match weapon_mode:
					WEAPON_MODE.SHRINK:
						target_collider._scale(0.9)
					WEAPON_MODE.GROW:
						target_collider._scale(1.1)
			elif target_collider.is_in_group("Enemies"):
				target_collider.scale = target_collider.scale * 1.1
				self.scale *= scale_rate_hit_enemy
			
	
			var new_mesh = MeshInstance3D.new()
			new_mesh.mesh = SphereMesh.new()
			new_mesh.transform.origin = shoot_target
			new_mesh.scale = Vector3.ONE * 0.1
			var level = get_node("..")
			level.add_child(new_mesh)
			await get_tree().create_timer(3).timeout
			new_mesh.queue_free()
		
func attack1(): # If not doing other things, start attack1
	if (idle_node_name in playback.get_current_node() or walk_node_name in playback.get_current_node()) and is_on_floor():
		if Input.is_action_pressed("attack"):
			shoot()
			if (is_attacking == false):
				playback.travel(attack1_node_name)
				
func attack2(): # If attack1 is animating, combo into attack 2
	if attack1_node_name in playback.get_current_node(): # Big Attack if sprinting, adds a dash
		if Input.is_action_just_pressed("attack"):
			playback.travel(attack2_node_name)
			
func attack3(): # If attack2 is animating, combo into attack 3. This is a template.
	if attack1_node_name in playback.get_current_node(): 
		if Input.is_action_just_pressed("attack"):
			pass #no current animation, but add it's playback here!
	
func rollattack(): # If attack pressed while rolling, do a special attack afterwards.
	if roll_node_name in playback.get_current_node(): 
		if Input.is_action_just_pressed("attack"):
			playback.travel(rollattack_node_name) #change this animation for a different attack
			
func bigattack(): # If attack pressed while springing, do a special attack
	if run_node_name in playback.get_current_node(): # Big Attack if sprinting, adds a dash
		if Input.is_action_just_pressed("attack"):
			horizontal_velocity = direction * dash_power
			playback.travel(bigattack_node_name) #Add and Change this animation node for a different attack

func _on_player_shot():
	hp_cur -= 1
	print("Player shot! Current life: ", hp_cur)
	self.scale *= 1.1

func _scaled(value, scale=self.scale):
	return scale * value

func _physics_process(delta):
	if Input.is_action_just_pressed("switch_action"):
		if weapon_mode == WEAPON_MODE.SHRINK:
			weapon_mode = WEAPON_MODE.GROW
			$WeaponMode.text = "GROW"
		elif weapon_mode == WEAPON_MODE.GROW:
			weapon_mode = WEAPON_MODE.SHRINK
			$WeaponMode.text = "SHRINK"
		else:
			print("Warning, unknown weapon mode: ", weapon_mode)
	
	$Health.value = hp_cur
	if hp_cur <= 0:
		die_and_restart()
	time_since_last_shot += delta
	rollattack()
	bigattack()
	attack1()
	attack2()
	attack3()
	sprint_and_roll()
	
	var on_floor = is_on_floor() # State control for is jumping/falling/landing
	var h_rot = $Camroot/h.global_transform.basis.get_euler().y
	
	movement_speed = 0
	angular_acceleration = 10
	acceleration = 15

	# Gravity mechanics and prevent slope-sliding
	if not is_on_floor(): 
		vertical_velocity += Vector3.DOWN * gravity * 2 * delta
	else: 
		#vertical_velocity = -get_floor_normal() * gravity / 3
		vertical_velocity = Vector3.DOWN * gravity / 10
	
	# Defining attack state: Add more attacks animations here as you add more!
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
	
#	Jump input and Mechanics
	if Input.is_action_just_pressed("jump") and ((is_attacking != true) and (is_rolling != true)) and is_on_floor():
		vertical_velocity = Vector3.UP * _scaled(jump_force, sqrt(self.scale[0]))
		
	# Movement input, state and mechanics. *Note: movement stops if attacking
	if (Input.is_action_pressed("forward") ||  Input.is_action_pressed("backward") ||  Input.is_action_pressed("left") ||  Input.is_action_pressed("right")):
		direction = Vector3(Input.get_action_strength("left") - Input.get_action_strength("right"),
					0,
					Input.get_action_strength("forward") - Input.get_action_strength("backward"))
		direction = direction.rotated(Vector3.UP, h_rot).normalized()
		is_walking = true
		
	# Sprint input, dash state and movement speed
		if Input.is_action_pressed("sprint") and $DashTimer.is_stopped() and (is_walking == true ):
			movement_speed = run_speed
			is_running = true
		else: # Walk State and speed
			movement_speed = walk_speed
			is_running = false
	else: 
		is_walking = false
		is_running = false
	
	if Input.is_action_pressed("aim"):  # Aim/Strafe input and  mechanics
		player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, $Camroot/h.rotation.y, delta * angular_acceleration)
	if Input.is_action_just_pressed("aim"):
		$Camroot/AnimationPlayer.play("aim")
	if Input.is_action_just_released("aim"):
		$Camroot/AnimationPlayer.play_backwards("aim")

	else: # Normal turn movement mechanics
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
	
	# scale over time (WARNING: this crashes Amons PC)
	# self.scale *= scale_rate * delta 
	
	move_and_slide()
	
	
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

func die_and_restart():
	$GameOver.visible = true
	await get_tree().create_timer(3).timeout
	get_tree().reload_current_scene()

func _on_world_boundary_body_exited(body: Node3D) -> void:
	if body == self:
		die_and_restart()


func _on_scene_enemy_killed(enemy: Node3D) -> void:
	if self.scale.length() > 0.5	:
		self.scale /= scale_rate_shoot * 3
	self.position += Vector3.UP * 0.1
