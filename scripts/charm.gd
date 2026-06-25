extends Resource
## Charm — описание одного амулета (чарма).
##
## `class_name Charm` делает этот тип доступным во всём проекте по имени Charm,
## как встроенные типы Godot. `extends Resource` — значит это «данные», а не объект
## на сцене: у чарма нет позиции/визуала, он просто хранит числа и текст.
##
## В этом прототипе мы создаём чармы прямо в коде (см. GameState._build_charm_catalog),
## но при желании такой ресурс можно сохранить отдельным файлом .tres и править мышкой
## в инспекторе Godot — это и есть смысл custom Resource.
class_name Charm

# --- Описание (для меню) ---
@export var id: String = ""           # уникальный код, например "heavy_nail"
@export var charm_name: String = ""   # название для игрока
@export var description: String = ""  # что делает (текст в меню)
@export var notch_cost: int = 1       # сколько ячеек (notches) занимает

# --- Эффекты (бонусы к характеристикам игрока) ---
# Плоские числовые поля — так проще всего: GameState просто суммирует их по всем
# надетым чармам, а player.gd применяет в нужном месте.
@export var nail_damage_bonus: int = 0    # плюс к урону гвоздя
@export var soul_per_hit_bonus: int = 0   # плюс к soul за удар гвоздём
@export var move_speed_mult: float = 1.0  # множитель скорости бега (1.0 = без изменений)
@export var focus_time_mult: float = 1.0  # множитель времени лечения (<1.0 = лечит быстрее)
@export var nail_range_mult: float = 1.0  # множитель размаха удара в стороны
