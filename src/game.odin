package game

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"

_ :: fmt

Game_Memory :: struct {
	p1:          Player,
	p2:          Player,
	ball:        Ball,
	game_freeze: bool,
	buf_spawner: BufSpawner,
	buf_effect:  BufEffect,
	pause_menu:  PauseMenu,
}

Width :: 1280
Height :: 720

g_mem: ^Game_Memory

@(export)
game_init_window :: proc() {
	rl.InitWindow(1280, 720, "Pong the dong")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	rl.SetExitKey(.F1)
}

collission_mouse_rect :: proc(rect: rl.Rectangle) -> bool {
	pos := rl.GetMousePosition()
	if pos.x > rect.x &&
	   pos.x < rect.x + rect.width &&
	   pos.y > rect.y &&
	   pos.y < rect.y + rect.height {
		return true
	}
	return false
}

Timer :: struct {
	time:     f32,
	max_time: f32,
	finished: bool,
}

create_timer :: proc(max_time: f32) -> Timer {
	return Timer{time = 0.0, max_time = max_time}
}

reset_timer :: proc(timer: ^Timer) {
	timer.time = 0.0
	timer.finished = false
}

update_timer :: proc(timer: ^Timer, dt: f32) -> bool {
	timer.time += dt
	if timer.time >= timer.max_time {
		timer.finished = true
	}
	return timer.finished
}

time_left :: proc(timer: Timer) -> f32 {
	return timer.max_time - timer.time
}

//rotates clockwise
rotate_point_around_origin :: proc(
	v: rl.Vector2,
	angle: f32,
	origin := rl.Vector2{0.0, 0.0},
) -> rl.Vector2 {
	v := v
	v -= origin
	v = {
		v.x * math.cos(angle) - v.y * math.sin(angle),
		v.y * math.cos(angle) + v.x * math.sin(angle),
	}
	v += origin
	return v
}

to_rad :: proc(deg: f32) -> f32 {
	return deg * 3.1415 / 180.0
}

rect_right :: proc(rect: rl.Rectangle, size: f32 = 5.0) -> rl.Rectangle {
	return rl.Rectangle{rect.x + rect.width - size, rect.y, size, rect.height}
}

rect_left :: proc(rect: rl.Rectangle, size: f32 = 5.0) -> rl.Rectangle {
	return rl.Rectangle{rect.x, rect.y, size, rect.height}
}

rect_top :: proc(rect: rl.Rectangle, size: f32 = 5.0) -> rl.Rectangle {
	return rl.Rectangle{rect.x, rect.y, rect.width, size}
}

rect_bottom :: proc(rect: rl.Rectangle, size: f32 = 5.0) -> rl.Rectangle {
	return rl.Rectangle{rect.x, rect.y + rect.height - size, rect.width, size}
}

Player :: struct {
	rect:      rl.Rectangle,
	speed:     f32,
	left:      bool,
	score:     int,
	color:     rl.Color,
	move_up:   rl.KeyboardKey,
	move_down: rl.KeyboardKey,
}

update_player :: proc(p: ^Player, dt: f32) {
	if rl.IsKeyDown(p.move_up) {
		p.rect.y -= p.speed * dt
	}

	if rl.IsKeyDown(p.move_down) {
		p.rect.y += p.speed * dt
	}

	if p.rect.y < 0.0 {
		p.rect.y = 0.0
	}
	if p.rect.y + p.rect.height > Height {
		p.rect.y = Height - p.rect.height
	}
}

Ball :: struct {
	pos:             rl.Vector2,
	pos_start:       rl.Vector2,
	radius:          f32,
	dir:             rl.Vector2,
	speed:           f32,
	speed_start:     f32,
	speed_increment: f32,
}

reset_ball :: proc(ball: Ball) -> Ball {
	return create_ball(ball.pos_start, ball.radius, ball.speed)
}

