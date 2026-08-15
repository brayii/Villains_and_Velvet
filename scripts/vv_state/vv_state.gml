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

function array_has_value(_values, _value) {
    for (var value_i = 0; value_i < array_length(_values); value_i++) {
        if (_values[value_i] == _value) return true;
    }
    return false;
}

function count_player_cards(_cards, _hero, _kind) {
    var count = 0;
    for (var card_i = 0; card_i < array_length(_cards); card_i++) {
        var card = _cards[card_i];
        if (card.hero == _hero && card.kind == _kind) count++;
    }
    return count;
}

function validate_player_composition(_cards) {
    if (array_length(_cards) != CORE_PLAYER_DECK_SIZE) return false;
    var hero_ids = [];
    for (var card_i = 0; card_i < array_length(_cards); card_i++) {
        var discovered_hero = _cards[card_i].hero;
        if (!array_has_value(hero_ids, discovered_hero)) array_push(hero_ids, discovered_hero);
    }
    if (array_length(hero_ids) != CORE_HERO_COUNT) return false;
    for (var hero_i = 0; hero_i < array_length(hero_ids); hero_i++) {
        var selected_hero = hero_ids[hero_i];
        if (count_player_cards(_cards, selected_hero, "Normal") != CORE_HERO_NORMAL_COPIES) return false;
        if (count_player_cards(_cards, selected_hero, "Ability") != CORE_HERO_ABILITY_COPIES) return false;
        if (count_player_cards(_cards, selected_hero, "Special") != CORE_HERO_SPECIAL_COPIES) return false;
    }
    return true;
}

function count_enemy_cards(_cards, _card_type, _code) {
    var count = 0;
    for (var card_i = 0; card_i < array_length(_cards); card_i++) {
        var card = _cards[card_i];
        if (card.card_type == _card_type) {
            if (_card_type != "minion" || _code == "" || card.code == _code) count++;
        }
    }
    return count;
}

function validate_enemy_composition(_cards) {
    if (array_length(_cards) != CORE_ENEMY_DECK_SIZE) return false;
    if (count_enemy_cards(_cards, "minion", "NA") != CORE_MINION_NA_COPIES) return false;
    if (count_enemy_cards(_cards, "minion", "NB") != CORE_MINION_NB_COPIES) return false;
    if (count_enemy_cards(_cards, "minion", "NC") != CORE_MINION_NC_COPIES) return false;
    if (count_enemy_cards(_cards, "minion", "AA") != CORE_MINION_AA_COPIES) return false;
    if (count_enemy_cards(_cards, "minion", "AB") != CORE_MINION_AB_COPIES) return false;
    if (count_enemy_cards(_cards, "minion", "SA") != CORE_MINION_SA_COPIES) return false;
    if (count_enemy_cards(_cards, "minion", "SB") != CORE_MINION_SB_COPIES) return false;
    if (count_enemy_cards(_cards, "minion", "SC") != CORE_MINION_SC_COPIES) return false;
    var minion_count = count_enemy_cards(_cards, "minion", "");
    var event_count = count_enemy_cards(_cards, "strike", "") + count_enemy_cards(_cards, "twist", "");
    return minion_count == CORE_MINION_TOTAL && event_count == CORE_ENEMY_EVENT_SLOTS;
}

function collect_player_cards() {
    var cards = [];
    for (var deck_i = 0; deck_i < array_length(player_deck); deck_i++) array_push(cards, player_deck[deck_i]);
    for (var discard_i = 0; discard_i < array_length(player_discard); discard_i++) array_push(cards, player_discard[discard_i]);
    for (var hand_i = 0; hand_i < array_length(hand); hand_i++) {
        if (!is_undefined(hand[hand_i])) array_push(cards, hand[hand_i]);
    }
    for (var build_i = 0; build_i < array_length(build); build_i++) {
        if (!is_undefined(build[build_i])) array_push(cards, build[build_i]);
    }
    return cards;
}

function collect_enemy_cards() {
    var cards = [];
    for (var deck_i = 0; deck_i < array_length(enemy_deck); deck_i++) array_push(cards, enemy_deck[deck_i]);
    for (var used_i = 0; used_i < array_length(enemy_used); used_i++) array_push(cards, enemy_used[used_i]);
    for (var minion_i = 0; minion_i < array_length(minions); minion_i++) {
        if (!is_undefined(minions[minion_i])) array_push(cards, minions[minion_i]);
    }
    return cards;
}

function validate_state(_context) {
    var player_cards = collect_player_cards();
    var enemy_cards = collect_enemy_cards();
    var player_total = array_length(player_cards);
    var enemy_total = array_length(enemy_cards);
    var valid_player_composition = validate_player_composition(player_cards);
    var valid_enemy_composition = validate_enemy_composition(enemy_cards);
    var valid_spaces = array_length(hand) == 3 && array_length(build) == 3 && array_length(minions) == 2;
    var valid = valid_player_composition && valid_enemy_composition
        && leader_hp >= 0 && leader_hp <= enemy_leader.max_hp
        && attack_left >= 0 && valid_spaces;
    if (!valid) {
        var state_message = _context + ": Player " + string(player_total)
            + "/" + string(CORE_PLAYER_DECK_SIZE)
            + ", Enemy " + string(enemy_total) + "/" + string(CORE_ENEMY_DECK_SIZE)
            + ", composition " + string(valid_player_composition)
            + "/" + string(valid_enemy_composition)
            + ", spaces " + string(array_length(hand)) + "/"
            + string(array_length(build)) + "/" + string(array_length(minions));
        log_add("STATE WARNING: " + state_message);
        show_debug_message("STATE WARNING: " + state_message);
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
