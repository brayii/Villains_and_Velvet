/// Deterministic Enemy AI scoring. This module ranks Build slots but does not resolve attacks.

#macro ENEMY_AI_HEALTH_WEIGHT 1.0
#macro ENEMY_AI_HEALTH_LEARNING_RATE 0.02
#macro ENEMY_AI_REWARD_EMA_BETA 0.05
#macro ENEMY_AI_EXPLORATION_RATE 0.05
#macro ENEMY_AI_EXPLORATION_MARGIN 1.0
#macro ENEMY_AI_PRODUCTION_HEALTH_LEARNING true
// Exploration stays gated until seeded evaluation demonstrates a production benefit.
#macro ENEMY_AI_PRODUCTION_EXPLORATION false
#macro VV_DEVELOPMENT_SELF_CHECKS false
#macro ENEMY_AI_TARGET_DELAY_FRAMES 45
#macro ENEMY_AI_RESULT_DELAY_FRAMES 30

function enemy_ai_baseline_init() {
    gameplay_seed = -1;
    gameplay_rng = vv_rng_create(irandom(2147483645));
    ai_exploration_seed = 104729;
    ai_exploration_rng = vv_rng_create(ai_exploration_seed);
    enemy_ai_exploration_opportunities = 0;
    enemy_ai_exploration_triggers = 0;
    enemy_ai_baseline_totals = {
        matches: 0,
        enemy_wins: 0,
        leader_survivals: 0,
        leader_hp_remaining: 0,
        leader_damage: 0,
        turns: 0,
        enemy_attacks: 0,
        guaranteed_attack_removed: 0,
        conditional_attack_removed: 0,
        cards_destroyed: 0,
        greedy_regret: 0,
        oracle_checks: 0,
        comparison_states: 0,
        comparison_differences: 0,
        fixed_conditional_regret: 0,
        learned_conditional_regret: 0,
        evaluation_states: 0,
        policy_a_regret: 0,
        policy_b_regret: 0,
        policy_c_regret: 0,
        policy_d_regret: 0,
        policy_a_threat_removed: 0,
        policy_b_threat_removed: 0,
        policy_c_threat_removed: 0,
        policy_d_threat_removed: 0,
        policy_a_regret_squared: 0,
        policy_b_regret_squared: 0,
        policy_c_regret_squared: 0,
        policy_d_regret_squared: 0,
        policy_a_best_matches: 0,
        policy_b_best_matches: 0,
        policy_c_best_matches: 0,
        policy_d_best_matches: 0,
        wc_min: enemy_ai_conditional_weight(),
        wc_max: enemy_ai_conditional_weight(),
        wh_min: enemy_ai_learned_health_weight(),
        wh_max: enemy_ai_learned_health_weight()
    };
    enemy_ai_baseline_match_active = false;
    enemy_ai_baseline_attack_active = false;
}

function enemy_ai_calculate_turn_reward(
_hp_before, _hp_end, _enemy_cards_remaining, _enemy_deck_initial_size, _terminal_result) {
    var initial_size = max(1, _enemy_deck_initial_size);
    var leader_damage = max(0, _hp_before - _hp_end);
    var damage_fraction = leader_damage / max(1, _hp_before);
    var deck_ratio = clamp(_enemy_cards_remaining / initial_size, 0, 1);
    var reward = -damage_fraction * (1 + deck_ratio);
    if (_terminal_result > 0) reward = 2;
    else if (_terminal_result < 0) reward = -2;
    return {
        leader_damage: leader_damage,
        damage_fraction: damage_fraction,
        deck_ratio: deck_ratio,
        reward: reward
    };
}

function enemy_ai_reward_init_match(_enemy_deck_initial_size) {
    enemy_ai_reward_initial_deck_size = max(1, floor(_enemy_deck_initial_size));
    enemy_ai_reward_cancel_turn();
    enemy_ai_last_turn_reward = 0;
    enemy_ai_last_advantage = 0;
}

function enemy_ai_reward_begin_player_response() {
    enemy_ai_reward_turn_active = enemy_ai_turn_attack_observation_count > 0
        && enemy_ai_policy_turn_number == turn_number;
    enemy_ai_reward_hp_before = leader_hp;
    enemy_ai_reward_turn_number = turn_number;
}

function enemy_ai_reward_cancel_turn() {
    enemy_ai_reward_turn_active = false;
    enemy_ai_reward_hp_before = 0;
    enemy_ai_reward_turn_number = -1;
}

function enemy_ai_policy_begin_turn() {
    enemy_ai_policy_decisions = [];
    enemy_ai_policy_turn_number = turn_number;
    enemy_ai_turn_attack_observation_count = 0;
}

function enemy_ai_policy_cancel_turn() {
    enemy_ai_policy_decisions = [];
    enemy_ai_policy_turn_number = -1;
    enemy_ai_turn_attack_observation_count = 0;
    enemy_ai_pending_decision_record = undefined;
}

function enemy_ai_health_weight() {
    return ENEMY_AI_PRODUCTION_HEALTH_LEARNING
        ? enemy_ai_learned_health_weight() : ENEMY_AI_HEALTH_WEIGHT;
}

function enemy_ai_learned_health_weight() {
    return clamp(ai_health_weight, 0.25, 3.0);
}

function enemy_ai_policy_choice_is_eligible(
_auto_enabled, _decision_turn, _current_turn, _candidate_count) {
    return _auto_enabled && _decision_turn == _current_turn && _candidate_count >= 2;
}

function enemy_ai_attack_observation_flags(_zone, _candidate_count) {
    var candidate_count = max(0, floor(_candidate_count));
    return {
        blocked: candidate_count == 0,
        forced: candidate_count == 1,
        hand: _zone == "hand"
    };
}

function enemy_ai_record_attack_observation(_zone, _candidate_count) {
    if (!enemy_auto_play || enemy_ai_policy_turn_number != turn_number) return false;
    var flags = enemy_ai_attack_observation_flags(_zone, _candidate_count);
    enemy_ai_turn_attack_observation_count++;
    ai_attack_observation_count++;
    if (flags.blocked) ai_blocked_attack_count++;
    if (flags.forced) ai_forced_attack_count++;
    if (flags.hand) ai_hand_attack_count++;
    vv_ai_data_mark_dirty();
    return true;
}

function enemy_ai_normalized_cost_delta(_candidate_costs, _chosen_index) {
    var candidate_count = array_length(_candidate_costs);
    if (candidate_count < 2 || _chosen_index < 0 || _chosen_index >= candidate_count) return 0;
    var cost_total = 0;
    var cost_min = _candidate_costs[0];
    var cost_max = _candidate_costs[0];
    for (var cost_i = 0; cost_i < candidate_count; cost_i++) {
        cost_total += _candidate_costs[cost_i];
        cost_min = min(cost_min, _candidate_costs[cost_i]);
        cost_max = max(cost_max, _candidate_costs[cost_i]);
    }
    var cost_range = cost_max - cost_min;
    if (cost_range <= 0) return 0;
    var chosen_cost = _candidate_costs[_chosen_index];
    var alternative_mean = (cost_total - chosen_cost) / (candidate_count - 1);
    return (chosen_cost - alternative_mean) / cost_range;
}

function enemy_ai_make_decision_record(_current_state, _selected_slot) {
    if (!ENEMY_AI_PRODUCTION_HEALTH_LEARNING) return undefined;
    var ranked = enemy_ai_rank_build_with_weights(_current_state.build_snapshot,
        enemy_ai_conditional_weight(), enemy_ai_health_weight());
    var candidates = [];
    var candidate_costs = [];
    var cost_total = 0;
    var chosen_cost = 0;
    var chosen_found = false;
    var chosen_candidate_index = -1;
    for (var rank_i = 0; rank_i < array_length(ranked); rank_i++) {
        var candidate = ranked[rank_i];
        if (!enemy_target_is_legal_in_build(_current_state.build_snapshot,
        candidate.slot, _current_state.attack_remaining)) continue;
        array_push(candidates, candidate);
        array_push(candidate_costs, candidate.destruction_cost);
        cost_total += candidate.destruction_cost;
        if (candidate.slot == _selected_slot) {
            chosen_cost = candidate.destruction_cost;
            chosen_found = true;
            chosen_candidate_index = array_length(candidates) - 1;
        }
    }
    var candidate_count = array_length(candidates);
    if (!chosen_found || !enemy_ai_policy_choice_is_eligible(enemy_auto_play,
    enemy_ai_policy_turn_number, turn_number, candidate_count)) return undefined;
    var alternative_mean = (cost_total - chosen_cost) / (candidate_count - 1);
    return {
        turn_id: turn_number,
        decision_index: array_length(enemy_ai_policy_decisions) + 1,
        remaining_enemy_attack: _current_state.attack_remaining,
        candidate_count: candidate_count,
        candidates: candidates,
        chosen_target: _selected_slot,
        chosen_target_cost: chosen_cost,
        alternative_cost_mean: alternative_mean,
        normalized_cost_delta: enemy_ai_normalized_cost_delta(
            candidate_costs, chosen_candidate_index)
    };
}

function enemy_ai_apply_health_learning(_weight, _advantage, _decisions) {
    var next_weight = clamp(_weight, 0.25, 3.0);
    var decision_count = array_length(_decisions);
    if (decision_count <= 0) return next_weight;
    for (var decision_i = 0; decision_i < decision_count; decision_i++) {
        next_weight -= ENEMY_AI_HEALTH_LEARNING_RATE * _advantage
            * _decisions[decision_i].normalized_cost_delta / decision_count;
        next_weight = clamp(next_weight, 0.25, 3.0);
    }
    return next_weight;
}

function enemy_ai_reward_measurement_is_eligible(
_turn_active, _has_ai_attacks, _snapshot_turn, _current_turn) {
    return _turn_active && _has_ai_attacks && _snapshot_turn == _current_turn;
}

function enemy_ai_reward_ema_transition(_old_ema, _reward) {
    return {
        old_ema: _old_ema,
        advantage: _reward - _old_ema,
        new_ema: (1 - ENEMY_AI_REWARD_EMA_BETA) * _old_ema
            + ENEMY_AI_REWARD_EMA_BETA * _reward
    };
}

function enemy_ai_policy_reward_should_update(_meaningful_choice_count) {
    return _meaningful_choice_count > 0;
}

