/// UI layout, drawing, hit testing, and input routing.

function vv_ui_init() {
    COL_BG = make_color_rgb(18, 25, 36);
    COL_PANEL = make_color_rgb(31, 42, 57);
    COL_EDGE = make_color_rgb(91, 111, 139);
    COL_TEXT = make_color_rgb(239, 244, 252);
    COL_MUTED = make_color_rgb(164, 178, 198);
    COL_ACCENT = make_color_rgb(70, 190, 180);
    COL_DANGER = make_color_rgb(224, 82, 92);
    COL_GOLD = make_color_rgb(242, 190, 72);
    COL_LEGAL = make_color_rgb(114, 221, 130);

    leader_rect = {x:16, y:16, w:520, h:99};
    minion_rects = [{x:560, y:50, w:170, h:245}, {x:780, y:50, w:170, h:245}];
    build_rects = [];
    hand_rects = [];
    for (var layout_i = 0; layout_i < 3; layout_i++) {
        array_push(build_rects, {x:240 + layout_i * 245, y:305, w:240, h:200});
        array_push(hand_rects, {x:240 + layout_i * 245, y:520, w:240, h:195});
    }
    action_rect = {x:1025, y:628, w:235, h:68};
    restart_rect = {x:525, y:470, w:230, h:70};
    setup_start_rect = {x:480, y:625, w:320, h:70};
    setup_strike_minus_rect = {x:675, y:378, w:72, h:54};
    setup_strike_plus_rect = {x:845, y:378, w:72, h:54};
    setup_twist_minus_rect = {x:675, y:452, w:72, h:54};
    setup_twist_plus_rect = {x:845, y:452, w:72, h:54};
    debug_event_log = false;
}

function point_in_rect(_px, _py, _rect) {
    return _px >= _rect.x && _px <= _rect.x + _rect.w
        && _py >= _rect.y && _py <= _rect.y + _rect.h;
}

function vv_ui_handle_input() {
    if (!device_mouse_check_button_pressed(0, mb_left)) return;
    var pointer_x = device_mouse_x_to_gui(0);
    var pointer_y = device_mouse_y_to_gui(0);

    if (setup_active) {
        if (point_in_rect(pointer_x, pointer_y, setup_strike_minus_rect)) command_adjust_enemy_event("strike", 0, -1);
        else if (point_in_rect(pointer_x, pointer_y, setup_strike_plus_rect)) command_adjust_enemy_event("strike", 0, 1);
        else if (point_in_rect(pointer_x, pointer_y, setup_twist_minus_rect)) command_adjust_enemy_event("twist", 0, -1);
        else if (point_in_rect(pointer_x, pointer_y, setup_twist_plus_rect)) command_adjust_enemy_event("twist", 0, 1);
        else if (point_in_rect(pointer_x, pointer_y, setup_start_rect)) command_start_game_from_setup();
        return;
    }

    if (game_over) {
        if (point_in_rect(pointer_x, pointer_y, restart_rect)) command_open_setup();
        return;
    }

    // Mandatory effects take input priority and pause automatic resolution.
    if (prompt_mode != "") {
        if (prompt_mode == "destroy_hand") {
            for (var hand_i = 0; hand_i < array_length(hand); hand_i++) {
                if (point_in_rect(pointer_x, pointer_y, hand_rects[hand_i])) {
                    command_prompt_hand(hand_i);
                    return;
                }
            }
        } else {
            for (var build_i = 0; build_i < 3; build_i++) {
                if (point_in_rect(pointer_x, pointer_y, build_rects[build_i])) {
                    command_prompt_build(build_i);
                    return;
                }
            }
        }
        log_add("Choose one of the highlighted cards.");
        return;
    }

    if (point_in_rect(pointer_x, pointer_y, action_rect)) {
        var player_action_phase = phase == "step1_ready" || phase == "build" || phase == "attack";
        if (player_action_phase && action_cooldown <= 0 && command_action()) action_cooldown = 24;
        return;
    }

    if (phase == "build") {
        for (var hand_i = 0; hand_i < array_length(hand); hand_i++) {
            if (point_in_rect(pointer_x, pointer_y, hand_rects[hand_i])) {
                command_select_hand(hand_i);
                return;
            }
        }
        for (var build_i = 0; build_i < 3; build_i++) {
            if (point_in_rect(pointer_x, pointer_y, build_rects[build_i])) {
                command_select_build(build_i);
                return;
            }
        }
    }

    if (phase == "attack") {
        for (var minion_i = 0; minion_i < 2; minion_i++) {
            if (point_in_rect(pointer_x, pointer_y, minion_rects[minion_i])) {
                command_attack_minion(minion_i);
                return;
            }
        }
        if (point_in_rect(pointer_x, pointer_y, leader_rect)) command_attack_leader();
    }
}

