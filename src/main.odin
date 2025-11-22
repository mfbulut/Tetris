package main

import "core:fmt"
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

srs_kick_data_jlstz := [8][5][2]int{
	{{0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2}},
	{{0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2}},
	{{0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2}},
	{{0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2}},
	{{0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2}},
	{{0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2}},
	{{0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2}},
	{{0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2}},
}

srs_kick_data_i := [8][5][2]int{
	{{0, 0}, {-2, 0}, {1, 0}, {-2, -1}, {1, 2}},
	{{0, 0}, {-1, 0}, {2, 0}, {-1, 2}, {2, -1}},
	{{0, 0}, {-1, 0}, {2, 0}, {-1, 2}, {2, -1}},
	{{0, 0}, {2, 0}, {-1, 0}, {2, 1}, {-1, -2}},
	{{0, 0}, {2, 0}, {-1, 0}, {2, 1}, {-1, -2}},
	{{0, 0}, {1, 0}, {-2, 0}, {1, -2}, {-2, 1}},
	{{0, 0}, {1, 0}, {-2, 0}, {1, -2}, {-2, 1}},
	{{0, 0}, {-2, 0}, {1, 0}, {-2, -1}, {1, 2}},
}

current_piece: Piece
current_piece_index: int
next_piece_index: int
held_piece_index := -1
can_hold := true

fall_timer: f32 = 0.0
fall_speed: f32 = 0.5

piece_bag: [14]int
bag_index := 0

input_buffer_time :: 0.2
last_left_press: f64 = -1.0
last_right_press: f64 = -1.0
last_hard_drop_press: f64 = -1.0
last_rotate_cw_press: f64 = -1.0
last_rotate_ccw_press: f64 = -1.0
last_hold_press: f64 = -1.0

total_time: f64 = 0.0

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
	rl.InitWindow(width, height, "Tetris")

	FONT_TTF :: #load("assets/determination.ttf")
	white_24.font = load_font(FONT_TTF, 24)
	white_36.font = load_font(FONT_TTF, 36)

	refill_bag()
	next_piece_index = get_next_piece()
	spawn_new_piece()

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		total_time += f64(dt)

		if rl.IsKeyPressed(.LEFT) do last_left_press = total_time
		if rl.IsKeyPressed(.RIGHT) do last_right_press = total_time
		if rl.IsKeyPressed(.SPACE) do last_hard_drop_press = total_time
		if rl.IsKeyPressed(.UP) || rl.IsKeyPressed(.X) do last_rotate_cw_press = total_time
		if rl.IsKeyPressed(.Z) do last_rotate_ccw_press = total_time
		if rl.IsKeyPressed(.C) do last_hold_press = total_time

		if (total_time - last_left_press) <= input_buffer_time {
			if can_move(current_piece, piece_x - 1, piece_y) {
				piece_x -= 1
				last_left_press = -1.0
			}
		}
		if (total_time - last_right_press) <= input_buffer_time {
			if can_move(current_piece, piece_x + 1, piece_y) {
				piece_x += 1
				last_right_press = -1.0
			}
		}

		if rl.IsKeyDown(.DOWN) {
			if can_move(current_piece, piece_x, piece_y + 1) {
				fall_timer += 20 * dt
			}
		}

		if (total_time - last_hard_drop_press) <= input_buffer_time {
			for can_move(current_piece, piece_x, piece_y + 1) {
				piece_y += 1
			}
			fall_timer = fall_speed * 2
			last_hard_drop_press = -1.0
		}

		if (total_time - last_rotate_cw_press) <= input_buffer_time {
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
				kick_offsets = srs_kick_data_i[kick_table_index]
			} else {
				kick_offsets = srs_kick_data_jlstz[kick_table_index]
			}

			rotated := false
			for offset in kick_offsets {
				if can_move(new_piece, piece_x + offset[0], piece_y + offset[1]) {
					current_piece_index = new_index
					current_piece = new_piece
					piece_x += offset[0]
					piece_y += offset[1]
					rotated = true
					last_rotate_cw_press = -1.0
					break
				}
			}
		}

		if (total_time - last_rotate_ccw_press) <= input_buffer_time {
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
				kick_offsets = srs_kick_data_i[kick_table_index]
			} else {
				kick_offsets = srs_kick_data_jlstz[kick_table_index]
			}

			rotated := false
			for offset in kick_offsets {
				if can_move(new_piece, piece_x + offset[0], piece_y + offset[1]) {
					current_piece_index = new_index
					current_piece = new_piece
					piece_x += offset[0]
					piece_y += offset[1]
					rotated = true
					last_rotate_ccw_press = -1.0
					break
				}
			}
		}

		if (total_time - last_hold_press) <= input_buffer_time && can_hold {
			can_hold = false
			last_hold_press = -1.0
			if held_piece_index == -1 {
				held_piece_index = current_piece_index
				spawn_new_piece()
			} else {
				temp_index := current_piece_index
				current_piece_index = held_piece_index
				held_piece_index = temp_index

				current_piece = piece_shapes[current_piece_index]
				piece_x = 3
				piece_y = -2
			}
		}

		fall_timer += dt
		if fall_timer >= fall_speed {
			if can_move(current_piece, piece_x, piece_y + 1) {
				piece_y += 1
				fall_timer = 0
			} else if fall_timer >= fall_speed * 2 {
				place_piece(current_piece, piece_x, piece_y)
				clear_lines()
				spawn_new_piece()
				can_hold = true
				fall_timer = 0
			}
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		hold_box_x :: x_offset - 6 * tile_size - 24
		hold_box_y :: y_offset
		rl.DrawRectangleRoundedLinesEx({hold_box_x, hold_box_y, 6 * tile_size, 6 * tile_size}, 0.2, 12, 2, rl.Color{60, 60, 60, 255})
		hold_text := "Hold"
		draw_text(hold_text, {hold_box_x + (3 * tile_size), hold_box_y + 24}, white_36)

		if held_piece_index != -1 {
			held_piece := piece_shapes[held_piece_index]
			hold_piece_grid_x_offset : f32= hold_box_x + tile_size
			hold_piece_grid_y_offset : f32= hold_box_y + 2 * tile_size
			draw_piece(held_piece, 0, 0, hold_piece_grid_x_offset, hold_piece_grid_y_offset)
		}

		next_box_x : f32 : x_offset + collumn_count * tile_size + 24
		next_box_y : f32 : y_offset
		rl.DrawRectangleRoundedLinesEx({next_box_x, next_box_y, 6 * tile_size, 6 * tile_size}, 0.2, 12, 2, rl.Color{60, 60, 60, 255})
		next_text := "Next"
		draw_text(next_text, {next_box_x + (3 * tile_size), next_box_y + 24}, white_36)

		next_piece := piece_shapes[next_piece_index]
		next_piece_grid_x_offset := next_box_x + tile_size
		next_piece_grid_y_offset := next_box_y + 2 * tile_size
		draw_piece(next_piece, 0, 0, next_piece_grid_x_offset, next_piece_grid_y_offset)

		score_text_x_center := next_box_x + (3 * tile_size)
		score_title_text := "Score"
		draw_text(score_title_text, {score_text_x_center, 6 * tile_size + 72}, white_36)

		score_str := fmt.tprintf("%d", score)
		draw_text(score_str, {score_text_x_center, 6 * tile_size + 108}, white_36)

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
		    draw_piece_outlines(current_piece, piece_x, ghost_y, x_offset, y_offset, 2, 255)
		}

		draw_piece(current_piece, piece_x, piece_y, x_offset, y_offset)

		rl.EndDrawing()
	}
}

