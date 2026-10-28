## Джокеры: данные + реакции на события. Срабатывают слева направо.
## Экземпляр джокера в забеге: {"id": String, "state": Dictionary}.
extends RefCounted

const Pieces = preload("res://core/pieces.gd")

const PRICE := {"common": 4, "uncommon": 6, "rare": 8}
const COLOR_NAMES := ["Красный", "Синий", "Зелёный", "Жёлтый", "Фиолетовый"]

const DEFS := {
	"brick": {"name": "Кирпич", "rarity": "common", "desc": "+4 к множителю"},
	"fan_0": {"name": "Красный фанат", "rarity": "common", "desc": "+1 к множителю за каждую красную снятую клетку"},
	"fan_1": {"name": "Синий фанат", "rarity": "common", "desc": "+1 к множителю за каждую синюю снятую клетку"},
	"fan_2": {"name": "Зелёный фанат", "rarity": "common", "desc": "+1 к множителю за каждую зелёную снятую клетку"},
	"fan_3": {"name": "Жёлтый фанат", "rarity": "common", "desc": "+1 к множителю за каждую жёлтую снятую клетку"},
	"fan_4": {"name": "Фиолетовый фанат", "rarity": "common", "desc": "+1 к множителю за каждую фиолетовую снятую клетку"},
	"wide": {"name": "Широкий жест", "rarity": "common", "desc": "+60 фишек, если снято 2+ линии"},
	"bomber": {"name": "Взрывник", "rarity": "common", "desc": "+20 фишек за каждую линию"},
	"corner": {"name": "Угловой", "rarity": "common", "desc": "+40 фишек, если линию закрыл уголок"},
	"stick": {"name": "Палка", "rarity": "common", "desc": "+5 к множителю, если линию закрыла палка"},
	"patient": {"name": "Терпеливый", "rarity": "common", "desc": "+2 к множителю за каждый оставшийся сброс"},
	"cramped": {"name": "Теснота", "rarity": "common", "desc": "+1 к множителю за каждые 5 занятых клеток"},
	"piggy": {"name": "Копилка", "rarity": "common", "desc": "+1 монета за каждые 3 снятые линии"},
	"spare": {"name": "Запасливый", "rarity": "common", "desc": "В конце раунда +1 монета за каждые 4 оставшиеся фигуры"},
	"cross": {"name": "Крест", "rarity": "uncommon", "desc": "+8 к множителю, если сняты строка и столбец сразу"},
	"minimal": {"name": "Минималист", "rarity": "uncommon", "desc": "×2 к множителю, если линию закрыла фигура из 1–2 клеток"},
	"purist": {"name": "Пурист", "rarity": "uncommon", "desc": "Одноцветные линии дают ×3 вместо ×2"},
	"cold": {"name": "Холодная голова", "rarity": "uncommon", "desc": "×1.5, если после хода занято не больше 1/4 поля"},
	"gold_rush": {"name": "Золотая лихорадка", "rarity": "uncommon", "desc": "Золотые клетки дают ещё +1 монету и +30 фишек"},
	"miser": {"name": "Скупец", "rarity": "uncommon", "desc": "+1 к множителю за каждые 4 монеты в кошельке"},
	"avalanche": {"name": "Лавина", "rarity": "uncommon", "desc": "+15 фишек за каждый ход серии"},
	"rainbow": {"name": "Радуга", "rarity": "rare", "desc": "×3, если среди снятых клеток все 5 цветов"},
	"growing": {"name": "Растущий", "rarity": "rare", "desc": "+1 к множителю навсегда за каждые 3+ линии разом (сейчас +{v})"},
	"crown": {"name": "Корона", "rarity": "rare", "desc": "×2, если поле очищено полностью"},
	"architect": {"name": "Архитектор", "rarity": "rare", "desc": "×0.5 к множителю за каждую линию после первой (×1.5 за 2, ×2 за 3…)"},
}

