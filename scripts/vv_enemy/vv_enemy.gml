/// Enemy targeting, attacks, Minion effects, Enemy Draw, and prompt resolution.

function build_snapshot_has_priority(_build_snapshot) {
    for (var priority_i = 0; priority_i < array_length(_build_snapshot); priority_i++) {
        if (!is_undefined(_build_snapshot[priority_i])
        && (card_has_ability(_build_snapshot[priority_i], ABILITY_GUARD)
        || card_has_ability(_build_snapshot[priority_i], ABILITY_FORTRESS))) return true;
    }
    return false;
}

function build_has_priority() {
    return build_snapshot_has_priority(build);
}

function enemy_target_is_legal_in_build(_build_snapshot, _index, _amount) {
    if (_index < 0 || _index >= array_length(_build_snapshot)
    || is_undefined(_build_snapshot[_index])) return false;
    if (build_snapshot_has_priority(_build_snapshot)
    && !card_has_ability(_build_snapshot[_index], ABILITY_GUARD)
    && !card_has_ability(_build_snapshot[_index], ABILITY_FORTRESS)) return false;
    return _amount >= _build_snapshot[_index].hp;
}

function enemy_target_is_legal(_index, _amount) {
    return enemy_target_is_legal_in_build(build, _index, _amount);
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
        enemy_ai_baseline_begin_attack(copy_build_snapshot(build), next_attack.amount);
        enemy_attack_prompt_id++;
        prompt_mode = "enemy_attack";
        prompt_value = next_attack.amount;
        prompt_source = next_attack.source;
        log_add(next_attack.source + " attacks for " + string(next_attack.amount) + ". Choose a highlighted target.");
        return true;
    }
    return false;
}

function command_end_enemy_attack_if_blocked() {
    if (prompt_mode != "enemy_attack" || enemy_has_legal_target(prompt_value)) return false;
    if (!build_has_cards()) {
        enemy_attack_notice = "The Build Area is clear.\nThe unused Attack ends.";
    } else if (build_has_priority()) {
        enemy_attack_notice = "Guard/Fortress blocks the rest.\nThe unused Attack ends.";
    } else {
        enemy_attack_notice = "No other card can be defeated.\nThe unused Attack ends.";
    }
    log_add(string(prompt_value) + " Attack remains, but no legal card can be defeated. The Attack ends.");
    prompt_mode = "";
    prompt_value = 0;
    prompt_source = "";
    enemy_ai_baseline_end_attack();
    resume_after_prompts();
    validate_state("Enemy Attack ends without a target");
    return true;
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

function resolve_escape_effect(_effect, _minion) {
    switch (_effect.id) {
        case EFFECT_HEAL_LEADER:
            heal_leader(_effect.params.amount);
            return false;
        case EFFECT_DESTROY_HAND_CARD:
            escape_cards_remaining = max(0, floor(variable_struct_exists(_effect.params, "count")
                ? _effect.params.count : 1));
            escape_prompt_source = _minion.name + " — Escape";
            return continue_escape_hand_destruction();
    }
    show_debug_message("UNKNOWN ESCAPE EFFECT: " + string(_effect.id));
    return false;
}

function continue_escape_hand_destruction() {
    if (escape_cards_remaining <= 0) return false;
    if (count_occupied_hand() <= 0) {
        log_add(escape_prompt_source + " cannot destroy the remaining "
            + string(escape_cards_remaining) + " Hand card(s) because the Hand is empty.");
        escape_cards_remaining = 0;
        return false;
    }
    prompt_mode = "destroy_hand";
    prompt_source = escape_prompt_source;
    log_add(prompt_source + ": choose a highlighted Hand card to destroy ("
        + string(escape_cards_remaining) + " remaining).");
    return true;
}

function continue_minion_escape() {
    if (is_undefined(escape_minion)) return false;
    while (escape_effect_index < array_length(escape_minion.escape_effects)) {
        var effect = escape_minion.escape_effects[escape_effect_index];
        escape_effect_index++;
        if (resolve_escape_effect(effect, escape_minion)) return true;
    }
    escape_minion = undefined;
    escape_effect_index = 0;
    escape_cards_remaining = 0;
    escape_prompt_source = "";
    resume_after_prompts();
    return true;
}

function resolve_minion_escape(_minion) {
    escape_minion = _minion;
    escape_effect_index = 0;
    escape_cards_remaining = 0;
    escape_prompt_source = "";
    continue_minion_escape();
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
        resolve_minion_escape(escaping);
    } else if (!is_undefined(minions[0])) {
        log_add(minions[0].name + " remains in Area 2 because Area 1 is empty.");
    }
    resume_after_prompts();
}

