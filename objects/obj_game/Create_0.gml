display_set_gui_size(1280, 720);
randomize();
gpu_set_texfilter(true);

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

debug_event_log = false;
art_sprites = {};

function art_cache_key(_file) {
    var key = string_replace_all(_file, "/", "_");
    key = string_replace_all(key, ".", "_");
    return key;
}

function get_art_sprite(_file) {
    if (_file == "") return -1;
    var key = art_cache_key(_file);
    if (variable_struct_exists(art_sprites, key)) return variable_struct_get(art_sprites, key);

    var sprite_id = -1;
    var full_path = working_directory + _file;
    if (file_exists(full_path)) sprite_id = sprite_add(full_path, 1, false, true, 0, 0);
    else log_add("Artwork could not be loaded: " + _file);

    variable_struct_set(art_sprites, key, sprite_id);
    return sprite_id;
}

function log_add(_text) {
    array_push(log_lines, _text);
    while (array_length(log_lines) > 6) log_lines = array_remove_index(log_lines, 0);
}

function count_occupied_build() {
    var count = 0;
    for (var count_i = 0; count_i < 3; count_i++) if (!is_undefined(build[count_i])) count++;
    return count;
}

function count_occupied_hand() {
    var count = 0;
    for (var count_i = 0; count_i < array_length(hand); count_i++) {
        if (!is_undefined(hand[count_i])) count++;
    }
    return count;
}

function count_live_minions() {
    var count = 0;
    for (var count_i = 0; count_i < 2; count_i++) if (!is_undefined(minions[count_i])) count++;
    return count;
}

function validate_state(_context) {
    var player_total = array_length(player_deck) + array_length(player_discard)
        + count_occupied_hand() + count_occupied_build();
    var enemy_total = array_length(enemy_deck) + array_length(enemy_used) + count_live_minions();
    var valid = player_total == 45 && enemy_total == 33
        && leader_hp >= 0 && leader_hp <= 175 && attack_left >= 0;
    if (!valid) {
        var state_message = _context + ": Player " + string(player_total)
            + "/45, Enemy " + string(enemy_total) + "/33";
        log_add("STATE WARNING: " + state_message);
    }
    return valid;
}

function reset_game() {
    leader_hp = 175;
    player_deck = make_player_deck();
    player_discard = [];
    enemy_deck = make_enemy_deck();
    enemy_used = [];
    hand = [undefined, undefined, undefined];
    build = [undefined, undefined, undefined];
    minions = [undefined, undefined]; // 0 = Area 2, 1 = Area 1
    revealed_enemy_card = undefined;
    selected_hand = -1;
    selected_build = -1;
    attack_left = 0;
    kill_bonus = 0;
    turn_number = 1;
    step_number = 1;
    phase = "step1_ready";
    prompt_mode = "";
    prompt_value = 0;
    prompt_source = "";
    enemy_attack_notice = "";
    resume_action = "";
    queued_attacks = [];
    action_cooldown = 0;
    auto_timer = 0;
    game_over = false;
    victory = false;
    enemy_exhausted = false;
    log_lines = [];
    log_add("The battle begins with both Minion Areas empty.");
    log_add("Tap START TURN when you are ready.");
    validate_state("Reset");
}

function recycle_player_deck() {
    if (array_length(player_deck) == 0 && array_length(player_discard) > 0) {
        player_deck = array_shuffle_copy(player_discard);
        player_discard = [];
        log_add("The discard pile was shuffled back into the Player Deck.");
    }
}

function draw_player_hand() {
    if (count_occupied_hand() > 0) {
        log_add("Cards left in your Hand were discarded.");
        for (var old_hand_i = 0; old_hand_i < array_length(hand); old_hand_i++) {
            if (!is_undefined(hand[old_hand_i])) array_push(player_discard, hand[old_hand_i]);
        }
    }
    hand = [undefined, undefined, undefined];
    for (var draw_slot = 0; draw_slot < 3; draw_slot++) {
        recycle_player_deck();
        if (array_length(player_deck) > 0) hand[draw_slot] = array_pop(player_deck);
    }
    log_add("Step 1 — Draw: " + string(count_occupied_hand()) + " cards in Hand.");
}