/// _terminal_result: +1 Enemy win, -1 Enemy loss, 0 non-terminal.
function enemy_ai_reward_finish_player_response(_terminal_result) {
    if (!enemy_ai_reward_measurement_is_eligible(enemy_ai_reward_turn_active,
    enemy_ai_turn_attack_observation_count > 0,
    enemy_ai_reward_turn_number, turn_number)) {
        enemy_ai_policy_cancel_turn();
        enemy_ai_reward_cancel_turn();
        return false;
    }
    var result = enemy_ai_calculate_turn_reward(
        enemy_ai_reward_hp_before, leader_hp, array_length(enemy_deck),
        enemy_ai_reward_initial_deck_size, _terminal_result);
    var overall_ema_update = enemy_ai_reward_ema_transition(ai_reward_ema, result.reward);
    enemy_ai_last_turn_reward = result.reward;
    var meaningful_choice_count = array_length(enemy_ai_policy_decisions);
    var policy_ema_update = enemy_ai_reward_ema_transition(
        ai_policy_choice_reward_ema, result.reward);
    var update_policy_reward = enemy_ai_policy_reward_should_update(meaningful_choice_count);
    enemy_ai_last_advantage = update_policy_reward
        ? policy_ema_update.advantage : 0;
    var old_health_weight = enemy_ai_learned_health_weight();
    if (update_policy_reward) {
        if (ENEMY_AI_PRODUCTION_HEALTH_LEARNING) {
            ai_health_weight = enemy_ai_apply_health_learning(
                old_health_weight, policy_ema_update.advantage, enemy_ai_policy_decisions);
        }
        ai_policy_choice_reward_ema = policy_ema_update.new_ema;
        ai_policy_choice_turn_count++;
    }
    ai_meaningful_choice_count += meaningful_choice_count;
    ai_reward_ema = overall_ema_update.new_ema;
    ai_auto_turn_count++;
    if (_terminal_result > 0) ai_games_won_auto++;
    else if (_terminal_result < 0) ai_games_lost_auto++;
    vv_ai_data_mark_dirty();
    if (_terminal_result != 0) vv_ai_data_save_if_dirty();
    show_debug_message("ENEMY AI REWARD | turn=" + string(turn_number)
        + " | hp_before=" + string(enemy_ai_reward_hp_before)
        + " | hp_end=" + string(leader_hp)
        + " | leader_damage=" + string(result.leader_damage)
        + " | damage_fraction=" + string(result.damage_fraction)
        + " | enemy_cards=" + string(array_length(enemy_deck))
        + "/" + string(enemy_ai_reward_initial_deck_size)
        + " | deck_ratio=" + string(result.deck_ratio)
        + " | terminal=" + string(_terminal_result)
        + " | reward=" + string(result.reward)
        + " | overall_ema_old=" + string(overall_ema_update.old_ema)
        + " | policy_ema_old=" + string(policy_ema_update.old_ema)
        + " | policy_advantage=" + string(enemy_ai_last_advantage)
        + " | meaningful_choices=" + string(meaningful_choice_count)
        + " | W_H_old=" + string(old_health_weight)
        + " | W_H_new=" + string(ai_health_weight)
        + " | overall_ema_new=" + string(ai_reward_ema)
        + " | policy_ema_new=" + string(ai_policy_choice_reward_ema)
        + " | auto_turns=" + string(ai_auto_turn_count));
    enemy_ai_policy_cancel_turn();
    enemy_ai_reward_cancel_turn();
    return true;
}

function enemy_ai_conditional_weight_from_counts(_exposures, _activations) {
    if (!vv_ai_data_is_counter(_exposures) || !vv_ai_data_is_counter(_activations)
    || _activations > _exposures) return 0.5;
    return clamp((_activations + 1) / (_exposures + 2), 0, 1);
}

function enemy_ai_conditional_weight() {
    return enemy_ai_conditional_weight_from_counts(
        ai_conditional_exposures, ai_conditional_activations);
}

function enemy_ai_count_exposed_conditional_abilities(_build_snapshot, _attack_amount, _minion_snapshot) {
    var can_trigger = false;
    for (var minion_i = 0; minion_i < array_length(_minion_snapshot); minion_i++) {
        if (!is_undefined(_minion_snapshot[minion_i])
        && _attack_amount >= _minion_snapshot[minion_i].hp) {
            can_trigger = true;
            break;
        }
    }
    if (!can_trigger) return 0;

    var exposed = 0;
    for (var card_i = 0; card_i < array_length(_build_snapshot); card_i++) {
        if (is_undefined(_build_snapshot[card_i])) continue;
        var card = _build_snapshot[card_i];
        if (!variable_struct_exists(card, "abilities")) continue;
        for (var ability_i = 0; ability_i < array_length(card.abilities); ability_i++) {
            if (ability_param_value(card.abilities[ability_i], "conditional_trigger", "")
            == CONDITIONAL_TRIGGER_MINION_DEFEATED) exposed++;
        }
    }
    return exposed;
}

function enemy_ai_conditional_learning_begin_attack(_build_snapshot, _attack_amount, _minion_snapshot) {
    conditional_learning_exposed_count = enemy_ai_count_exposed_conditional_abilities(
        _build_snapshot, _attack_amount, _minion_snapshot);
    conditional_learning_activated = false;
    conditional_learning_attack_active = true;
}

function enemy_ai_conditional_learning_note_minion_defeated() {
    if (conditional_learning_attack_active && conditional_learning_exposed_count > 0) {
        conditional_learning_activated = true;
    }
}

function enemy_ai_conditional_learning_apply_observation(
_exposures, _activations, _exposed_count, _activated) {
    var next_exposures = _exposures + max(0, floor(_exposed_count));
    var next_activations = _activations;
    if (_activated && _exposed_count > 0) {
        next_activations += max(0, floor(_exposed_count));
    }
    return {
        exposures: next_exposures,
        activations: min(next_activations, next_exposures)
    };
}

function enemy_ai_conditional_learning_finish_attack() {
    if (!conditional_learning_attack_active) return false;
    conditional_learning_attack_active = false;
    if (conditional_learning_exposed_count <= 0) return false;
    var learned = enemy_ai_conditional_learning_apply_observation(
        ai_conditional_exposures, ai_conditional_activations,
        conditional_learning_exposed_count, conditional_learning_activated);
    ai_conditional_exposures = learned.exposures;
    ai_conditional_activations = learned.activations;
    conditional_learning_exposed_count = 0;
    conditional_learning_activated = false;
    vv_ai_data_mark_dirty();
    return true;
}

function enemy_ai_conditional_learning_reset_attack() {
    conditional_learning_attack_active = false;
    conditional_learning_exposed_count = 0;
    conditional_learning_activated = false;
}

function enemy_ai_baseline_begin_match() {
    enemy_ai_baseline_match_active = gameplay_seed >= 0;
    enemy_ai_baseline_attack_active = false;
    enemy_ai_baseline_match = {
        seeded: gameplay_seed >= 0,
        started_in_auto: enemy_auto_play,
        mode_changed: false,
        leader_damage: 0,
        enemy_attacks: 0,
        guaranteed_attack_removed: 0,
        conditional_attack_removed: 0,
        cards_destroyed: 0,
        greedy_regret: 0,
        oracle_checks: 0,
        comparison_states: 0,
        comparison_differences: 0,
        fixed_conditional_regret: 0,
        learned_conditional_regret: 0,
        evaluation_states: 0,
        policy_a_regret: 0,
        policy_b_regret: 0,
        policy_c_regret: 0,
        policy_d_regret: 0,
        policy_a_threat_removed: 0,
        policy_b_threat_removed: 0,
        policy_c_threat_removed: 0,
        policy_d_threat_removed: 0,
        policy_a_best_matches: 0,
        policy_b_best_matches: 0,
        policy_c_best_matches: 0,
        policy_d_best_matches: 0,
        wc_start: enemy_ai_conditional_weight(),
        wh_start: enemy_ai_learned_health_weight(),
        exploration_seed: ai_exploration_seed,
        leader_id: enemy_leader.id,
        scenario_id: enemy_scenario.id,
        minion_set_id: enemy_minion_set.id,
        leader_strikes: array_length(enemy_event_selection.leader_strikes),
        twists: array_length(enemy_event_selection.twists)
    };
}

function enemy_ai_baseline_note_mode_change() {
    if (enemy_ai_baseline_match_active) enemy_ai_baseline_match.mode_changed = true;
    enemy_ai_reward_cancel_turn();
    enemy_ai_policy_cancel_turn();
    if (!enemy_auto_play) enemy_ai_baseline_end_attack();
}

function enemy_ai_baseline_begin_attack(_build_snapshot, _attack_amount) {
    enemy_ai_baseline_attack_active = false;
    if (!enemy_ai_baseline_match_active || !enemy_auto_play) return;
    var comparison = enemy_ai_oracle_compare(_build_snapshot, _attack_amount);
    var conditional_comparison = enemy_ai_compare_conditional_policies(
        _build_snapshot, _attack_amount);
    var evaluation = enemy_ai_evaluate_policy_variants(
        _build_snapshot, _attack_amount, vv_rng_clone(ai_exploration_rng));
    enemy_ai_baseline_attack_active = true;
    enemy_ai_baseline_match.enemy_attacks++;
    enemy_ai_baseline_match.greedy_regret += comparison.greedy_regret;
    enemy_ai_baseline_match.oracle_checks++;
    enemy_ai_baseline_match.comparison_states++;
    if (conditional_comparison.sequences_differ) {
        enemy_ai_baseline_match.comparison_differences++;
    }
    enemy_ai_baseline_match.fixed_conditional_regret += conditional_comparison.fixed_regret;
    enemy_ai_baseline_match.learned_conditional_regret += conditional_comparison.learned_regret;
    enemy_ai_baseline_match.evaluation_states++;
    enemy_ai_baseline_match.policy_a_regret += evaluation.A.regret;
    enemy_ai_baseline_match.policy_b_regret += evaluation.B.regret;
    enemy_ai_baseline_match.policy_c_regret += evaluation.C.regret;
    enemy_ai_baseline_match.policy_d_regret += evaluation.D.regret;
    enemy_ai_baseline_match.policy_a_threat_removed += evaluation.A.threat_removed;
    enemy_ai_baseline_match.policy_b_threat_removed += evaluation.B.threat_removed;
    enemy_ai_baseline_match.policy_c_threat_removed += evaluation.C.threat_removed;
    enemy_ai_baseline_match.policy_d_threat_removed += evaluation.D.threat_removed;
    enemy_ai_baseline_totals.wc_min = min(enemy_ai_baseline_totals.wc_min, evaluation.W_C);
    enemy_ai_baseline_totals.wc_max = max(enemy_ai_baseline_totals.wc_max, evaluation.W_C);
    enemy_ai_baseline_totals.wh_min = min(enemy_ai_baseline_totals.wh_min, evaluation.W_H);
    enemy_ai_baseline_totals.wh_max = max(enemy_ai_baseline_totals.wh_max, evaluation.W_H);
    if (enemy_ai_scores_are_close(evaluation.A.regret, 0)) enemy_ai_baseline_match.policy_a_best_matches++;
    if (enemy_ai_scores_are_close(evaluation.B.regret, 0)) enemy_ai_baseline_match.policy_b_best_matches++;
    if (enemy_ai_scores_are_close(evaluation.C.regret, 0)) enemy_ai_baseline_match.policy_c_best_matches++;
    if (enemy_ai_scores_are_close(evaluation.D.regret, 0)) enemy_ai_baseline_match.policy_d_best_matches++;
}

