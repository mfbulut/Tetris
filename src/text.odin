package main

import rl "vendor:raylib"

vec :: rl.Vector2

TextOptions :: struct {
	font         : rl.Font,
	size         : f32,
	spacing      : f32,
	line_spacing : f32,
	center       : bool,
	color        : rl.Color,
	background   : rl.Color,
}

white_24 : TextOptions = {
	font         = rl.GetFontDefault(),
	size         = 24,
	spacing      = 0,
	center       = true,
	color        = rl.WHITE,
}

white_36 : TextOptions = {
	font         = rl.GetFontDefault(),
	size         = 36,
	spacing      = 0,
	center       = true,
	color        = rl.WHITE,
}

MeasureRune :: proc(r: rune, pos: rl.Vector2 = {}, opts := white_24) -> (advance: rl.Vector2) {
	opts := opts
	using opts
	if font.texture.id == 0 do font = rl.GetFontDefault()
	if r < ' ' && r != '\t' do return
	scaling := size / f32(font.baseSize)

	// Advance
	glyph := rl.GetGlyphIndex(font, r)
	advance1 := f32(font.glyphs[glyph].advanceX)
	advance.x += (advance1 if advance1 != 0 else font.recs[glyph].width) * scaling + spacing
	advance.y = size + line_spacing
	return
}

MeasureTextLine :: proc(text: string, opts := white_24) -> (text_size: vec) {
	using opts

	assert(font.texture.id != 0, "MeasureText was given a bad font")
	if len(text) == 0 do return

	scaling := size / f32(font.baseSize)

	for r, i in text {
		if r < ' ' && r != '\t' do continue
		glyph := rl.GetGlyphIndex(font, r)
		advance := f32(font.glyphs[glyph].advanceX)
		text_size.x += (advance if advance != 0 else font.recs[glyph].width) * scaling + spacing
	}

	text_size.y = size + line_spacing
	return
}

draw_text :: proc(text: string, pos: rl.Vector2, opts := white_24) -> (text_size: vec) {
	opts := opts
	using opts
	if font.texture.id == 0 do font = rl.GetFontDefault()

	scaling := size / f32(font.baseSize)

	// --- MODIFICATION START ---
	// Get text dimensions first
	text_dim := MeasureTextLine(text, opts)

	start_pos := pos
	if center {
		// Adjust start position to center the text block at 'pos'
		start_pos.x -= text_dim.x / 2
		start_pos.y -= text_dim.y / 2 // Also center vertically
	}

	current_offset: vec
	// --- MODIFICATION END ---

	for r, i in text {
		if r < ' ' && r != '\t' do continue

		// Use floor_vec for crisp pixel-aligned text
		draw_pos := floor_vec(start_pos + current_offset)

		// Pass 'opts' to MeasureRune, not the default
		rl.DrawRectangleV(draw_pos, MeasureRune(r, draw_pos, opts), background)
		rl.DrawTextCodepoint(font, r, draw_pos, size, color)

		glyph := rl.GetGlyphIndex(font, r)
		advance1 := f32(font.glyphs[glyph].advanceX)
		advance  := (advance1 if advance1 != 0 else font.recs[glyph].width) * scaling + spacing
		current_offset.x += advance
	}

	// Return the dimensions we calculated at the start
	return text_dim
}


load_font :: proc(data: [] byte, text_size: int, SDF := false, glyph_count := 0x024F, filter := rl.TextureFilter.TRILINEAR) -> rl.Font {
	font: rl.Font

	font.baseSize = i32(text_size)
	font.glyphCount = 25000

	font.glyphs = rl.LoadFontData(transmute(rawptr) raw_data(data), i32(len(data)), font.baseSize, nil, font.glyphCount, .SDF if SDF else .DEFAULT);

	atlas := rl.GenImageFontAtlas(font.glyphs, &font.recs, font.glyphCount, font.baseSize, 4, 0);
	font.texture = rl.LoadTextureFromImage(atlas);
	rl.UnloadImage(atlas);

	rl.SetTextureFilter(font.texture, filter)

	return font
}

floor_vec :: proc(pos: vec) -> vec {
	return { f32(i32(pos.x)), f32(i32(pos.y)) }
}