create_ball :: proc(pos: rl.Vector2, radius: f32, speed: f32) -> Ball {
	ball: Ball
	ball.pos = pos
	ball.pos_start = pos
	ball.radius = radius
	ball.speed = speed
	ball.speed_start = speed
	ball.speed_increment = 30.0

	dir := rl.Vector2{1.0, 0.0}
	angle := f32(int(rand.float32() * 120.0) - 60)
	if sign := rand.int31() % 2; sign == 0 {
		angle += 180.0
	}

	ball.dir = rl.Vector2Normalize(rotate_point_around_origin(dir, to_rad(angle)))

	return ball
}

update_ball :: proc(ball: ^Ball, p1: ^Player, p2: ^Player, dt: f32) -> bool {
	freeze := false

	ball.pos += ball.dir * ball.speed * dt

	if ball.pos.x > Width {
		ball.dir.x *= -1.0
		p1.score += 1

		ball.pos = ball.pos_start
		dir := rl.Vector2{1.0, 0.0}
		angle := f32(int(rand.float32() * 120.0) - 60)
		if sign := rand.int31() % 2; sign == 0 {
			angle += 180.0
		}
		ball.dir = rl.Vector2Normalize(rotate_point_around_origin(dir, to_rad(angle)))
		ball.speed = ball.speed_start
		freeze = true
	}

	if ball.pos.x < 0.0 {
		ball.dir.x *= -1.0
		p2.score += 1

		ball.pos = ball.pos_start
		dir := rl.Vector2{1.0, 0.0}
		angle := f32(int(rand.float32() * 120.0) - 60)
		if sign := rand.int31() % 2; sign == 0 {
			angle += 180.0
		}
		ball.dir = rl.Vector2Normalize(rotate_point_around_origin(dir, to_rad(angle)))
		ball.speed = ball.speed_start
		freeze = true
	}
	if ball.pos.y > Height || ball.pos.y < 0.0 {
		ball.dir.y *= -1
	}

	if rl.CheckCollisionCircleRec(ball.pos, ball.radius, rect_right(p1.rect)) {
		ball.dir.x *= -1

		ball.speed += ball.speed_increment
	}
	if rl.CheckCollisionCircleRec(ball.pos, ball.radius, rect_top(p1.rect)) ||
	   rl.CheckCollisionCircleRec(ball.pos, ball.radius, rect_bottom(p1.rect)) {
		ball.dir.y *= -1

	}

	if rl.CheckCollisionCircleRec(ball.pos, ball.radius, rect_left(p2.rect)) {
		ball.dir.x *= -1

		ball.speed += ball.speed_increment
	}
	if rl.CheckCollisionCircleRec(ball.pos, ball.radius, rect_top(p2.rect)) ||
	   rl.CheckCollisionCircleRec(ball.pos, ball.radius, rect_bottom(p2.rect)) {
		ball.dir.y *= -1

	}

	return freeze
}

draw_stripped_line :: proc(
	start, end: rl.Vector2,
	space_count: int,
	space: f32 = 20.0,
	color := rl.WHITE,
) {
	line_count := space_count + 1
	line_len := (Height - (space * f32(space_count))) / f32(line_count)

	for i in 0 ..< line_count {
		offset := f32(i) * (line_len + space)
		rl.DrawLineV({Width / 2, offset}, {Width / 2, offset + line_len}, rl.WHITE)
	}
}

fit_text_in_line :: proc(text: string, scale: int, width: f32, min_scale := 15) -> int {
	text_cstring := strings.clone_to_cstring(text, context.temp_allocator)
	if f32(rl.MeasureText(text_cstring, i32(min_scale))) > width {
		return 1000
	}
	scale := scale
	for scale > min_scale {
		if f32(rl.MeasureText(text_cstring, i32(scale))) < width {
			break
		}
		scale -= 1
	}
	return scale
}

fit_text_in_column :: proc(scale: int, height: f32, min_scale: f32 = 15) -> int {
	if f32(scale) < height {
		return scale
	} else if height >= min_scale {
		return int(height)
	} else {
		return 1000
	}
}

