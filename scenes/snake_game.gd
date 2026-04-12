extends Node2D

const CELL_SIZE: int = 20
const GRID_WIDTH: int = 32
const GRID_HEIGHT: int = 24

@onready var snake_head_tex: Texture2D = preload("res://art/snakehead.png")
@onready var beer_tex: Texture2D = preload("res://art/piwo.png")
@onready var water_tex: Texture2D = preload("res://art/woda.png")

# 🎧 AUDIO
@onready var music_normal: AudioStreamPlayer = $MusicNormal
@onready var music_party: AudioStreamPlayer = $MusicParty
@onready var sfx_beer: AudioStreamPlayer = $SfxBeer
@onready var sfx_water: AudioStreamPlayer = $SfxWater

enum Direction { UP, DOWN, LEFT, RIGHT }
enum GameMode { NORMAL, HARDCORE }
enum GameState { MENU, INSTRUCTIONS_NORMAL, INSTRUCTIONS_HARDCORE, PLAYING, GAME_OVER }

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

var party_border_phase: float = 0.0
var hardcore_border_phase: float = 0.0   # 🚨 faza kogutów policyjnych


func _ready() -> void:
	randomize()
	queue_redraw()


# ---------------- START ----------------

func _start_game() -> void:
	_reset_game()
	game_state = GameState.PLAYING

	music_party.stop()
	music_normal.play()


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


# ---------------- PARTY MODE ----------------

func _start_party_mode() -> void:

	party_mode = true
	party_foods.clear()

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var pos := Vector2i(x, y)
			if pos not in snake:
				party_foods.append(pos)

	music_normal.stop()
	music_party.play()


# ---------------- SPAWN ----------------

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


# ---------------- LOOP ----------------

func _process(delta: float) -> void:

	if game_state == GameState.MENU:
		_handle_menu_input()
		return

	if game_state == GameState.INSTRUCTIONS_NORMAL:
		queue_redraw()
		if Input.is_action_just_pressed("ui_accept"):
			_start_game()
		return

	if game_state == GameState.INSTRUCTIONS_HARDCORE:
		queue_redraw()
		if Input.is_action_just_pressed("ui_accept"):
			_start_game()
		return

	if game_state == GameState.GAME_OVER:
		queue_redraw()
		if Input.is_action_just_pressed("ui_accept"):
			game_state = GameState.MENU
		return

	if paused:
		return

	if hit_flash > 0.0:
		hit_flash -= delta

	_handle_input()

	move_timer += delta

	if move_timer >= move_interval:
		move_timer = 0.0
		_move_snake()

	if party_mode and good_food_eaten >= 2:
		party_border_phase += delta * 8.0

	# 🚨 HARDCORE BORDER ANIMATION — tylko w party mode
	if game_mode == GameMode.HARDCORE and party_mode and game_state == GameState.PLAYING:
		hardcore_border_phase += delta * 6.0


# ---------------- INPUT ----------------

func _handle_menu_input() -> void:

	if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
		game_mode = GameMode.HARDCORE if game_mode == GameMode.NORMAL else GameMode.NORMAL
		queue_redraw()

	if Input.is_action_just_pressed("ui_accept"):
		if game_mode == GameMode.NORMAL:
			game_state = GameState.INSTRUCTIONS_NORMAL
		else:
			game_state = GameState.INSTRUCTIONS_HARDCORE


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


# ---------------- MOVE ----------------

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

	# ---------------- WALL COLLISION = INSTANT DEATH ----------------
	if new_head.x < 0 or new_head.x >= GRID_WIDTH or new_head.y < 0 or new_head.y >= GRID_HEIGHT:
		lives = 1
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
			good_food_eaten += 1
		else:
			snake.pop_back()

	else:

		if new_head == food_pos:

			sfx_beer.play()
			score += 1

			if game_mode == GameMode.HARDCORE:
				good_food_eaten += 1
				if good_food_eaten >= 2:
					_start_party_mode()

			move_interval = max(0.05, move_interval - 0.005)
			_spawn_foods()

		elif game_mode == GameMode.NORMAL and new_head == bad_food_pos:

			sfx_water.play()
			_lose_life()
			snake.pop_back()
			_spawn_foods()

		else:
			snake.pop_back()

	queue_redraw()


# ---------------- GAME OVER ----------------

func _lose_life() -> void:

	lives -= 1
	hit_flash = HIT_FLASH_TIME

	if lives <= 0:
		game_state = GameState.GAME_OVER
		music_normal.stop()
		music_party.stop()

	queue_redraw()


# ---------------- FIXED ROTATION ----------------

func _get_head_rotation() -> float:
	match direction:
		Direction.UP:
			return deg_to_rad(270)
		Direction.DOWN:
			return deg_to_rad(90)
		Direction.LEFT:
			return deg_to_rad(180)
		Direction.RIGHT:
			return deg_to_rad(0)
	return 0.0


# ---------------- DRAW ----------------

