extends Node2D

## Playable sandbox for weapons until they are wired into player.gd:
## K dispara/ataca con el arma, L recoge (o suelta si no hay nada cerca).
## Input actions are added at runtime so project.godot stays untouched.

const DEMO_ACTIONS := {
	&"fire": [KEY_K, KEY_X],
	&"pickup": [KEY_L, KEY_E],
}

@export var player: CharacterBody2D
@export var holder: WeaponHolder
@export var hud: Label

@onready var _player_visual: Control = player.get_node("Visual")


func _ready() -> void:
	for action in DEMO_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in DEMO_ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	holder.ammo_changed.connect(func(_a): _refresh_hud())
	holder.weapon_equipped.connect(func(_w, _a): _refresh_hud())
	holder.weapon_dropped.connect(func(_w, _a): _refresh_hud())
	holder.weapon_spent.connect(func(_w): _refresh_hud())
	_refresh_hud()


func _physics_process(_delta: float) -> void:
	# player.gd flips its Visual to face; mirror that into the holder.
	holder.facing = 1 if _player_visual.scale.x >= 0.0 else -1
	if player.health.is_dead():
		return
	var weapon := holder.weapon
	var wants_fire := Input.is_action_pressed("fire") if weapon != null and weapon.automatic \
			else Input.is_action_just_pressed("fire")
	if wants_fire:
		holder.try_use()
	if Input.is_action_just_pressed("pickup") and not holder.try_pick_up():
		holder.drop()


func _refresh_hud() -> void:
	var line := "Sin arma"
	if holder.has_weapon():
		var uses := "∞" if holder.weapon.has_unlimited_ammo() else str(holder.ammo)
		line = "%s  %s" % [holder.weapon.display_name, uses]
	hud.text = "%s\nA/D mover  W saltar  J golpe  K disparar  L recoger/soltar" % line
