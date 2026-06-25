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
# Набор/экипировка чармов изменились (ловят меню чармов и игрок — пересчитать эффекты).
signal charms_changed

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
# Заклинание «Vengeful Spirit». Сделано флагом (как даш), но по умолчанию ВКЛЮЧЕНО —
# так удобно тестировать. Позже сможем выдавать его пикапом, поставив здесь false.
var has_spell: bool = true

# --- Точка возрождения (последняя активированная скамейка) ---
var respawn_position: Vector2 = Vector2.ZERO
var has_respawn_point: bool = false

# --- Чармы (амулеты) ---
# Сколько всего ячеек (notches) под чармы. В Hollow Knight их число растёт по игре;
# у нас пока фиксировано, но это переменная — потом легко увеличить и сохранить.
var notch_capacity: int = 3
# Каталог ВСЕХ чармов игры: ключ — id (String), значение — объект Charm.
# Заполняется в _build_charm_catalog() при старте.
var charm_catalog: Dictionary = {}
# Какие чармы игрок получил и какие сейчас надеты (храним id-строки).
var owned_charm_ids: Array[String] = []
var equipped_charm_ids: Array[String] = []

# Суммарные бонусы от НАДЕТЫХ чармов. Пересчитываются в _recalc_charm_bonuses().
# player.gd читает эти поля в точке использования (урон, скорость и т.д.).
var nail_damage_bonus: int = 0
var soul_per_hit_bonus: int = 0
var move_speed_mult: float = 1.0
var focus_time_mult: float = 1.0
var nail_range_mult: float = 1.0


# Путь к файлу сохранения. "user://" — это спец-папка Godot для данных игры
# (на Windows: %APPDATA%\Godot\app_userdata\<имя проекта>\). Туда можно писать.
const SAVE_PATH: String = "user://save.json"


func _ready() -> void:
	# 1) Строим каталог всех чармов (чтобы было из чего набирать).
	# 2) Грузим сохранение (оно может содержать список владеемых/надетых чармов).
	# 3) Пересчитываем бонусы по надетым чармам.
	# 4) Рассылаем значения, чтобы HUD показал правильные числа (через кадр —
	#    call_deferred — чтобы HUD успел подключиться к сигналам).
	_build_charm_catalog()
	load_game()
	_recalc_charm_bonuses()
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


# --- Чармы (амулеты) ---

func _build_charm_catalog() -> void:
	# Создаём все чармы игры в коде. Каждый — объект Charm с описанием и эффектами.
	# Чтобы добавить новый чарм — просто допиши ещё один блок по образцу.

	var heavy := Charm.new()
	heavy.id = "heavy_nail"
	heavy.charm_name = "Тяжёлый гвоздь"
	heavy.description = "Удары гвоздём наносят больше урона (+3)."
	heavy.notch_cost = 2
	heavy.nail_damage_bonus = 3
	charm_catalog[heavy.id] = heavy

	var longnail := Charm.new()
	longnail.id = "longnail"
	longnail.charm_name = "Длинный гвоздь"
	longnail.description = "Увеличивает размах удара в стороны."
	longnail.notch_cost = 1
	longnail.nail_range_mult = 1.4
	charm_catalog[longnail.id] = longnail

	var soul_catcher := Charm.new()
	soul_catcher.id = "soul_catcher"
	soul_catcher.charm_name = "Собиратель душ"
	soul_catcher.description = "Удар гвоздём даёт больше soul (+5)."
	soul_catcher.notch_cost = 1
	soul_catcher.soul_per_hit_bonus = 5
	charm_catalog[soul_catcher.id] = soul_catcher

	var sprint := Charm.new()
	sprint.id = "sprintmaster"
	sprint.charm_name = "Прыткие ноги"
	sprint.description = "Бег быстрее на 25%."
	sprint.notch_cost = 1
	sprint.move_speed_mult = 1.25
	charm_catalog[sprint.id] = sprint

	var quick_focus := Charm.new()
	quick_focus.id = "quick_focus"
	quick_focus.charm_name = "Быстрый фокус"
	quick_focus.description = "Лечение (Focus) происходит заметно быстрее."
	quick_focus.notch_cost = 3
	quick_focus.focus_time_mult = 0.6
	charm_catalog[quick_focus.id] = quick_focus


