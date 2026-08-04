class_name SaveRecoveryDialog
extends ConfirmationDialog

## Shared recovery prompt for regiment and character controllers.
##
## Persistence detects candidates and performs filesystem operations; this
## dialog only presents the explicit player choice. It never recovers, discards,
## or overwrites a file without a button press.

signal recovery_requested(path: String, recovery_kind: String)
signal discard_temporary_requested(path: String)

var _path: String = ""
var _recovery_kind: String = ""
var _discard_button: Button


func _init() -> void:
	title = "OWCA Save Recovery"
	ok_button_text = "RECOVER"
	cancel_button_text = "KEEP CURRENT FILE"
	confirmed.connect(_on_confirmed)
	custom_action.connect(_on_custom_action)
	_discard_button = add_button("DISCARD TEMPORARY", true, "discard_temporary")


func present(path: String, recovery: Dictionary) -> void:
	_path = path
	_recovery_kind = str(recovery.get("recommended", ""))
	if _recovery_kind == "temporary":
		dialog_text = "OWCA found a complete, validated temporary save beside this file. It may contain work interrupted before replacement.\n\nRecover it, keep the current file for now, or explicitly discard the temporary candidate."
		_discard_button.visible = true
	elif _recovery_kind == "backup":
		dialog_text = "The selected save is invalid, but OWCA found its last validated backup.\n\nRecover the backup or cancel without changing either file."
		_discard_button.visible = false
	else:
		return
	popup_centered(Vector2i(610, 250))


func _on_confirmed() -> void:
	recovery_requested.emit(_path, _recovery_kind)


func _on_custom_action(action: StringName) -> void:
	if str(action) == "discard_temporary":
		hide()
		discard_temporary_requested.emit(_path)
