package main

import rl "vendor:raylib"

width :: 1280
height :: 720

x_offset :: width / 2.0 - collumn_count * tile_size / 2.0
y_offset :: height / 2.0 - row_count * tile_size / 2.0
collumn_count :: 10
row_count :: 20
tile_size :: 32

score := 0
piece_x := 3
piece_y := -2

board: [collumn_count * row_count]int

current_piece: Piece
current_piece_index: int
next_piece_index: int
held_piece_index := -1
can_hold := true

fall_timer := f32(0.0)
fall_speed := f32(0.5)

lock_delay_duration :: f32(0.5)
lock_timer := f32(0.0)
lock_reset_count := 0
max_lock_resets :: 15

piece_bag: [14]int
bag_index := 0

InputAction :: enum {
	Left,
	Right,
	HardDrop,
	RotateCW,
	RotateCCW,
	Hold,
}

input_buffer_time :: 0.2
input_buffers: [InputAction]f32

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
	rl.InitWindow(width, height, "Tetris")

	refill_bag()
	next_piece_index = get_next_piece()
	spawn_new_piece()

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		for action in InputAction {
			if input_buffers[action] > 0.0 {
				input_buffers[action] -= dt
			}
		}

		if rl.IsKeyPressed(.LEFT) || rl.IsKeyPressedRepeat(.LEFT) do input_buffers[.Left] = input_buffer_time
		if rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressedRepeat(.RIGHT) do input_buffers[.Right] = input_buffer_time
		if rl.IsKeyPressed(.SPACE) do input_buffers[.HardDrop] = input_buffer_time
		if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.X) do input_buffers[.RotateCW] = input_buffer_time
		if rl.IsKeyPressed(.Z) do input_buffers[.RotateCCW] = input_buffer_time
		if rl.IsKeyPressed(.C) do input_buffers[.Hold] = input_buffer_time

		if input_buffers[.Left] > 0.0 {
			if can_move(current_piece, piece_x - 1, piece_y) {
				piece_x -= 1
				input_buffers[.Left] = 0.0
				try_reset_lock_delay()
			}
		}
		if input_buffers[.Right] > 0.0 {
			if can_move(current_piece, piece_x + 1, piece_y) {
				piece_x += 1
				input_buffers[.Right] = 0.0
				try_reset_lock_delay()
			}
		}

		if rl.IsKeyDown(.DOWN) {
			if can_move(current_piece, piece_x, piece_y + 1) {
				fall_timer += 10 * dt
			}
		}

		if input_buffers[.HardDrop] > 0.0 {
			for can_move(current_piece, piece_x, piece_y + 1) {
				piece_y += 1
			}
			input_buffers[.HardDrop] = 0.0
			lock_current_piece()
		}

		if input_buffers[.RotateCW] > 0.0 {
			new_index := current_piece_index + 7
			if new_index >= 28 {
				new_index -= 28
			}
			new_piece := piece_shapes[new_index]

			piece_type := current_piece_index % 7
			rotation_state := current_piece_index / 7
			kick_table_index := rotation_state * 2 + 0

			kick_offsets: [5][2]int
			if piece_type == 6 {
				kick_offsets = kick_table_i[kick_table_index]
			} else {
				kick_offsets = kick_table_jlstz[kick_table_index]
			}

			rotated := false
			for offset in kick_offsets {
				if can_move(new_piece, piece_x + offset[0], piece_y + offset[1]) {
					current_piece_index = new_index
					current_piece = new_piece
					piece_x += offset[0]
					piece_y += offset[1]
					rotated = true
					input_buffers[.RotateCW] = 0.0
					try_reset_lock_delay()
					break
				}
			}
		}

		if input_buffers[.RotateCCW] > 0.0 {
			new_index := current_piece_index - 7
			if new_index < 0 {
				new_index += 28
			}
			new_piece := piece_shapes[new_index]

			piece_type := current_piece_index % 7
			rotation_state := current_piece_index / 7
			kick_table_index := rotation_state * 2 + 1

			kick_offsets: [5][2]int
			if piece_type == 6 {
				kick_offsets = kick_table_i[kick_table_index]
			} else {
				kick_offsets = kick_table_jlstz[kick_table_index]
			}

			rotated := false
			for offset in kick_offsets {
				if can_move(new_piece, piece_x + offset[0], piece_y + offset[1]) {
					current_piece_index = new_index
					current_piece = new_piece
					piece_x += offset[0]
					piece_y += offset[1]
					rotated = true
					input_buffers[.RotateCCW] = 0.0
					try_reset_lock_delay()
					break
				}
			}
		}

		if input_buffers[.Hold] > 0.0 && can_hold {
			can_hold = false
			input_buffers[.Hold] = 0.0
			piece_type := current_piece_index % 7
			if held_piece_index == -1 {
				held_piece_index = piece_type
				spawn_new_piece()
			} else {
				temp_type := piece_type
				current_piece_index = held_piece_index
				held_piece_index = temp_type

				current_piece = piece_shapes[current_piece_index]
				piece_x = 3
				piece_y = -2
				fall_timer = 0
				lock_timer = 0
				lock_reset_count = 0
			}
		}

		grounded := !can_move(current_piece, piece_x, piece_y + 1)
		if grounded {
			lock_timer += dt
			if lock_timer >= lock_delay_duration {
				lock_current_piece()
			}
		} else {
			lock_timer = 0
			lock_reset_count = 0
			fall_timer += dt
			if fall_timer >= fall_speed {
				piece_y += 1
				fall_timer = 0
			}
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		hold_box_x :: x_offset - 6 * tile_size - 24
		hold_box_y :: y_offset
		rl.DrawRectangleRoundedLinesEx({hold_box_x, hold_box_y, 6 * tile_size, 6 * tile_size}, 0.2, 12, 2, rl.Color{60, 60, 60, 255})
		draw_text_centered( "Hold", {hold_box_x + (3 * tile_size), hold_box_y + 24}, 36, rl.WHITE)

		if held_piece_index != -1 {
			held_piece := piece_shapes[held_piece_index]
			hold_piece_grid_x_offset : f32= hold_box_x + tile_size
			hold_piece_grid_y_offset : f32= hold_box_y + 2 * tile_size
			draw_piece(held_piece, 0, 0, hold_piece_grid_x_offset, hold_piece_grid_y_offset)
		}

		next_box_x : f32 : x_offset + collumn_count * tile_size + 24
		next_box_y : f32 : y_offset
		rl.DrawRectangleRoundedLinesEx({next_box_x, next_box_y, 6 * tile_size, 6 * tile_size}, 0.2, 12, 2, rl.Color{60, 60, 60, 255})

		draw_text_centered("Next", {next_box_x + (3 * tile_size), next_box_y + 24}, 36, rl.WHITE)

		next_piece := piece_shapes[next_piece_index]
		next_piece_grid_x_offset := next_box_x + tile_size
		next_piece_grid_y_offset := next_box_y + 2 * tile_size
		draw_piece(next_piece, 0, 0, next_piece_grid_x_offset, next_piece_grid_y_offset)

		score_text_x_center := next_box_x + (3 * tile_size)
		draw_text_centered("Score", {score_text_x_center, 6 * tile_size + 72}, 36, rl.WHITE)

		score_str := rl.TextFormat("%d", score)
		draw_text_centered(score_str, {score_text_x_center, 6 * tile_size + 108}, 36, rl.WHITE)

		for i in 0..<collumn_count {
			for j in 0..<row_count {
				color := board[i + j * collumn_count]
				draw_tile(i, j, piece_colors[color], x_offset, y_offset)
			}
		}

		rl.DrawRectangleLinesEx({x_offset, y_offset, collumn_count * tile_size, row_count * tile_size}, 2, rl.Color{60, 60, 60, 255})

		ghost_y := piece_y
		for can_move(current_piece, piece_x, ghost_y + 1) {
			ghost_y += 1
		}
		if ghost_y != piece_y {
		    draw_piece_outlines(current_piece, piece_x, ghost_y, x_offset, y_offset, 2)
		}

		draw_piece(current_piece, piece_x, piece_y, x_offset, y_offset)

		rl.EndDrawing()
	}
}

