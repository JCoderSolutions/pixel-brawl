class_name GrenadeData
extends WeaponData

## A throwable or launched weapon. WeaponHolder throws a Grenade instead of firing bullets;
## when the fuse runs out it spawns an Explosion that hurts every Hurtbox in
## range (damage falls off with distance) and breaks DestructibleMap blocks.

## Seconds between the throw and the blast.
@export var fuse_time := 2.0
## Launch velocity for a thrower facing right; X is flipped when facing left.
@export var throw_velocity := Vector2(260.0, -220.0)
@export_range(0.0, 1.0) var bounce := 0.45
## Blows up on the first wall, floor or fighter it touches instead of waiting
## for the fuse (rockets). The fuse still caps how long it can fly.
@export var explode_on_contact := false
## 1 = normal arc; 0 = flies straight like a rocket.
@export var gravity_scale := 1.0

@export_group("Explosion")
@export var explosion_radius := 40.0
## Share of `damage` dealt at the edge of the radius (full damage at the centre).
@export_range(0.0, 1.0) var min_damage_ratio := 0.35
## Push away from the centre, strongest at the centre.
@export var explosion_knockback := 320.0
## Extra upward push so blasts launch fighters instead of sliding them.
@export var explosion_lift := 120.0
## Damage applied to each map block the blast touches (blocks have 30 hp).
@export var block_damage := 30