function enemy_ai_baseline_record_destroyed_card(_build_snapshot, _slot) {
    if (!enemy_ai_baseline_attack_active || _slot < 0
    || _slot >= array_length(_build_snapshot) || is_undefined(_build_snapshot[_slot])) return;
    var before = evaluate_build(_build_snapshot);
    var after = evaluate_build(copy_build_without_slot(_build_snapshot, _slot));
    enemy_ai_baseline_match.guaranteed_attack_removed +=
        before.guaranteed_attack - after.guaranteed_attack;
    enemy_ai_baseline_match.conditional_attack_removed +=
        before.conditional_attack - after.conditional_attack;
    enemy_ai_baseline_match.cards_destroyed++;
}

function enemy_ai_baseline_end_attack() {
    enemy_ai_baseline_attack_active = false;
}

function enemy_ai_baseline_record_leader_damage(_amount) {
    if (enemy_ai_baseline_match_active && _amount > 0) {
        enemy_ai_baseline_match.leader_damage += _amount;
    }
}

function enemy_ai_baseline_finish_match(_enemy_won) {
    if (!enemy_ai_baseline_match_active) return;
    enemy_ai_baseline_end_attack();
    enemy_ai_baseline_match_active = false;
    if (!enemy_ai_baseline_match.started_in_auto || enemy_ai_baseline_match.mode_changed) {
        show_debug_message("ENEMY AI BASELINE | mixed/manual match excluded");
        return;
    }
    var totals = enemy_ai_baseline_totals;
    totals.matches++;
    if (_enemy_won) totals.enemy_wins++;
    if (leader_hp > 0) totals.leader_survivals++;
    totals.leader_hp_remaining += leader_hp;
    totals.leader_damage += enemy_ai_baseline_match.leader_damage;
    totals.turns += turn_number;
    totals.enemy_attacks += enemy_ai_baseline_match.enemy_attacks;
    totals.guaranteed_attack_removed += enemy_ai_baseline_match.guaranteed_attack_removed;
    totals.conditional_attack_removed += enemy_ai_baseline_match.conditional_attack_removed;
    totals.cards_destroyed += enemy_ai_baseline_match.cards_destroyed;
    totals.greedy_regret += enemy_ai_baseline_match.greedy_regret;
    totals.oracle_checks += enemy_ai_baseline_match.oracle_checks;
    totals.comparison_states += enemy_ai_baseline_match.comparison_states;
    totals.comparison_differences += enemy_ai_baseline_match.comparison_differences;
    totals.fixed_conditional_regret += enemy_ai_baseline_match.fixed_conditional_regret;
    totals.learned_conditional_regret += enemy_ai_baseline_match.learned_conditional_regret;
    totals.evaluation_states += enemy_ai_baseline_match.evaluation_states;
    totals.policy_a_regret += enemy_ai_baseline_match.policy_a_regret;
    totals.policy_b_regret += enemy_ai_baseline_match.policy_b_regret;
    totals.policy_c_regret += enemy_ai_baseline_match.policy_c_regret;
    totals.policy_d_regret += enemy_ai_baseline_match.policy_d_regret;
    totals.policy_a_threat_removed += enemy_ai_baseline_match.policy_a_threat_removed;
    totals.policy_b_threat_removed += enemy_ai_baseline_match.policy_b_threat_removed;
    totals.policy_c_threat_removed += enemy_ai_baseline_match.policy_c_threat_removed;
    totals.policy_d_threat_removed += enemy_ai_baseline_match.policy_d_threat_removed;
    totals.policy_a_regret_squared += enemy_ai_baseline_match.policy_a_regret
        * enemy_ai_baseline_match.policy_a_regret;
    totals.policy_b_regret_squared += enemy_ai_baseline_match.policy_b_regret
        * enemy_ai_baseline_match.policy_b_regret;
    totals.policy_c_regret_squared += enemy_ai_baseline_match.policy_c_regret
        * enemy_ai_baseline_match.policy_c_regret;
    totals.policy_d_regret_squared += enemy_ai_baseline_match.policy_d_regret
        * enemy_ai_baseline_match.policy_d_regret;
    totals.policy_a_best_matches += enemy_ai_baseline_match.policy_a_best_matches;
    totals.policy_b_best_matches += enemy_ai_baseline_match.policy_b_best_matches;
    totals.policy_c_best_matches += enemy_ai_baseline_match.policy_c_best_matches;
    totals.policy_d_best_matches += enemy_ai_baseline_match.policy_d_best_matches;

    var win_rate = totals.matches > 0 ? totals.enemy_wins / totals.matches : 0;
    var survival_rate = totals.matches > 0 ? totals.leader_survivals / totals.matches : 0;
    var average_leader_hp = totals.matches > 0 ? totals.leader_hp_remaining / totals.matches : 0;
    var damage_per_turn = totals.turns > 0 ? totals.leader_damage / totals.turns : 0;
    var cards_per_attack = totals.enemy_attacks > 0
        ? totals.cards_destroyed / totals.enemy_attacks : 0;
    var average_regret = totals.oracle_checks > 0
        ? totals.greedy_regret / totals.oracle_checks : 0;
    var fixed_conditional_regret = totals.comparison_states > 0
        ? totals.fixed_conditional_regret / totals.comparison_states : 0;
    var learned_conditional_regret = totals.comparison_states > 0
        ? totals.learned_conditional_regret / totals.comparison_states : 0;
    var policy_a_variance = enemy_ai_evaluation_variance(totals.policy_a_regret,
        totals.policy_a_regret_squared, totals.matches);
    var policy_b_variance = enemy_ai_evaluation_variance(totals.policy_b_regret,
        totals.policy_b_regret_squared, totals.matches);
    var policy_c_variance = enemy_ai_evaluation_variance(totals.policy_c_regret,
        totals.policy_c_regret_squared, totals.matches);
    var policy_d_variance = enemy_ai_evaluation_variance(totals.policy_d_regret,
        totals.policy_d_regret_squared, totals.matches);
    show_debug_message("ENEMY AI BASELINE | seed=" + string(gameplay_seed)
        + " | matches=" + string(totals.matches)
        + " | enemy_win_rate=" + string(win_rate)
        + " | leader_survival_rate=" + string(survival_rate)
        + " | average_leader_hp=" + string(average_leader_hp)
        + " | leader_damage_per_turn=" + string(damage_per_turn)
        + " | guaranteed_attack_removed=" + string(totals.guaranteed_attack_removed)
        + " | conditional_attack_removed=" + string(totals.conditional_attack_removed)
        + " | cards_per_attack=" + string(cards_per_attack)
        + " | average_greedy_regret=" + string(average_regret)
        + " | learned_W_C=" + string(enemy_ai_conditional_weight())
        + " | comparison_states=" + string(totals.comparison_states)
        + " | different_sequences=" + string(totals.comparison_differences)
        + " | fixed_W_C_regret=" + string(fixed_conditional_regret)
        + " | learned_W_C_regret=" + string(learned_conditional_regret)
        + " | evaluation_states=" + string(totals.evaluation_states)
        + " | A_regret=" + string(totals.policy_a_regret)
        + " | B_regret=" + string(totals.policy_b_regret)
        + " | C_regret=" + string(totals.policy_c_regret)
        + " | D_regret=" + string(totals.policy_d_regret)
        + " | threat_removed_ABCD=" + string(totals.policy_a_threat_removed) + "/"
        + string(totals.policy_b_threat_removed) + "/"
        + string(totals.policy_c_threat_removed) + "/"
        + string(totals.policy_d_threat_removed)
        + " | best_matches_ABCD=" + string(totals.policy_a_best_matches) + "/"
        + string(totals.policy_b_best_matches) + "/"
        + string(totals.policy_c_best_matches) + "/"
        + string(totals.policy_d_best_matches)
        + " | regret_variance=" + string(policy_a_variance) + "/"
        + string(policy_b_variance) + "/" + string(policy_c_variance)
        + "/" + string(policy_d_variance)
        + " | W_C_range=" + string(totals.wc_min) + ".." + string(totals.wc_max)
        + " | W_H_range=" + string(totals.wh_min) + ".." + string(totals.wh_max)
        + " | W_C=" + string(enemy_ai_baseline_match.wc_start)
        + " | W_H=" + string(enemy_ai_baseline_match.wh_start)
        + " | exploration_seed=" + string(enemy_ai_baseline_match.exploration_seed)
        + " | content=" + enemy_ai_baseline_match.leader_id
        + "/" + enemy_ai_baseline_match.scenario_id
        + "/" + enemy_ai_baseline_match.minion_set_id
        + " | events=" + string(enemy_ai_baseline_match.leader_strikes)
        + "+" + string(enemy_ai_baseline_match.twists));
}

function enemy_ai_start_seeded_playtest(_seed) {
    if (!is_real(_seed)) return false;
    gameplay_seed = floor(_seed);
    vv_rng_set_seed(gameplay_rng, gameplay_seed);
    if (!reset_game()) return false;
    setup_active = false;
    return true;
}

function enemy_ai_stop_seeded_playtest() {
    gameplay_seed = -1;
    enemy_ai_baseline_match_active = false;
    enemy_ai_baseline_end_attack();
    randomize();
    vv_rng_set_seed(gameplay_rng, irandom(2147483645));
}

function enemy_ai_set_exploration_seed(_seed) {
    if (!is_real(_seed) || is_nan(_seed) || is_infinity(_seed)) return false;
    ai_exploration_seed = vv_rng_normalize_seed(_seed);
    vv_rng_set_seed(ai_exploration_rng, ai_exploration_seed);
    return true;
}

