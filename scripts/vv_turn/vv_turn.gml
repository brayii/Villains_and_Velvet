/// Seven-step turn coordination and automatic phase timing.

#macro ENEMY_EVENT_REVEAL_FRAMES 50
#macro ENEMY_EVENT_GAP_FRAMES 20

function resume_after_prompts() {
    if (prompt_mode != "") return;
    if (start_queued_attack()) return;
    var action = resume_action;
    resume_action = "";
    if (action == "finish_advance") {
        if (!is_undefined(advance_incoming_minion)) {
            if (advance_escape_pending && !is_undefined(minions[0])) {
                retire_minion(0, "finishes escaping");
            }
            minions[0] = advance_incoming_minion;
            minions[1] = undefined;
            log_add(minions[0].name + " advances to Area 2.");
        }
        advance_incoming_minion = undefined;
        advance_escape_pending = false;
        log_add("Step 2 — Advance/Escape complete.");
        step_number = 3;
        phase = "step3_ready";
        auto_timer = 50;
        log_add("Next: Enemy Draw.");
        validate_state("Advance/Escape complete");
    } else if (action == "continue_enemy_draw") {
        phase = "enemy_event_reveal_wait";
        auto_timer = ENEMY_EVENT_REVEAL_FRAMES;
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
    build_changed = false;
    build_finish_confirm = false;
    phase = "build";
    log_add("Build your team, then tap DONE BUILDING.");
}

function finish_build() {
    var empty_build_spaces = 0;
    for (var build_check_i = 0; build_check_i < 3; build_check_i++) {
        if (is_undefined(build[build_check_i])) empty_build_spaces++;
    }
    if ((!build_changed || empty_build_spaces > 0) && !build_finish_confirm) {
        build_finish_confirm = true;
        selected_hand = -1;
        selected_build = -1;
        return;
    }
    build_finish_confirm = false;
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
    enemy_ai_conditional_learning_begin_attack(
        copy_build_snapshot(build), attack_left, minions);
    attack_finish_confirm = false;
    phase = "attack";
    log_add("Step 5 — Player Attack: " + string(attack_left) + ".");
    if (attack_left <= 0) show_attack_completion("NO ATTACK AVAILABLE", "Attack step skipped.");
}

function show_attack_completion(_heading, _text) {
    attack_finish_confirm = false;
    attack_notice_heading = _heading;
    attack_notice_text = _text;
    phase = "attack_complete_wait";
    auto_timer = 60;
}

function complete_attack_step() {
    enemy_ai_conditional_learning_finish_attack();
    log_add("Step 5 complete. " + string(attack_left) + " unused Attack remains until End Turn.");
    attack_finish_confirm = false;
    step_number = 6;
    phase = "step6_ready";
    auto_timer = 40;
    log_add("Attack complete. Discarding the cards left in your Hand.");
}

function finish_attack() {
    if (attack_left > 0 && !attack_finish_confirm) {
        attack_finish_confirm = true;
        return;
    }
    complete_attack_step();
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
        enemy_ai_baseline_finish_match(true);
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

function vv_turn_update() {
    if (setup_active) return;
    if (action_cooldown > 0) action_cooldown--;
    if (enemy_ai_update_auto_targeting()) return;
    if (auto_timer > 0 && prompt_mode == "" && !game_over) {
        auto_timer--;
        if (auto_timer == 0) {
            if (phase == "enemy_event_reveal_wait") {
                revealed_enemy_card = undefined;
                revealed_enemy_draw_number = 0;
                phase = "enemy_event_gap_wait";
                auto_timer = ENEMY_EVENT_GAP_FRAMES;
            } else if (phase == "enemy_event_gap_wait") draw_next_enemy_card();
            else if (phase == "attack_complete_wait") complete_attack_step();
            else command_action();
        }
    }
}
