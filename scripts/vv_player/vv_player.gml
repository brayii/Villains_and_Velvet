/// Player Deck recycling, Hand/Build interaction, and Player Attack rules.

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

function count_unique_other_heroes(_cards, _source_index) {
    var hero_ids = [];
    var source_hero = _cards[_source_index].hero;
    for (var other_i = 0; other_i < array_length(_cards); other_i++) {
        if (other_i != _source_index && !is_undefined(_cards[other_i])) {
            var other_hero = _cards[other_i].hero;
            if (other_hero != source_hero && !array_has_value(hero_ids, other_hero)) {
                array_push(hero_ids, other_hero);
            }
        }
    }
    return array_length(hero_ids);
}

function compute_attack_summary() {
    var total = 0;
    var rally_cards = 0;
    var gained_after_kill = 0;
    for (var card_i = 0; card_i < 3; card_i++) if (!is_undefined(build[card_i])) {
        total += build[card_i].atk;
        if (build[card_i].ability_id == ABILITY_RALLY) rally_cards++;
        if (build[card_i].ability_id == ABILITY_OVERPOWER) gained_after_kill += 2;
        if (build[card_i].ability_id == ABILITY_RELENTLESS) gained_after_kill += 3;
    }
    for (var card_i = 0; card_i < 3; card_i++) if (!is_undefined(build[card_i])) {
        var other_rallies = rally_cards;
        if (build[card_i].ability_id == ABILITY_RALLY) other_rallies--;
        total += max(0, other_rallies);
        if (build[card_i].ability_id == ABILITY_UNITY) {
            total += 2 * count_unique_other_heroes(build, card_i);
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
    log_add("Enemy Leader takes " + string(damage) + " damage (" + string(leader_hp) + "/" + string(enemy_leader.max_hp) + ").");
    if (leader_hp == 0) {
        game_over = true;
        victory = true;
        phase = "game_over";
        log_add("Victory! The Enemy Leader has been defeated.");
    }
    validate_state("Player attacks Leader");
    return true;
}