function draw_panel(_rect, _fill, _outline) {
    draw_set_color(_fill);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, false);
    draw_set_color(_outline);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, true);
}

function draw_center(_text, _x, _y, _color) {
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_color(_color);
    draw_text(_x, _y, _text);
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
    var draw_y = _rect.y + (_rect.h - source_h * scale) / 2;
    draw_sprite_ext(_sprite, 0, draw_x, draw_y, scale, scale, 0, c_white, 1);
}

function draw_card(_card, _rect, _selected, _legal) {
    var fill = COL_PANEL;
    if (!is_undefined(_card)) {
        if (variable_struct_exists(_card, "theme_color")) fill = _card.theme_color;
        else fill = make_color_rgb(92, 47, 48);
    }
    var outline = COL_EDGE;
    if (_legal) outline = COL_LEGAL;
    if (_selected) outline = COL_GOLD;
    draw_panel(_rect, fill, outline);
    if (is_undefined(_card)) {
        draw_center("EMPTY", _rect.x + _rect.w / 2, _rect.y + _rect.h / 2, COL_MUTED);
    } else {
        var art_sprite = variable_struct_exists(_card, "art_file") ? get_art_sprite(_card.art_file) : -1;
        if (art_sprite >= 0) {
            draw_art_contained(art_sprite, _rect, 4);
        } else {
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
            draw_set_color(COL_TEXT);
            draw_text(_rect.x + 10, _rect.y + 8, _card.name);
            draw_set_color(COL_GOLD);
            draw_text(_rect.x + 10, _rect.y + 34, "ATK " + string(_card.atk));
            draw_set_color(COL_ACCENT);
            draw_text(_rect.x + _rect.w - 64, _rect.y + 34, "HP " + string(_card.hp));
            draw_set_color(COL_TEXT);
            if (_card.ability != "") draw_text(_rect.x + 10, _rect.y + 59, _card.ability);
            draw_set_color(COL_MUTED);
            draw_text_ext(_rect.x + 10, _rect.y + 82, _card.effect, 16, _rect.w - 20);
        }
    }
    draw_set_color(outline);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, true);
    if (_legal) {
        draw_set_color(COL_LEGAL);
        draw_roundrect(_rect.x + 2, _rect.y + 2, _rect.x + _rect.w - 2, _rect.y + _rect.h - 2, true);
    }
}

function draw_enemy_reveal(_card, _rect) {
    var reveal_fill = _card.card_type == "strike"
        ? make_color_rgb(105, 48, 42)
        : make_color_rgb(68, 48, 105);
    var reveal_edge = _card.card_type == "strike" ? COL_DANGER : COL_GOLD;
    draw_panel(_rect, reveal_fill, reveal_edge);
    var reveal_sprite = get_art_sprite(_card.art_file);
    if (reveal_sprite >= 0) draw_art_contained(reveal_sprite, _rect, 4);
    draw_set_color(reveal_edge);
    draw_roundrect(_rect.x, _rect.y, _rect.x + _rect.w, _rect.y + _rect.h, true);
}

