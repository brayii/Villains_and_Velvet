/// UI layout, drawing, hit testing, and input routing.

function vv_ui_init() {
    COL_BG = make_color_rgb(15, 22, 33);
    COL_PANEL = make_color_rgb(29, 40, 56);
    COL_EDGE = make_color_rgb(112, 132, 159);
    COL_TEXT = make_color_rgb(247, 244, 238);
    COL_MUTED = make_color_rgb(178, 190, 207);
    COL_ACCENT = make_color_rgb(73, 194, 184);
    COL_DANGER = make_color_rgb(228, 88, 99);
    COL_GOLD = make_color_rgb(246, 191, 66);
    COL_LEGAL = make_color_rgb(124, 224, 142);

    var ui_font_file = working_directory + "atkinson_hyperlegible_next_medium.ttf";
    UI_FONT_SMALL = -1;
    UI_FONT_BODY = -1;
    UI_FONT_TITLE = -1;
    if (file_exists(ui_font_file)) {
        UI_FONT_SMALL = font_add(ui_font_file, 13, false, false, 32, 255);
        UI_FONT_BODY = font_add(ui_font_file, 15, false, false, 32, 255);
        UI_FONT_TITLE = font_add(ui_font_file, 20, false, false, 32, 255);
    }

    leader_rect = {x:16, y:16, w:520, h:99};
    minion_rects = [{x:560, y:50, w:170, h:245}, {x:780, y:50, w:170, h:245}];
    build_rects = [];
    hand_rects = [];
    for (var layout_i = 0; layout_i < 3; layout_i++) {
        array_push(build_rects, {x:240 + layout_i * 245, y:305, w:240, h:200});
        array_push(hand_rects, {x:240 + layout_i * 245, y:520, w:240, h:195});
    }
    action_rect = {x:1025, y:628, w:235, h:68};
    setup_start_rect = {x:480, y:635, w:320, h:60};
    setup_exit_rect = {x:1080, y:650, w:160, h:46};
    match_menu_rect = {x:20, y:130, w:46, h:46};
    auto_toggle_rect = {x:76, y:130, w:46, h:46};
    menu_resume_rect = {x:490, y:280, w:300, h:58};
    menu_options_rect = {x:490, y:352, w:300, h:58};
    menu_exit_rect = {x:490, y:424, w:300, h:58};
    menu_confirm_rect = {x:490, y:344, w:300, h:58};
    menu_cancel_rect = {x:490, y:416, w:300, h:58};
    result_play_rect = {x:490, y:400, w:300, h:54};
    result_options_rect = {x:490, y:466, w:300, h:54};
    result_exit_rect = {x:490, y:532, w:300, h:54};
    setup_strike_page = 0;
    setup_twist_page = 0;
    setup_advanced_events = false;
    setup_event_defaults_restored = false;
    debug_event_log = false;

    drag_threshold = 8;
    tap_move_limit = 6;
    inspect_hold_frames = 30;
    vv_ui_reset_match_interaction();
}

function vv_ui_cleanup() {
    var ui_fonts = [UI_FONT_SMALL, UI_FONT_BODY, UI_FONT_TITLE];
    for (var font_i = 0; font_i < array_length(ui_fonts); font_i++) {
        if (ui_fonts[font_i] >= 0 && font_exists(ui_fonts[font_i])) font_delete(ui_fonts[font_i]);
    }
    UI_FONT_SMALL = -1;
    UI_FONT_BODY = -1;
    UI_FONT_TITLE = -1;
}

function vv_ui_set_font(_font) {
    draw_set_font(_font >= 0 && font_exists(_font) ? _font : -1);
}

