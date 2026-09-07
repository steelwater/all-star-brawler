class_name HumanFighterController
extends FighterController

var input_player := 1


func configure(new_input_player: int) -> void:
	input_player = new_input_player


func get_command(_delta: float) -> FighterCommand:
	var command := FighterCommand.new()
	command.move_axis = _axis("left", "right")
	command.jump = _just_pressed("jump")
	command.attack = _just_pressed("attack")
	command.defend = _pressed("defend")
	command.duck = _pressed("duck")
	command.kick = _just_pressed("kick")
	command.weapon_action = _just_pressed("weapon_action")
	command.taunt = _just_pressed("taunt")
	return command


func _action(suffix: String) -> StringName:
	return StringName("p%d_%s" % [input_player, suffix])


func _axis(negative: String, positive: String) -> float:
	var negative_action := _action(negative)
	var positive_action := _action(positive)
	if not InputMap.has_action(negative_action) or not InputMap.has_action(positive_action):
		return 0.0
	return Input.get_axis(negative_action, positive_action)


func _pressed(suffix: String) -> bool:
	var action := _action(suffix)
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func _just_pressed(suffix: String) -> bool:
	var action := _action(suffix)
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)