function enemy_ai_exploration_random() {
    return vv_rng_random(ai_exploration_rng);
}

function enemy_ai_exploration_irandom(_maximum) {
    return vv_rng_irandom(ai_exploration_rng, _maximum);
}

function enemy_ai_score_candidate(_evaluation_before, _build_snapshot, _slot,
_conditional_weight, _health_weight) {
    var candidate_snapshot = copy_build_without_slot(_build_snapshot, _slot);
    var evaluation_after = evaluate_build(candidate_snapshot);
    var guaranteed_threat = _evaluation_before.guaranteed_attack
        - evaluation_after.guaranteed_attack;
    var conditional_threat = _evaluation_before.conditional_attack
        - evaluation_after.conditional_attack;
    var destruction_cost = card_enemy_destruction_cost(_build_snapshot[_slot]);
    return {
        slot: _slot,
        guaranteed_threat: guaranteed_threat,
        conditional_threat: conditional_threat,
        destruction_cost: destruction_cost,
        score: guaranteed_threat
            + _conditional_weight * conditional_threat
            - _health_weight * destruction_cost
    };
}

function enemy_ai_candidate_ranks_before(_left, _right) {
    if (_left.score != _right.score) return _left.score > _right.score;
    if (_left.guaranteed_threat != _right.guaranteed_threat) {
        return _left.guaranteed_threat > _right.guaranteed_threat;
    }
    if (_left.destruction_cost != _right.destruction_cost) {
        return _left.destruction_cost < _right.destruction_cost;
    }
    return _left.slot < _right.slot;
}

function enemy_ai_rank_build_with_weights(_build_snapshot, _conditional_weight, _health_weight) {
    var evaluation_before = evaluate_build(_build_snapshot);
    var ranked = [];
    for (var slot_i = 0; slot_i < array_length(_build_snapshot); slot_i++) {
        if (is_undefined(_build_snapshot[slot_i])) continue;
        var candidate = enemy_ai_score_candidate(evaluation_before, _build_snapshot, slot_i,
            _conditional_weight, _health_weight);
        var inserted = false;
        for (var rank_i = 0; rank_i < array_length(ranked); rank_i++) {
            if (enemy_ai_candidate_ranks_before(candidate, ranked[rank_i])) {
                array_insert(ranked, rank_i, candidate);
                inserted = true;
                break;
            }
        }
        if (!inserted) array_push(ranked, candidate);
    }
    return ranked;
}

function enemy_ai_rank_build(_build_snapshot) {
    return enemy_ai_rank_build_with_weights(_build_snapshot,
        enemy_ai_conditional_weight(), enemy_ai_health_weight());
}

function enemy_ai_choose_target_with_weights(_current_state, _conditional_weight, _health_weight) {
    if (!is_struct(_current_state)
    || !variable_struct_exists(_current_state, "build_snapshot")
    || !is_array(_current_state.build_snapshot)
    || !variable_struct_exists(_current_state, "attack_remaining")
    || !is_real(_current_state.attack_remaining)
    || _current_state.attack_remaining < 0) return -1;

    var ranked = enemy_ai_rank_build_with_weights(_current_state.build_snapshot,
        _conditional_weight, _health_weight);
    for (var rank_i = 0; rank_i < array_length(ranked); rank_i++) {
        var slot = ranked[rank_i].slot;
        if (enemy_target_is_legal_in_build(_current_state.build_snapshot, slot,
        _current_state.attack_remaining)) return slot;
    }
    return -1;
}

function enemy_ai_near_equal_valid_targets(_current_state, _ranked, _margin) {
    var result = [];
    var top_score = undefined;
    for (var rank_i = 0; rank_i < array_length(_ranked); rank_i++) {
        var candidate = _ranked[rank_i];
        if (!enemy_target_is_legal_in_build(_current_state.build_snapshot,
        candidate.slot, _current_state.attack_remaining)) continue;
        if (is_undefined(top_score)) top_score = candidate.score;
        if (candidate.score >= top_score - _margin) array_push(result, candidate);
    }
    return result;
}

function enemy_ai_choose_target(_current_state) {
    if (!is_struct(_current_state)
    || !variable_struct_exists(_current_state, "build_snapshot")
    || !is_array(_current_state.build_snapshot)
    || !variable_struct_exists(_current_state, "attack_remaining")
    || !is_real(_current_state.attack_remaining)
    || _current_state.attack_remaining < 0) return -1;

    var ranked = enemy_ai_rank_build_with_weights(_current_state.build_snapshot,
        enemy_ai_conditional_weight(), enemy_ai_health_weight());
    var near_equal = enemy_ai_near_equal_valid_targets(
        _current_state, ranked, ENEMY_AI_EXPLORATION_MARGIN);
    if (array_length(near_equal) == 0) return -1;
    if (!enemy_auto_play || !ENEMY_AI_PRODUCTION_EXPLORATION
    || array_length(near_equal) == 1) return near_equal[0].slot;

    enemy_ai_exploration_opportunities++;
    if (enemy_ai_exploration_random() >= ENEMY_AI_EXPLORATION_RATE) {
        return near_equal[0].slot;
    }
    enemy_ai_exploration_triggers++;
    return near_equal[enemy_ai_exploration_irandom(array_length(near_equal) - 1)].slot;
}

function enemy_ai_cancel_pending_targeting() {
    enemy_ai_visual_stage = "";
    enemy_ai_visual_timer = 0;
    enemy_ai_selected_slot = -1;
    enemy_ai_pending_card = undefined;
    enemy_ai_pending_prompt_id = -1;
    enemy_ai_pending_attack = 0;
    enemy_ai_pending_source = "";
    enemy_ai_pending_zone = "";
    enemy_ai_pending_decision_record = undefined;
    enemy_ai_result_heading = "";
    enemy_ai_result_text = "";
}

function enemy_ai_pending_target_is_current() {
    var targets_hand = enemy_ai_pending_zone == "hand";
    var pending_cards = targets_hand ? hand : build;
    return enemy_auto_play && !setup_active && !game_over && !match_menu_active
        && enemy_ai_visual_stage == "targeting"
        && prompt_mode == (targets_hand ? "enemy_attack_hand" : "enemy_attack")
        && enemy_attack_prompt_id == enemy_ai_pending_prompt_id
        && prompt_value == enemy_ai_pending_attack
        && prompt_source == enemy_ai_pending_source
        && enemy_ai_selected_slot >= 0
        && enemy_ai_selected_slot < array_length(pending_cards)
        && !is_undefined(pending_cards[enemy_ai_selected_slot])
        && pending_cards[enemy_ai_selected_slot] == enemy_ai_pending_card
        && (targets_hand ? enemy_hand_target_is_legal(enemy_ai_selected_slot, prompt_value)
            : enemy_target_is_legal(enemy_ai_selected_slot, prompt_value));
}

function enemy_ai_choose_hand_target_in_hand(_hand, _attack_remaining) {
    var selected = -1;
    var lowest_health = 999999;
    for (var hand_i = 0; hand_i < array_length(_hand); hand_i++) {
        if (enemy_hand_target_is_legal_in_hand(_hand, hand_i, _attack_remaining)
        && _hand[hand_i].hp < lowest_health) {
            lowest_health = _hand[hand_i].hp;
            selected = hand_i;
        }
    }
    return selected;
}

function enemy_ai_choose_hand_target(_attack_remaining) {
    return enemy_ai_choose_hand_target_in_hand(hand, _attack_remaining);
}

function enemy_ai_schedule_current_target() {
    var targets_hand = prompt_mode == "enemy_attack_hand";
    if (!enemy_auto_play || (prompt_mode != "enemy_attack" && !targets_hand) || setup_active
    || game_over || match_menu_active || enemy_ai_visual_stage != "") return false;

    var current_state = {
        build_snapshot: copy_build_snapshot(build),
        attack_remaining: prompt_value
    };
    var selected_slot = targets_hand
        ? enemy_ai_choose_hand_target(prompt_value) : enemy_ai_choose_target(current_state);
    if (selected_slot < 0) {
        return targets_hand ? command_end_enemy_hand_attack_if_blocked()
            : command_end_enemy_attack_if_blocked();
    }
    enemy_ai_pending_decision_record = targets_hand
        ? undefined
        : enemy_ai_make_decision_record(current_state, selected_slot);
    enemy_ai_visual_stage = "targeting";
    enemy_ai_visual_timer = ENEMY_AI_TARGET_DELAY_FRAMES;
    enemy_ai_selected_slot = selected_slot;
    enemy_ai_pending_zone = targets_hand ? "hand" : "build";
    enemy_ai_pending_card = targets_hand ? hand[selected_slot] : build[selected_slot];
    enemy_ai_pending_prompt_id = enemy_attack_prompt_id;
    enemy_ai_pending_attack = prompt_value;
    enemy_ai_pending_source = prompt_source;
    return true;
}

function enemy_ai_submit_current_target() {
    if (!enemy_ai_pending_target_is_current()) {
        enemy_ai_cancel_pending_targeting();
        return false;
    }
    var selected_slot = enemy_ai_selected_slot;
    var submitted_prompt_id = enemy_ai_pending_prompt_id;
    var decision_record = enemy_ai_pending_decision_record;
    var pending_zone = enemy_ai_pending_zone;
    enemy_ai_cancel_pending_targeting();
    var submitted = pending_zone == "hand"
        ? command_prompt_hand(selected_slot) : command_prompt_build(selected_slot);
    if (submitted && !is_undefined(decision_record)
    && decision_record.turn_id == enemy_ai_policy_turn_number) {
        array_push(enemy_ai_policy_decisions, decision_record);
    }
    enemy_ai_visual_stage = "result";
    enemy_ai_visual_timer = ENEMY_AI_RESULT_DELAY_FRAMES;
    var attack_prompt_active = prompt_mode == "enemy_attack"
        || prompt_mode == "enemy_attack_hand";
    if (attack_prompt_active && enemy_attack_prompt_id == submitted_prompt_id) {
        enemy_ai_result_heading = "CARD DESTROYED";
        enemy_ai_result_text = string(prompt_value) + " Attack remains.\nThe same attack continues.";
    } else if (attack_prompt_active || array_length(full_assault_minions) > 0
    || resume_action == "continue_full_assault") {
        enemy_ai_result_heading = "CARD DESTROYED";
        enemy_ai_result_text = "Full Assault continues.";
    } else {
        enemy_ai_result_heading = "ATTACK COMPLETE";
        enemy_ai_result_text = "The attack has finished.";
    }
    return submitted;
}

