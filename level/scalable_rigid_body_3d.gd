class_name ScalableRigidBody3D extends RigidBody3D

@export var scale_rate = 0.01
@export var mesh : MeshInstance3D
@export var collision_shape : CollisionShape3D

# Called when the node enters the scene tree for the first time.
func _ready():
	if not mesh:
		mesh = $MeshInstance3D
	if not collision_shape:
		collision_shape = $CollisionShape3D


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	_scale(1 - scale_rate * delta)
	#$MeshInstance3D.scale = $MeshInstance3D.scale * (1 - scale_rate * delta)
	#$CollisionShape3D.shape.radius = $CollisionShape3D.shape.radius * (1 - scale_rate * delta)
	# self.scale = self.scale * (1 - scale_rate * delta)
	# self.add_constant_central_force(Vector3.RIGHT * 9.81)
	
func _scale(scale_fac):
	mesh.scale = mesh.scale * scale_fac
	
	if collision_shape.shape is SphereShape3D:
		collision_shape.shape.radius *= scale_fac
	elif collision_shape.shape is BoxShape3D:
		collision_shape.shape.size *= scale_fac
	elif collision_shape.shape is CylinderShape3D or collision_shape.shape is CapsuleShape3D:
		collision_shape.shape.height *= scale_fac
		collision_shape.shape.radius *= scale_fac
	else:
		print("Collision shape not implemented! ", $CollisionShape3D)
