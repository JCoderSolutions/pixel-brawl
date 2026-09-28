extends Node

## Manual test scene for bots: runs the match arena with the humans and bots
## set below. With 0 humans it is a spectator match, handy to watch the AI
## play (and to tune BotProfile values) without touching a key.

@export_range(0, 1) var humans := 0
@export var difficulties: Array[BotProfile.Difficulty] = [
	BotProfile.Difficulty.EASY, BotProfile.Difficulty.NORMAL, BotProfile.Difficulty.HARD,
]
@export var arena_scene: PackedScene = preload("res://scenes/maps/test_arena.tscn")


func _ready() -> void:
	GameManager.human_players = humans
	GameManager.bot_difficulties.assign(difficulties)
	add_child(arena_scene.instantiate())
