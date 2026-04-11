extends Node2D

const CELL_SIZE: int = 20
const GRID_WIDTH: int = 32
const GRID_HEIGHT: int = 24

@onready var snake_head_tex: Texture2D = preload("res://art/snakehead.png")
@onready var beer_tex: Texture2D = preload("res://art/piwo.png")
@onready var water_tex: Texture2D = preload("res://art/woda.png")

enum Direction { UP, DOWN, LEFT, RIGHT }
enum GameMode { NORMAL, HARDCORE }
enum GameState { MENU, PLAYING, GAME_OVER }

var direction_queue: Array[Direction] = []
const MAX_QUEUE_SIZE := 3

var snake: Array[Vector2i] = []
var direction: Direction = Direction.RIGHT

var food_pos: Vector2i
var bad_food_pos: Vector2i

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

	score = 0
	lives = 3
	move_interval = 0.15

	party_mode = false
	good_food_eaten = 0
	party_foods.clear()

	direction_queue.clear()

	hit_flash = 0.0

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

	if game_state == GameState.GAME_OVER:
		if Input.is_action_just_pressed("ui_accept"):
			game_state = GameState.MENU
		queue_redraw()
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

	var new_dir: Direction

	if Input.is_action_just_pressed("ui_up"):
		new_dir = Direction.UP

	elif Input.is_action_just_pressed("ui_down"):
		new_dir = Direction.DOWN

	elif Input.is_action_just_pressed("ui_left"):
		new_dir = Direction.LEFT

	elif Input.is_action_just_pressed("ui_right"):
		new_dir = Direction.RIGHT

	else:
		return


	var last_dir := direction

	if direction_queue.size() > 0:
		last_dir = direction_queue[-1]

	if _is_opposite(new_dir, last_dir):
		return

	if direction_queue.size() < MAX_QUEUE_SIZE:
		direction_queue.append(new_dir)


func _is_opposite(a: Direction, b: Direction) -> bool:

	return (
		(a == Direction.UP and b == Direction.DOWN) or
		(a == Direction.DOWN and b == Direction.UP) or
		(a == Direction.LEFT and b == Direction.RIGHT) or
		(a == Direction.RIGHT and b == Direction.LEFT)
	)


func _move_snake() -> void:

	if direction_queue.size() > 0:
		direction = direction_queue.pop_front()

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
	var screen_h = GRID_HEIGHT * CELL_SIZE


	# ===== MENU =====

	if game_state == GameState.MENU:

		var title := "SNAKE"
		var mode_text := "MODE: " + ("NORMAL" if game_mode == GameMode.NORMAL else "HARDCORE")
		var info := "ENTER - START | LEFT/RIGHT - MODE"

		var t_size = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
		var m_size = font.get_string_size(mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var i_size = font.get_string_size(info, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)

		draw_string(font, Vector2((screen_w - t_size.x)/2, 150), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
		draw_string(font, Vector2((screen_w - m_size.x)/2, 200), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8,0.8,1))
		draw_string(font, Vector2((screen_w - i_size.x)/2, 250), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7,0.7,0.7))

		return


	# ===== TŁO =====

	draw_rect(
		Rect2(Vector2.ZERO, Vector2(screen_w, screen_h)),
		Color(0.05,0.05,0.05)
	)


	# ===== FOOD =====

	if party_mode:

		for pos in party_foods:
			draw_texture_rect(
				beer_tex,
				Rect2(pos * CELL_SIZE, Vector2(CELL_SIZE,CELL_SIZE)),
				false
			)

	else:

		draw_texture_rect(
			beer_tex,
			Rect2(food_pos * CELL_SIZE, Vector2(CELL_SIZE,CELL_SIZE)),
			false
		)

		if game_mode == GameMode.NORMAL:

			draw_texture_rect(
				water_tex,
				Rect2(bad_food_pos * CELL_SIZE, Vector2(CELL_SIZE,CELL_SIZE)),
				false
			)


	# ===== PARTY TEXT =====

	if party_mode:

		var txt := "PARTY MODE"
		var size = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)

		draw_string(
			font,
			Vector2((screen_w - size.x)/2, 90),
			txt,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20,
			Color(1,1,0)
		)


	# ===== SNAKE =====

	for i in range(snake.size()):

		var pos := snake[i] * CELL_SIZE

		if i == 0:

			draw_texture_rect(
				snake_head_tex,
				Rect2(pos, Vector2(CELL_SIZE,CELL_SIZE)),
				false
			)

		else:

			draw_rect(
				Rect2(pos, Vector2(CELL_SIZE,CELL_SIZE)),
				Color("#8DD86D")
			)


	# ===== UI =====

	draw_string(font, Vector2(10,20), "Score: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, Vector2(10,40), "Lives: %d" % lives, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1,0.6,0.6))


	# ===== GAME OVER =====

	if game_state == GameState.GAME_OVER:

		var txt1 := "GAME OVER"
		var txt2 := "PRESS ENTER TO RESTART"

		var s1 = font.get_string_size(txt1, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
		var s2 = font.get_string_size(txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)

		draw_string(font, Vector2((screen_w - s1.x)/2, screen_h/2 - 10), txt1, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1,0.3,0.3))
		draw_string(font, Vector2((screen_w - s2.x)/2, screen_h/2 + 25), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)


	# ===== HIT FLASH =====

	if hit_flash > 0.0:

		var alpha := hit_flash / HIT_FLASH_TIME

		draw_rect(
			Rect2(Vector2.ZERO, Vector2(screen_w, screen_h)),
			Color(1,0,0,0.3 * alpha)
		)