function vv_ui_reset_match_interaction() {
    enemy_ai_cancel_pending_targeting();
    pointer_card_down = false;
    pointer_card_type = "";
    pointer_card_index = -1;
    pointer_card_value = undefined;
    pointer_down_x = 0;
    pointer_down_y = 0;
    pointer_max_distance = 0;
    pointer_hold_frames = 0;
    drag_active = false;
    card_popup = undefined;
    card_popup_type = "";
    detail_card_selected = undefined;
    interaction_feedback_rect = undefined;
    interaction_feedback_kind = "";
    interaction_feedback_timer = 0;
    action_press_timer = 0;
    build_changed = false;
    build_finish_confirm = false;
    attack_finish_confirm = false;
    attack_notice_heading = "";
    attack_notice_text = "";
    match_menu_active = false;
    quit_match_confirm = false;
}

function point_in_rect(_px, _py, _rect) {
    return _px >= _rect.x && _px <= _rect.x + _rect.w
        && _py >= _rect.y && _py <= _rect.y + _rect.h;
}

function draw_panel(_rect, _fill, _outline) {
    draw_set_color(_fill);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, false);
    draw_set_color(_outline);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, true);
}

function draw_glass_panel(_rect, _fill, _outline, _alpha) {
    draw_set_alpha(_alpha);
    draw_set_color(_fill);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, false);
    draw_set_alpha(1);
    draw_set_color(_outline);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, true);
}

function draw_center(_text, _x, _y, _color) {
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_color(_color);
    draw_text(_x, _y, _text);
}

function draw_center_shadow(_text, _x, _y, _color) {
    draw_set_alpha(0.78);
    draw_center(_text, _x + 1, _y + 2, COL_BG);
    draw_set_alpha(1);
    draw_center(_text, _x, _y, _color);
}

function draw_art_contained(_sprite, _rect, _padding) {
    if (_sprite < 0) return;
    var source_w = sprite_get_width(_sprite);
    var source_h = sprite_get_height(_sprite);
    var scale = min((_rect.w - _padding * 2) / source_w, (_rect.h - _padding * 2) / source_h);
    var draw_w = source_w * scale;
    var draw_h = source_h * scale;
    var draw_x = _rect.x + (_rect.w - draw_w) / 2;
    var draw_y = _rect.y + (_rect.h - draw_h) / 2;
    draw_sprite_ext(_sprite, 0, draw_x, draw_y, scale, scale, 0, c_white, 1);
}

function draw_art_cover(_sprite, _rect) {
    if (_sprite < 0) return;
    var source_w = sprite_get_width(_sprite);
    var source_h = sprite_get_height(_sprite);
    var scale = max(_rect.w / source_w, _rect.h / source_h);
    var draw_x = _rect.x + (_rect.w - source_w * scale) / 2;
    // The castle and its flags are the background's focal point. Crop excess
    // ground at the bottom instead of cutting artwork from the top.
    var draw_y = _rect.y;
    draw_sprite_ext(_sprite, 0, draw_x, draw_y, scale, scale, 0, c_white, 1);
}

function card_abilities_text(_card) {
    if (!variable_struct_exists(_card, "abilities") || array_length(_card.abilities) == 0) return "No ability.";
    var result = "";
    for (var ability_i = 0; ability_i < array_length(_card.abilities); ability_i++) {
        var ability = _card.abilities[ability_i];
        if (result != "") result += "\n";
        result += ability.name + ": " + ability.text;
    }
    return result;
}