fit_text_in_rect :: proc(
	text: string,
	dims: rl.Vector2,
	wanted_scale: int,
	min_scale: f32 = 15,
) -> int {
	scale_x := fit_text_in_line(text, wanted_scale, dims.x, int(min_scale))
	scale_y := fit_text_in_column(wanted_scale, dims.y, min_scale)

	if scale_x < scale_y && scale_y != 1000 {
		return scale_x
	} else if scale_y < scale_x && scale_x != 1000 {
		return scale_y
	} else if scale_x == scale_y && scale_x != 1000 {
		return scale_x
	} else {
		return 0
	}
}

adjust_and_draw_text :: proc(
	text: string,
	rect: rl.Rectangle,
	padding: rl.Vector2 = {10.0, 10.0},
	wanted_scale: int = 100,
	color := rl.WHITE,
	center := true,
) {
	scale := fit_text_in_rect(
		text,
		{rect.width - 2 * padding.x, rect.height - 2 * padding.y},
		wanted_scale,
	)

	text_cstring := strings.clone_to_cstring(text, context.temp_allocator)
	text_width := f32(rl.MeasureText(text_cstring, i32(scale)))

	centering_padding := f32(0.0)
	if center {
		centering_padding = f32((rect.width - text_width) / 2)
	}

	if scale != 0 {
		rl.DrawText(
			text_cstring,
			i32(rect.x + padding.x + centering_padding),
			i32(rect.y + padding.y),
			i32(scale),
			color,
		)
	}
}

draw_num_text :: proc(num: int, rect: rl.Rectangle, color := rl.WHITE) {
	buf: [4]byte
	str := strconv.itoa(buf[:], num)
	adjust_and_draw_text(str, rect)
}

get_random_pos :: proc(zone: rl.Rectangle) -> rl.Vector2 {
	x := f32((rand.int31() % i32(zone.width)) + i32(zone.x))
	y := f32((rand.int31() % i32(zone.height)) + i32(zone.y))
	return {x, y}
}

get_rect :: proc(buf_spawner: BufSpawner) -> rl.Rectangle {
	return {
		buf_spawner.buf_pos.x,
		buf_spawner.buf_pos.y,
		buf_spawner.buf_size,
		buf_spawner.buf_size,
	}
}

BufSpawner :: struct {
	time_btw_spawns: Timer,
	buf_size:        f32,
	buf_pos:         rl.Vector2,
	lifetime:        Timer,
	spawned_buf:     bool,
	spawn_zone:      rl.Rectangle,
	textures:        [4]rl.Texture2D,
	letter:          int,
	type:            int,
}

BufState :: enum {
	NotClicked,
	P1,
	P2,
}

BufType :: enum {
	IncreaseSize,
	DecreaseSize,
	ObscureVision,
	ReverseControls,
}

random :: proc(num: int) -> int {
	return int(rand.int31() % i32(num))
}

get_buf_type :: proc(num: int) -> BufType {
	switch num {
	case 0:
		return .IncreaseSize
	case 1:
		return .DecreaseSize
	case 2:
		return .ObscureVision
	case 3:
		return .ReverseControls
	case:
		return .IncreaseSize
	}
}

create_buf_spawner :: proc() -> BufSpawner {
	return BufSpawner {
		time_btw_spawns = create_timer(4.0),
		lifetime = create_timer(1.5),
		buf_size = 40,
		spawn_zone = rl.Rectangle{100.0, 100.0, Width - 200.0, Height - 200.0},
		textures = {
			rl.LoadTexture("res/blue.png"),
			rl.LoadTexture("res/red.png"),
			rl.LoadTexture("res/yellow.png"),
			rl.LoadTexture("res/green.png"),
		},
		type = random(4),
	}
}