function enemy_ai_update_auto_targeting() {
    if (enemy_ai_visual_stage == "targeting") {
        if (!enemy_ai_pending_target_is_current()) {
            enemy_ai_cancel_pending_targeting();
            return true;
        }
        enemy_ai_visual_timer--;
        if (enemy_ai_visual_timer <= 0) enemy_ai_submit_current_target();
        return true;
    }
    if (enemy_ai_visual_stage == "result") {
        if (!enemy_auto_play || setup_active || game_over || match_menu_active) {
            enemy_ai_cancel_pending_targeting();
            return true;
        }
        enemy_ai_visual_timer--;
        if (enemy_ai_visual_timer <= 0) enemy_ai_cancel_pending_targeting();
        return true;
    }
    if (enemy_auto_play && (prompt_mode == "enemy_attack" || prompt_mode == "enemy_attack_hand")) {
        enemy_ai_schedule_current_target();
        return true;
    }
    return false;
}

// Development-only oracle helpers. Production Auto targeting never calls these functions.
function enemy_ai_oracle_sequence_value_with_weight(
_initial_evaluation, _final_snapshot, _conditional_weight) {
    var final_evaluation = evaluate_build(_final_snapshot);
    var guaranteed_removed = _initial_evaluation.guaranteed_attack
        - final_evaluation.guaranteed_attack;
    var conditional_removed = _initial_evaluation.conditional_attack
        - final_evaluation.conditional_attack;
    return guaranteed_removed + _conditional_weight * conditional_removed;
}

function enemy_ai_oracle_sequence_value(_initial_evaluation, _final_snapshot) {
    return enemy_ai_oracle_sequence_value_with_weight(
        _initial_evaluation, _final_snapshot, enemy_ai_conditional_weight());
}

function enemy_ai_copy_sequence(_source_sequence) {
    var copied_sequence = [];
    for (var sequence_i = 0; sequence_i < array_length(_source_sequence); sequence_i++) {
        array_push(copied_sequence, _source_sequence[sequence_i]);
    }
    return copied_sequence;
}

function enemy_ai_oracle_sequence_ranks_before(_left, _right) {
    var shared_length = min(array_length(_left), array_length(_right));
    for (var sequence_i = 0; sequence_i < shared_length; sequence_i++) {
        if (_left[sequence_i] != _right[sequence_i]) return _left[sequence_i] < _right[sequence_i];
    }
    return array_length(_left) < array_length(_right);
}

function enemy_ai_oracle_search_with_weight(
_initial_evaluation, _build_snapshot, _attack_remaining, _sequence, _conditional_weight) {
    var best_result = undefined;
    for (var slot_i = 0; slot_i < array_length(_build_snapshot); slot_i++) {
        if (!enemy_target_is_legal_in_build(_build_snapshot, slot_i, _attack_remaining)) continue;
        var next_attack = _attack_remaining - card_enemy_destruction_cost(_build_snapshot[slot_i]);
        var next_snapshot = copy_build_without_slot(_build_snapshot, slot_i);
        var next_sequence = enemy_ai_copy_sequence(_sequence);
        array_push(next_sequence, slot_i);
        var candidate = enemy_ai_oracle_search_with_weight(_initial_evaluation, next_snapshot,
            next_attack, next_sequence, _conditional_weight);
        if (is_undefined(best_result)
        || candidate.sequence_value > best_result.sequence_value
        || (enemy_ai_scores_are_close(candidate.sequence_value, best_result.sequence_value)
            && enemy_ai_oracle_sequence_ranks_before(candidate.sequence, best_result.sequence))) {
            best_result = candidate;
        }
    }
    if (!is_undefined(best_result)) return best_result;
    return {
        sequence: enemy_ai_copy_sequence(_sequence),
        sequence_value: enemy_ai_oracle_sequence_value_with_weight(
            _initial_evaluation, _build_snapshot, _conditional_weight),
        final_snapshot: copy_build_snapshot(_build_snapshot),
        attack_remaining: _attack_remaining
    };
}

function enemy_ai_oracle_search(_initial_evaluation, _build_snapshot, _attack_remaining, _sequence) {
    return enemy_ai_oracle_search_with_weight(_initial_evaluation, _build_snapshot,
        _attack_remaining, _sequence, enemy_ai_conditional_weight());
}

function enemy_ai_oracle_greedy_sequence_with_weights(
_build_snapshot, _attack_remaining, _policy_conditional_weight,
_policy_health_weight, _value_conditional_weight) {
    var initial_evaluation = evaluate_build(_build_snapshot);
    var simulated_build = copy_build_snapshot(_build_snapshot);
    var simulated_attack = _attack_remaining;
    var sequence = [];
    while (true) {
        var selected_slot = enemy_ai_choose_target_with_weights({
            build_snapshot: simulated_build,
            attack_remaining: simulated_attack
        }, _policy_conditional_weight, _policy_health_weight);
        if (selected_slot < 0) break;
        simulated_attack -= card_enemy_destruction_cost(simulated_build[selected_slot]);
        simulated_build = copy_build_without_slot(simulated_build, selected_slot);
        array_push(sequence, selected_slot);
    }
    return {
        sequence: sequence,
        sequence_value: enemy_ai_oracle_sequence_value_with_weight(
            initial_evaluation, simulated_build, _value_conditional_weight),
        final_snapshot: simulated_build,
        attack_remaining: simulated_attack
    };
}

function enemy_ai_oracle_greedy_sequence(_build_snapshot, _attack_remaining) {
    var conditional_weight = enemy_ai_conditional_weight();
    return enemy_ai_oracle_greedy_sequence_with_weights(_build_snapshot, _attack_remaining,
        conditional_weight, enemy_ai_health_weight(), conditional_weight);
}

function enemy_ai_oracle_exploration_sequence_with_weights(
_build_snapshot, _attack_remaining, _policy_conditional_weight,
_policy_health_weight, _value_conditional_weight, _exploration_rng) {
    var initial_evaluation = evaluate_build(_build_snapshot);
    var simulated_build = copy_build_snapshot(_build_snapshot);
    var simulated_attack = _attack_remaining;
    var sequence = [];
    while (true) {
        var current_state = {
            build_snapshot: simulated_build,
            attack_remaining: simulated_attack
        };
        var ranked = enemy_ai_rank_build_with_weights(simulated_build,
            _policy_conditional_weight, _policy_health_weight);
        var near_equal = enemy_ai_near_equal_valid_targets(
            current_state, ranked, ENEMY_AI_EXPLORATION_MARGIN);
        if (array_length(near_equal) == 0) break;
        var selected_index = 0;
        if (array_length(near_equal) > 1
        && vv_rng_random(_exploration_rng) < ENEMY_AI_EXPLORATION_RATE) {
            selected_index = vv_rng_irandom(_exploration_rng, array_length(near_equal) - 1);
        }
        var selected_slot = near_equal[selected_index].slot;
        simulated_attack -= card_enemy_destruction_cost(simulated_build[selected_slot]);
        simulated_build = copy_build_without_slot(simulated_build, selected_slot);
        array_push(sequence, selected_slot);
    }
    return {
        sequence: sequence,
        sequence_value: enemy_ai_oracle_sequence_value_with_weight(
            initial_evaluation, simulated_build, _value_conditional_weight),
        final_snapshot: simulated_build,
        attack_remaining: simulated_attack
    };
}

function enemy_ai_evaluation_policy_result(_greedy, _best_value, _initial_evaluation) {
    var final_evaluation = evaluate_build(_greedy.final_snapshot);
    var guaranteed_removed = _initial_evaluation.guaranteed_attack
        - final_evaluation.guaranteed_attack;
    var conditional_removed = _initial_evaluation.conditional_attack
        - final_evaluation.conditional_attack;
    return {
        sequence: _greedy.sequence,
        value: _greedy.sequence_value,
        regret: max(0, _best_value - _greedy.sequence_value),
        matches_best: enemy_ai_scores_are_close(_best_value, _greedy.sequence_value),
        guaranteed_threat_removed: guaranteed_removed,
        conditional_threat_removed: conditional_removed,
        threat_removed: guaranteed_removed + enemy_ai_conditional_weight() * conditional_removed,
        cards_destroyed: array_length(_greedy.sequence)
    };
}

function enemy_ai_evaluation_variance(_sum, _sum_squared, _count) {
    if (_count <= 0) return 0;
    var average_value = _sum / _count;
    return max(0, _sum_squared / _count - average_value * average_value);
}

function enemy_ai_evaluate_policy_variants(
_build_snapshot, _attack_remaining, _exploration_rng) {
    var learned_wc = enemy_ai_conditional_weight();
    var learned_wh = enemy_ai_learned_health_weight();
    var initial_evaluation = evaluate_build(_build_snapshot);
    var exhaustive = enemy_ai_oracle_search_with_weight(initial_evaluation,
        copy_build_snapshot(_build_snapshot), _attack_remaining, [], learned_wc);
    var policy_a = enemy_ai_oracle_greedy_sequence_with_weights(
        _build_snapshot, _attack_remaining, 0.5, 1.0, learned_wc);
    var policy_b = enemy_ai_oracle_greedy_sequence_with_weights(
        _build_snapshot, _attack_remaining, learned_wc, 1.0, learned_wc);
    var policy_c = enemy_ai_oracle_greedy_sequence_with_weights(
        _build_snapshot, _attack_remaining, learned_wc, learned_wh, learned_wc);
    var policy_d = enemy_ai_oracle_exploration_sequence_with_weights(
        _build_snapshot, _attack_remaining, learned_wc, learned_wh,
        learned_wc, _exploration_rng);
    return {
        gameplay_seed: gameplay_seed,
        exploration_seed: _exploration_rng.seed,
        W_C: learned_wc,
        W_H: learned_wh,
        best_value: exhaustive.sequence_value,
        best_sequence: exhaustive.sequence,
        A: enemy_ai_evaluation_policy_result(
            policy_a, exhaustive.sequence_value, initial_evaluation),
        B: enemy_ai_evaluation_policy_result(
            policy_b, exhaustive.sequence_value, initial_evaluation),
        C: enemy_ai_evaluation_policy_result(
            policy_c, exhaustive.sequence_value, initial_evaluation),
        D: enemy_ai_evaluation_policy_result(
            policy_d, exhaustive.sequence_value, initial_evaluation)
    };
}

