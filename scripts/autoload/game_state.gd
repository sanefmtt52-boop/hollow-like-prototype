extends Node
## GameState — глобальное состояние игры (синглтон / autoload).
##
## Этот скрипт подключён как Autoload (см. project.godot), поэтому к нему
## можно обращаться из ЛЮБОГО скрипта просто по имени: GameState.health,
## GameState.add_soul(11) и т.д. Он живёт всё время, пока запущена игра,
## и не сбрасывается при смене сцены/уровня.
##
## Здесь хранится то, что должно "пережить" перезагрузку уровня:
## здоровье, soul, открытые способности и точка возрождения (скамейка).

# --- Сигналы ---
# Сигнал — это "оповещение". GameState не знает про HUD напрямую;
# он просто кричит "здоровье изменилось!", а HUD слушает и обновляет себя.
# Это развязывает логику и интерфейс (см. hud.gd, где мы подключаемся к сигналам).
signal health_changed(current: int, maximum: int)
signal soul_changed(current: int, maximum: int)
signal player_died

# --- Здоровье (маски) ---
const MAX_HEALTH: int = 5
var health: int = MAX_HEALTH

# --- Soul (ресурс для лечения/заклинаний) ---
const MAX_SOUL: int = 99
const SOUL_PER_HIT: int = 11   # сколько soul даёт одно попадание гвоздём
const SOUL_PER_CAST: int = 33  # сколько стоит лечение/заклинание
var soul: int = 0

# --- Открытые способности (ключи прогресса метроидвании) ---
var has_dash: bool = false

# --- Точка возрождения (последняя активированная скамейка) ---
var respawn_position: Vector2 = Vector2.ZERO
var has_respawn_point: bool = false


func _ready() -> void:
	# При старте рассылаем текущие значения, чтобы HUD сразу показал правильные числа.
	# call_deferred — ждём один кадр, чтобы HUD успел подключиться к сигналам.
	call_deferred("_broadcast_initial")


func _broadcast_initial() -> void:
	health_changed.emit(health, MAX_HEALTH)
	soul_changed.emit(soul, MAX_SOUL)


# --- Soul ---

func add_soul(amount: int) -> void:
	soul = clampi(soul + amount, 0, MAX_SOUL)
	soul_changed.emit(soul, MAX_SOUL)


func can_cast() -> bool:
	return soul >= SOUL_PER_CAST


func spend_soul_for_cast() -> bool:
	# Возвращает true, если хватило soul и мы его потратили.
	if not can_cast():
		return false
	soul -= SOUL_PER_CAST
	soul_changed.emit(soul, MAX_SOUL)
	return true


# --- Здоровье ---

func take_damage(amount: int = 1) -> void:
	health = clampi(health - amount, 0, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0:
		player_died.emit()


func heal(amount: int = 1) -> void:
	health = clampi(health + amount, 0, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)


func restore_full_health() -> void:
	# Используется скамейкой.
	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)


# --- Скамейка / возрождение ---

func set_respawn(pos: Vector2) -> void:
	respawn_position = pos
	has_respawn_point = true


# --- Сохранение на диск (заполним в милстоуне M5) ---

func save_game() -> void:
	pass


func load_game() -> void:
	pass