update_buf_spawner :: proc(spawner: ^BufSpawner, dt: f32) -> BufState {
	buf_state := BufState.NotClicked

	if !spawner.spawned_buf {
		if spawn_buf := update_timer(&spawner.time_btw_spawns, dt); spawn_buf {
			//spawning the buf
			reset_timer(&spawner.lifetime)
			spawner.spawned_buf = true

			spawner.type = random(len(spawner.textures))

			spawner.buf_pos = get_random_pos(spawner.spawn_zone)
			spawner.letter = int((rand.int31() % (91 - 65)) + 65)
			for spawner.letter == 65 ||
			    spawner.letter == 68 ||
			    spawner.letter == 83 ||
			    spawner.letter == 81 ||
			    spawner.letter == 87 {
				spawner.letter = int((rand.int31() % (91 - 65)) + 65)
			}
		}
	} else {
		if lifetime_finished := update_timer(&spawner.lifetime, dt); lifetime_finished {
			reset_timer(&spawner.time_btw_spawns)
			spawner.spawned_buf = false
		}

		if collission_mouse_rect(get_rect(spawner^)) && rl.IsMouseButtonPressed(.LEFT) {
			buf_state = .P2
		} else if rl.IsKeyPressed(rl.KeyboardKey(spawner.letter)) {
			buf_state = .P1
		}
	}

	return buf_state
}

draw_buf :: proc(spawner: BufSpawner) {
	color := rl.WHITE
	if time_left(spawner.lifetime) < 0.5 {
		color.a = u8(255 * time_left(spawner.lifetime))
	}

	rl.DrawTextureEx(
		spawner.textures[spawner.type],
		spawner.buf_pos,
		0.0,
		spawner.buf_size / 16.0,
		color,
	)

	if spawner.type == 2 {
		//making text black on yellow buf to be able to see the letter
		color.r = 0
		color.g = 0
		color.b = 0
	}

	adjust_and_draw_text(
		utf8.runes_to_string({rune(spawner.letter)}, context.temp_allocator),
		get_rect(spawner),
		center = false,
		color = color,
	)
	free_all(context.temp_allocator)
}

BufEffect :: struct {
	is_alive:        bool,
	lifetime:        Timer,
	effect:          int,
	state:           BufState,
	buf_given:       bool,

	//to change the effects later
	increase_values: rl.Vector2,
	decrease_values: rl.Vector2,
	left_rect:       rl.Rectangle,
	right_rect:      rl.Rectangle,
}

create_buf_effect :: proc() -> BufEffect {
	return BufEffect {
		is_alive = false,
		lifetime = create_timer(3.0),
		effect = -1,
		increase_values = {50, 100},
		decrease_values = {25, 50},
		left_rect = rl.Rectangle{200, 0, 450, Height},
		right_rect = rl.Rectangle{650, 0, 450, Height},
	}
}

add_buf :: proc(buf_effect: ^BufEffect, p1: ^Player, p2: ^Player) {
	effect := get_buf_type(buf_effect.effect)
	buffed_player := buf_effect.state == .P1 ? p1 : p2
	unbuffed_player := buf_effect.state == .P1 ? p2 : p1
	switch effect {
	case .IncreaseSize:
		if !buf_effect.buf_given {
			buffed_player.rect.height += buf_effect.increase_values.y
			buffed_player.rect.y -= buf_effect.increase_values.x
			buf_effect.buf_given = true
		}
	case .DecreaseSize:
		if !buf_effect.buf_given {
			unbuffed_player.rect.height -= buf_effect.decrease_values.y
			unbuffed_player.rect.y += buf_effect.decrease_values.x
			buf_effect.buf_given = true
		}
	case .ObscureVision:
		if buf_effect.state == .P1 {
			rl.DrawRectangleRec(buf_effect.right_rect, rl.GRAY)
		}
		if buf_effect.state == .P2 {
			rl.DrawRectangleRec(buf_effect.left_rect, rl.GRAY)
		}
	case .ReverseControls:
		if !buf_effect.buf_given {
			down_move := unbuffed_player.move_down
			unbuffed_player.move_down = unbuffed_player.move_up
			unbuffed_player.move_up = down_move
			buf_effect.buf_given = true
		}
	}
}

PauseMenu :: struct {
	is_alive:        bool,
	help_rect:       rl.Rectangle,
	help_color:      rl.Color,
	help_open:       bool,
	help_back_rect:  rl.Rectangle,
	help_back_color: rl.Color,
	reset_rect:      rl.Rectangle,
	reset_color:     rl.Color,
	textures:        [4]rl.Texture2D,
}