function enemy_ai_oracle_compare_with_health_weight(
_build_snapshot, _attack_remaining, _health_weight) {
    var oracle_snapshot = copy_build_snapshot(_build_snapshot);
    var initial_evaluation = evaluate_build(oracle_snapshot);
    var conditional_weight = enemy_ai_conditional_weight();
    var greedy_result = enemy_ai_oracle_greedy_sequence_with_weights(
        oracle_snapshot, _attack_remaining, conditional_weight,
        _health_weight, conditional_weight);
    var exhaustive_result = enemy_ai_oracle_search(initial_evaluation, oracle_snapshot,
        _attack_remaining, []);
    return {
        greedy_sequence: greedy_result.sequence,
        best_exhaustive_sequence: exhaustive_result.sequence,
        greedy_sequence_value: greedy_result.sequence_value,
        best_exhaustive_sequence_value: exhaustive_result.sequence_value,
        greedy_regret: exhaustive_result.sequence_value - greedy_result.sequence_value
    };
}

function enemy_ai_oracle_compare(_build_snapshot, _attack_remaining) {
    return enemy_ai_oracle_compare_with_health_weight(
        _build_snapshot, _attack_remaining, enemy_ai_health_weight());
}

function enemy_ai_sequences_match(_left, _right) {
    if (array_length(_left) != array_length(_right)) return false;
    for (var sequence_i = 0; sequence_i < array_length(_left); sequence_i++) {
        if (_left[sequence_i] != _right[sequence_i]) return false;
    }
    return true;
}

function enemy_ai_compare_conditional_policies_with_weight(
_build_snapshot, _attack_remaining, _learned_weight) {
    var learned_weight = clamp(_learned_weight, 0, 1);
    var initial_evaluation = evaluate_build(_build_snapshot);
    var exhaustive = enemy_ai_oracle_search_with_weight(initial_evaluation,
        copy_build_snapshot(_build_snapshot), _attack_remaining, [], learned_weight);
    var fixed = enemy_ai_oracle_greedy_sequence_with_weights(_build_snapshot,
        _attack_remaining, 0.5, ENEMY_AI_HEALTH_WEIGHT, learned_weight);
    var learned = enemy_ai_oracle_greedy_sequence_with_weights(_build_snapshot,
        _attack_remaining, learned_weight, ENEMY_AI_HEALTH_WEIGHT, learned_weight);
    return {
        learned_weight: learned_weight,
        fixed_sequence: fixed.sequence,
        learned_sequence: learned.sequence,
        sequences_differ: !enemy_ai_sequences_match(fixed.sequence, learned.sequence),
        fixed_value: fixed.sequence_value,
        learned_value: learned.sequence_value,
        best_value: exhaustive.sequence_value,
        fixed_regret: max(0, exhaustive.sequence_value - fixed.sequence_value),
        learned_regret: max(0, exhaustive.sequence_value - learned.sequence_value)
    };
}

function enemy_ai_compare_conditional_policies(_build_snapshot, _attack_remaining) {
    return enemy_ai_compare_conditional_policies_with_weight(
        _build_snapshot, _attack_remaining, enemy_ai_conditional_weight());
}

function enemy_ai_scores_are_close(_left, _right) {
    return abs(_left - _right) < 0.0001;
}

function enemy_ai_run_scoring_self_checks(_hero_definitions) {
    // Startup checks must be deterministic and must never depend on a player's
    // persisted learning history.
    var check_conditional_weight = enemy_ai_conditional_weight_from_counts(0, 0);
    var goblin = find_hero_definition(_hero_definitions, "goblin");
    var skeleton = find_hero_definition(_hero_definitions, "skeleton");
    var orc = find_hero_definition(_hero_definitions, "orc");
    if (is_undefined(goblin) || is_undefined(skeleton) || is_undefined(orc)) {
        return content_validation_result(false, "Enemy AI scoring checks require the core Heroes.");
    }

    var ranked = enemy_ai_rank_build_with_weights([goblin.normal, skeleton.normal, orc.normal],
        check_conditional_weight, ENEMY_AI_HEALTH_WEIGHT);
    if (array_length(ranked) != 3 || ranked[0].slot != 0 || ranked[1].slot != 1
    || ranked[2].slot != 2 || !enemy_ai_scores_are_close(ranked[0].score, 2)) {
        return content_validation_result(false, "Enemy AI basic scoring check failed.");
    }

    ranked = enemy_ai_rank_build_with_weights([goblin.ability, skeleton.normal, undefined],
        check_conditional_weight, ENEMY_AI_HEALTH_WEIGHT);
    if (array_length(ranked) != 2 || ranked[0].slot != 0
    || !enemy_ai_scores_are_close(ranked[0].guaranteed_threat, 4)
    || !enemy_ai_scores_are_close(ranked[0].conditional_threat, 2)
    || !enemy_ai_scores_are_close(ranked[0].score,
        2 + 2 * check_conditional_weight)) {
        return content_validation_result(false, "Enemy AI conditional scoring check failed.");
    }

    ranked = enemy_ai_rank_build_with_weights([skeleton.ability, goblin.normal, orc.normal],
        check_conditional_weight, ENEMY_AI_HEALTH_WEIGHT);
    if (array_length(ranked) != 3 || ranked[0].slot != 1
    || ranked[1].slot != 0 || ranked[2].slot != 2) {
        return content_validation_result(false, "Enemy AI Build-synergy scoring check failed.");
    }

    ranked = enemy_ai_rank_build_with_weights([goblin.normal, goblin.normal, undefined],
        check_conditional_weight, ENEMY_AI_HEALTH_WEIGHT);
    if (array_length(ranked) != 2 || ranked[0].slot != 0 || ranked[1].slot != 1) {
        return content_validation_result(false, "Enemy AI stable-slot tie-break check failed.");
    }

    var lower_health = card_player("test_a", "Test A", "Ability", 4, 3,
        [ability_entry(ABILITY_OVERPOWER, "Test", "", {amount:2})], "", "", 0);
    var higher_health = card_player("test_b", "Test B", "Ability", 4, 4,
        [ability_entry(ABILITY_OVERPOWER, "Test", "", {amount:4})], "", "", 0);
    ranked = enemy_ai_rank_build_with_weights([higher_health, lower_health, undefined],
        check_conditional_weight, ENEMY_AI_HEALTH_WEIGHT);
    if (array_length(ranked) != 2 || ranked[0].slot != 1
    || !enemy_ai_scores_are_close(ranked[0].score, ranked[1].score)
    || !enemy_ai_scores_are_close(ranked[0].guaranteed_threat, ranked[1].guaranteed_threat)) {
        return content_validation_result(false, "Enemy AI Health tie-break check failed.");
    }

    return content_validation_result(true, "");
}

function enemy_ai_run_selection_self_checks(_hero_definitions) {
    // Keep selection checks isolated from persisted learning data as well.
    var check_conditional_weight = enemy_ai_conditional_weight_from_counts(0, 0);
    var goblin = find_hero_definition(_hero_definitions, "goblin");
    var skeleton = find_hero_definition(_hero_definitions, "skeleton");
    var orc = find_hero_definition(_hero_definitions, "orc");
    if (is_undefined(goblin) || is_undefined(skeleton) || is_undefined(orc)) {
        return content_validation_result(false, "Enemy AI selection checks require the core Heroes.");
    }

    var state = {
        build_snapshot: [goblin.normal, skeleton.normal, orc.normal],
        attack_remaining: 10
    };
    if (enemy_ai_choose_target_with_weights(state,
    check_conditional_weight, ENEMY_AI_HEALTH_WEIGHT) != 0) {
        return content_validation_result(false, "Enemy AI preferred-target selection check failed.");
    }

    state.attack_remaining = 2;
    if (enemy_ai_choose_target_with_weights(state,
    check_conditional_weight, ENEMY_AI_HEALTH_WEIGHT) != -1) {
        return content_validation_result(false, "Enemy AI no-destroyable-target check failed.");
    }

    state.build_snapshot = [goblin.normal, skeleton.normal, orc.ability];
    state.attack_remaining = 10;
    if (enemy_ai_choose_target_with_weights(state,
    check_conditional_weight, ENEMY_AI_HEALTH_WEIGHT) != 2) {
        return content_validation_result(false, "Enemy AI Guard-priority selection check failed.");
    }

    state.build_snapshot = [goblin.normal, skeleton.normal, orc.special];
    state.attack_remaining = 7;
    if (enemy_ai_choose_target_with_weights(state,
    check_conditional_weight, ENEMY_AI_HEALTH_WEIGHT) != -1) {
        return content_validation_result(false, "Enemy AI undestroyable-priority check failed.");
    }

    var expensive_threat = card_player("test_threat", "Test Threat", "Normal", 20, 10,
        [], "", "", 0);
    state.build_snapshot = [expensive_threat, goblin.normal, undefined];
    state.attack_remaining = 5;
    if (enemy_ai_choose_target_with_weights(state,
    check_conditional_weight, ENEMY_AI_HEALTH_WEIGHT) != 1) {
        return content_validation_result(false, "Enemy AI valid-ranked-fallback check failed.");
    }

    state.build_snapshot = [undefined, undefined, undefined];
    if (enemy_ai_choose_target_with_weights(state,
    check_conditional_weight, ENEMY_AI_HEALTH_WEIGHT) != -1
    || enemy_ai_choose_target_with_weights(undefined,
    check_conditional_weight, ENEMY_AI_HEALTH_WEIGHT) != -1) {
        return content_validation_result(false, "Enemy AI empty-state selection check failed.");
    }

    return content_validation_result(true, "");
}

