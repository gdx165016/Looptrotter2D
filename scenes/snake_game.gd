extends Node2D

const CELL_SIZE: int = 20
const GRID_WIDTH: int = 32
const GRID_HEIGHT: int = 24

enum Direction { UP, DOWN, LEFT, RIGHT }
enum GameMode { NORMAL, HARDCORE }
enum GameState { MENU, PLAYING, GAME_OVER }

var snake: Array[Vector2i] = []
var direction: Direction = Direction.RIGHT
var next_direction: Direction = Direction.RIGHT

var food_pos: Vector2i
var bad_food_pos: Vector2i

# party mode
var party_foods: Array[Vector2i] = []
var party_mode: bool = false
var good_food_eaten: int = 0

var move_timer: float = 0.0
var move_interval: float = 0.15

var game_state: GameState = GameState.MENU
var game_mode: GameMode = GameMode.NORMAL

var paused: bool = false
var score: int = 0
var lives: int = 3

# efekt uderzenia
var hit_flash: float = 0.0
const HIT_FLASH_TIME := 0.25


func _ready() -> void:
	randomize()
	queue_redraw()


func _start_game() -> void:
	_reset_game()
	game_state = GameState.PLAYING


func _reset_game() -> void:
	snake.clear()

	var start_pos := Vector2i(GRID_WIDTH / 2, GRID_HEIGHT / 2)

	snake.append(start_pos)
	snake.append(start_pos + Vector2i(-1, 0))
	snake.append(start_pos + Vector2i(-2, 0))

	direction = Direction.RIGHT
	next_direction = Direction.RIGHT

	score = 0
	lives = 3
	paused = false
	move_interval = 0.15
	hit_flash = 0.0

	party_mode = false
	good_food_eaten = 0
	party_foods.clear()

	_spawn_foods()


func _spawn_foods() -> void:

	while true:
		var pos := Vector2i(randi() % GRID_WIDTH, randi() % GRID_HEIGHT)
		if pos not in snake:
			food_pos = pos
			break

	if game_mode == GameMode.NORMAL:
		while true:
			var pos := Vector2i(randi() % GRID_WIDTH, randi() % GRID_HEIGHT)
			if pos not in snake and pos != food_pos:
				bad_food_pos = pos
				break


func _start_party_mode() -> void:
	party_mode = true
	party_foods.clear()

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var pos := Vector2i(x, y)
			if pos not in snake:
				party_foods.append(pos)


func _process(delta: float) -> void:

	if game_state == GameState.MENU:
		_handle_menu_input()
		return

	if Input.is_action_just_pressed("ui_select"):
		paused = !paused
		queue_redraw()

	if game_state == GameState.GAME_OVER:
		if Input.is_action_just_pressed("ui_accept"):
			game_state = GameState.MENU
		return

	if paused:
		return

	if hit_flash > 0.0:
		hit_flash -= delta
		queue_redraw()

	_handle_input()

	move_timer += delta

	if move_timer >= move_interval:
		move_timer = 0.0
		_move_snake()


func _handle_menu_input() -> void:

	if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
		if game_mode == GameMode.NORMAL:
			game_mode = GameMode.HARDCORE
		else:
			game_mode = GameMode.NORMAL
		queue_redraw()

	if Input.is_action_just_pressed("ui_accept"):
		_start_game()


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
		Direction.UP: dir_vec = Vector2i(0, -1)
		Direction.DOWN: dir_vec = Vector2i(0, 1)
		Direction.LEFT: dir_vec = Vector2i(-1, 0)
		Direction.RIGHT: dir_vec = Vector2i(1, 0)

	var new_head := head + dir_vec

	if new_head.x < 0 or new_head.x >= GRID_WIDTH \
	or new_head.y < 0 or new_head.y >= GRID_HEIGHT:
		_lose_life()
		return

	if new_head in snake:
		_lose_life()
		return

	snake.insert(0, new_head)

	if party_mode:

		if new_head in party_foods:
			party_foods.erase(new_head)
			score += 1
		else:
			snake.pop_back()

	else:

		if new_head == food_pos:

			score += 1

			if game_mode == GameMode.HARDCORE:
				good_food_eaten += 1
				if good_food_eaten >= 2:
					_start_party_mode()

			move_interval = max(0.05, move_interval - 0.005)
			_spawn_foods()

		elif game_mode == GameMode.NORMAL and new_head == bad_food_pos:
			_lose_life()
			snake.pop_back()
			_spawn_foods()

		else:
			snake.pop_back()

	queue_redraw()


func _lose_life() -> void:

	lives -= 1
	hit_flash = HIT_FLASH_TIME

	if lives <= 0:
		game_state = GameState.GAME_OVER

	queue_redraw()

func _draw() -> void:

	var font = ThemeDB.fallback_font
	var screen_w = GRID_WIDTH * CELL_SIZE

	if game_state == GameState.MENU:

		var title := "SNAKE"
		var mode_text := "MODE: " + ("NORMAL" if game_mode == GameMode.NORMAL else "HARDCORE")
		var info := "ENTER - START | LEFT/RIGHT - MODE"

		var title_size = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
		draw_string(font, Vector2((screen_w - title_size.x) / 2, 150), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)

		var mode_size = font.get_string_size(mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		draw_string(font, Vector2((screen_w - mode_size.x) / 2, 200), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.8, 1))

		var info_size = font.get_string_size(info, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, Vector2((screen_w - info_size.x) / 2, 250), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.7, 0.7))

		return

	draw_rect(
		Rect2(Vector2.ZERO, Vector2(GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE)),
		Color(0.05, 0.05, 0.05)
	)

	if party_mode:
		for pos in party_foods:
			draw_rect(Rect2(pos * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE)), Color(1, 1, 0))
	else:
		draw_rect(Rect2(food_pos * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE)), Color(1, 0.2, 0.2))

		if game_mode == GameMode.NORMAL:
			draw_rect(Rect2(bad_food_pos * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE)), Color(0.2, 1, 0.2))

	for i in range(snake.size()):
		var rect := Rect2(snake[i] * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
		var col := Color(0.1, 0.8, 0.1)
		if i == 0:
			col = Color(0.2, 1, 0.2)
		draw_rect(rect, col)

	draw_string(font, Vector2(10, 20), "Score: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, Vector2(10, 40), "Lives: %d" % lives, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.6, 0.6))

	if party_mode:
		draw_string(font, Vector2(10, 60), "PARTY MODE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 0))

	if game_state == GameState.GAME_OVER:
		var go_text = "GAME OVER - ENTER"
		var go_size = font.get_string_size(go_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		draw_string(font, Vector2((screen_w - go_size.x) / 2, 200), go_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.4, 0.4))

	if paused:
		var p_text = "PAUSED"
		var p_size = font.get_string_size(p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		draw_string(font, Vector2((screen_w - p_size.x) / 2, 180), p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 0.3))

	if hit_flash > 0.0:
		var alpha := hit_flash / HIT_FLASH_TIME
		draw_rect(
			Rect2(Vector2.ZERO, Vector2(GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE)),
			Color(1, 0, 0, 0.3 * alpha)
		)