create_pause_menu :: proc() -> PauseMenu {
	return PauseMenu {
		is_alive = false,
		help_rect = {Width / 2 - 150, Height / 2 - 150, 300, 100},
		reset_rect = {Width / 2 - 150, Height / 2, 300, 100},
		help_color = rl.Color{0, 0, 0, 0},
		reset_color = rl.Color{0, 0, 0, 0},
		help_back_rect = {25, 25, 75, 75},
		help_back_color = rl.WHITE,
	}
}

update_pause_menu :: proc(pause_menu: ^PauseMenu) -> bool {
	reset_game := false
	if collission_mouse_rect(pause_menu.help_rect) {
		pause_menu.help_color = {60, 60, 60, 200}
		if rl.IsMouseButtonPressed(.LEFT) {
			pause_menu.help_open = true
			pause_menu.help_color = {100, 100, 100, 200}
		}
	} else {
		pause_menu.help_color = {0, 0, 0, 0}
	}

	if collission_mouse_rect(pause_menu.reset_rect) {
		pause_menu.reset_color = {60, 60, 60, 200}
		if rl.IsMouseButtonPressed(.LEFT) {
			pause_menu.reset_color = {100, 100, 100, 200}
			reset_game = true
		}
	} else {
		pause_menu.reset_color = {0, 0, 0, 0}
	}

	if pause_menu.help_open && collission_mouse_rect(pause_menu.help_back_rect) {
		pause_menu.help_back_color = rl.GRAY
		if rl.IsMouseButtonPressed(.LEFT) {
			pause_menu.help_back_color = {60, 60, 60, 255}
			pause_menu.help_open = false
		}
	} else {
		pause_menu.help_back_color = rl.WHITE
	}

	return reset_game
}

draw_texture_on_rect :: proc(tex: rl.Texture, rect: rl.Rectangle) {
	scale_x := rect.width / f32(tex.width)
	scale_y := rect.height / f32(tex.height)

	if scale_y < scale_x {
		x := rect.x + (rect.width / 2.0 - f32(tex.width) * scale_y * 0.5)
		rl.DrawTextureEx(tex, {x, rect.y}, 0.0, scale_y, rl.WHITE)
	} else {
		y := rect.y + (rect.height / 2.0 - f32(tex.height) * scale_x * 0.5)
		rl.DrawTextureEx(tex, {rect.x, y}, 0.0, scale_x, rl.WHITE)
	}
}

draw_pause_menu :: proc(pause_menu: PauseMenu) {
	rl.DrawRectangleRec({0.0, 0.0, Width, Height}, rl.Color{0, 0, 0, 190})

	if pause_menu.help_open {
		for i in 0 ..< 4 {
			draw_texture_on_rect(pause_menu.textures[i], {300, f32(200 + (i * 100)), 75, 75})
		}
		rl.DrawRectangleRec({450, 200, 500, 75}, rl.BLACK)
		adjust_and_draw_text("Increases player size", {450, 200, 500, 75})
		rl.DrawRectangleRec({450, 300, 500, 75}, rl.BLACK)
		adjust_and_draw_text("Decreases enemy player size", {450, 300, 500, 75})
		rl.DrawRectangleRec({450, 400, 500, 75}, rl.BLACK)
		adjust_and_draw_text(
			"Draws a gray rectangle that covers most of the enemy's side",
			{450, 400, 500, 75},
		)
		rl.DrawRectangleRec({450, 500, 500, 75}, rl.BLACK)
		adjust_and_draw_text("reverses enemy's movement", {450, 500, 500, 75})

		rl.DrawRectangleRec(pause_menu.help_back_rect, pause_menu.help_back_color)
		adjust_and_draw_text("BACK", pause_menu.help_back_rect, center = false)

		return
	}

	rl.DrawRectangleRec(pause_menu.help_rect, pause_menu.help_color)
	adjust_and_draw_text("HELP", pause_menu.help_rect)
	rl.DrawRectangleRec(pause_menu.reset_rect, pause_menu.reset_color)
	adjust_and_draw_text("RESET", pause_menu.reset_rect)
}