function draw_setup_counter_button(_rect, _text, _enabled) {
    draw_panel(_rect, _enabled ? COL_ACCENT : COL_PANEL, _enabled ? COL_TEXT : COL_EDGE);
    draw_center(_text, _rect.x + _rect.w / 2, _rect.y + _rect.h / 2,
        _enabled ? COL_BG : COL_MUTED);
}

function vv_ui_draw_setup() {
    draw_center("VILLAINS & VELVET", 640, 40, COL_GOLD);
    draw_center("CHOOSE YOUR BATTLE", 640, 70, COL_TEXT);

    var leader_panel = {x:50, y:105, w:350, h:180};
    var scenario_panel = {x:465, y:105, w:350, h:180};
    var heroes_panel = {x:880, y:105, w:350, h:180};
    draw_panel(leader_panel, COL_PANEL, COL_EDGE);
    draw_panel(scenario_panel, COL_PANEL, COL_EDGE);
    draw_panel(heroes_panel, COL_PANEL, COL_EDGE);

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(COL_GOLD);
    draw_text(70, 122, "LEADER");
    draw_text(485, 122, "SCENARIO");
    draw_text(900, 122, "HEROES  " + string(array_length(selected_hero_ids)) + " / " + string(CORE_HERO_COUNT));
    draw_set_color(COL_TEXT);
    draw_text(70, 165, enemy_leader.name);
    draw_set_color(COL_MUTED);
    draw_text(70, 198, "HEALTH  " + string(enemy_leader.starting_hp) + " / " + string(enemy_leader.max_hp));
    draw_text(70, 228, "ATTACK  " + string(enemy_leader.attack));
    draw_set_color(COL_TEXT);
    draw_text(485, 165, enemy_scenario.name);
    draw_set_color(COL_MUTED);
    draw_text(485, 198, "25 MINIONS");
    draw_text(485, 228, "8 ENEMY EVENT SLOTS");
    for (var setup_hero_i = 0; setup_hero_i < array_length(selected_hero_ids); setup_hero_i++) {
        var setup_hero = find_hero_definition(available_heroes, selected_hero_ids[setup_hero_i]);
        if (!is_undefined(setup_hero)) {
            draw_set_color(COL_TEXT);
            draw_text(900, 160 + setup_hero_i * 35, string(setup_hero_i + 1) + ".  " + setup_hero.name);
        }
    }

    var events_panel = {x:160, y:320, w:960, h:270};
    draw_panel(events_panel, make_color_rgb(24, 33, 46), COL_EDGE);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(COL_GOLD);
    draw_text(185, 340, "ENEMY EVENTS");
    draw_set_color(COL_MUTED);
    draw_text(185, 370, "Leader Strike");
    draw_text(185, 444, "Twist");

    var selected_strike = enemy_event_selection.leader_strikes[0];
    var selected_twist = enemy_event_selection.twists[0];
    var strike_definition = find_enemy_event_definition(enemy_leader.leader_strikes, selected_strike.id);
    var twist_definition = find_enemy_event_definition(enemy_scenario.twists, selected_twist.id);
    draw_set_color(COL_TEXT);
    draw_text(340, 387, strike_definition.card.name);
    draw_text(340, 461, twist_definition.card.name);
    draw_center(string(selected_strike.copies), 797, 405, COL_TEXT);
    draw_center(string(selected_twist.copies), 797, 479, COL_TEXT);
    draw_setup_counter_button(setup_strike_minus_rect, "-", selected_strike.copies > 0);
    draw_setup_counter_button(setup_strike_plus_rect, "+", selected_strike.copies < strike_definition.max_copies);
    draw_setup_counter_button(setup_twist_minus_rect, "-", selected_twist.copies > 0);
    draw_setup_counter_button(setup_twist_plus_rect, "+", selected_twist.copies < twist_definition.max_copies);

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(setup_validation.valid ? COL_LEGAL : COL_DANGER);
    draw_text(940, 370, "EVENTS: " + string(enemy_event_validation.total)
        + " / " + string(CORE_ENEMY_EVENT_SLOTS));
    var setup_status = "READY";
    if (enemy_event_validation.total > CORE_ENEMY_EVENT_SLOTS) {
        setup_status = "REMOVE " + string(enemy_event_validation.total - CORE_ENEMY_EVENT_SLOTS);
    } else if (enemy_event_validation.total < CORE_ENEMY_EVENT_SLOTS) {
        setup_status = "ADD " + string(CORE_ENEMY_EVENT_SLOTS - enemy_event_validation.total);
    } else if (!setup_validation.valid) {
        setup_status = "CHECK SELECTION";
    }
    draw_text(940, 410, setup_status);

    draw_panel(setup_start_rect, setup_validation.valid ? COL_ACCENT : COL_PANEL,
        setup_validation.valid ? COL_TEXT : COL_EDGE);
    draw_center("START GAME", setup_start_rect.x + setup_start_rect.w / 2,
        setup_start_rect.y + setup_start_rect.h / 2,
        setup_validation.valid ? COL_BG : COL_MUTED);
}