func get_charm(id: String) -> Charm:
	# Вернуть объект чарма по id (или null, если такого нет).
	return charm_catalog.get(id, null)


func is_owned(id: String) -> bool:
	return id in owned_charm_ids


func is_equipped(id: String) -> bool:
	return id in equipped_charm_ids


func add_charm(id: String) -> void:
	# Выдать игроку чарм (вызывается из пикапа). Дубликаты не добавляем.
	if charm_catalog.has(id) and not is_owned(id):
		owned_charm_ids.append(id)
		charms_changed.emit()


func used_notches() -> int:
	# Сколько ячеек сейчас занято надетыми чармами.
	var total := 0
	for cid in equipped_charm_ids:
		var c: Charm = charm_catalog.get(cid, null)
		if c != null:
			total += c.notch_cost
	return total


func free_notches() -> int:
	return notch_capacity - used_notches()


func can_equip(id: String) -> bool:
	# Надеть можно, если чарм есть у игрока, ещё не надет и помещается в свободные ячейки.
	var c: Charm = charm_catalog.get(id, null)
	if c == null or not is_owned(id) or is_equipped(id):
		return false
	return c.notch_cost <= free_notches()


func equip_charm(id: String) -> bool:
	if not can_equip(id):
		return false
	equipped_charm_ids.append(id)
	_recalc_charm_bonuses()
	charms_changed.emit()
	return true


func unequip_charm(id: String) -> void:
	if is_equipped(id):
		equipped_charm_ids.erase(id)
		_recalc_charm_bonuses()
		charms_changed.emit()


func toggle_charm(id: String) -> bool:
	# Удобно для меню: надет — снять; иначе попытаться надеть.
	# Возвращает true, если после действия чарм НАДЕТ.
	if is_equipped(id):
		unequip_charm(id)
		return false
	return equip_charm(id)


func _recalc_charm_bonuses() -> void:
	# Считаем суммарные бонусы заново по всем надетым чармам.
	# Бонусы-слагаемые начинаем с 0, множители — с 1.0.
	nail_damage_bonus = 0
	soul_per_hit_bonus = 0
	move_speed_mult = 1.0
	focus_time_mult = 1.0
	nail_range_mult = 1.0
	for cid in equipped_charm_ids:
		var c: Charm = charm_catalog.get(cid, null)
		if c == null:
			continue
		nail_damage_bonus += c.nail_damage_bonus
		soul_per_hit_bonus += c.soul_per_hit_bonus
		move_speed_mult *= c.move_speed_mult
		focus_time_mult *= c.focus_time_mult
		nail_range_mult *= c.nail_range_mult


# --- Сохранение на диск ---

func save_game() -> void:
	# Собираем состояние в обычный словарь (Vector2 раскладываем на x и y,
	# потому что JSON не знает про векторы).
	var data := {
		"health": health,
		"soul": soul,
		"has_dash": has_dash,
		"has_spell": has_spell,
		"has_respawn_point": has_respawn_point,
		"respawn_x": respawn_position.x,
		"respawn_y": respawn_position.y,
		"notch_capacity": notch_capacity,
		"owned_charm_ids": owned_charm_ids,
		"equipped_charm_ids": equipped_charm_ids,
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
	has_spell = bool(data.get("has_spell", true))
	has_respawn_point = bool(data.get("has_respawn_point", false))
	respawn_position = Vector2(data.get("respawn_x", 0.0), data.get("respawn_y", 0.0))

	# Чармы. JSON отдаёт обычные (нетипизированные) массивы, поэтому переносим id
	# по одному в наши типизированные Array[String] — иначе Godot ругнётся на тип.
	notch_capacity = int(data.get("notch_capacity", 3))
	owned_charm_ids.clear()
	for cid in data.get("owned_charm_ids", []):
		owned_charm_ids.append(str(cid))
	equipped_charm_ids.clear()
	for cid in data.get("equipped_charm_ids", []):
		# Надеваем только то, что реально есть в каталоге (на случай старого сейва).
		if charm_catalog.has(str(cid)):
			equipped_charm_ids.append(str(cid))


## Удаляет файл сохранения (новая игра). Удобно для отладки.
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