function build_has_cards() {
    return count_occupied_build() > 0;
}

function build_has_priority() {
    for (var priority_i = 0; priority_i < 3; priority_i++) {
        if (!is_undefined(build[priority_i])
        && (build[priority_i].ability == "Guard" || build[priority_i].ability == "Fortress")) return true;
    }
    return false;
}

function enemy_target_is_legal(_index, _amount) {
    if (_index < 0 || _index > 2 || is_undefined(build[_index])) return false;
    if (build_has_priority()
    && build[_index].ability != "Guard" && build[_index].ability != "Fortress") return false;
    return _amount >= build[_index].hp;
}

function enemy_has_legal_target(_amount) {
    for (var target_i = 0; target_i < 3; target_i++) {
        if (enemy_target_is_legal(target_i, _amount)) return true;
    }
    return false;
}

function lowest_build_indices() {
    var result = [];
    var lowest_hp = 9999;
    for (var low_i = 0; low_i < 3; low_i++) if (!is_undefined(build[low_i])) {
        if (build[low_i].hp < lowest_hp) {
            lowest_hp = build[low_i].hp;
            result = [low_i];
        } else if (build[low_i].hp == lowest_hp) array_push(result, low_i);
    }
    return result;
}

function prompt_build_is_legal(_index) {
    if (_index < 0 || _index > 2 || is_undefined(build[_index])) return false;
    if (prompt_mode == "enemy_attack") return enemy_target_is_legal(_index, prompt_value);
    if (prompt_mode == "disrupt") return true;
    if (prompt_mode == "shatter") {
        var tied = lowest_build_indices();
        for (var tied_i = 0; tied_i < array_length(tied); tied_i++) if (tied[tied_i] == _index) return true;
    }
    return false;
}

function destroy_build_card(_index, _source) {
    if (is_undefined(build[_index])) return;
    log_add(build[_index].name + " destroyed by " + _source + ".");
    array_push(player_discard, build[_index]);
    build[_index] = undefined;
}

function discard_build_card(_index, _source) {
    if (is_undefined(build[_index])) return;
    log_add(build[_index].name + " discarded by " + _source + ".");
    array_push(player_discard, build[_index]);
    build[_index] = undefined;
}

function destroy_hand_card(_index, _source) {
    if (_index < 0 || _index >= array_length(hand) || is_undefined(hand[_index])) return;
    log_add(hand[_index].name + " destroyed by " + _source + ".");
    array_push(player_discard, hand[_index]);
    hand[_index] = undefined;
}

function retire_minion(_index, _reason) {
    if (is_undefined(minions[_index])) return;
    log_add(minions[_index].name + " " + _reason + ".");
    array_push(enemy_used, minions[_index]);
    minions[_index] = undefined;
}

function queue_enemy_attack(_amount, _source) {
    if (_amount > 0) array_push(queued_attacks, {amount:_amount, source:_source});
}

function start_queued_attack() {
    while (array_length(queued_attacks) > 0) {
        var next_attack = queued_attacks[0];
        queued_attacks = array_remove_index(queued_attacks, 0);
        if (!build_has_cards()) {
            enemy_attack_notice = "The Build Area is empty.\nThe Attack ends.";
            log_add(next_attack.source + " attacks for " + string(next_attack.amount) + ", but the Build Area is empty.");
            continue;
        }
        if (!enemy_has_legal_target(next_attack.amount)) {
            if (build_has_priority()) {
                enemy_attack_notice = "Guard/Fortress blocks the Attack.\nIt is not strong enough to defeat it.";
                log_add(next_attack.source + " cannot defeat Guard or Fortress. The Attack ends.");
            } else {
                enemy_attack_notice = "No Build card can be defeated.\nThe unused Attack ends.";
                log_add(next_attack.source + " cannot defeat any Build card. The Attack ends.");
            }
            continue;
        }
        enemy_attack_notice = "";
        prompt_mode = "enemy_attack";
        prompt_value = next_attack.amount;
        prompt_source = next_attack.source;
        log_add(next_attack.source + " attacks for " + string(next_attack.amount) + ". Choose a highlighted target.");
        return true;
    }
    return false;
}

