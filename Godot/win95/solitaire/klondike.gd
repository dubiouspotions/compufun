class_name Klondike
extends RefCounted
## The rules of Klondike solitaire, draw one, with no drawing. A card is an int from 0 to 51:
## [method suit] is card / 13 and [method rank] is card % 13 + 1 (1 is the Ace, 13 the King).
## A pile is an int: [constant STOCK], [constant WASTE], FOUNDATION + 0..3, TABLEAU + 0..6.

enum Suit { SPADES, HEARTS, DIAMONDS, CLUBS }

const STOCK: int = 0
const WASTE: int = 1
const FOUNDATION: int = 2
const TABLEAU: int = 6
const PILES: int = 13
const KING: int = 13

## Each pile's cards, bottom first.
var _piles: Array[Array] = []
## How many cards at the bottom of each tableau column lie face down, by column.
var _hidden: PackedInt32Array = []


func _init() -> void:
	for i in PILES:
		_piles.append([])
	_hidden.resize(7)


static func suit(card: int) -> int:
	return card / 13


static func rank(card: int) -> int:
	return card % 13 + 1


static func is_red(card: int) -> bool:
	return suit(card) in [Suit.HEARTS, Suit.DIAMONDS]


## Shuffles a full deck with [param seed] and deals it: column i gets i + 1 cards, its top face up.
func deal(seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var deck: Array = range(52)
	for i in range(51, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: int = deck[i]
		deck[i] = deck[j]
		deck[j] = swap
	set_piles([], [], [[], [], [], []], [], [])
	for column in 7:
		for i in column + 1:
			_piles[TABLEAU + column].append(deck.pop_back())
		_hidden[column] = column
	_piles[STOCK] = deck


## Sets every pile at once, bottom card first: for a test, or a deal that isn't random.
## [param tableau] has 7 columns (an empty array is 7 empty columns); [param hidden] says how many
## cards of each column lie face down (empty: none).
func set_piles(stock: Array, waste: Array, foundations: Array, tableau: Array, hidden: Array) -> void:
	_piles[STOCK] = stock.duplicate()
	_piles[WASTE] = waste.duplicate()
	for i in 4:
		_piles[FOUNDATION + i] = (foundations[i] as Array).duplicate()
	for i in 7:
		_piles[TABLEAU + i] = (tableau[i] as Array).duplicate() if i < tableau.size() else []
		_hidden[i] = hidden[i] if i < hidden.size() else 0


## The cards of [param pile], bottom first. Don't change the array.
func cards(pile: int) -> Array:
	return _piles[pile]


## True when the card at [param index] in [param pile] lies face up.
func is_face_up(pile: int, index: int) -> bool:
	if pile == STOCK:
		return false
	if pile >= TABLEAU:
		return index >= _hidden[pile - TABLEAU]
	return true


## Clicks the stock: turns its top card onto the waste, or, when the stock is empty, turns the
## waste over to make the stock again. False when both are empty.
func draw() -> bool:
	if not _piles[STOCK].is_empty():
		_piles[WASTE].append(_piles[STOCK].pop_back())
		return true
	if _piles[WASTE].is_empty():
		return false
	_piles[WASTE].reverse()
	_piles[STOCK] = _piles[WASTE]
	_piles[WASTE] = []
	return true


## True when the cards of [param from] from [param index] to the top may go onto [param to].
func can_move(from: int, index: int, to: int) -> bool:
	var moving: Array = _piles[from]
	if from == to or from == STOCK or to < FOUNDATION or index < 0 or index >= moving.size():
		return false
	if not is_face_up(from, index):
		return false
	var count := moving.size() - index
	if count > 1 and from < TABLEAU:
		return false
	var card: int = moving[index]
	var target: Array = _piles[to]
	if to < TABLEAU:
		if count > 1:
			return false
		if target.is_empty():
			return rank(card) == 1
		return suit(target.back()) == suit(card) and rank(target.back()) + 1 == rank(card)
	if target.is_empty():
		return rank(card) == KING
	return is_red(target.back()) != is_red(card) and rank(target.back()) == rank(card) + 1


## Moves the cards of [param from] from [param index] up onto [param to], if the rules allow,
## and turns up the new top card of a tableau column. False, and no change, when they don't.
func move(from: int, index: int, to: int) -> bool:
	if not can_move(from, index, to):
		return false
	var moving: Array = _piles[from].slice(index)
	_piles[from].resize(index)
	_piles[to].append_array(moving)
	if from >= TABLEAU:
		var column := from - TABLEAU
		_hidden[column] = mini(_hidden[column], maxi(index - 1, 0))
	return true


## Moves the top card of [param from] onto the foundation that takes it. False when none does.
func to_foundation(from: int) -> bool:
	var index: int = _piles[from].size() - 1
	for i in 4:
		if move(from, index, FOUNDATION + i):
			return true
	return false


## True when all four foundations hold their thirteen cards.
func is_won() -> bool:
	for i in 4:
		if _piles[FOUNDATION + i].size() != KING:
			return false
	return true
