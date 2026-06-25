extends CharacterBody2D
## EnemyCrawler — простой враг-патрульный.
##
## Ходит по платформе туда-сюда, разворачиваясь у стены или у края (чтобы не
## падать вниз). Имеет здоровье, мигает при попадании и умирает. Урон игроку
## наносится КОНТАКТОМ — но логика урона живёт в игроке (его Hurtbox замечает
## врага по группе "enemy"); враг сам ничего про игрока не знает.

@export var max_health: int = 10
@export var gravity: float = 980.0
@export var patrol_speed: float = 60.0

var _health: int
var _dir: int = 1  # направление патруля: 1 = вправо, -1 = влево

@onready var floor_check: RayCast2D = $FloorCheck


func _ready() -> void:
	add_to_group("enemy")
	_health = max_health
	# Луч-щуп смотрит вниз перед врагом — так мы видим, есть ли впереди пол.
	floor_check.position.x = _dir * 22.0


func _physics_process(delta: float) -> void:
	# Притяжение к земле.
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	# Разворот: если упёрлись в стену ИЛИ впереди обрыв (нет пола под щупом).
	if is_on_wall():
		_flip()
	elif is_on_floor() and not floor_check.is_colliding():
		_flip()

	velocity.x = _dir * patrol_speed
	move_and_slide()


func _flip() -> void:
	_dir = -_dir
	floor_check.position.x = _dir * 22.0


## Вызывается хитбоксом игрока при попадании.
func take_damage(amount: int) -> void:
	_health -= amount
	_flash()
	if _health <= 0:
		die()


func _flash() -> void:
	modulate = Color(1, 0.4, 0.4)
	await get_tree().create_timer(0.08).timeout
	modulate = Color(1, 1, 1)


func die() -> void:
	queue_free()