draw_piece_outlines :: proc(piece: Piece, x: int, y: int, x_off: f32, y_off: f32, thickness: f32) {
	ts := f32(tile_size)

	piece_index := 0
	for val in piece {
		if val > 0 {
			piece_index = val
			break
		}
	}

	if piece_index == 0 do return

	color := piece_colors[piece_index]

	is_filled :: proc(p: Piece, c, r: int) -> bool {
		if c < 0 || c >= 4 || r < 0 || r >= 4 do return false
		return p[c + r * 4] > 0
	}

	for j in 0..<4 {
		for i in 0..<4 {
			if is_filled(piece, i, j) {
				px := x_off + f32(x + i) * ts
				py := y_off + f32(y + j) * ts

				if !is_filled(piece, i, j - 1) do rl.DrawRectangleRec({px, py, ts, thickness}, color)
				if !is_filled(piece, i, j + 1) do rl.DrawRectangleRec({px, py + ts - thickness, ts, thickness}, color)
				if !is_filled(piece, i - 1, j) do rl.DrawRectangleRec({px, py, thickness, ts}, color)
				if !is_filled(piece, i + 1, j) do rl.DrawRectangleRec({px + ts - thickness, py, thickness, ts}, color)

				if is_filled(piece, i, j - 1) && is_filled(piece, i - 1, j) && !is_filled(piece, i - 1, j - 1) do rl.DrawRectangleRec({px, py, thickness, thickness}, color)
				if is_filled(piece, i, j - 1) && is_filled(piece, i + 1, j) && !is_filled(piece, i + 1, j - 1) do rl.DrawRectangleRec({px + ts - thickness, py, thickness, thickness}, color)
				if is_filled(piece, i, j + 1) && is_filled(piece, i - 1, j) && !is_filled(piece, i - 1, j + 1) do rl.DrawRectangleRec({px, py + ts - thickness, thickness, thickness}, color)
				if is_filled(piece, i, j + 1) && is_filled(piece, i + 1, j) && !is_filled(piece, i + 1, j + 1) do rl.DrawRectangleRec({px + ts - thickness, py + ts - thickness, thickness, thickness}, color)
			}
		}
	}
}