reset_player_1 :: proc(p: ^Player) {
	p.rect = rl.Rectangle{50.0, Height / 4 + 100.0, 30.0, 150.0}
	p.speed = 500.0
	p.color = rl.WHITE
	p.move_up = rl.KeyboardKey.W
	p.move_down = rl.KeyboardKey.S
	p.score = 0
}

reset_player_2 :: proc(p: ^Player) {
	p.rect = rl.Rectangle{Width - 80.0, Height / 4 + 100.0, 30.0, 150.0}
	p.speed = 500.0
	p.color = rl.WHITE
	p.move_up = rl.KeyboardKey.UP
	p.move_down = rl.KeyboardKey.DOWN
	p.score = 0
}

@(export)
game_init :: proc() {
	g_mem = new(Game_Memory)

	g_mem^ = Game_Memory {
		p1 = Player {
			rect = rl.Rectangle{50.0, Height / 4 + 100.0, 30.0, 150.0},
			speed = 500.0,
			left = true,
			color = rl.WHITE,
			move_up = rl.KeyboardKey.W,
			move_down = rl.KeyboardKey.S,
		},
		p2 = Player {
			rect = rl.Rectangle{Width - 80.0, Height / 4 + 100.0, 30.0, 150.0},
			speed = 500.0,
			color = rl.WHITE,
			move_up = rl.KeyboardKey.UP,
			move_down = rl.KeyboardKey.DOWN,
		},
		ball = create_ball({Width / 2, Height / 2}, 10.0, 700.0),
		//ball = create_ball({Width / 2, Height / 2}, 10.0, 100.0),
		game_freeze = true,
		buf_spawner = create_buf_spawner(),
		buf_effect = create_buf_effect(),
		pause_menu = create_pause_menu(),
	}
	g_mem.pause_menu.textures = g_mem.buf_spawner.textures

	game_hot_reloaded(g_mem)
}

