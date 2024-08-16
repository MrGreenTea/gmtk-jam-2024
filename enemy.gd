extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@onready var target = get_node("/root/Main/NavigationRegion3D/Target")

func _ready():
	print(self.get_path())

func _physics_process(delta):
	
	print(target)
	if target != null:
		var target_pos = target.position
		print(target_pos)
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

	move_and_slide()