draw_piece_outlines :: proc(piece: Piece, x: int, y: int, x_off: f32, y_off: f32, thickness: f32, alpha: u8 = 255) {
	ts := f32(tile_size)

	piece_index := 0
	for val in piece {
		if val > 0 {
			piece_index = val
			break
		}
	}

	if piece_index == 0 {
		return
	}

	color := piece_colors[piece_index]
	color.a = alpha

	for j in 0..<4 {
		for i in 0..<4 {
			if piece[i + j * 4] > 0 {
				px := x_off + f32(x + i) * ts
				py := y_off + f32(y + j) * ts

				if j == 0 || piece[i + (j - 1) * 4] == 0 {
					rl.DrawRectangleRec({px, py, ts, thickness}, color)
				}
				if j == 3 || piece[i + (j + 1) * 4] == 0 {
					rl.DrawRectangleRec({px, py + ts - thickness, ts, thickness}, color)
				}
				if i == 0 || piece[(i - 1) + j * 4] == 0 {
					rl.DrawRectangleRec({px, py, thickness, ts}, color)
				}
				if i == 3 || piece[(i + 1) + j * 4] == 0 {
					rl.DrawRectangleRec({px + ts - thickness, py, thickness, ts}, color)
				}

				if i > 0 && j > 0 {
					if piece[i + (j - 1) * 4] > 0 && piece[(i - 1) + j * 4] > 0 && piece[(i - 1) + (j - 1) * 4] == 0 {
						rl.DrawRectangleRec({px, py, thickness, thickness}, color)
					}
				}
				if i < 3 && j > 0 {
					if piece[i + (j - 1) * 4] > 0 && piece[(i + 1) + j * 4] > 0 && piece[(i + 1) + (j - 1) * 4] == 0 {
						rl.DrawRectangleRec({px + ts - thickness, py, thickness, thickness}, color)
					}
				}
				if i > 0 && j < 3 {
					if piece[i + (j + 1) * 4] > 0 && piece[(i - 1) + j * 4] > 0 && piece[(i - 1) + (j + 1) * 4] == 0 {
						rl.DrawRectangleRec({px, py + ts - thickness, thickness, thickness}, color)
					}
				}
				if i < 3 && j < 3 {
					if piece[i + (j + 1) * 4] > 0 && piece[(i + 1) + j * 4] > 0 && piece[(i + 1) + (j + 1) * 4] == 0 {
						rl.DrawRectangleRec({px + ts - thickness, py + ts - thickness, thickness, thickness}, color)
					}
				}
			}
		}
	}
}

draw_piece :: proc(piece: Piece, x: int, y: int, x_off: f32, y_off: f32, alpha: u8 = 255) {
	for i in 0..<4 {
		for j in 0..<4 {
			if piece[i + j * 4] > 0 {
				color := piece_colors[piece[i + j * 4]]
				color.a = alpha
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

clear_lines :: proc() {
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
		can_hold = true
	}
}