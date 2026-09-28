extends Node2D

## Sandbox for tuning ragdoll deaths: hit the dummies with J, press R to
## bring everyone back. Open this scene and run it with F6.

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
