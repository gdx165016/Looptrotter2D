extends Node2D

const CELL_SIZE: int = 20
const GRID_WIDTH: int = 32
const GRID_HEIGHT: int = 24

enum Direction { UP, DOWN, LEFT, RIGHT }

var snake: Array[Vector2i] = []
var direction: Direction = Direction.RIGHT
var next_direction: Direction = Direction.RIGHT
var food_pos: Vector2i

var move_timer: float = 0.0
var move_interval: float = 0.15

var game_over: bool = false
var score: int = 0


func _ready() -> void:
	randomize()
	_reset_game()


func _reset_game() -> void:
	snake.clear()

	var start_pos := Vector2i(GRID_WIDTH / 2, GRID_HEIGHT / 2)

	snake.append(start_pos)
	snake.append(start_pos + Vector2i(-1, 0))
	snake.append(start_pos + Vector2i(-2, 0))

	direction = Direction.RIGHT
	next_direction = Direction.RIGHT

	score = 0
	game_over = false
	move_interval = 0.15

	_spawn_food()

	queue_redraw()


func _spawn_food() -> void:
	while true:
		var pos := Vector2i(
			randi() % GRID_WIDTH,
			randi() % GRID_HEIGHT
		)

		if pos not in snake:
			food_pos = pos
			break


func _process(delta: float) -> void:

	if game_over:
		if Input.is_action_just_pressed("ui_accept"):
			_reset_game()
		return

	_handle_input()

	move_timer += delta

	if move_timer >= move_interval:
		move_timer = 0.0
		_move_snake()


func _handle_input() -> void:

	if Input.is_action_just_pressed("ui_up") and direction != Direction.DOWN:
		next_direction = Direction.UP

	elif Input.is_action_just_pressed("ui_down") and direction != Direction.UP:
		next_direction = Direction.DOWN

	elif Input.is_action_just_pressed("ui_left") and direction != Direction.RIGHT:
		next_direction = Direction.LEFT

	elif Input.is_action_just_pressed("ui_right") and direction != Direction.LEFT:
		next_direction = Direction.RIGHT


func _move_snake() -> void:

	direction = next_direction

	var head := snake[0]

	var dir_vec: Vector2i

	match direction:
		Direction.UP:
			dir_vec = Vector2i(0, -1)

		Direction.DOWN:
			dir_vec = Vector2i(0, 1)

		Direction.LEFT:
			dir_vec = Vector2i(-1, 0)

		Direction.RIGHT:
			dir_vec = Vector2i(1, 0)

	var new_head := head + dir_vec

	# kolizja ze ścianą
	if new_head.x < 0 or new_head.x >= GRID_WIDTH \
	or new_head.y < 0 or new_head.y >= GRID_HEIGHT:
		_game_over()
		return

	# kolizja z samym sobą
	if new_head in snake:
		_game_over()
		return

	snake.insert(0, new_head)

	# jedzenie
	if new_head == food_pos:

		score += 1

		move_interval = max(0.05, move_interval - 0.005)

		_spawn_food()

	else:

		snake.pop_back()

	queue_redraw()


func _game_over() -> void:

	game_over = true

	queue_redraw()


func _draw() -> void:

	# tło
	draw_rect(
		Rect2(
			Vector2.ZERO,
			Vector2(GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE)
		),
		Color(0.05, 0.05, 0.05)
	)

	# jedzenie
	var food_rect := Rect2(
		Vector2(
			food_pos.x * CELL_SIZE,
			food_pos.y * CELL_SIZE
		),
		Vector2(CELL_SIZE, CELL_SIZE)
	)

	draw_rect(food_rect, Color(1, 0.2, 0.2))

	# wąż
	for i in range(snake.size()):

		var seg := snake[i]

		var rect := Rect2(
			Vector2(
				seg.x * CELL_SIZE,
				seg.y * CELL_SIZE
			),
			Vector2(CELL_SIZE, CELL_SIZE)
		)

		var col := Color(0.1, 0.8, 0.1)

		if i == 0:
			col = Color(0.2, 1, 0.2)

		draw_rect(rect, col)

	# ===== TEKST (działa w Godot 4) =====

	var font = ThemeDB.fallback_font
	var font_size := 16

	# wynik
	draw_string(
		font,
		Vector2(10, 20),
		"Score: %d" % score,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color.WHITE
	)

	# game over
	if game_over:

		var msg := "GAME OVER - Enter aby zagrać ponownie"

		var size := font.get_string_size(
			msg,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20
		)

		var pos := Vector2(
			(GRID_WIDTH * CELL_SIZE - size.x) / 2,
			(GRID_HEIGHT * CELL_SIZE) / 2
		)

		draw_string(
			font,
			pos,
			msg,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20,
			Color(1, 0.4, 0.4)
		)
