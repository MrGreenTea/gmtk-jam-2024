extends Node3D

@export var radius: int
@export var enemy: PackedScene
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_spawner_timer_timeout() -> void:
	print("Spawn Enemy")
	var new_enemy: Node3D = enemy.instantiate()
	new_enemy.target_character_with_collisionshape3d = get_node("../Player")
	get_parent().add_child(new_enemy)
	new_enemy.global_position = self.global_position + Vector3.RIGHT * randf_range(-radius, radius) + Vector3.FORWARD * randf_range(-radius, radius)