function resume_after_prompts() {
    if (prompt_mode != "") return;
    if (start_queued_attack()) return;
    var action = resume_action;
    resume_action = "";
    if (action == "finish_advance") {
        if (!is_undefined(minions[0])) retire_minion(0, "finishes escaping");
        minions[0] = minions[1];
        minions[1] = undefined;
        if (!is_undefined(minions[0])) log_add(minions[0].name + " advances to Area 2.");
        log_add("Step 2 — Advance/Escape complete.");
        step_number = 3;
        phase = "step3_ready";
        auto_timer = 50;
        log_add("Next: Enemy Draw.");
    } else if (action == "continue_enemy_draw") {
        phase = "enemy_continue_wait";
        auto_timer = 50;
    } else if (action == "finish_enemy") {
        step_number = 4;
        phase = "step4_ready";
        auto_timer = 45;
        selected_hand = -1;
        selected_build = -1;
        log_add("Step 3 complete: a Minion is in Area 1. Build your attack.");
        validate_state("Enemy Draw complete");
    }
}

function heal_leader(_amount) {
    var healing_room = 175 - leader_hp;
    var healed = min(_amount, healing_room);
    var overflow = _amount - healed;
    leader_hp += healed;
    log_add("Leader heals " + string(healed) + " HP (" + string(leader_hp) + "/175).");
    if (overflow > 0) {
        log_add(string(overflow) + " excess healing becomes Overflow Attack.");
        queue_enemy_attack(overflow, "Overflow");
    }
}

function begin_advance_phase() {
    step_number = 2;
    resume_action = "finish_advance";
    log_add("Step 2 — Advance/Escape.");
    if (!is_undefined(minions[0])) {
        var escaping = minions[0];
        log_add(escaping.name + " begins its Escape effect.");
        if (escaping.escape == "heal") {
            heal_leader(escaping.escape_value);
        } else if (escaping.escape == "destroy_hand") {
            if (count_occupied_hand() > 0) {
                prompt_mode = "destroy_hand";
                log_add("SB escapes. Choose a highlighted Hand card to destroy.");
            } else log_add("SB Escape finds no card in Hand to destroy.");
        }
    }
    resume_after_prompts();
}

function resolve_minion_entry(_minion) {
    log_add(_minion.name + " enters Minion Area 1.");
    resume_action = "finish_enemy";
    if (_minion.ability == "Disrupt" && build_has_cards()) {
        prompt_mode = "disrupt";
        prompt_value = _minion.atk;
        log_add("AA uses Disrupt. Choose a highlighted Build card to discard.");
        return;
    }
    if (_minion.ability == "Crush") {
        queue_enemy_attack(7, "AB — Crush (1 of 2)");
        queue_enemy_attack(7, "AB — Crush (2 of 2)");
    } else if (_minion.ability == "Shatter") {
        var tied = lowest_build_indices();
        if (array_length(tied) == 1) destroy_build_card(tied[0], "SB Shatter");
        else if (array_length(tied) > 1) {
            prompt_mode = "shatter";
            prompt_value = 8;
            log_add("SB uses Shatter. Choose a highlighted card tied for lowest Health.");
            return;
        }
        queue_enemy_attack(8, "SB — Attack");
    } else if (_minion.ability == "Devastate") {
        queue_enemy_attack(10, "SC — Devastate (1 of 2)");
        queue_enemy_attack(10, "SC — Devastate (2 of 2)");
    } else {
        queue_enemy_attack(_minion.atk, _minion.name + " — Attack");
    }
    resume_after_prompts();
}