func _draw() -> void:

	var font = ThemeDB.fallback_font
	var screen_w = GRID_WIDTH * CELL_SIZE
	var screen_h = GRID_HEIGHT * CELL_SIZE

	# ---------------- GAME OVER ----------------
	if game_state == GameState.GAME_OVER:

		draw_rect(Rect2(Vector2.ZERO, Vector2(screen_w, screen_h)), Color(0,0,0))

		var txt1 := "GAME OVER"
		var txt2 := "PRESS ENTER TO RETURN"

		var s1 = font.get_string_size(txt1, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)
		var s2 = font.get_string_size(txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)

		draw_string(font, Vector2((screen_w - s1.x)/2, screen_h/2 - 20), txt1, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1,0.3,0.3))
		draw_string(font, Vector2((screen_w - s2.x)/2, screen_h/2 + 20), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

		return

	# ---------------- INSTRUCTIONS NORMAL ----------------
	if game_state == GameState.INSTRUCTIONS_NORMAL:

		draw_rect(Rect2(Vector2.ZERO, Vector2(screen_w, screen_h)), Color(0,0,0))

		var txt1 := "MOCNY FULL – zbieraj, aby dostawać punkty"
		var txt2 := "WODA – uważaj, zabiera ci ona życia!"
		var txt3 := "ZDERZENIE ZE ŚCIANĄ – to game over"
		var txt4 := "NACIŚNIJ ENTER, ABY ZACZĄĆ"

		var s1 = font.get_string_size(txt1, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var s2 = font.get_string_size(txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var s3 = font.get_string_size(txt3, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var s4 = font.get_string_size(txt4, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)

		draw_string(font, Vector2((screen_w - s1.x)/2, 150), txt1, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		draw_string(font, Vector2((screen_w - s2.x)/2, 190), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		draw_string(font, Vector2((screen_w - s3.x)/2, 230), txt3, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		draw_string(font, Vector2((screen_w - s4.x)/2, 300), txt4, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8,0.8,1))

		return

	# ---------------- INSTRUCTIONS HARDCORE ----------------
	if game_state == GameState.INSTRUCTIONS_HARDCORE:

		draw_rect(Rect2(Vector2.ZERO, Vector2(screen_w, screen_h)), Color(0,0,0))

		var txt1 := "Zbieraj MOCNY FULL, kaucja sama się nie odda!"
		var txt2 := "NACIŚNIJ ENTER, ABY ZACZĄĆ"

		var s1 = font.get_string_size(txt1, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		var s2 = font.get_string_size(txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)

		draw_string(font, Vector2((screen_w - s1.x)/2, 200), txt1, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		draw_string(font, Vector2((screen_w - s2.x)/2, 260), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8,0.8,1))

		return

	# ---------------- MENU ----------------
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


	# ---------------- GAMEPLAY ----------------

	draw_rect(Rect2(Vector2.ZERO, Vector2(screen_w, screen_h)), Color(0.05,0.05,0.05))

	# 🚨 HARDCORE BORDER EFFECT — tylko w party mode
	if game_mode == GameMode.HARDCORE and party_mode and game_state == GameState.PLAYING:

		var t = sin(hardcore_border_phase)

		var col1 = Color(1, 0, 0, abs(t))     # czerwony
		var col2 = Color(0, 0.3, 1, abs(-t)) # niebieski

		var thickness = 6

		draw_rect(Rect2(0, 0, screen_w, thickness), col1 if t > 0 else col2)
		draw_rect(Rect2(0, screen_h - thickness, screen_w, thickness), col1 if t > 0 else col2)
		draw_rect(Rect2(0, 0, thickness, screen_h), col1 if t > 0 else col2)
		draw_rect(Rect2(screen_w - thickness, 0, thickness, screen_h), col1 if t > 0 else col2)


	# ---------------- FOOD + SNAKE ----------------

	if party_mode:

		for pos in party_foods:
			draw_texture_rect(beer_tex, Rect2(pos * CELL_SIZE, Vector2(CELL_SIZE,CELL_SIZE)), false)

	else:

		draw_texture_rect(beer_tex, Rect2(food_pos * CELL_SIZE, Vector2(CELL_SIZE,CELL_SIZE)), false)

		if game_mode == GameMode.NORMAL:
			draw_texture_rect(water_tex, Rect2(bad_food_pos * CELL_SIZE, Vector2(CELL_SIZE,CELL_SIZE)), false)


	for i in range(snake.size()):

		var pos := snake[i] * CELL_SIZE

		if i == 0:

			var pos_v2 := Vector2(pos)

			draw_set_transform(
				pos_v2 + Vector2(CELL_SIZE/2, CELL_SIZE/2),
				_get_head_rotation(),
				Vector2.ONE
			)

			draw_texture_rect(
				snake_head_tex,
				Rect2(Vector2(-CELL_SIZE/2, -CELL_SIZE/2), Vector2(CELL_SIZE,CELL_SIZE)),
				false
			)

			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		else:

			draw_rect(Rect2(pos, Vector2(CELL_SIZE,CELL_SIZE)), Color("#8DD86D"))


	# ---------------- PARTY MODE TEXT (na wierzchu, migający) ----------------
	if party_mode:

		var txt := "PARTY MODE"
		var size = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)

		var t = sin(hardcore_border_phase)

		var col1 = Color(1, 0, 0, abs(t))
		var col2 = Color(0, 0.3, 1, abs(-t))

		var final_color = col1 if t > 0 else col2

		draw_string(
			font,
			Vector2((screen_w - size.x)/2, 90),
			txt,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20,
			final_color
		)


	# ---------------- HUD ----------------

	draw_string(font, Vector2(10,20), "Score: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, Vector2(10,40), "Lives: %d" % lives, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1,0.6,0.6))


	if hit_flash > 0.0:

		var alpha := hit_flash / HIT_FLASH_TIME

		draw_rect(Rect2(Vector2.ZERO, Vector2(screen_w, screen_h)), Color(1,0,0,0.3 * alpha))
