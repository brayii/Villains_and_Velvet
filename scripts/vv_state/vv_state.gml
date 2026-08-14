/// Game-state initialization, counts, validation, and debug logging.

function array_remove_index(_source, _index) {
    var result = [];
    for (var source_i = 0; source_i < array_length(_source); source_i++) {
        if (source_i != _index) array_push(result, _source[source_i]);
    }
    return result;
}

function log_add(_text) {
    array_push(log_lines, _text);
    while (array_length(log_lines) > 6) log_lines = array_remove_index(log_lines, 0);
}

function count_occupied_build() {
    var count = 0;
    for (var count_i = 0; count_i < 3; count_i++) {
        if (!is_undefined(build[count_i])) count++;
    }
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
    for (var count_i = 0; count_i < 2; count_i++) {
        if (!is_undefined(minions[count_i])) count++;
    }
    return count;
}

function build_has_cards() {
    return count_occupied_build() > 0;
}

function validate_state(_context) {
    var player_total = array_length(player_deck) + array_length(player_discard)
        + count_occupied_hand() + count_occupied_build();
    var enemy_total = array_length(enemy_deck) + array_length(enemy_used) + count_live_minions();
    var valid_spaces = array_length(hand) == 3 && array_length(build) == 3 && array_length(minions) == 2;
    var valid = player_total == 45 && enemy_total == 33
        && leader_hp >= 0 && leader_hp <= enemy_leader.max_hp
        && attack_left >= 0 && valid_spaces;
    if (!valid) {
        var state_message = _context + ": Player " + string(player_total)
            + "/45, Enemy " + string(enemy_total) + "/33"
            + ", spaces " + string(array_length(hand)) + "/"
            + string(array_length(build)) + "/" + string(array_length(minions));
        log_add("STATE WARNING: " + state_message);
    }
    return valid;
}

function reset_game() {
    leader_hp = enemy_leader.max_hp;
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