function draw_card(_card, _rect, _selected, _legal) {
    var card_rect = _selected && !is_undefined(_card)
        ? {x:_rect.x, y:_rect.y - 4, w:_rect.w, h:_rect.h}
        : _rect;
    var fill = COL_PANEL;
    if (!is_undefined(_card)) {
        if (variable_struct_exists(_card, "theme_color")) fill = _card.theme_color;
        else fill = make_color_rgb(92, 47, 48);
    }
    var outline = COL_EDGE;
    if (_legal) outline = COL_LEGAL;
    if (_selected) outline = COL_GOLD;
    if (is_undefined(_card)) {
        draw_set_alpha(_legal ? 0.26 : 0.12);
        draw_set_color(fill);
        draw_roundrect(card_rect.x, card_rect.y, card_rect.x + card_rect.w, card_rect.y + card_rect.h, false);
        draw_set_alpha(1);
    } else {
        draw_set_alpha(_selected ? 0.34 : 0.22);
        draw_set_color(COL_BG);
        draw_roundrect(card_rect.x + 5, card_rect.y + 7,
            card_rect.x + card_rect.w + 5, card_rect.y + card_rect.h + 7, false);
        draw_set_alpha(1);
        draw_panel(card_rect, fill, outline);
    }
    if (!is_undefined(_card)) {
        var art_sprite = variable_struct_exists(_card, "art_file") ? get_art_sprite(_card.art_file) : -1;
        if (art_sprite >= 0) {
            draw_art_contained(art_sprite, card_rect, 4);
        } else {
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
            draw_set_color(COL_TEXT);
            draw_text(card_rect.x + 10, card_rect.y + 8, _card.name);
            draw_set_color(COL_GOLD);
            draw_text(card_rect.x + 10, card_rect.y + 34, "ATK " + string(_card.atk));
            draw_set_color(COL_ACCENT);
            draw_text(card_rect.x + card_rect.w - 64, card_rect.y + 34, "HP " + string(_card.hp));
            draw_set_color(COL_TEXT);
            draw_set_color(COL_MUTED);
            draw_text_ext(card_rect.x + 10, card_rect.y + 59, card_abilities_text(_card), 16, card_rect.w - 20);
        }
    }
    if (is_undefined(_card) && !_legal) draw_set_alpha(0.48);
    draw_set_color(outline);
    draw_roundrect(card_rect.x, card_rect.y, card_rect.x + card_rect.w, card_rect.y + card_rect.h, true);
    draw_set_alpha(1);
    if (_legal) {
        var legal_pulse = 0.58 + 0.42 * abs(sin(current_time / 220));
        draw_set_alpha(legal_pulse);
        draw_set_color(COL_LEGAL);
        draw_roundrect(card_rect.x + 2, card_rect.y + 2,
            card_rect.x + card_rect.w - 2, card_rect.y + card_rect.h - 2, true);
        draw_set_alpha(1);
    }
}

function draw_enemy_reveal(_card, _rect) {
    var reveal_fill = _card.card_type == "strike"
        ? make_color_rgb(105, 48, 42)
        : make_color_rgb(68, 48, 105);
    var reveal_edge = _card.card_type == "strike" ? COL_DANGER : COL_GOLD;
    draw_panel(_rect, reveal_fill, reveal_edge);
    var reveal_sprite = get_art_sprite(_card.art_file);
    if (reveal_sprite >= 0) {
        draw_art_contained(reveal_sprite, _rect, 4);
    } else {
        draw_center(_card.card_type == "strike" ? "LEADER STRIKE" : "TWIST",
            _rect.x + _rect.w / 2, _rect.y + 28, reveal_edge);
        draw_center(string_upper(_card.name), _rect.x + _rect.w / 2,
            _rect.y + 68, COL_TEXT);
        draw_set_halign(fa_center);
        draw_set_valign(fa_top);
        draw_set_color(COL_TEXT);
        draw_text_ext(_rect.x + _rect.w / 2, _rect.y + 108,
            _card.effect, 18, _rect.w - 28);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    }
    draw_set_color(reveal_edge);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, true);
}

function draw_setup_gear(_rect, _active) {
    draw_panel(_rect, _active ? COL_ACCENT : COL_PANEL, COL_EDGE);
    var center_x = _rect.x + _rect.w / 2;
    var center_y = _rect.y + _rect.h / 2;
    var gear_color = _active ? COL_BG : COL_TEXT;
    draw_set_color(gear_color);
    draw_circle(center_x, center_y, 10, true);
    draw_circle(center_x, center_y, 4, true);
    for (var tooth_i = 0; tooth_i < 8; tooth_i++) {
        var angle = tooth_i * 45;
        draw_line_width(center_x + lengthdir_x(10, angle), center_y + lengthdir_y(10, angle),
            center_x + lengthdir_x(16, angle), center_y + lengthdir_y(16, angle), 4);
    }
}
