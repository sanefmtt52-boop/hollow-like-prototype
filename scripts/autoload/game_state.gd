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
# Просьба показать короткое сообщение на экране (ловит HUD).
signal message(text: String)

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


# Путь к файлу сохранения. "user://" — это спец-папка Godot для данных игры
# (на Windows: %APPDATA%\Godot\app_userdata\<имя проекта>\). Туда можно писать.
const SAVE_PATH: String = "user://save.json"


func _ready() -> void:
	# Сначала пытаемся загрузить сохранение с диска (если оно есть),
	# затем рассылаем значения, чтобы HUD показал правильные числа.
	# call_deferred — ждём один кадр, чтобы HUD успел подключиться к сигналам.
	load_game()
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


# --- Сообщения на экране ---

func show_message(text: String) -> void:
	message.emit(text)


# --- Сохранение на диск ---

func save_game() -> void:
	# Собираем состояние в обычный словарь (Vector2 раскладываем на x и y,
	# потому что JSON не знает про векторы).
	var data := {
		"health": health,
		"soul": soul,
		"has_dash": has_dash,
		"has_respawn_point": has_respawn_point,
		"respawn_x": respawn_position.x,
		"respawn_y": respawn_position.y,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Не удалось открыть файл для сохранения: " + SAVE_PATH)
		return
	file.store_string(JSON.stringify(data))
	file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return  # сохранения ещё нет — играем с начала
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Файл сохранения повреждён, игнорирую.")
		return

	# Читаем значения с подстраховкой (get с дефолтом на случай старого файла).
	health = int(data.get("health", MAX_HEALTH))
	soul = int(data.get("soul", 0))
	has_dash = bool(data.get("has_dash", false))
	has_respawn_point = bool(data.get("has_respawn_point", false))
	respawn_position = Vector2(data.get("respawn_x", 0.0), data.get("respawn_y", 0.0))


## Удаляет файл сохранения (новая игра). Удобно для отладки.
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
