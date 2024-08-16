extends CharacterBody3D

const VIEW_RANGE = 1.5
const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# @onready var target = get_node("/root/Main/NavigationRegion3D/Target")
@export var target : Node3D

func _ready():
	print(self.get_path())

func _physics_process(delta):
	
	if target != null:
		var target_pos = target.position
	else:
		print("Target is null")
		
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	# var direction = (transform.basis * Vector3(1.0, 0, 0)).normalized()
	var direction = (target.position - self.position).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	# rotate towards player
	look_at(target.global_position)
	
	move_and_slide()
	player_visible()

func player_visible():
	var direction = target.position - self.position
	var forward_dir = -self.transform.basis.z
	print("Forward dir", forward_dir)
	var dot_product = direction.dot(forward_dir)
	print("Dot product", dot_product)
	
	if player_not_hidden():
		print("I see player")
	else:
		print("Where are you?")

func player_not_hidden():
	var space_state = get_world_3d().direct_space_state
	var from = self.global_position
	var to = target.global_position
	var query = PhysicsRayQueryParameters3D.create(from, to, 1, [self])
	var result = space_state.intersect_ray(query)
	print("collding result: ", result)
	if (result):
		if result.collider == target:
			return true
		else:
			print("Colliding with", result.collider)
			return false
			
