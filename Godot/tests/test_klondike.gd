extends "res://tests/test.gd"

const K := preload("res://win95/solitaire/klondike.gd")


func run() -> void:
	var game: K = K.new()
	game.deal(7)
	var dealt := 0
	for column in 7:
		var pile := K.TABLEAU + column
		dealt += game.cards(pile).size()
		check("column %d holds %d" % [column, column + 1], game.cards(pile).size(), column + 1)
		check("column %d top face up" % column, game.is_face_up(pile, column), true)
		check("column %d below face down" % column, column == 0 or not game.is_face_up(pile, column - 1), true)
	check("the stock holds the rest", game.cards(K.STOCK).size(), 52 - dealt)
	var all: Array = game.cards(K.STOCK).duplicate()
	for column in 7:
		all.append_array(game.cards(K.TABLEAU + column))
	all.sort()
	check("one of each card", all, range(52))
	var again: K = K.new()
	again.deal(7)
	check("a seed deals the same game", again.cards(K.STOCK), game.cards(K.STOCK))

	# Stock and waste: draw one, then recycle.
	game.set_piles([1, 2], [], [[], [], [], []], [], [])
	check("draw", game.draw(), true)
	check("draws the top card", game.cards(K.WASTE), [2])
	game.draw()
	check("an empty stock recycles", game.draw(), true)
	check("in the order it was dealt", game.cards(K.STOCK), [1, 2])
	check("the waste is empty", game.cards(K.WASTE), [])
	game.set_piles([], [], [[], [], [], []], [], [])
	check("nothing to draw", game.draw(), false)

	# Foundations: an Ace first, then up by suit.
	var ace_spades := _card(K.Suit.SPADES, 1)
	game.set_piles([], [ace_spades, _card(K.Suit.SPADES, 2)], [[], [], [], []], [], [])
	check("a Two can't start a foundation", game.move(K.WASTE, 1, K.FOUNDATION), false)
	game.set_piles([], [_card(K.Suit.SPADES, 2), ace_spades], [[], [], [], []], [], [])
	check("an Ace starts one", game.to_foundation(K.WASTE), true)
	check("the Two follows", game.move(K.WASTE, 0, K.FOUNDATION), true)
	game.set_piles([], [_card(K.Suit.HEARTS, 3)], [[ace_spades, _card(K.Suit.SPADES, 2)], [], [], []], [], [])
	check("not another suit", game.move(K.WASTE, 0, K.FOUNDATION), false)

	# Tableau: down in alternating colours, a King on an empty column.
	var black_nine := _card(K.Suit.CLUBS, 9)
	game.set_piles([], [_card(K.Suit.HEARTS, 8)], [[], [], [], []], [[black_nine]], [])
	check("a red Eight on a black Nine", game.can_move(K.WASTE, 0, K.TABLEAU), true)
	game.set_piles([], [_card(K.Suit.SPADES, 8)], [[], [], [], []], [[black_nine]], [])
	check("not a black Eight", game.can_move(K.WASTE, 0, K.TABLEAU), false)
	game.set_piles([], [_card(K.Suit.HEARTS, 7)], [[], [], [], []], [[black_nine]], [])
	check("not a Seven", game.can_move(K.WASTE, 0, K.TABLEAU), false)
	game.set_piles([], [_card(K.Suit.HEARTS, 12), _card(K.Suit.HEARTS, 13)], [[], [], [], []], [], [])
	check("a King on an empty column", game.move(K.WASTE, 1, K.TABLEAU + 3), true)
	check("only a King", game.move(K.WASTE, 0, K.TABLEAU + 4), false)

	# A run moves together, and the card under it turns up.
	var under := _card(K.Suit.DIAMONDS, 1)
	var run_cards := [_card(K.Suit.SPADES, 10), _card(K.Suit.HEARTS, 9), _card(K.Suit.CLUBS, 8)]
	game.set_piles([], [], [[], [], [], []], [[under] + run_cards, [_card(K.Suit.DIAMONDS, 11)]], [1])
	check("a face-down card can't move", game.can_move(K.TABLEAU, 0, K.TABLEAU + 1), false)
	check("a run moves", game.move(K.TABLEAU, 1, K.TABLEAU + 1), true)
	check("onto the Jack", game.cards(K.TABLEAU + 1).size(), 4)
	check("the card under it turns up", game.is_face_up(K.TABLEAU, 0), true)
	check("a run can't go to a foundation", game.can_move(K.TABLEAU + 1, 1, K.FOUNDATION), false)
	check("the stock can't be dragged", game.can_move(K.STOCK, 0, K.TABLEAU), false)

	# The win.
	var full: Array = []
	for s in 4:
		full.append(range(s * 13, s * 13 + (12 if s == K.Suit.CLUBS else 13)))
	game.set_piles([], [_card(K.Suit.CLUBS, 13)], full, [], [])
	check("not won with a King left", game.is_won(), false)
	check("the last King goes up", game.to_foundation(K.WASTE), true)
	check("won", game.is_won(), true)

	check("won", game.is_won(), true)

	var window: Control = (load("res://win95/solitaire/solitaire.tscn") as PackedScene).instantiate()
	root.add_child(window)
	await process_frame
	var size := window.get_combined_minimum_size()
	check("the window fits the desktop above the taskbar", size.x <= 640 and size.y <= 452, true)
	print("Solitaire window: ", size)

	# What the Start menu lists: ComputerState.installed_programs(), which names the Game autoload.
	for customer in ["young_entrepreneur", "skater_bro"]:
		var setup := (load("res://customers/%s.tres" % customer) as Customer).computer.win95_setup
		var sol := setup.file_at("C:\\WINDOWS\\SOL.EXE")
		check("%s has Solitaire as C:\\WINDOWS\\SOL.EXE" % customer, sol != null and sol.program == load("res://win95/solitaire/solitaire.tscn"), true)

func _card(suit: int, rank: int) -> int:
	return suit * 13 + rank - 1