function draw_next_enemy_card() {
    step_number = 3;
    phase = "start_resolving";
    revealed_enemy_card = undefined;
    enemy_attack_notice = "";
    if (array_length(enemy_deck) == 0) {
        enemy_exhausted = true;
        step_number = 4;
        phase = "step4_ready";
        auto_timer = 45;
        log_add("The Enemy Deck is empty. This is your final chance to build and attack.");
        validate_state("Enemy Deck exhausted");
        return;
    }
    var enemy_card = array_pop(enemy_deck);
    if (array_length(enemy_deck) == 0) enemy_exhausted = true;
    if (enemy_card.card_type == "strike") {
        revealed_enemy_card = enemy_card;
        array_push(enemy_used, enemy_card);
        log_add("Enemy Draw: Direct Assault.");
        queue_enemy_attack(8, "Direct Assault");
        resume_action = "continue_enemy_draw";
        resume_after_prompts();
    } else if (enemy_card.card_type == "twist") {
        revealed_enemy_card = enemy_card;
        array_push(enemy_used, enemy_card);
        log_add("Enemy Draw: Reinforcements.");
        if (!is_undefined(minions[0])) queue_enemy_attack(minions[0].atk, "Reinforcements: " + minions[0].name);
        else log_add("Area 2 is empty; Reinforcements has no effect.");
        resume_action = "continue_enemy_draw";
        resume_after_prompts();
    } else {
        minions[1] = enemy_card;
        resolve_minion_entry(enemy_card);
    }
}

function do_step_1() {
    if (phase != "step1_ready" || game_over) return;
    step_number = 1;
    log_add("— TURN " + string(turn_number) + " —");
    log_add("Step 1 — Draw three Player cards.");
    draw_player_hand();
    step_number = 2;
    phase = "step2_ready";
    auto_timer = 50;
    log_add("Next: Advance/Escape.");
}

function do_step_2() {
    if (phase != "step2_ready" || game_over) return;
    phase = "start_resolving";
    begin_advance_phase();
}

function do_step_3() {
    if (phase != "step3_ready" || game_over) return;
    phase = "start_resolving";
    draw_next_enemy_card();
}

function begin_build() {
    if (phase != "step4_ready" || game_over) return;
    enemy_attack_notice = "";
    phase = "build";
    log_add("Build your team, then tap READY TO ATTACK.");
}

function compute_attack_summary() {
    var total = 0;
    var rally_cards = 0;
    var gained_after_kill = 0;
    for (var card_i = 0; card_i < 3; card_i++) if (!is_undefined(build[card_i])) {
        total += build[card_i].atk;
        if (build[card_i].ability == "Rally") rally_cards++;
        if (build[card_i].ability == "Overpower") gained_after_kill += 2;
        if (build[card_i].ability == "Relentless") gained_after_kill += 3;
    }
    for (var card_i = 0; card_i < 3; card_i++) if (!is_undefined(build[card_i])) {
        var other_rallies = rally_cards;
        if (build[card_i].ability == "Rally") other_rallies--;
        total += max(0, other_rallies);
        if (build[card_i].ability == "Unity") {
            var hero_a = false;
            var hero_b = false;
            var hero_c = false;
            for (var other_i = 0; other_i < 3; other_i++) if (other_i != card_i && !is_undefined(build[other_i])) {
                if (build[other_i].hero != build[card_i].hero) {
                    if (build[other_i].hero == "A") hero_a = true;
                    if (build[other_i].hero == "B") hero_b = true;
                    if (build[other_i].hero == "C") hero_c = true;
                }
            }
            total += 2 * (hero_a + hero_b + hero_c);
        }
    }
    return {total:total, kill_bonus:gained_after_kill};
}