draw_piece :: proc(piece: Piece, x: int, y: int, x_off: f32, y_off: f32) {
	for i in 0..<4 {
		for j in 0..<4 {
			if piece[i + j * 4] > 0 {
				color := piece_colors[piece[i + j * 4]]
				draw_tile(x + i, y + j, color, x_off, y_off)
			}
		}
	}
}

draw_tile :: proc(x: int, y: int, color: rl.Color, x_off: f32, y_off: f32) {
	if x < 0 || y < 0 do return
	rect := rl.Rectangle{x_off + f32(x) * tile_size, y_off + f32(y) * tile_size, tile_size, tile_size}
	rl.DrawRectangleRec(rect, color)
	rl.DrawRectangleLinesEx(rect, 1, rl.Color{24, 24, 24, 255})
}

can_move :: proc(piece: Piece, new_x: int, new_y: int) -> bool {
	for i in 0..<4 {
		for j in 0..<4 {
			if piece[i + j * 4] > 0 {
				board_x := new_x + i
				board_y := new_y + j

				if board_x < 0 || board_x >= collumn_count do return false
				if board_y >= row_count do return false

				if board_y < 0 do continue

				if board[board_x + board_y * collumn_count] > 0 do return false
			}
		}
	}
	return true
}

place_piece :: proc(piece: Piece, x: int, y: int) {
	for i in 0..<4 {
		for j in 0..<4 {
			if piece[i + j * 4] > 0 {
				board_x := x + i
				board_y := y + j

				if board_y >= 0 && board_y < row_count && board_x >= 0 && board_x < collumn_count {
					board[board_x + board_y * collumn_count] = piece[i + j * 4]
				}
			}
		}
	}
}

