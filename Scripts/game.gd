extends Node

# =============================================================================
# GAME — Singleton (autoload) con el estado global simple del juego
# =============================================================================
# Por ahora gestiona la economía (monedas). Centralizar aquí permite que la
# moneda, la tienda y la UI hablen entre sí sin acoplarse directamente.

signal coins_changed(total: int)

var coins: int = 0

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

func spend(amount: int) -> bool:
	"""Intenta gastar monedas. Devuelve true si había suficientes."""
	if coins >= amount:
		coins -= amount
		coins_changed.emit(coins)
		return true
	return false

func reset() -> void:
	coins = 0
	coins_changed.emit(coins)
