## Детерминированный ГСЧ забега: один сид даёт один и тот же забег (нужно для ежедневного забега и симулятора).
extends RefCounted

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func randf() -> float:
	return _rng.randf()

func chance(p: float) -> bool:
	return _rng.randf() < p

func pick(arr: Array):
	return arr[_rng.randi_range(0, arr.size() - 1)]

## Выбор по весам: weights — словарь {значение: вес}.
func pick_weighted(weights: Dictionary):
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := _rng.randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return weights.keys()[-1]

func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