clear_lines :: proc() -> int {
	lines_cleared := 0

	for j := row_count - 1; j >= 0; j -= 1 {
		line_full := true
		for i in 0..<collumn_count {
			if board[i + j * collumn_count] == 0 {
				line_full = false
				break
			}
		}

		if line_full {
			lines_cleared += 1

			for row := j; row > 0; row -= 1 {
				for col in 0..<collumn_count {
					board[col + row * collumn_count] = board[col + (row - 1) * collumn_count]
				}
			}

			for col in 0..<collumn_count {
				board[col] = 0
			}

			j += 1
		}
	}

	score += lines_cleared * 100
	return lines_cleared
}


try_reset_lock_delay :: proc() {
	if !can_move(current_piece, piece_x, piece_y + 1) && lock_reset_count < max_lock_resets {
		lock_timer = 0
		lock_reset_count += 1
	}
}

lock_current_piece :: proc() {
	place_piece(current_piece, piece_x, piece_y)
	_ = clear_lines()

	spawn_new_piece()
	can_hold = true
	fall_timer = 0
	lock_timer = 0
	lock_reset_count = 0
}

refill_bag :: proc() {
	for i in 0..<7 {
		piece_bag[i] = i
	}

	for i := 6; i > bag_index; i -= 1 {
		j := bag_index + int(rl.GetRandomValue(0, i32(i - bag_index)))
		piece_bag[i], piece_bag[j] = piece_bag[j], piece_bag[i]
	}
}

get_next_piece :: proc() -> int {
	if bag_index >= 7 {
		bag_index = 0
		refill_bag()
	}

	piece := piece_bag[bag_index]
	bag_index += 1
	return piece
}

spawn_new_piece :: proc() {
	current_piece_index = next_piece_index
	next_piece_index = get_next_piece()
	current_piece = piece_shapes[current_piece_index]

	piece_x = 3
	piece_y = -2

	if !can_move(current_piece, piece_x, piece_y) {
		for i in 0..<collumn_count * row_count {
			board[i] = 0
		}
		score = 0
		held_piece_index = -1
		fall_timer = 0
		lock_timer = 0
		lock_reset_count = 0
		can_hold = true
	}
}

draw_text_centered :: proc(text: cstring, pos: rl.Vector2, size: f32, color: rl.Color) {
	text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, size, 3)
	draw_pos := rl.Vector2{pos.x - text_size.x / 2, pos.y - text_size.y / 2}
	rl.DrawTextEx(rl.GetFontDefault(), text, draw_pos, size, 3, color)
}

Piece :: [4 * 4]int

