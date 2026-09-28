class_name BotProfile
extends RefCounted
## Tuning knobs for one bot difficulty. A profile is plain data: the bot reads
## it, never writes it, so the same profile can drive any number of bots.

enum Difficulty { EASY, NORMAL, HARD }

const NAMES := ["Fácil", "Normal", "Difícil"]

var difficulty := Difficulty.NORMAL
## Ticks between decisions (who to chase, when to strike). Movement and
## ledge safety still run every tick, so a slow bot is dim, not suicidal.
var think_interval := 10
## Chance, per decision with a target in range, of actually striking.
var aggression := 0.8
## Grenades whose fuse is below this (seconds) are fled; 0 ignores them.
var grenade_awareness := 1.2
## Chases a loose weapon over an opponent while the weapon is closer than
## this fraction of the opponent's distance.
var weapon_greed := 1.0
## Horizontal tolerance, in px, when lining up a shot with a target's height.
var aim_tolerance := 12.0


static func create(level: Difficulty) -> BotProfile:
	var profile := BotProfile.new()
	profile.difficulty = level
	match level:
		Difficulty.EASY:
			profile.think_interval = 20
			profile.aggression = 0.45
			profile.grenade_awareness = 0.0
			profile.weapon_greed = 0.5
			profile.aim_tolerance = 20.0
		Difficulty.HARD:
			profile.think_interval = 4
			profile.aggression = 1.0
			profile.grenade_awareness = 2.0
			profile.weapon_greed = 1.6
			profile.aim_tolerance = 10.0
	return profile


static func display_name(level: int) -> String:
	return NAMES[clampi(level, 0, NAMES.size() - 1)]