function continue_minion_entry() {
    if (is_undefined(entry_minion)) return false;
    while (entry_ability_index < array_length(entry_minion.abilities)) {
        var ability = entry_minion.abilities[entry_ability_index];
        entry_ability_index++;
        var ability_source = entry_minion.name + " — " + ability.name;
        switch (ability.id) {
            case ABILITY_DISRUPT:
                if (build_has_cards()) {
                    prompt_mode = "disrupt";
                    prompt_value = 0;
                    prompt_source = ability_source;
                    log_add(entry_minion.name + " uses " + ability.name + ". Choose a highlighted Build card to discard.");
                    return true;
                }
                log_add(entry_minion.name + " uses " + ability.name + ", but the Build Area is empty.");
                break;
            case ABILITY_CRUSH:
            case ABILITY_DEVASTATE:
                entry_has_attack_pattern = true;
                queue_enemy_attack(entry_minion.atk, ability_source + " (1 of 2)");
                queue_enemy_attack(entry_minion.atk, ability_source + " (2 of 2)");
                break;
            case ABILITY_SHATTER:
                var tied = lowest_build_indices();
                if (array_length(tied) == 1) destroy_build_card(tied[0], ability_source);
                else if (array_length(tied) > 1) {
                    prompt_mode = "shatter";
                    prompt_value = 0;
                    prompt_source = ability_source;
                    log_add(entry_minion.name + " uses " + ability.name + ". Choose a highlighted card tied for lowest Health.");
                    return true;
                } else log_add(entry_minion.name + " uses " + ability.name + ", but the Build Area is empty.");
                break;
            case ABILITY_PROTECTOR:
                log_add(entry_minion.name + " is protecting the Enemy Leader.");
                break;
            default:
                show_debug_message("UNKNOWN MINION ENTRY ABILITY: " + string(ability.id));
                break;
        }
    }
    if (!entry_has_attack_pattern) queue_enemy_attack(entry_minion.atk, entry_minion.name + " — Attack");
    entry_minion = undefined;
    entry_ability_index = 0;
    entry_has_attack_pattern = false;
    resume_after_prompts();
    return true;
}

function resolve_minion_entry(_minion) {
    log_add(_minion.name + " enters Minion Area 1.");
    resume_action = "finish_enemy";
    entry_minion = _minion;
    entry_ability_index = 0;
    entry_has_attack_pattern = false;
    continue_minion_entry();
}

function resolve_leader_strike(_card) {
    var draw_source = "Enemy Draw #" + string(revealed_enemy_draw_number) + " — " + _card.name;
    log_add(draw_source + ".");
    var resolved = true;
    for (var effect_i = 0; effect_i < array_length(_card.effects); effect_i++) {
        var effect = _card.effects[effect_i];
        switch (effect.id) {
            case EFFECT_LEADER_BASIC_ATTACK:
                queue_enemy_attack(enemy_leader.attack, draw_source);
                break;
            default:
                resolved = false;
                show_debug_message("UNKNOWN LEADER STRIKE EFFECT: " + string(effect.id));
                break;
        }
    }
    if (!resolved) log_add(_card.name + " has an unknown Leader Strike effect that does nothing.");
    return resolved;
}