piece_shapes := [28]Piece{
    // 1
	{
		0,0,0,0,
		0,1,0,0,
		1,1,1,0,
		0,0,0,0,
	},
	{
		0,0,0,0,
		0,0,2,0,
		2,2,2,0,
		0,0,0,0,
	},
	{
		0,0,0,0,
		3,0,0,0,
		3,3,3,0,
		0,0,0,0,
	},
	{
		0,0,0,0,
		0,4,4,0,
		4,4,0,0,
		0,0,0,0,
	},
	{
		0,0,0,0,
		5,5,0,0,
		0,5,5,0,
		0,0,0,0,
	},
	{
		0,0,0,0,
		0,6,6,0,
		0,6,6,0,
		0,0,0,0,
	},
	{
		0,0,0,0,
		0,0,0,0,
		7,7,7,7,
		0,0,0,0,
	},

    // 2
	{
		0,0,0,0,
		0,1,0,0,
		0,1,1,0,
		0,1,0,0,
	},
	{
		0,0,0,0,
		0,2,0,0,
		0,2,0,0,
		0,2,2,0,
	},
	{
		0,0,0,0,
		0,3,3,0,
		0,3,0,0,
		0,3,0,0,
	},
	{
		0,0,0,0,
		0,4,0,0,
		0,4,4,0,
		0,0,4,0,
	},
	{
		0,0,0,0,
		0,0,5,0,
		0,5,5,0,
		0,5,0,0,
	},
	{
		0,0,0,0,
		0,6,6,0,
		0,6,6,0,
		0,0,0,0,
	},
	{
		0,0,7,0,
		0,0,7,0,
		0,0,7,0,
		0,0,7,0,
	},

    // 3
	{
		0,0,0,0,
		0,0,0,0,
		1,1,1,0,
		0,1,0,0,
	},
	{
		0,0,0,0,
		0,0,0,0,
		2,2,2,0,
		2,0,0,0,
	},
	{
		0,0,0,0,
		0,0,0,0,
		3,3,3,0,
		0,0,3,0,
	},
	{
		0,0,0,0,
		0,0,0,0,
		0,4,4,0,
		4,4,0,0,
	},
	{
		0,0,0,0,
		0,0,0,0,
		5,5,0,0,
		0,5,5,0,
	},
	{
		0,0,0,0,
		0,6,6,0,
		0,6,6,0,
		0,0,0,0,
	},
	{
		0,0,0,0,
		0,0,0,0,
		7,7,7,7,
		0,0,0,0,
	},

    // 4
	{
		0,0,0,0,
		0,1,0,0,
		1,1,0,0,
		0,1,0,0,
	},
	{
		0,0,0,0,
		2,2,0,0,
		0,2,0,0,
		0,2,0,0,
	},
	{
		0,0,0,0,
		0,3,0,0,
		0,3,0,0,
		3,3,0,0,
	},
	{
		0,0,0,0,
		0,4,0,0,
		0,4,4,0,
		0,0,4,0,
	},
	{
		0,0,0,0,
		0,0,5,0,
		0,5,5,0,
		0,5,0,0,
	},
	{
		0,0,0,0,
		0,6,6,0,
		0,6,6,0,
		0,0,0,0,
	},
	{
		0,0,7,0,
		0,0,7,0,
		0,0,7,0,
		0,0,7,0,
	},
}

piece_colors := [8]rl.Color {
	rl.Color{0, 0, 0, 255},
	rl.Color{175, 41, 138, 255},
	rl.Color{227, 91, 2, 255},
	rl.Color{33, 65, 198, 255},
	rl.Color{89, 177, 1, 255},
	rl.Color{215, 15, 55, 255},
	rl.Color{227, 159, 2, 255},
	rl.Color{15, 155, 215, 255},
}

kick_table_jlstz := [8][5][2]int{
	{{0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2}},
	{{0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2}},
	{{0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2}},
	{{0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2}},
	{{0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2}},
	{{0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2}},
	{{0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2}},
	{{0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2}},
}

kick_table_i := [8][5][2]int{
	{{0, 0}, {-2, 0}, {1, 0}, {-2, 1}, {1, -2}},
	{{0, 0}, {-1, 0}, {2, 0}, {-1, -2}, {2, 1}},
	{{0, 0}, {-1, 0}, {2, 0}, {-1, -2}, {2, 1}},
	{{0, 0}, {2, 0}, {-1, 0}, {2, -1}, {-1, 2}},
	{{0, 0}, {2, 0}, {-1, 0}, {2, -1}, {-1, 2}},
	{{0, 0}, {1, 0}, {-2, 0}, {1, 2}, {-2, -1}},
	{{0, 0}, {1, 0}, {-2, 0}, {1, 2}, {-2, -1}},
	{{0, 0}, {-2, 0}, {1, 0}, {-2, 1}, {1, -2}},
}
