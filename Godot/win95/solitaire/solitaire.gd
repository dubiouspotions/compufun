extends "res://win95/window.gd"
## Klondike solitaire: the Game menu and the win. The play is on %Table.

enum Menu { DEAL, CLOSE }

const _MESSAGE := preload("res://win95/message_box.tscn")


func _ready() -> void:
	super()
	%Game.id_pressed.connect(_on_game_menu)
	%Table.won.connect(_on_won)


func _on_game_menu(id: int) -> void:
	match id:
		Menu.DEAL:
			%Table.deal()
		Menu.CLOSE:
			request_close()


func _on_won() -> void:
	var desktop := get_parent() as Win95Desktop
	if desktop == null:
		push_error("Solitaire: not on a Win95Desktop, so it can't say the game is won")
		return
	var box: Node = desktop.open(_MESSAGE, false)
	box.closed.connect(box.queue_free)
	box.answered.connect(func(button: String) -> void:
		if button == "Yes":
			%Table.deal())
	box.ask("Solitaire", "You win! Deal again?", ["Yes", "No"])
