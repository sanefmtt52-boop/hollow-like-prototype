extends CanvasLayer
## CharmMenu — экран экипировки чармов (амулетов).
##
## Открывается клавишей C (действие "charm_menu") и ставит игру на ПАУЗУ.
## Узел работает ВСЕГДА (process_mode = Always задан в сцене), поэтому ловит
## нажатие открытия даже когда игра идёт, и навигацию — когда игра на паузе
## (на паузе обычные узлы, в т.ч. игрок и враги, замирают).
##
## Список строится «на лету» из owned_charm_ids: для каждого чарма — строка-Label.
## Управление: ↑/↓ — выбор, Enter/Space — надеть/снять, C/Esc — закрыть.

@onready var dim: ColorRect = $Dim
@onready var list: VBoxContainer = $Dim/List
@onready var notches_label: Label = $Dim/Notches

var _open: bool = false
var _selected: int = 0  # индекс выделенной строки в списке владеемых чармов


func _ready() -> void:
	dim.visible = false
	# Если эффекты/набор чармов изменятся (надели/сняли) — перерисуем список.
	GameState.charms_changed.connect(_refresh)


func _unhandled_input(event: InputEvent) -> void:
	# Открытие/закрытие — ловим всегда.
	if event.is_action_pressed("charm_menu"):
		_toggle()
		return
	# Остальные клавиши обрабатываем, только пока меню открыто.
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):       # Esc
		_toggle()
	elif event.is_action_pressed("ui_up"):         # ↑
		_move_selection(-1)
	elif event.is_action_pressed("ui_down"):       # ↓
		_move_selection(1)
	elif event.is_action_pressed("ui_accept"):     # Enter / Space
		_toggle_selected_charm()


func _toggle() -> void:
	_open = not _open
	dim.visible = _open
	# get_tree().paused замораживает все обычные узлы (наш узел — Always, он живёт).
	get_tree().paused = _open
	if _open:
		_selected = 0
		_refresh()


func _move_selection(step: int) -> void:
	var n := GameState.owned_charm_ids.size()
	if n == 0:
		return
	# wrapi заворачивает индекс по кругу (после последнего — снова первый).
	_selected = wrapi(_selected + step, 0, n)
	_refresh()


func _toggle_selected_charm() -> void:
	var owned := GameState.owned_charm_ids
	if _selected < 0 or _selected >= owned.size():
		return
	var cid: String = owned[_selected]
	var was_equipped := GameState.is_equipped(cid)
	GameState.toggle_charm(cid)  # надет -> снять, иначе попытаться надеть
	# Если хотели надеть, но он так и не надет — значит не хватило ячеек.
	if not was_equipped and not GameState.is_equipped(cid):
		GameState.show_message("Не хватает свободных ячеек для этого чарма")
	_refresh()


func _refresh() -> void:
	# Удаляем старые строки (remove_child — сразу убираем из показа; queue_free — чистим память).
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()

	var owned := GameState.owned_charm_ids
	notches_label.text = "Ячейки: %d / %d занято" % [GameState.used_notches(), GameState.notch_capacity]

	if owned.is_empty():
		var empty := Label.new()
		empty.text = "(пока нет чармов — их нужно найти в мире)"
		list.add_child(empty)
		return

	for i in owned.size():
		var cid: String = owned[i]
		var charm: Charm = GameState.get_charm(cid)
		if charm == null:
			continue
		var row := Label.new()
		var mark := "[★]" if GameState.is_equipped(cid) else "[ ]"   # надет / снят
		var cursor := "> " if i == _selected else "  "
		row.text = "%s%s %s  (%d яч.)  — %s" % [
			cursor, mark, charm.charm_name, charm.notch_cost, charm.description
		]
		# Подсветка: выделенная строка — жёлтая, просто надетая — зелёная.
		if i == _selected:
			row.modulate = Color(1, 0.9, 0.4)
		elif GameState.is_equipped(cid):
			row.modulate = Color(0.6, 1, 0.6)
		list.add_child(row)
