## Фигуры: формы, повороты и генерация с цветом и особыми клетками.
extends RefCounted

const COLORS := 5

## Семейства фигур — к ним привязаны улучшения в магазине и часть джокеров.
const FAMILIES := ["dot", "line", "square", "corner", "t", "z"]

const FAMILY_NAMES := {
	"dot": "Точка", "line": "Палка", "square": "Квадрат",
	"corner": "Уголок", "t": "Тетрис-Т", "z": "Зигзаг",
}

## Базовые формы (все повороты считаются ниже).
const SHAPES := {
	"dot1": {"family": "dot", "cells": [Vector2i(0, 0)]},
	"line2": {"family": "line", "cells": [Vector2i(0, 0), Vector2i(1, 0)]},
	"line3": {"family": "line", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]},
	"line4": {"family": "line", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]},
	"line5": {"family": "line", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]},
	"sq2": {"family": "square", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	"sq3": {"family": "square", "cells": [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]},
	"rect23": {"family": "square", "cells": [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
	"corner3": {"family": "corner", "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	"corner5": {"family": "corner", "cells": [
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]},
	"l4": {"family": "corner", "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]},
	"t4": {"family": "t", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]},
	"z4": {"family": "z", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]},
}

## Вес формы в раздаче: крупные фигуры реже.
const WEIGHTS := {
	"dot1": 4, "line2": 8, "line3": 9, "line4": 7, "line5": 4,
	"sq2": 9, "sq3": 3, "rect23": 4, "corner3": 9, "corner5": 5,
	"l4": 8, "t4": 7, "z4": 6,
}

const KIND_NORMAL := 0
const KIND_GOLD := 1
const KIND_GLASS := 2
const KIND_STONE := 3

static func rotate_cells(cells: Array, times: int) -> Array:
	var out: Array = cells.duplicate()
	for _i in range(times % 4):
		var r: Array = []
		for c in out:
			r.append(Vector2i(-c.y, c.x))
		out = r
	return normalize(out)

static func normalize(cells: Array) -> Array:
	var mx := 1 << 20
	var my := 1 << 20
	for c in cells:
		mx = mini(mx, c.x)
		my = mini(my, c.y)
	var out: Array = []
	for c in cells:
		out.append(Vector2i(c.x - mx, c.y - my))
	return out

static func bounds(cells: Array) -> Vector2i:
	var w := 0
	var h := 0
	for c in cells:
		w = maxi(w, c.x + 1)
		h = maxi(h, c.y + 1)
	return Vector2i(w, h)

## Новая фигура. special_chances: {KIND_GOLD: 0.05, ...} — шанс, что одна клетка будет особой.
static func make(rng, special_chances: Dictionary = {}, mono_color: int = -1) -> Dictionary:
	var shape: String = rng.pick_weighted(WEIGHTS)
	var cells := rotate_cells(SHAPES[shape].cells, rng.randi_range(0, 3))
	var color: int = mono_color if mono_color >= 0 else rng.randi_range(0, COLORS - 1)
	var kinds: Array = []
	for _c in cells:
		kinds.append(KIND_NORMAL)
	for kind in special_chances:
		if rng.chance(special_chances[kind]):
			kinds[rng.randi_range(0, cells.size() - 1)] = kind
	return {"shape": shape, "family": SHAPES[shape].family, "cells": cells, "kinds": kinds, "color": color}