function enemy_ai_run_oracle_self_checks(_hero_definitions) {
    var goblin = find_hero_definition(_hero_definitions, "goblin");
    var skeleton = find_hero_definition(_hero_definitions, "skeleton");
    var orc = find_hero_definition(_hero_definitions, "orc");
    if (is_undefined(goblin) || is_undefined(skeleton) || is_undefined(orc)) {
        return content_validation_result(false, "Enemy AI oracle checks require the core Heroes.");
    }

    var original_snapshot = [goblin.normal, skeleton.normal, orc.normal];
    var result = enemy_ai_oracle_compare_with_health_weight(
        original_snapshot, 12, ENEMY_AI_HEALTH_WEIGHT);
    if (!enemy_ai_scores_are_close(result.greedy_sequence_value,
    result.best_exhaustive_sequence_value) || !enemy_ai_scores_are_close(result.greedy_regret, 0)
    || is_undefined(original_snapshot[0]) || is_undefined(original_snapshot[1])
    || is_undefined(original_snapshot[2])) {
        return content_validation_result(false, "Enemy AI oracle baseline/snapshot check failed.");
    }

    var greedy_card = card_player("oracle_a", "Oracle A", "Normal", 8, 4, [], "", "", 0);
    var pair_card_b = card_player("oracle_b", "Oracle B", "Normal", 6, 3, [], "", "", 0);
    var pair_card_c = card_player("oracle_c", "Oracle C", "Normal", 6, 3, [], "", "", 0);
    result = enemy_ai_oracle_compare_with_health_weight(
        [greedy_card, pair_card_b, pair_card_c], 6, ENEMY_AI_HEALTH_WEIGHT);
    if (array_length(result.greedy_sequence) != 1 || result.greedy_sequence[0] != 0
    || array_length(result.best_exhaustive_sequence) != 2
    || result.best_exhaustive_sequence[0] != 1 || result.best_exhaustive_sequence[1] != 2
    || !enemy_ai_scores_are_close(result.greedy_sequence_value, 8)
    || !enemy_ai_scores_are_close(result.best_exhaustive_sequence_value, 12)
    || !enemy_ai_scores_are_close(result.greedy_regret, 4)) {
        return content_validation_result(false, "Enemy AI oracle regret check failed.");
    }

    result = enemy_ai_oracle_compare_with_health_weight(
        [goblin.normal, skeleton.normal, orc.ability], 9, ENEMY_AI_HEALTH_WEIGHT);
    if (array_length(result.best_exhaustive_sequence) < 1
    || result.best_exhaustive_sequence[0] != 2) {
        return content_validation_result(false, "Enemy AI oracle priority check failed.");
    }

    result = enemy_ai_oracle_compare_with_health_weight(
        [goblin.ability, undefined, undefined], 2, ENEMY_AI_HEALTH_WEIGHT);
    var conditional_sequence_value = 4 + 2 * enemy_ai_conditional_weight();
    if (!enemy_ai_scores_are_close(result.greedy_sequence_value, conditional_sequence_value)
    || !enemy_ai_scores_are_close(result.best_exhaustive_sequence_value, conditional_sequence_value)) {
        return content_validation_result(false, "Enemy AI oracle conditional-value check failed.");
    }

    result = enemy_ai_oracle_compare_with_health_weight(
        [undefined, undefined, undefined], 10, ENEMY_AI_HEALTH_WEIGHT);
    if (array_length(result.greedy_sequence) != 0
    || array_length(result.best_exhaustive_sequence) != 0
    || !enemy_ai_scores_are_close(result.greedy_regret, 0)) {
        return content_validation_result(false, "Enemy AI oracle empty-Build check failed.");
    }

    return content_validation_result(true, "");
}

function enemy_ai_run_release_self_checks() {
    if (!enemy_ai_scores_are_close(enemy_ai_conditional_weight_from_counts(0, 0), 0.5)
    || !enemy_ai_scores_are_close(enemy_ai_conditional_weight_from_counts(3, 0), 0.2)
    || !enemy_ai_scores_are_close(enemy_ai_conditional_weight_from_counts(3, 3), 0.8)
    || enemy_ai_conditional_weight() < 0 || enemy_ai_conditional_weight() > 1
    || !enemy_ai_scores_are_close(ENEMY_AI_HEALTH_WEIGHT, 1.0)
    || !enemy_ai_scores_are_close(ENEMY_AI_HEALTH_LEARNING_RATE, 0.02)
    || enemy_ai_health_weight() < 0.25 || enemy_ai_health_weight() > 3.0
    || !ENEMY_AI_PRODUCTION_HEALTH_LEARNING
    || ENEMY_AI_PRODUCTION_EXPLORATION
    || ENEMY_AI_TARGET_DELAY_FRAMES <= 0 || ENEMY_AI_RESULT_DELAY_FRAMES <= 0) {
        return content_validation_result(false, "Enemy AI deterministic release constants are invalid.");
    }
    var manual_settings = vv_settings_decode("{\"settings_version\":1,\"enemy_targeting_mode\":\"manual\"}");
    var auto_settings = vv_settings_decode("{\"settings_version\":1,\"enemy_targeting_mode\":\"auto\"}");
    var corrupt_settings = vv_settings_decode("not valid json");
    if (!manual_settings.valid || manual_settings.enemy_auto_play
    || !auto_settings.valid || !auto_settings.enemy_auto_play
    || corrupt_settings.valid || !corrupt_settings.enemy_auto_play) {
        return content_validation_result(false, "Enemy AI settings recovery release check failed.");
    }

    var first_shuffle = array_shuffle_copy_with_rng(
        [0, 1, 2, 3, 4, 5, 6, 7], vv_rng_create(18427));
    var second_shuffle = array_shuffle_copy_with_rng(
        [0, 1, 2, 3, 4, 5, 6, 7], vv_rng_create(18427));
    for (var shuffle_i = 0; shuffle_i < array_length(first_shuffle); shuffle_i++) {
        if (first_shuffle[shuffle_i] != second_shuffle[shuffle_i]) {
            return content_validation_result(false, "Enemy AI seeded-playtest release check failed.");
        }
    }
    return content_validation_result(true, "");
}

function enemy_ai_run_rng_self_checks() {
    var gameplay_a = vv_rng_create(271828);
    var gameplay_b = vv_rng_create(271828);
    var exploration_a = vv_rng_create(111);
    var exploration_b = vv_rng_create(999);

    // Different AI streams may be consumed differently without moving gameplay state.
    vv_rng_random(exploration_a);
    vv_rng_random(exploration_b);
    vv_rng_random(exploration_b);
    var deck_a = array_shuffle_copy_with_rng(
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], gameplay_a);
    var deck_b = array_shuffle_copy_with_rng(
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], gameplay_b);
    for (var deck_i = 0; deck_i < array_length(deck_a); deck_i++) {
        if (deck_a[deck_i] != deck_b[deck_i]) {
            return content_validation_result(false,
                "Enemy AI exploration changed gameplay RNG results.");
        }
    }

    var repeat_a = vv_rng_create(314159);
    var repeat_b = vv_rng_create(314159);
    for (var repeat_i = 0; repeat_i < 8; repeat_i++) {
        if (!enemy_ai_scores_are_close(vv_rng_random(repeat_a), vv_rng_random(repeat_b))) {
            return content_validation_result(false,
                "Enemy AI exploration RNG reproducibility check failed.");
        }
    }
    if (gameplay_a.state != gameplay_b.state
    || exploration_a.state == exploration_b.state
    || vv_rng_irandom(vv_rng_create(42), 0) != 0) {
        return content_validation_result(false,
            "Enemy AI independent RNG state check failed.");
    }
    return content_validation_result(true, "");
}

function enemy_ai_run_exploration_self_checks() {
    if (!enemy_ai_scores_are_close(ENEMY_AI_EXPLORATION_RATE, 0.05)
    || !enemy_ai_scores_are_close(ENEMY_AI_EXPLORATION_MARGIN, 1.0)) {
        return content_validation_result(false,
            "Enemy AI exploration constants are invalid.");
    }

    var best = card_player("explore_best", "Best", "Normal", 1, 2, [], "", "", 0);
    var boundary = card_player("explore_boundary", "Boundary", "Normal", 1, 3, [], "", "", 0);
    var undestroyable = card_player("explore_wall", "Wall", "Normal", 1, 6, [], "", "", 0);
    var inferior = card_player("explore_inferior", "Inferior", "Normal", 1, 4, [], "", "", 0);
    var state = {
        build_snapshot: [best, boundary, undestroyable, inferior],
        attack_remaining: 5
    };
    var ranked = [
        {slot:0, score:10},
        {slot:2, score:9.8},
        {slot:1, score:9},
        {slot:3, score:8.99}
    ];
    var near_equal = enemy_ai_near_equal_valid_targets(
        state, ranked, ENEMY_AI_EXPLORATION_MARGIN);
    if (array_length(near_equal) != 2
    || near_equal[0].slot != 0 || near_equal[1].slot != 1) {
        return content_validation_result(false,
            "Enemy AI bounded exploration pool check failed.");
    }

    var guard = card_player("explore_guard", "Guard", "Ability", 1, 4,
        [ability_entry(ABILITY_GUARD, "Guard", "", {})], "", "", 0);
    state.build_snapshot = [best, boundary, guard];
    ranked = [{slot:0, score:10}, {slot:1, score:9.5}, {slot:2, score:8}];
    near_equal = enemy_ai_near_equal_valid_targets(
        state, ranked, ENEMY_AI_EXPLORATION_MARGIN);
    if (array_length(near_equal) != 1 || near_equal[0].slot != 2) {
        return content_validation_result(false,
            "Enemy AI exploration priority-target check failed.");
    }

    var trial_rng = vv_rng_create(1618033);
    var trials = 20000;
    var triggered = 0;
    for (var trial_i = 0; trial_i < trials; trial_i++) {
        if (vv_rng_random(trial_rng) < ENEMY_AI_EXPLORATION_RATE) triggered++;
    }
    var observed_rate = triggered / trials;
    if (observed_rate < 0.04 || observed_rate > 0.06) {
        return content_validation_result(false,
            "Enemy AI exploration frequency check failed.");
    }
    return content_validation_result(true, "");
}

function enemy_ai_run_evaluation_self_checks(_hero_definitions) {
    var goblin = find_hero_definition(_hero_definitions, "goblin");
    var skeleton = find_hero_definition(_hero_definitions, "skeleton");
    var orc = find_hero_definition(_hero_definitions, "orc");
    if (is_undefined(goblin) || is_undefined(skeleton) || is_undefined(orc)) {
        return content_validation_result(false,
            "Enemy AI evaluation checks require the core Heroes.");
    }
    var snapshot = [goblin.ability, skeleton.special, orc.normal];
    var live_exploration_state = ai_exploration_rng.state;
    var first = enemy_ai_evaluate_policy_variants(
        snapshot, 9, vv_rng_create(24681357));
    var second = enemy_ai_evaluate_policy_variants(
        snapshot, 9, vv_rng_create(24681357));
    if (!enemy_ai_sequences_match(first.D.sequence, second.D.sequence)
    || !enemy_ai_scores_are_close(first.D.value, second.D.value)
    || !enemy_ai_scores_are_close(first.D.regret, second.D.regret)
    || first.A.regret < 0 || first.B.regret < 0
    || first.C.regret < 0 || first.D.regret < 0
    || !enemy_ai_scores_are_close(first.W_C, enemy_ai_conditional_weight())
    || !enemy_ai_scores_are_close(first.W_H, enemy_ai_learned_health_weight())
    || !enemy_ai_scores_are_close(enemy_ai_evaluation_variance(2, 4, 2), 1)
    || ai_exploration_rng.state != live_exploration_state
    || is_undefined(snapshot[0]) || is_undefined(snapshot[1]) || is_undefined(snapshot[2])) {
        return content_validation_result(false,
            "Enemy AI adaptive evaluation check failed.");
    }
    return content_validation_result(true, "");
}

