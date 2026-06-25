extends Area2D
## CharmPickup — подбираемый чарм в мире (по образцу ability_pickup).
##
## Какой именно чарм даёт — задаётся в инспекторе полем `charm_id` (id из каталога
## GameState, например "heavy_nail"). При касании игроком добавляет чарм в набор и
## исчезает. Если чарм уже получен (например, после загрузки сейва) — пикап убирает
## себя сразу в _ready, чтобы не лежал повторно. Это тот же паттерн, что у даша.

@export var charm_id: String = ""


func _ready() -> void:
	# Если у пикапа есть табличка — подпишем её названием чарма.
	var charm: Charm = GameState.get_charm(charm_id)
	if has_node("Label") and charm != null:
		$Label.text = charm.charm_name

	# Уже в наборе? Тогда не показываем пикап повторно.
	if GameState.is_owned(charm_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameState.add_charm(charm_id)
		var charm: Charm = GameState.get_charm(charm_id)
		var nm: String = charm.charm_name if charm != null else charm_id
		GameState.show_message("Получен чарм: %s. Нажми C, чтобы открыть меню и надеть" % nm)
		queue_free()