function vv_ui_draw_game() {
draw_clear(COL_BG);
// Battlefield artwork with a dark veil keeps the cards and instructions readable.
var background_rect = {x:0, y:0, w:1280, h:720};
draw_art_cover(background_art_sprite, background_rect);
draw_set_alpha(0.62);
draw_set_color(COL_BG);
draw_rectangle(0, 0, 1280, 720, false);
draw_set_alpha(1);

if (setup_active) {
    vv_ui_draw_setup();
    return;
}

// Leader and Minions.
draw_panel(leader_rect, make_color_rgb(72, 37, 48), leader_is_protected() ? COL_GOLD : COL_DANGER);
draw_art_contained(leader_art_sprite, leader_rect, 2);

// Live values are placed in the fields built into the Leader artwork.
draw_center(string(leader_hp), leader_rect.x + 224, leader_rect.y + 61, make_color_rgb(43, 24, 24));
var leader_strikes_remaining = 0;
for (var strike_i = 0; strike_i < array_length(enemy_deck); strike_i++) {
    if (enemy_deck[strike_i].card_type == "strike") leader_strikes_remaining++;
}
draw_set_color(make_color_rgb(17, 22, 36));
draw_rectangle(leader_rect.x + 253, leader_rect.y + 82,
    leader_rect.x + 272, leader_rect.y + 97, false);
draw_center(string(leader_strikes_remaining), leader_rect.x + 263, leader_rect.y + 89, COL_TEXT);
draw_set_color(leader_is_protected() ? COL_GOLD : COL_DANGER);
draw_roundrect(leader_rect.x, leader_rect.y, leader_rect.x + leader_rect.w, leader_rect.y + leader_rect.h, true);

draw_center("AREA 2", 645, 17, COL_GOLD);
draw_center("ESCAPES WHEN PUSHED", 645, 36, COL_MUTED);
if (!is_undefined(revealed_enemy_card)) {
    draw_center(revealed_enemy_card.card_type == "strike" ? "LEADER STRIKE" : "TWIST", 865, 17, COL_GOLD);
    draw_center(revealed_enemy_card.name, 865, 36, COL_TEXT);
} else {
    draw_center("AREA 1", 865, 17, COL_GOLD);
    draw_center("MINIONS ENTER HERE", 865, 36, COL_MUTED);
}
draw_card(minions[0], minion_rects[0], false, false);
if (!is_undefined(revealed_enemy_card)) draw_enemy_reveal(revealed_enemy_card, minion_rects[1]);
else draw_card(minions[1], minion_rects[1], false, false);
draw_center("←", 755, 186, COL_ACCENT);

// Build and Hand.
draw_center("BUILD AREA", 640, 297, COL_MUTED);
for (var build_i = 0; build_i < 3; build_i++) {
    var legal_build = (prompt_mode != "" && prompt_build_is_legal(build_i))
        || (phase == "build" && prompt_mode == "" && selected_hand >= 0);
    draw_card(build[build_i], build_rects[build_i], selected_build == build_i, legal_build);
}

draw_center("HAND", 640, 512, COL_MUTED);
for (var hand_i = 0; hand_i < 3; hand_i++) {
    var hand_card = hand_i < array_length(hand) ? hand[hand_i] : undefined;
    var legal_hand = prompt_mode == "destroy_hand" && hand_i < array_length(hand)
        && !is_undefined(hand_card);
    draw_card(hand_card, hand_rects[hand_i], selected_hand == hand_i, legal_hand);
}

// Event log.
if (debug_event_log) {
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(COL_MUTED);
    draw_text(16, 222, "EVENT LOG");
    for (var log_i = 0; log_i < array_length(log_lines); log_i++) {
        var log_box = {x:12, y:244 + log_i * 67, w:270, h:60};
        draw_panel(log_box, make_color_rgb(24, 33, 46), COL_EDGE);
        draw_text_ext(log_box.x + 8, log_box.y + 7, log_lines[log_i], 16, log_box.w - 16);
    }
}

// Context help.
var instruction = "";
if (prompt_mode == "" && enemy_attack_notice != "") instruction = enemy_attack_notice;
else if (prompt_mode == "enemy_attack") instruction = "Choose a highlighted Build card.";
else if (prompt_mode == "disrupt") instruction = "Choose a highlighted Build card.";
else if (prompt_mode == "shatter") instruction = "Choose a highlighted card with the lowest HP.";
else if (prompt_mode == "destroy_hand") instruction = "Choose a highlighted Hand card.";
else if (phase == "step1_ready") instruction = "Tap START TURN to draw 3 cards.";
else if (phase == "step2_ready") instruction = "Minions advance and escape.";
else if (phase == "step3_ready" || phase == "enemy_continue_wait") instruction = "Enemy cards are being drawn.";
else if (phase == "step4_ready") instruction = "Build phase is opening.";
else if (phase == "start_resolving") instruction = "Choose a highlighted card to continue.";
else if (phase == "build") {
    if (selected_hand >= 0) instruction = "Hand card selected. Tap a Build space to place or swap it.";
    else if (selected_build >= 0) instruction = "Build card selected. Tap a Hand card to swap it.";
    else instruction = "Place or swap cards, then tap READY TO ATTACK.";
} else if (phase == "attack") instruction = "Attack " + string(attack_left) + ": tap a Minion or the Leader. If you cannot defeat a Minion, you keep your Attack.";
else if (phase == "step5_ready") instruction = "Get ready to attack.";
else if (phase == "step6_ready") instruction = "Discarding the cards left in your Hand...";
else if (phase == "end_ready") instruction = "Ending your turn...";
if (prompt_mode == "enemy_attack") {
    instruction = prompt_source + "\nAttack: " + string(prompt_value) + "\n"
        + (build_has_priority() ? "Choose a highlighted Guard or Fortress." : "Choose a card this Attack can defeat.");
}
var context_panel = {x:985, y:16, w:280, h:190};
draw_panel(context_panel, make_color_rgb(24, 33, 46), COL_EDGE);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(COL_MUTED);
draw_text(1000, 29, "TURN STEPS");
var step_list = [
    "STEP 1: DRAW CARDS",
    "STEP 2: ADVANCE / ESCAPE",
    "STEP 3: ENEMY DRAW",
    "STEP 4: BUILD",
    "STEP 5: PLAYER ATTACK",
    "STEP 6: DISCARD",
    "STEP 7: END TURN"
];
for (var step_i = 0; step_i < 7; step_i++) {
    draw_set_color(step_i + 1 == step_number ? COL_GOLD : COL_MUTED);
    draw_text(1000, 53 + step_i * 19, step_list[step_i]);
}

// Short current instruction remains separate from the permanent step list.
draw_set_color(prompt_mode == "enemy_attack" ? COL_DANGER : COL_TEXT);
draw_text_ext(1000, 225, instruction, 18, 250);

// A selected card gets a readable description without covering the board.
var detail_card = undefined;
if (selected_hand >= 0 && selected_hand < array_length(hand)) detail_card = hand[selected_hand];
else if (selected_build >= 0 && selected_build < 3) detail_card = build[selected_build];
else if (!is_undefined(revealed_enemy_card)) detail_card = revealed_enemy_card;
else if (!is_undefined(minions[1])) detail_card = minions[1];
else if (!is_undefined(minions[0])) detail_card = minions[0];

if (!is_undefined(detail_card)) {
    var detail_panel = {x:985, y:325, w:280, h:170};
    draw_panel(detail_panel, make_color_rgb(24, 33, 46), COL_EDGE);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(COL_MUTED);
    draw_text(1000, 337, "CARD DETAILS");
    draw_set_color(COL_TEXT);
    draw_text(1000, 361, string_upper(detail_card.name));
    if (variable_struct_exists(detail_card, "atk")) {
        draw_set_color(COL_GOLD);
        draw_text(1000, 385, "ATK " + string(detail_card.atk));
        draw_set_color(COL_ACCENT);
        draw_text(1090, 385, "HP " + string(detail_card.hp));
    }
    var detail_y = variable_struct_exists(detail_card, "atk") ? 410 : 385;
    if (variable_struct_exists(detail_card, "ability") && detail_card.ability != "") {
        draw_set_color(COL_GOLD);
        draw_text(1000, detail_y, detail_card.ability);
        detail_y += 21;
    }
    draw_set_color(COL_TEXT);
    var detail_text = detail_card.effect != "" ? detail_card.effect : "No ability.";
    draw_text_ext(1000, detail_y, detail_text, 15, 250);
}

// Main action.
var match_panel = {x:1025, y:515, w:235, h:96};
draw_panel(match_panel, make_color_rgb(24, 33, 46), COL_EDGE);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_color(COL_GOLD);
draw_text(1038, 526, "TURN " + string(turn_number));
draw_set_color(COL_MUTED);
draw_text(1038, 548, "PLAYER DECK: " + string(array_length(player_deck)));
draw_text(1038, 570, "DISCARD: " + string(array_length(player_discard)));
draw_text(1038, 590, "ENEMY DECK: " + string(array_length(enemy_deck)));

var button_enabled = prompt_mode == "" && action_cooldown <= 0
    && (phase == "step1_ready" || phase == "build" || phase == "attack");
draw_panel(action_rect, button_enabled ? COL_ACCENT : COL_PANEL, button_enabled ? COL_TEXT : COL_EDGE);
var button_text = "";
if (prompt_mode != "") button_text = "CHOOSE A CARD";
else if (phase == "step1_ready") button_text = turn_number == 1 ? "START TURN" : "START NEXT TURN";
else if (phase == "build") button_text = "READY TO ATTACK";
else if (phase == "attack") button_text = "END ATTACK";
else button_text = "RESOLVING...";
draw_center(button_text, action_rect.x + action_rect.w / 2, action_rect.y + action_rect.h / 2,
    button_enabled ? COL_BG : COL_MUTED);

if (game_over) {
    draw_set_alpha(0.9);
    draw_set_color(COL_BG);
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1);
    draw_center(victory ? "VICTORY" : "DEFEAT", 640, 305, victory ? COL_ACCENT : COL_DANGER);
    draw_center(victory ? "The Enemy Leader has been defeated." : "The Enemy Deck ran out before the Leader fell.",
        640, 365, COL_TEXT);
    draw_panel(restart_rect, COL_GOLD, COL_TEXT);
    draw_center("PLAY AGAIN", 640, 505, COL_BG);
}
}
