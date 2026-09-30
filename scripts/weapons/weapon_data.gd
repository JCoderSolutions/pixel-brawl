class_name WeaponData
extends Resource

## Everything that makes one weapon different from another. Weapons are pure
## data: WeaponHolder reads these values to fire projectiles or swing a blade,
## so a new gun is a new .tres, not new code.

enum Kind { RANGED, MELEE }
## Inventory slot it takes (Superfighters): a fighter carries one weapon per
## slot and switches between them.
enum Slot { MELEE, HANDGUN, RIFLE, THROWABLE }

@export var id: StringName
@export var display_name := ""
@export var kind := Kind.RANGED
@export var slot := Slot.RIFLE
@export var damage := 10
## Knockback along +X; flipped by the wielder's facing when the hit lands.
@export var knockback := Vector2(120.0, -60.0)
## Seconds between two uses.
@export var cooldown := 0.3
## Uses before the weapon is spent and discarded. -1 means unlimited.
@export var max_ammo := -1
## Keeps firing while the button is held instead of once per press.
@export var automatic := false
## Damage when thrown at someone (pickup button with nothing to grab).
@export var throw_damage := 12
## Metal blades can send bullets back with a well-timed block (katana).
@export var metal := false
## Placeholder color until the art pass replaces it with a sprite.
@export var color := Color.WHITE

@export_group("Ranged")
@export var projectiles_per_shot := 1
## Total cone angle; pellets are spread evenly across it.
@export var spread_degrees := 0.0
@export var projectile_speed := 600.0
@export var projectile_range := 400.0
@export var muzzle_offset := 12.0

@export_group("Melee")
@export var reach := Vector2(28.0, 18.0)
@export var melee_offset := 20.0
@export var melee_startup := 0.05
@export var melee_active := 0.12

@export_group("Art")
## Sprite drawn instead of the WeaponArt shapes, barrel pointing right.
@export var sprite: Texture2D
## Pixel of `sprite` that sits in the hand (the holder's origin).
@export var sprite_grip := Vector2.ZERO


func is_ranged() -> bool:
	return kind == Kind.RANGED


func has_unlimited_ammo() -> bool:
	return max_ammo < 0


## Angles in degrees for each projectile of one shot, symmetric around 0 so a
## shotgun blast always reads the same and tests stay deterministic.
func spread_angles() -> Array[float]:
	var angles: Array[float] = []
	var count := maxi(projectiles_per_shot, 1)
	if count == 1:
		angles.append(0.0)
		return angles
	var step := spread_degrees / float(count - 1)
	for i in count:
		angles.append(-spread_degrees / 2.0 + step * i)
	return angles