function command_select_hand(_index) {
    if (phase != "build" || _index < 0 || _index >= array_length(hand) || is_undefined(hand[_index])) return false;
    if (selected_build >= 0 && !is_undefined(build[selected_build])) {
        var build_card = build[selected_build];
        var hand_card = hand[_index];
        build[selected_build] = hand_card;
        hand[_index] = build_card;
        log_add("Swapped " + build_card.name + " with " + hand_card.name + ".");
        selected_build = -1;
        selected_hand = -1;
        validate_state("Build-first swap");
        return true;
    }
    selected_hand = selected_hand == _index ? -1 : _index;
    selected_build = -1;
    if (selected_hand >= 0) {
        log_add("Selected " + hand[_index].name + ". Choose a highlighted space in the Build Area.");
    } else {
        log_add("Hand selection cancelled.");
    }
    return true;
}

function command_select_build(_index) {
    if (phase != "build" || _index < 0 || _index > 2) return false;
    if (selected_hand >= 0 && selected_hand < array_length(hand) && !is_undefined(hand[selected_hand])) {
        var hand_card = hand[selected_hand];
        if (is_undefined(build[_index])) {
            build[_index] = hand_card;
            hand[selected_hand] = undefined;
            log_add("Placed " + hand_card.name + " in Build " + string(_index + 1) + ".");
        } else {
            var build_card = build[_index];
            build[_index] = hand_card;
            hand[selected_hand] = build_card;
            log_add("Swapped " + build_card.name + " with " + hand_card.name + ".");
        }
        selected_hand = -1;
        selected_build = -1;
        validate_state("Hand-first Build action");
        return true;
    }
    if (!is_undefined(build[_index])) {
        selected_build = selected_build == _index ? -1 : _index;
        selected_hand = -1;
        return true;
    }
    log_add("Select a Hand card before choosing an empty Build space.");
    return false;
}

function command_prompt_hand(_index) {
    if (prompt_mode != "destroy_hand" || _index < 0 || _index >= array_length(hand)
    || is_undefined(hand[_index])) return false;
    destroy_hand_card(_index, "SB Escape");
    prompt_mode = "";
    resume_after_prompts();
    validate_state("SB Escape");
    return true;
}

function command_prompt_build(_index) {
    if (!prompt_build_is_legal(_index)) {
        log_add("That card cannot be targeted. Choose a highlighted card.");
        return false;
    }
    if (prompt_mode == "enemy_attack") {
        prompt_value -= build[_index].hp;
        destroy_build_card(_index, "enemy Attack");
        if (prompt_value > 0 && enemy_has_legal_target(prompt_value)) {
            log_add(string(prompt_value) + " Attack remains. Choose another highlighted target.");
            return true;
        }
        if (prompt_value > 0) {
            if (!build_has_cards()) {
                enemy_attack_notice = "The Build Area is clear.\nThe unused Attack ends.";
            } else if (build_has_priority()) {
                enemy_attack_notice = "Guard/Fortress blocks the rest.\nThe unused Attack ends.";
            } else {
                enemy_attack_notice = "No other card can be defeated.\nThe unused Attack ends.";
            }
            log_add(string(prompt_value) + " Attack remains, but no legal card can be defeated. The Attack ends.");
        }
        prompt_mode = "";
        prompt_value = 0;
        prompt_source = "";
        resume_after_prompts();
        validate_state("Enemy Attack");
        return true;
    }
    if (prompt_mode == "disrupt") {
        discard_build_card(_index, "AA Disrupt");
        var aa_attack = prompt_value;
        prompt_mode = "";
        prompt_value = 0;
        queue_enemy_attack(aa_attack, "AA — Attack");
        resume_after_prompts();
        validate_state("AA Disrupt");
        return true;
    }
    if (prompt_mode == "shatter") {
        destroy_build_card(_index, "SB Shatter");
        var sb_attack = prompt_value;
        prompt_mode = "";
        prompt_value = 0;
        queue_enemy_attack(sb_attack, "SB — Attack");
        resume_after_prompts();
        validate_state("SB Shatter");
        return true;
    }
    return false;
}

