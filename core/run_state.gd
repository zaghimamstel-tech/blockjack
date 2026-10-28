## Состояние забега: этажи, раунды, раздача фигур, монеты, магазин. Без UI.
extends RefCounted

const Rng = preload("res://core/rng.gd")
const Board = preload("res://core/board.gd")
const Pieces = preload("res://core/pieces.gd")
const Scoring = preload("res://core/scoring.gd")
const Jokers = preload("res://core/jokers.gd")

const FLOORS := 5
const BASE_TARGETS := [300, 450, 600]
const FLOOR_GROWTH := 2.2
const HANDS := 8
const HAND_SIZE := 3
const DISCARDS := 3
const MAX_JOKERS := 5
const ROUND_REWARD := [3, 4, 5]
const START_COINS := 4
const UPGRADE_PRICE := 5
const PACK_PRICE := 4
const REROLL_PRICE := 5
## «Спешка»: фигур вдвое меньше, поэтому цель ниже (подобрано симулятором).
const RUSH_TARGET := 0.6

const BOSSES := {
	"fog": {"name": "Туман", "desc": "Видна только одна фигура из трёх"},
	"stones": {"name": "Камнепад", "desc": "С каждой раздачей падают 2 камня"},
	"mono": {"name": "Монохром", "desc": "Все фигуры одного цвета, чистые линии не считаются"},
	"tight": {"name": "Теснота", "desc": "Поле 7×7"},
	"rush": {"name": "Спешка", "desc": "Всего 12 фигур"},
}
const ROUND_NAMES := ["Малый раунд", "Большой раунд", "Босс"]
const SPECIAL_KINDS := [Pieces.KIND_GOLD, Pieces.KIND_GLASS, Pieces.KIND_STONE]
const KIND_NAMES := {Pieces.KIND_GOLD: "золото", Pieces.KIND_GLASS: "стекло", Pieces.KIND_STONE: "камень"}

signal changed

var seed_value: int
var rng
var floor_num := 1
var round_idx := 0
var bosses: Array = []
var coins := START_COINS
var jokers: Array = []
var levels := {}
var special_chances := {}
var phase := "play" # play | won | lost | shop | run_won

# Раунд
var board
var hand: Array = []
var hands_left := 0
var discards_left := 0
var round_score := 0
var target := 0
var streak := 0
var last_reward := {}

# Магазин
var offers: Array = []
var reroll_price := REROLL_PRICE

func _init(seed_in: int = 0) -> void:
	seed_value = seed_in if seed_in != 0 else int(Time.get_unix_time_from_system())
	rng = Rng.new(seed_value)
	var ids := BOSSES.keys()
	rng.shuffle(ids)
	for f in FLOORS:
		bosses.append(ids[f % ids.size()])
	start_round()

func boss() -> String:
	return bosses[floor_num - 1] if round_idx == 2 else ""

func target_for(f: int, r: int) -> int:
	return int(round(BASE_TARGETS[r] * pow(FLOOR_GROWTH, f - 1) / 10.0)) * 10

func start_round() -> void:
	phase = "play"
	var b := boss()
	board = Board.new(7 if b == "tight" else 8)
	hands_left = (12 if b == "rush" else HANDS * HAND_SIZE) / HAND_SIZE
	discards_left = DISCARDS
	round_score = 0
	streak = 0
	target = target_for(floor_num, round_idx)
	if b == "rush":
		target = int(round(target * RUSH_TARGET / 10.0)) * 10
	deal_hand()
	changed.emit()

func deal_hand() -> void:
	hands_left -= 1
	var mono: int = rng.randi_range(0, Pieces.COLORS - 1) if boss() == "mono" else -1
	if boss() == "stones":
		board.drop_stones(rng, 2)
	# Даём шанс: до 5 попыток раздать руку, где хоть что-то влезает.
	for _attempt in 5:
		hand = []
		for _i in HAND_SIZE:
			hand.append(Pieces.make(rng, special_chances, mono))
		if _any_fits():
			break

func _any_fits() -> bool:
	for i in hand.size():
		if hand[i] != null and is_usable(i) and board.fits_anywhere(hand[i].cells):
			return true
	return false

func pieces_left() -> int:
	var n := hands_left * HAND_SIZE
	for p in hand:
		if p != null:
			n += 1
	return n

## В «Тумане» доступна только первая оставшаяся фигура.
func is_usable(i: int) -> bool:
	if hand[i] == null:
		return false
	if boss() != "fog":
		return true
	for k in i:
		if hand[k] != null:
			return false
	return true

