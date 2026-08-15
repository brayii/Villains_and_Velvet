/// Enemy targeting, attacks, Minion effects, Enemy Draw, and prompt resolution.

function build_has_priority() {
    for (var priority_i = 0; priority_i < 3; priority_i++) {
        if (!is_undefined(build[priority_i])
        && (build[priority_i].ability_id == ABILITY_GUARD || build[priority_i].ability_id == ABILITY_FORTRESS)) return true;
    }
    return false;
}

function enemy_target_is_legal(_index, _amount) {
    if (_index < 0 || _index > 2 || is_undefined(build[_index])) return false;
    if (build_has_priority()
    && build[_index].ability_id != ABILITY_GUARD && build[_index].ability_id != ABILITY_FORTRESS) return false;
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
        for (var tied_i = 0; tied_i < array_length(tied); tied_i++) {
            if (tied[tied_i] == _index) return true;
        }
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

function heal_leader(_amount) {
    var healing_room = enemy_leader.max_hp - leader_hp;
    var healed = min(_amount, healing_room);
    var overflow = _amount - healed;
    leader_hp += healed;
    log_add("Leader heals " + string(healed) + " HP (" + string(leader_hp) + "/" + string(enemy_leader.max_hp) + ").");
    if (overflow > 0) {
        log_add(string(overflow) + " excess healing becomes Overflow Attack.");
        queue_enemy_attack(overflow, "Overflow");
    }
}

function begin_advance_phase() {
    step_number = 2;
    resume_action = "finish_advance";
    log_add("Step 2 — Advance/Escape.");
    // A Minion escapes only when the Minion in Area 1 pushes it out.
    if (!is_undefined(minions[0]) && !is_undefined(minions[1])) {
        var escaping = minions[0];
        log_add(minions[1].name + " pushes " + escaping.name + " out of Area 2.");
        log_add(escaping.name + " begins its Escape effect.");
        if (escaping.escape == "heal") {
            heal_leader(escaping.escape_value);
        } else if (escaping.escape == "destroy_hand") {
            if (count_occupied_hand() > 0) {
                prompt_mode = "destroy_hand";
                log_add("SB escapes. Choose a highlighted Hand card to destroy.");
            } else log_add("SB Escape finds no card in Hand to destroy.");
        }
    } else if (!is_undefined(minions[0])) {
        log_add(minions[0].name + " remains in Area 2 because Area 1 is empty.");
    }
    resume_after_prompts();
}

function resolve_minion_entry(_minion) {
    log_add(_minion.name + " enters Minion Area 1.");
    resume_action = "finish_enemy";
    if (_minion.ability_id == ABILITY_DISRUPT && build_has_cards()) {
        prompt_mode = "disrupt";
        prompt_value = _minion.atk;
        log_add("AA uses Disrupt. Choose a highlighted Build card to discard.");
        return;
    }
    if (_minion.ability_id == ABILITY_CRUSH) {
        queue_enemy_attack(_minion.atk, "AB — Crush (1 of 2)");
        queue_enemy_attack(_minion.atk, "AB — Crush (2 of 2)");
    } else if (_minion.ability_id == ABILITY_SHATTER) {
        var tied = lowest_build_indices();
        if (array_length(tied) == 1) destroy_build_card(tied[0], "SB Shatter");
        else if (array_length(tied) > 1) {
            prompt_mode = "shatter";
            prompt_value = _minion.atk;
            log_add("SB uses Shatter. Choose a highlighted card tied for lowest Health.");
            return;
        }
        queue_enemy_attack(_minion.atk, "SB — Attack");
    } else if (_minion.ability_id == ABILITY_DEVASTATE) {
        queue_enemy_attack(_minion.atk, "SC — Devastate (1 of 2)");
        queue_enemy_attack(_minion.atk, "SC — Devastate (2 of 2)");
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
        queue_enemy_attack(enemy_leader.attack, "Direct Assault");
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

function leader_is_protected() {
    for (var minion_i = 0; minion_i < 2; minion_i++) {
        if (!is_undefined(minions[minion_i]) && minions[minion_i].ability_id == ABILITY_PROTECTOR) return true;
    }
    return false;
}