function resolve_twist(_card) {
    var draw_source = "Enemy Draw #" + string(revealed_enemy_draw_number) + " — " + _card.name;
    log_add(draw_source + ".");
    var resolved = true;
    for (var effect_i = 0; effect_i < array_length(_card.effects); effect_i++) {
        var effect = _card.effects[effect_i];
        switch (effect.id) {
            case EFFECT_AREA_2_ATTACK:
                if (!is_undefined(minions[0])) {
                    queue_enemy_attack(minions[0].atk, draw_source + ": " + minions[0].name);
                } else {
                    log_add("Area 2 is empty; " + _card.name + " has no effect.");
                }
                break;
            default:
                resolved = false;
                show_debug_message("UNKNOWN TWIST EFFECT: " + string(effect.id));
                break;
        }
    }
    if (!resolved) log_add(_card.name + " has an unknown Twist effect that does nothing.");
    return resolved;
}

function draw_next_enemy_card() {
    step_number = 3;
    phase = "start_resolving";
    revealed_enemy_card = undefined;
    revealed_enemy_draw_number = 0;
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
    enemy_draw_number++;
    var enemy_card = array_pop(enemy_deck);
    if (array_length(enemy_deck) == 0) enemy_exhausted = true;
    if (enemy_card.card_type == "strike") {
        revealed_enemy_card = enemy_card;
        revealed_enemy_draw_number = enemy_draw_number;
        array_push(enemy_used, enemy_card);
        resolve_leader_strike(enemy_card);
        resume_action = "continue_enemy_draw";
        resume_after_prompts();
    } else if (enemy_card.card_type == "twist") {
        revealed_enemy_card = enemy_card;
        revealed_enemy_draw_number = enemy_draw_number;
        array_push(enemy_used, enemy_card);
        resolve_twist(enemy_card);
        resume_action = "continue_enemy_draw";
        resume_after_prompts();
    } else {
        log_add("Enemy Draw #" + string(enemy_draw_number) + " — " + enemy_card.name + ".");
        minions[1] = enemy_card;
        resolve_minion_entry(enemy_card);
    }
}

function command_prompt_hand(_index) {
    if (prompt_mode != "destroy_hand" || _index < 0 || _index >= array_length(hand)
    || is_undefined(hand[_index])) return false;
    var source = prompt_source;
    destroy_hand_card(_index, source);
    escape_cards_remaining = max(0, escape_cards_remaining - 1);
    prompt_mode = "";
    prompt_source = "";
    if (!continue_escape_hand_destruction()) continue_minion_escape();
    validate_state("Escape destroys Hand card");
    return true;
}

function command_prompt_build(_index) {
    if (!prompt_build_is_legal(_index)) {
        log_add("That card cannot be targeted. Choose a highlighted card.");
        return false;
    }
    if (prompt_mode == "enemy_attack") {
        enemy_ai_baseline_record_destroyed_card(copy_build_snapshot(build), _index);
        prompt_value -= build[_index].hp;
        destroy_build_card(_index, "enemy Attack");
        if (prompt_value > 0 && enemy_has_legal_target(prompt_value)) {
            log_add(string(prompt_value) + " Attack remains. Choose another highlighted target.");
            return true;
        }
        if (prompt_value > 0) return command_end_enemy_attack_if_blocked();
        prompt_mode = "";
        prompt_value = 0;
        prompt_source = "";
        enemy_ai_baseline_end_attack();
        resume_after_prompts();
        validate_state("Enemy Attack");
        return true;
    }
    if (prompt_mode == "disrupt") {
        var disrupt_source = prompt_source;
        discard_build_card(_index, disrupt_source);
        prompt_mode = "";
        prompt_value = 0;
        prompt_source = "";
        continue_minion_entry();
        validate_state("Disrupt resolves");
        return true;
    }
    if (prompt_mode == "shatter") {
        var shatter_source = prompt_source;
        destroy_build_card(_index, shatter_source);
        prompt_mode = "";
        prompt_value = 0;
        prompt_source = "";
        continue_minion_entry();
        validate_state("Shatter resolves");
        return true;
    }
    return false;
}

function find_leader_protector() {
    for (var minion_i = 0; minion_i < 2; minion_i++) {
        if (!is_undefined(minions[minion_i]) && card_has_ability(minions[minion_i], ABILITY_PROTECTOR)) return minions[minion_i];
    }
    return undefined;
}

function leader_is_protected() {
    return !is_undefined(find_leader_protector());
}
