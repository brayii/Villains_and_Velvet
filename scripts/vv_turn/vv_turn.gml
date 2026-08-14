/// Seven-step turn coordination and automatic phase timing.

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

function vv_turn_update() {
    if (action_cooldown > 0) action_cooldown--;
    if (auto_timer > 0 && prompt_mode == "" && !game_over) {
        auto_timer--;
        if (auto_timer == 0) {
            if (phase == "enemy_continue_wait") draw_next_enemy_card();
            else command_action();
        }
    }
}
