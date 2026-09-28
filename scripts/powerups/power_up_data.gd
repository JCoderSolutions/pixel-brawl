class_name PowerUpData
extends Resource

## One power-up, as pure data: PowerUpReceiver reads these values, so a new
## power-up of an existing kind is a new .tres, not new code.

enum Effect { HEAL, SPEED, STRENGTH, SHIELD }

@export var id: StringName
@export var display_name := ""
@export var effect := Effect.HEAL
## HEAL: hit points restored. SPEED: run speed multiplier. STRENGTH: damage
## multiplier. SHIELD: points soaked up before health.
@export var amount := 1.0
## Seconds the effect lasts; 0 for instant ones (HEAL).
@export var duration := 0.0
## Placeholder color until the art pass replaces it with a sprite.
@export var color := Color.WHITE


func is_instant() -> bool:
	return duration <= 0.0