function enemy_ai_run_future_content_self_checks() {
    var future_effect = ability_entry("future_shared_effect", "Any Display Name", "", {
        guaranteed_attack_self: 3,
        guaranteed_attack_others: 2,
        conditional_attack_self: 4,
        conditional_attack_others: 2,
        conditional_trigger: CONDITIONAL_TRIGGER_MINION_DEFEATED,
        enemy_target_priority: true,
        enemy_destruction_cost_delta: 2
    });
    var source = card_player("future_source", "Source Display Name", "Ability",
        1, 3, [future_effect], "", "", 0);
    var partner = card_player("future_partner", "Partner Display Name", "Normal",
        2, 2, [], "", "", 0);
    var snapshot = [source, partner, undefined];
    var evaluation = evaluate_build(snapshot);
    var without_source = evaluate_build(copy_build_without_slot(snapshot, 0));
    var scored = enemy_ai_score_candidate(evaluation, snapshot, 0, 0.5, 1.0);

    var renamed = variable_clone(source);
    renamed.name = "Completely Different Display Name";
    renamed.abilities[0].name = "Renamed Effect";
    var renamed_evaluation = evaluate_build([renamed, partner, undefined]);
    var state = {build_snapshot:snapshot, attack_remaining:6};
    var legal_pool = enemy_ai_near_equal_valid_targets(state,
        enemy_ai_rank_build_with_weights(snapshot, 0.5, 1.0), 999);
    var sequence = enemy_ai_oracle_greedy_sequence_with_weights(
        snapshot, 6, 0.5, 1.0, 0.5);
    var future_minion = card_minion("future_minion", "Future Minion", "Normal",
        1, 4, [], "", [], "");
    var future_exposure = enemy_ai_count_exposed_conditional_abilities(
        snapshot, 6, [future_minion, undefined]);

    if (!enemy_ai_scores_are_close(evaluation.guaranteed_attack, 8)
    || !enemy_ai_scores_are_close(evaluation.conditional_attack, 6)
    || !enemy_ai_scores_are_close(without_source.guaranteed_attack, 2)
    || !enemy_ai_scores_are_close(without_source.conditional_attack, 0)
    || !enemy_ai_scores_are_close(scored.guaranteed_threat, 6)
    || !enemy_ai_scores_are_close(scored.conditional_threat, 6)
    || !enemy_ai_scores_are_close(renamed_evaluation.guaranteed_attack,
        evaluation.guaranteed_attack)
    || !enemy_ai_scores_are_close(renamed_evaluation.conditional_attack,
        evaluation.conditional_attack)
    || !build_snapshot_has_priority(snapshot)
    || enemy_target_is_legal_in_build(snapshot, 1, 6)
    || enemy_target_is_legal_in_build(snapshot, 0, 4)
    || !enemy_target_is_legal_in_build(snapshot, 0, 5)
    || card_enemy_destruction_cost(source) != 5
    || scored.destruction_cost != 5
    || future_exposure != 1
    || array_length(legal_pool) != 1 || legal_pool[0].slot != 0
    || array_length(sequence.sequence) != 1 || sequence.sequence[0] != 0
    || is_undefined(sequence.final_snapshot[1])) {
        return content_validation_result(false,
            "Enemy AI future-content compatibility check failed.");
    }
    return content_validation_result(true, "");
}

function enemy_ai_run_conditional_learning_self_checks(_hero_definitions) {
    var goblin = find_hero_definition(_hero_definitions, "goblin");
    if (is_undefined(goblin)) {
        return content_validation_result(false, "Enemy AI learning checks require Goblin.");
    }
    var affordable_minion = card_minion("learning_target", "Learning Target", "Normal",
        1, 4, [], "", [], "");
    var expensive_minion = card_minion("learning_wall", "Learning Wall", "Normal",
        1, 20, [], "", [], "");
    var exposed = enemy_ai_count_exposed_conditional_abilities(
        [goblin.ability, goblin.special, undefined], 8,
        [affordable_minion, undefined]);
    var blocked = enemy_ai_count_exposed_conditional_abilities(
        [goblin.ability, goblin.special, undefined], 8,
        [expensive_minion, undefined]);
    var absent = enemy_ai_count_exposed_conditional_abilities(
        [goblin.normal, undefined, undefined], 8,
        [affordable_minion, undefined]);
    if (exposed != 2 || blocked != 0 || absent != 0) {
        return content_validation_result(false, "Enemy AI conditional exposure check failed.");
    }
    var activated = enemy_ai_conditional_learning_apply_observation(5, 2, 2, true);
    var not_activated = enemy_ai_conditional_learning_apply_observation(5, 2, 2, false);
    if (activated.exposures != 7 || activated.activations != 4
    || not_activated.exposures != 7 || not_activated.activations != 2) {
        return content_validation_result(false, "Enemy AI conditional observation check failed.");
    }
    var immediate_card = card_player("baseline_immediate", "Immediate", "Normal",
        6, 3, [], "", "", 0);
    var conditional_card = card_player("baseline_conditional", "Conditional", "Ability",
        4, 2, [ability_entry(ABILITY_RELENTLESS, "Conditional Test", "", {amount:3})],
        "", "", 0);
    var comparison = enemy_ai_compare_conditional_policies_with_weight(
        [immediate_card, conditional_card, undefined], 3, 0.1);
    if (!comparison.sequences_differ || comparison.fixed_sequence[0] != 1
    || comparison.learned_sequence[0] != 0 || comparison.learned_regret != 0
    || comparison.fixed_regret <= 0) {
        return content_validation_result(false, "Enemy AI fixed/learned baseline comparison check failed.");
    }
    return content_validation_result(true, "");
}

function enemy_ai_run_reward_self_checks() {
    var normal = enemy_ai_calculate_turn_reward(100, 80, 16, 32, 0);
    var no_damage = enemy_ai_calculate_turn_reward(100, 110, 8, 32, 0);
    var enemy_win = enemy_ai_calculate_turn_reward(100, 20, 0, 32, 1);
    var enemy_loss = enemy_ai_calculate_turn_reward(100, 0, 20, 32, -1);
    var ema_update = enemy_ai_reward_ema_transition(0.4, -0.6);
    var terminal_update = enemy_ai_reward_ema_transition(0, 2);
    if (!enemy_ai_scores_are_close(normal.leader_damage, 20)
    || !enemy_ai_scores_are_close(normal.damage_fraction, 0.2)
    || !enemy_ai_scores_are_close(normal.deck_ratio, 0.5)
    || !enemy_ai_scores_are_close(normal.reward, -0.3)
    || !enemy_ai_scores_are_close(no_damage.reward, 0)
    || !enemy_ai_scores_are_close(enemy_win.reward, 2)
    || !enemy_ai_scores_are_close(enemy_loss.reward, -2)
    || !enemy_ai_scores_are_close(ema_update.advantage, -1)
    || !enemy_ai_scores_are_close(ema_update.new_ema, 0.35)
    || !enemy_ai_scores_are_close(terminal_update.advantage, 2)
    || !enemy_ai_scores_are_close(terminal_update.new_ema, 0.1)
    || !enemy_ai_reward_measurement_is_eligible(true, true, 4, 4)
    || enemy_ai_reward_measurement_is_eligible(true, false, 4, 4)
    || enemy_ai_reward_measurement_is_eligible(false, true, 4, 4)
    || enemy_ai_reward_measurement_is_eligible(true, true, 3, 4)
    || !enemy_ai_policy_reward_should_update(1)
    || enemy_ai_policy_reward_should_update(0)) {
        return content_validation_result(false, "Enemy AI reward calculation check failed.");
    }
    return content_validation_result(true, "");
}

function enemy_ai_run_health_learning_self_checks() {
    var one_expensive = [{normalized_cost_delta:0.5}];
    var two_expensive = [
        {normalized_cost_delta:0.5},
        {normalized_cost_delta:0.5}
    ];
    var positive = enemy_ai_apply_health_learning(1.0, 1.0, one_expensive);
    var negative = enemy_ai_apply_health_learning(1.0, -1.0, one_expensive);
    var shared = enemy_ai_apply_health_learning(1.0, 1.0, two_expensive);
    var lower_clamp = enemy_ai_apply_health_learning(0.251, 100, one_expensive);
    var upper_clamp = enemy_ai_apply_health_learning(2.999, -100, one_expensive);
    var forced = enemy_ai_apply_health_learning(1.25, 1.0, []);
    var blocked_observation = enemy_ai_attack_observation_flags("build", 0);
    var forced_observation = enemy_ai_attack_observation_flags("build", 1);
    var hand_observation = enemy_ai_attack_observation_flags("hand", 2);
    if (!enemy_ai_scores_are_close(enemy_ai_normalized_cost_delta([2, 4, 8], 2), 5 / 6)
    || !enemy_ai_scores_are_close(enemy_ai_normalized_cost_delta([4, 4], 0), 0)
    || !enemy_ai_scores_are_close(positive, 0.99)
    || !enemy_ai_scores_are_close(negative, 1.01)
    || !enemy_ai_scores_are_close(shared, 0.99)
    || !enemy_ai_scores_are_close(lower_clamp, 0.25)
    || !enemy_ai_scores_are_close(upper_clamp, 3.0)
    || !enemy_ai_scores_are_close(forced, 1.25)
    || !blocked_observation.blocked || blocked_observation.forced
    || !forced_observation.forced || forced_observation.blocked
    || !hand_observation.hand || hand_observation.blocked
    || !enemy_ai_policy_choice_is_eligible(true, 2, 2, 2)
    || enemy_ai_policy_choice_is_eligible(false, 2, 2, 2)
    || enemy_ai_policy_choice_is_eligible(true, 1, 2, 2)
    || enemy_ai_policy_choice_is_eligible(true, 2, 2, 1)
    || enemy_ai_policy_choice_is_eligible(true, 2, 2, 0)) {
        return content_validation_result(false, "Enemy AI Health learning check failed.");
    }
    return content_validation_result(true, "");
}