function command_attack_minion(_index) {
    if (phase != "attack" || _index < 0 || _index > 1 || is_undefined(minions[_index])) return false;
    if (attack_left >= minions[_index].hp) {
        attack_left -= minions[_index].hp;
        var defeated_name = minions[_index].name;
        retire_minion(_index, "is defeated");
        if (kill_bonus > 0) {
            attack_left += kill_bonus;
            log_add("Defeating " + defeated_name + " activates your card abilities: +"
                + string(kill_bonus) + " Attack.");
        }
    } else {
        log_add("You need " + string(minions[_index].hp) + " Attack to defeat "
            + minions[_index].name + ", but you only have " + string(attack_left)
            + ". Your Attack was not spent.");
    }
    validate_state("Player attacks Minion");
    return true;
}

function leader_is_protected() {
    for (var minion_i = 0; minion_i < 2; minion_i++) {
        if (!is_undefined(minions[minion_i]) && minions[minion_i].ability == "Protector") return true;
    }
    return false;
}

function command_attack_leader() {
    if (phase != "attack") return false;
    if (leader_is_protected()) {
        log_add("SA Protector prevents attacks on the Leader.");
        return false;
    }
    if (attack_left <= 0) {
        log_add("You have no Attack left.");
        return false;
    }
    var damage = attack_left;
    leader_hp = max(0, leader_hp - damage);
    attack_left = 0;
    log_add("Enemy Leader takes " + string(damage) + " damage (" + string(leader_hp) + "/175).");
    if (leader_hp == 0) {
        game_over = true;
        victory = true;
        phase = "game_over";
        log_add("Victory! The Enemy Leader has been defeated.");
    }
    validate_state("Player attacks Leader");
    return true;
}

function finish_build() {
    selected_hand = -1;
    selected_build = -1;
    step_number = 5;
    phase = "step5_ready";
    auto_timer = 35;
    log_add("Your Build is ready. Prepare to attack.");
}

function begin_attack() {
    var summary = compute_attack_summary();
    attack_left = summary.total;
    kill_bonus = summary.kill_bonus;
    phase = "attack";
    log_add("Step 5 — Player Attack: " + string(attack_left) + ".");
}

function finish_attack() {
    log_add("Step 5 complete. " + string(attack_left) + " unused Attack remains until End Turn.");
    step_number = 6;
    phase = "step6_ready";
    auto_timer = 40;
    log_add("Attack complete. Discarding the cards left in your Hand.");
}

function do_step_6() {
    for (var discard_hand_i = 0; discard_hand_i < array_length(hand); discard_hand_i++) {
        if (!is_undefined(hand[discard_hand_i])) array_push(player_discard, hand[discard_hand_i]);
        hand[discard_hand_i] = undefined;
    }
    log_add("Step 6 — all remaining Hand cards discarded.");
    step_number = 7;
    phase = "end_ready";
    auto_timer = 40;
    log_add("Discard complete. Ending turn.");
}

function finish_turn() {
    attack_left = 0;
    log_add("Step 7 — End Turn.");
    selected_hand = -1;
    selected_build = -1;
    if (enemy_exhausted && leader_hp > 0) {
        game_over = true;
        victory = false;
        phase = "game_over";
        log_add("Defeat. The Enemy Deck is empty, but the Leader still stands.");
    } else {
        turn_number++;
        step_number = 1;
        phase = "step1_ready";
        log_add("Turn " + string(turn_number) + " ready. Tap START NEXT TURN.");
    }
    validate_state("End Turn");
}

function command_action() {
    if (game_over || prompt_mode != "") return false;
    if (phase == "step1_ready") do_step_1();
    else if (phase == "step2_ready") do_step_2();
    else if (phase == "step3_ready") do_step_3();
    else if (phase == "step4_ready") begin_build();
    else if (phase == "build") finish_build();
    else if (phase == "step5_ready") begin_attack();
    else if (phase == "attack") finish_attack();
    else if (phase == "step6_ready") do_step_6();
    else if (phase == "end_ready") finish_turn();
    else return false;
    return true;
}

reset_game();
background_art_sprite = get_art_sprite(ART_BACKGROUND);
leader_art_sprite = get_art_sprite(ART_ENEMY_LEADER);
