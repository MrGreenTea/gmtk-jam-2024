extends Node3D

@onready var start_time = Time.get_unix_time_from_system()
@onready var timer_label: Label = $SurvivalTime

signal enemy_killed(enemy: Node3D)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func seconds_to_timer(time: float) -> String:
	var minutes = time / 60
	var seconds = fmod(time, 60)
	return "%02d:%02d" % [minutes, seconds]

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var elapsed_time = Time.get_unix_time_from_system() - start_time
	timer_label.text = seconds_to_timer(elapsed_time)