static func price(id: String) -> int:
	return PRICE[DEFS[id].rarity]

static func sell_price(id: String) -> int:
	return price(id) / 2

static func make(id: String) -> Dictionary:
	return {"id": id, "state": {"v": 0}}

static func describe(j: Dictionary) -> String:
	return String(DEFS[j.id].desc).replace("{v}", str(j.state.get("v", 0)))

static func has(jokers: Array, id: String) -> bool:
	for j in jokers:
		if j.id == id:
			return true
	return false

## Срабатывание на ход с очисткой линий. s — счёт хода (chips, mult, coins, log), ctx — контекст хода.
static func on_score(j: Dictionary, s: Dictionary, ctx: Dictionary) -> void:
	var clear: Dictionary = ctx.clear
	var piece: Dictionary = ctx.piece
	var name: String = DEFS[j.id].name
	match j.id:
		"brick":
			_mult(s, name, 4)
		"fan_0", "fan_1", "fan_2", "fan_3", "fan_4":
			var color := int(j.id.substr(4))
			var n := 0
			for c in clear.cleared:
				if c.c == color:
					n += 1
			if n > 0:
				_mult(s, name, n)
		"wide":
			if clear.lines >= 2:
				_chips(s, name, 60)
		"bomber":
			_chips(s, name, 20 * clear.lines)
		"corner":
			if piece.family == "corner":
				_chips(s, name, 40)
		"stick":
			if piece.family == "line":
				_mult(s, name, 5)
		"patient":
			if ctx.discards_left > 0:
				_mult(s, name, 2 * ctx.discards_left)
		"cramped":
			var n: int = ctx.board.filled_count() / 5
			if n > 0:
				_mult(s, name, n)
		"piggy":
			j.state.v += clear.lines
			var coins: int = j.state.v / 3
			if coins > 0:
				j.state.v -= coins * 3
				s.coins += coins
				s.log.append([name, "+%d мон." % coins])
		"cross":
			if clear.rows.size() > 0 and clear.cols.size() > 0:
				_mult(s, name, 8)
		"minimal":
			if piece.cells.size() <= 2:
				_xmult(s, name, 2.0)
		"cold":
			if ctx.board.filled_count() * 4 <= ctx.board.size * ctx.board.size:
				_xmult(s, name, 1.5)
		"gold_rush":
			var n := 0
			for c in clear.cleared:
				if c.k == Pieces.KIND_GOLD:
					n += 1
			if n > 0:
				_chips(s, name, 30 * n)
				s.coins += n
		"miser":
			var n: int = ctx.coins / 4
			if n > 0:
				_mult(s, name, n)
		"avalanche":
			_chips(s, name, 15 * ctx.streak)
		"rainbow":
			var seen := {}
			for c in clear.cleared:
				seen[c.c] = true
			if seen.size() >= Pieces.COLORS:
				_xmult(s, name, 3.0)
		"growing":
			if clear.lines >= 3:
				j.state.v += 1
			if j.state.v > 0:
				_mult(s, name, j.state.v)
		"crown":
			if ctx.board.is_empty():
				_xmult(s, name, 2.0)
		"architect":
			if clear.lines >= 2:
				_xmult(s, name, 1.0 + 0.5 * (clear.lines - 1))

## Монеты в конце выигранного раунда.
static func on_round_end(j: Dictionary, ctx: Dictionary) -> int:
	match j.id:
		"spare":
			return ctx.pieces_left / 4
	return 0

static func _chips(s: Dictionary, src: String, v: int) -> void:
	s.chips += v
	s.log.append([src, "+%d фишек" % v])

static func _mult(s: Dictionary, src: String, v: float) -> void:
	s.mult += v
	s.log.append([src, "+%s множ." % _fmt(v)])

static func _xmult(s: Dictionary, src: String, v: float) -> void:
	s.mult *= v
	s.log.append([src, "×%s множ." % _fmt(v)])

static func _fmt(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