@(export)
game_update :: proc() -> bool {
	dt := rl.GetFrameTime()

	if rl.IsKeyPressed(.SPACE) && !g_mem.pause_menu.is_alive {
		g_mem.game_freeze = false
	}

	if rl.IsKeyPressed(rl.KeyboardKey.ESCAPE) {
		g_mem.pause_menu.is_alive = !g_mem.pause_menu.is_alive
		g_mem.game_freeze = g_mem.pause_menu.is_alive
	}

	//if the game is paused we cannot move players
	if !g_mem.pause_menu.is_alive {
		update_player(&g_mem.p1, dt)
		update_player(&g_mem.p2, dt)
	} else {
		if reset_game := update_pause_menu(&g_mem.pause_menu); reset_game {
			g_mem.pause_menu.is_alive = false
			g_mem.game_freeze = true

			ball := &g_mem.ball
			ball.pos = ball.pos_start
			dir := rl.Vector2{1.0, 0.0}
			angle := f32(int(rand.float32() * 120.0) - 60)
			if sign := rand.int31() % 2; sign == 0 {
				angle += 180.0
			}
			ball.dir = rl.Vector2Normalize(rotate_point_around_origin(dir, to_rad(angle)))
			ball.speed = ball.speed_start

			reset_player_1(&g_mem.p1)
			reset_player_2(&g_mem.p2)

			g_mem.buf_effect.is_alive = false
			reset_timer(&g_mem.buf_spawner.lifetime)
			reset_timer(&g_mem.buf_spawner.time_btw_spawns)
			reset_timer(&g_mem.buf_effect.lifetime)
		}
	}

	if !g_mem.game_freeze {
		if freeze := update_ball(&g_mem.ball, &g_mem.p1, &g_mem.p2, dt); freeze {
			g_mem.game_freeze = true
			reset_timer(&g_mem.buf_spawner.lifetime)
			reset_timer(&g_mem.buf_spawner.time_btw_spawns)
		}

		buf_state := update_buf_spawner(&g_mem.buf_spawner, dt)
		if g_mem.buf_spawner.spawned_buf && (buf_state == .P1 || buf_state == .P2) {

			g_mem.buf_effect.is_alive = true
			reset_timer(&g_mem.buf_effect.lifetime)
			g_mem.buf_effect.state = buf_state
			g_mem.buf_effect.effect = g_mem.buf_spawner.type
			g_mem.buf_effect.buf_given = false

			reset_timer(&g_mem.buf_spawner.lifetime)
			reset_timer(&g_mem.buf_spawner.time_btw_spawns)
			g_mem.buf_spawner.spawned_buf = false
		}
	}

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	rl.DrawRectangleRec(g_mem.p1.rect, g_mem.p1.color)
	rl.DrawRectangleRec(g_mem.p2.rect, g_mem.p2.color)
	rl.DrawCircleV(g_mem.ball.pos, g_mem.ball.radius, rl.WHITE)
	rl.DrawLineV(g_mem.ball.pos, g_mem.ball.pos + g_mem.ball.dir * 50, rl.ORANGE)

	draw_stripped_line({Width / 2, 0.0}, {Width / 2, Height}, 12)

	//buf effect
	if g_mem.buf_effect.is_alive && !g_mem.game_freeze {
		if is_dead := update_timer(&g_mem.buf_effect.lifetime, dt); is_dead {
			g_mem.buf_effect.is_alive = false

			//reversing the effects
			buffed_player := g_mem.buf_effect.state == .P1 ? &g_mem.p1 : &g_mem.p2
			unbuffed_player := g_mem.buf_effect.state == .P2 ? &g_mem.p1 : &g_mem.p2
			effect := get_buf_type(g_mem.buf_effect.effect)
			switch effect {
			case .IncreaseSize:
				buffed_player.rect.height -= g_mem.buf_effect.increase_values.y
				buffed_player.rect.y += g_mem.buf_effect.increase_values.x
			case .DecreaseSize:
				unbuffed_player.rect.height += g_mem.buf_effect.decrease_values.y
				unbuffed_player.rect.y -= g_mem.buf_effect.decrease_values.x
			case .ObscureVision:
			case .ReverseControls:
				down_move := unbuffed_player.move_down
				unbuffed_player.move_down = unbuffed_player.move_up
				unbuffed_player.move_up = down_move
			}

		}
		add_buf(&g_mem.buf_effect, &g_mem.p1, &g_mem.p2)
		time_left := time_left(g_mem.buf_effect.lifetime)

		buf: [8]byte
		str := strconv.ftoa(buf[:], f64(time_left), 'f', 2, 64)
		str = str[1:] //removing the + or - sign

		color: rl.Color
		if time_left > 2.0 {
			color = rl.LIME
		} else if time_left > 1.0 {
			color = rl.YELLOW
		} else if time_left > 0.0 {
			color = rl.RED
		}

		rl.DrawRectangleRec({Width / 2 - 40, Height - 80, 80, 40}, rl.BLACK)
		rl.DrawText(
			strings.clone_to_cstring(str, context.temp_allocator),
			Width / 2 - 40,
			Height - 80,
			40,
			color,
		)
	}

	draw_num_text(g_mem.p1.score, {Width / 2 - 100, 0.0, 80.0, 80.0})
	draw_num_text(g_mem.p2.score, {Width / 2, 0.0, 80.0, 80.0})

	if g_mem.game_freeze {
		rl.DrawRectangle(Width / 2 - 175, 250, 200, 30, rl.BLACK)
		rl.DrawText("Press [SPACE] to start", Width / 2 - 175, 250, 30, rl.WHITE)
		rl.DrawText("Keyboard", 25, 200, 30, rl.WHITE)
		rl.DrawText("Mouse", Width - 160, 200, 30, rl.WHITE)
	} else {
		if g_mem.buf_spawner.spawned_buf {
			draw_buf(g_mem.buf_spawner)
		}
	}

	if g_mem.pause_menu.is_alive {
		draw_pause_menu(g_mem.pause_menu)
	}


	free_all(context.temp_allocator)
	rl.EndDrawing()
	return !rl.WindowShouldClose()
}

@(export)
game_shutdown :: proc() {
	free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g_mem = (^Game_Memory)(mem)
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.Z)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.Q)
}