## Ход. Возвращает {} если поставить нельзя, иначе результат подсчёта + clear.
func place(i: int, origin: Vector2i) -> Dictionary:
	if phase != "play" or not is_usable(i) or not board.can_place(hand[i].cells, origin):
		return {}
	var piece: Dictionary = hand[i]
	board.place(piece, origin)
	hand[i] = null
	var clear: Dictionary = board.clear_full()
	streak = streak + 1 if clear.lines > 0 else 0
	var s := Scoring.score_move({
		"piece": piece, "clear": clear, "board": board, "streak": streak,
		"jokers": jokers, "levels": levels, "discards_left": discards_left,
		"pieces_left": pieces_left(), "coins": coins, "boss": boss(),
	})
	round_score += s.score
	coins += s.coins
	s["clear"] = clear
	s["piece"] = piece
	s["origin"] = origin
	if hand.all(func(p): return p == null) and hands_left > 0 and round_score < target:
		deal_hand()
	_check_end()
	changed.emit()
	return s

func can_discard() -> bool:
	return phase == "play" and discards_left > 0

func discard() -> bool:
	if not can_discard():
		return false
	discards_left -= 1
	hands_left += 1 # сброс не тратит раздачу
	deal_hand()
	_check_end()
	changed.emit()
	return true

func _check_end() -> void:
	if round_score >= target:
		_win_round()
	elif pieces_left() == 0:
		phase = "lost"
	elif not _any_fits() and discards_left == 0:
		phase = "lost"

func _win_round() -> void:
	phase = "won"
	var r := {"base": ROUND_REWARD[round_idx], "hands": hands_left, "interest": mini(coins / 5, 5), "jokers": 0}
	for j in jokers:
		r.jokers += Jokers.on_round_end(j, {"pieces_left": pieces_left()})
	r["total"] = r.base + r.hands + r.interest + r.jokers
	coins += r.total
	last_reward = r

## После победы в раунде — в магазин (или конец забега после последнего босса).
func to_shop() -> void:
	if phase != "won":
		return
	if floor_num == FLOORS and round_idx == 2:
		phase = "run_won"
	else:
		phase = "shop"
		reroll_price = REROLL_PRICE
		_fill_offers()
	changed.emit()

func _fill_offers() -> void:
	offers = []
	var pool: Array = []
	for id in Jokers.DEFS:
		if not Jokers.has(jokers, id):
			pool.append(id)
	rng.shuffle(pool)
	# Редкие реже: первый подходящий из перемешанного пула с отсевом по редкости.
	var picked := 0
	for id in pool:
		if picked == 2:
			break
		var rar: String = Jokers.DEFS[id].rarity
		if rar == "rare" and not rng.chance(0.35):
			continue
		if rar == "uncommon" and not rng.chance(0.7):
			continue
		offers.append({"type": "joker", "id": id, "price": Jokers.price(id), "sold": false})
		picked += 1
	var fam: String = rng.pick(Pieces.FAMILIES)
	offers.append({"type": "upgrade", "family": fam, "price": UPGRADE_PRICE, "sold": false})
	offers.append({"type": "pack", "kind": rng.pick(SPECIAL_KINDS), "price": PACK_PRICE, "sold": false})

func can_buy(i: int) -> bool:
	if phase != "shop" or i < 0 or i >= offers.size():
		return false
	var o: Dictionary = offers[i]
	if o.sold or coins < o.price:
		return false
	return not (o.type == "joker" and jokers.size() >= MAX_JOKERS)

func buy(i: int) -> bool:
	if not can_buy(i):
		return false
	var o: Dictionary = offers[i]
	coins -= o.price
	o.sold = true
	match o.type:
		"joker":
			jokers.append(Jokers.make(o.id))
		"upgrade":
			levels[o.family] = levels.get(o.family, 0) + 1
		"pack":
			special_chances[o.kind] = special_chances.get(o.kind, 0.0) + 0.08
	changed.emit()
	return true

func reroll() -> bool:
	if phase != "shop" or coins < reroll_price:
		return false
	coins -= reroll_price
	reroll_price += 1
	_fill_offers()
	changed.emit()
	return true

func sell_joker(i: int) -> bool:
	if i < 0 or i >= jokers.size():
		return false
	coins += Jokers.sell_price(jokers[i].id)
	jokers.remove_at(i)
	changed.emit()
	return true

func move_joker(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 or from >= jokers.size() or to >= jokers.size():
		return
	var j = jokers[from]
	jokers.remove_at(from)
	jokers.insert(to, j)
	changed.emit()

func leave_shop() -> void:
	if phase != "shop":
		return
	round_idx += 1
	if round_idx > 2:
		round_idx = 0
		floor_num += 1
	start_round()

## Номер раунда в забеге, 1..15.
func round_number() -> int:
	return (floor_num - 1) * 3 + round_idx + 1
