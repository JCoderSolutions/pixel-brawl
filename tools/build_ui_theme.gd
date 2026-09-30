extends SceneTree

## Regenerates assets/ui/theme.tres from UiTokens (scripts/ui/ui_theme.gd).
## Run after changing a token:
##   godot --headless --path . -s tools/build_ui_theme.gd


func _init() -> void:
	var error := ResourceSaver.save(UiTheme.build(), UiTheme.PATH)
	print("OK: %s written" % UiTheme.PATH if error == OK else "FAILED: %s" % error_string(error))
	quit(0 if error == OK else 1)
