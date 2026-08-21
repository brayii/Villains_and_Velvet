/// Controlled first-battle training. Normal setup selections are restored afterward.

enum TutorialStep {
    Intro, T1_StartTurn, T1_HoldHero, T1_InspectOpen, T1_InspectClose,
    T1_Step2Watch, T1_Step2Result, T1_CorgiReveal, T1_CorgiEntryWatch,
    T1_CorgiEntryResult, T1_DragHero1, T1_DragHero2, T1_DragHero3,
    T1_BuildReady, T1_AttackLeader, T1_AttackLeaderResult, T1_DiscardResult,
    T1_EndResult, T2_StartTurn, T2_DrawResult, T2_CorgiAdvanceWatch,
    T2_CorgiAdvanceResult, T2_DirectAssaultRead, T2_DirectAssaultWatch,
    T2_DirectAssaultResult, T2_EventDrawRule, T2_RedPandaEntryWatch,
    T2_RedPandaAttackWatch, T2_RedPandaAttackResult, T2_Rebuild1,
    T2_Rebuild2, T2_Rebuild3, T2_BuildReady, T2_NotEnoughAttack,
    T2_DoneAttacking, T2_ConfirmEnd, T2_BothMinionsRemainResult,
    T2_EndResult, T3_StartTurn, T3_PreEscapeReason, T3_AdvanceWatch,
    T3_Area2Full, T3_PushWatch, T3_EscapeResult, T3_EscapeEffectRead,
    T3_EscapeEffectWatch, T3_EscapeEffectResult, T3_AdvanceResult,
    T3_ReinforcementsRead, T3_ReinforcementsWatch, T3_ReinforcementsResult,
    T3_EventDrawReminder, T3_BunnyEntryWatch, T3_BunnyAttackWatch,
    T3_BunnyAttackResult, T3_Rebuild, T3_BuildReady, T3_AttackBunny,
    T3_AttackBunnyResult, T3_AttackLeader, T3_AttackLeaderResult,
    T3_DiscardWatch, T3_DiscardResult, T3_EndResult, Complete
}

function vv_tutorial_profile() {
    return {
        leader_id:"velvet_queen",
        scenario_id:"the_assault",
        minion_set_id:"velvet_menagerie",
        hero_ids:["goblin", "skeleton", "orc"],
        hero_kinds:["Normal", "Normal", "Ability"],
        minion_slot:"NA"
    };
}

function vv_tutorial_init() {
    tutorial_mode = false;
    tutorial_saved_setup = undefined;
    tutorial_escape_seen = false;
    tutorial_minion_defeated = false;
    tutorial_leader_attacked = false;
    tutorial_final_leader_attacked = false;
    tutorial_complete_prompt = false;
    tutorial_entry_notice_timer = 0;
    tutorial_move_notice_timer = 0;
    tutorial_step = TutorialStep.Intro;
    tutorial_pause = false;
    tutorial_heading = "";
    tutorial_body = "";
    tutorial_message_kind = "";
}

function vv_tutorial_set_state(_step, _kind, _heading, _body, _pause) {
    tutorial_step = _step;
    tutorial_message_kind = _kind;
    tutorial_heading = _heading;
    tutorial_body = _body;
    tutorial_pause = _pause;
}

function vv_tutorial_blocks_automatic_progress() {
    return tutorial_mode && tutorial_pause;
}

function vv_tutorial_action_allowed() {
    if (!tutorial_mode) return true;
    if (turn_number != 1) return true;
    if (phase == "step1_ready") return tutorial_step == TutorialStep.T1_StartTurn;
    if (phase == "step2_ready") return tutorial_step == TutorialStep.T1_InspectClose;
    if (phase == "step3_ready") return tutorial_step == TutorialStep.T1_CorgiReveal;
    if (phase == "build") return tutorial_step == TutorialStep.T1_BuildReady;
    return true;
}

function vv_tutorial_build_drop_allowed(_source_area, _source_index, _target_area, _target_index) {
    if (!tutorial_mode || turn_number != 1) return true;
    var expected = count_occupied_build();
    return _source_area == "hand" && _target_area == "build"
        && _source_index == expected && _target_index == expected;
}

function vv_tutorial_continue() {
    if (!tutorial_mode || !tutorial_pause) return false;
    switch (tutorial_step) {
        case TutorialStep.Intro:
            vv_tutorial_set_state(TutorialStep.T1_StartTurn, "action", "YOUR ACTION",
                "Tap START TURN to draw\n3 Hero cards.", false);
            return true;
        case TutorialStep.T1_Step2Result:
            vv_tutorial_set_state(TutorialStep.T1_CorgiReveal, "action", "YOUR ACTION",
                "Tap ENEMY DRAW to reveal the first enemy.", false);
            return true;
        case TutorialStep.T1_CorgiEntryResult:
            vv_tutorial_set_state(TutorialStep.T1_DragHero1, "action", "YOUR ACTION",
                "Drag the glowing Hero into the glowing Build space.", false);
            return true;
        case TutorialStep.T1_AttackLeaderResult:
            vv_tutorial_set_state(TutorialStep.T1_DiscardResult, "result", "RESULT",
                "Unused Hand cards are discarded at the end of the turn.", true);
            return true;
        case TutorialStep.T1_DiscardResult:
            vv_tutorial_set_state(TutorialStep.T1_EndResult, "action", "YOUR ACTION",
                "Tap END TURN. Your Build cards stay in play.", false);
            return true;
    }
    return false;
}

function vv_tutorial_card_inspected(_opened) {
    if (!tutorial_mode) return;
    if (_opened && tutorial_step == TutorialStep.T1_HoldHero) {
        vv_tutorial_set_state(TutorialStep.T1_InspectOpen, "tip", "READ THIS CARD",
            "The enlarged card shows its Attack, Health, and ability. Tap outside it when you are ready.", false);
    } else if (!_opened && tutorial_step == TutorialStep.T1_InspectOpen) {
        vv_tutorial_set_state(TutorialStep.T1_InspectClose, "action", "YOUR ACTION",
            "Tap ADVANCE / ESCAPE. Area 1 is empty, so nothing moves.", false);
    }
}

function vv_tutorial_after_player_draw() {
    if (!tutorial_mode || turn_number != 1) return;
    auto_timer = 0;
    vv_tutorial_set_state(TutorialStep.T1_HoldHero, "action", "YOUR ACTION",
        "Press and hold the glowing Hero card to inspect it.", false);
}

function vv_tutorial_after_advance() {
    if (!tutorial_mode) return;
    if (turn_number == 1) vv_tutorial_set_state(TutorialStep.T1_Step2Result, "result", "RESULT",
        "Area 1 was empty, so no Minion advanced or escaped.", true);
}

function vv_tutorial_after_enemy_entry(_minion) {
    if (!tutorial_mode) return;
    if (turn_number == 1 && _minion.id == "corgi") vv_tutorial_set_state(TutorialStep.T1_CorgiEntryResult,
        "result", "RESULT", "Corgi entered Area 1 and attacked. Your Build was empty, so no Hero was lost.", true);
}

function vv_tutorial_after_build_move() {
    if (!tutorial_mode) return;
    if (turn_number == 1) {
        var filled = count_occupied_build();
        if (filled == 1) vv_tutorial_set_state(TutorialStep.T1_DragHero2, "action", "YOUR ACTION", "Drag the next Hero into the glowing Build space.", false);
        else if (filled == 2) vv_tutorial_set_state(TutorialStep.T1_DragHero3, "action", "YOUR ACTION", "Drag the final Hero into the glowing Build space.", false);
        else if (filled == 3) vv_tutorial_set_state(TutorialStep.T1_BuildReady, "action", "YOUR ACTION", "Your Build has 11 Attack. Tap DONE BUILDING.", false);
    }
}

function vv_tutorial_after_attack_started() {
    if (tutorial_mode && turn_number == 1) vv_tutorial_set_state(TutorialStep.T1_AttackLeader, "action", "YOUR ACTION",
        "Corgi needs 8 Attack, but first learn to strike the Leader. Tap the glowing Leader.", false);
}

function vv_tutorial_after_leader_attack() {
    if (!tutorial_mode) return;
    if (turn_number == 1) vv_tutorial_set_state(TutorialStep.T1_AttackLeaderResult, "result", "RESULT",
        "All 11 Attack damaged the Velvet Queen. Attack is spent only when an attack succeeds.", true);
}

function vv_tutorial_find_content_index(_registry, _content_id) {
    for (var content_i = 0; content_i < array_length(_registry); content_i++) {
        if (_registry[content_i].id == _content_id) return content_i;
    }
    return -1;
}

function vv_tutorial_begin() {
    var profile = vv_tutorial_profile();
    var leader_index = vv_tutorial_find_content_index(available_leaders, profile.leader_id);
    var scenario_index = vv_tutorial_find_content_index(available_scenarios, profile.scenario_id);
    var minion_set_index = vv_tutorial_find_content_index(available_minion_sets, profile.minion_set_id);
    if (leader_index < 0 || scenario_index < 0 || minion_set_index < 0
    || !validate_hero_selection(available_heroes, profile.hero_ids)) return false;

    tutorial_saved_setup = {
        leader_index:selected_leader_index,
        scenario_index:selected_scenario_index,
        minion_set_index:selected_minion_set_index,
        hero_ids:variable_clone(selected_hero_ids),
        events:variable_clone(enemy_event_selection)
    };
    selected_leader_index = leader_index;
    selected_scenario_index = scenario_index;
    selected_minion_set_index = minion_set_index;
    enemy_leader = available_leaders[leader_index];
    enemy_scenario = available_scenarios[scenario_index];
    enemy_minion_set = available_minion_sets[minion_set_index];
    selected_hero_ids = variable_clone(profile.hero_ids);
    enemy_event_selection = make_default_enemy_event_selection(enemy_leader, enemy_scenario);
    leader_art_sprite = get_art_sprite(enemy_leader.art_file);
    tutorial_mode = true;
    return true;
}

function vv_tutorial_restore_setup() {
    if (is_undefined(tutorial_saved_setup)) return;
    selected_leader_index = tutorial_saved_setup.leader_index;
    selected_scenario_index = tutorial_saved_setup.scenario_index;
    selected_minion_set_index = tutorial_saved_setup.minion_set_index;
    selected_hero_ids = variable_clone(tutorial_saved_setup.hero_ids);
    enemy_leader = available_leaders[selected_leader_index];
    enemy_scenario = available_scenarios[selected_scenario_index];
    enemy_minion_set = available_minion_sets[selected_minion_set_index];
    enemy_event_selection = variable_clone(tutorial_saved_setup.events);
    leader_art_sprite = get_art_sprite(enemy_leader.art_file);
    tutorial_saved_setup = undefined;
}

function vv_tutorial_take_player_card(_deck, _hero_id, _kind) {
    for (var card_i = 0; card_i < array_length(_deck); card_i++) {
        var candidate = _deck[card_i];
        if (candidate.hero == _hero_id && candidate.kind == _kind) {
            var card = _deck[card_i];
            array_delete(_deck, card_i, 1);
            return card;
        }
    }
    return undefined;
}

function vv_tutorial_take_minion(_deck, _slot) {
    for (var card_i = 0; card_i < array_length(_deck); card_i++) {
        var candidate = _deck[card_i];
        if (candidate.card_type == "minion" && candidate.minion_slot == _slot) {
            var card = _deck[card_i];
            array_delete(_deck, card_i, 1);
            return card;
        }
    }
    return undefined;
}

function vv_tutorial_take_enemy_card(_deck, _id) {
    for (var card_i = 0; card_i < array_length(_deck); card_i++) {
        if (_deck[card_i].id == _id) {
            var card = _deck[card_i];
            array_delete(_deck, card_i, 1);
            return card;
        }
    }
    return undefined;
}

function vv_tutorial_configure_match() {
    var profile = vv_tutorial_profile();
    var opening_hand = [];
    for (var hero_i = 0; hero_i < array_length(profile.hero_ids); hero_i++) {
        var hero_card = vv_tutorial_take_player_card(player_deck,
            profile.hero_ids[hero_i], profile.hero_kinds[hero_i]);
        if (!is_undefined(hero_card)) array_push(opening_hand, hero_card);
    }
    // Stack later tutorial hands before Turn 1's opening hand (the deck pops from the end).
    var later_cards = [
        vv_tutorial_take_player_card(player_deck, "goblin", "Normal"),
        vv_tutorial_take_player_card(player_deck, "skeleton", "Normal"),
        vv_tutorial_take_player_card(player_deck, "orc", "Normal"),
        vv_tutorial_take_player_card(player_deck, "orc", "Ability"),
        vv_tutorial_take_player_card(player_deck, "orc", "Ability"),
        vv_tutorial_take_player_card(player_deck, "orc", "Special")
    ];
    for (var later_i = 0; later_i < array_length(later_cards); later_i++) {
        if (!is_undefined(later_cards[later_i])) array_push(player_deck, later_cards[later_i]);
    }
    for (var opening_i = array_length(opening_hand) - 1; opening_i >= 0; opening_i--) {
        array_push(player_deck, opening_hand[opening_i]);
    }
    // Controlled Enemy draws: Corgi; Direct Assault, Red Panda; Reinforcements, Bunny.
    var tutorial_enemies = [
        vv_tutorial_take_enemy_card(enemy_deck, "bunny"),
        vv_tutorial_take_enemy_card(enemy_deck, "reinforcements"),
        vv_tutorial_take_enemy_card(enemy_deck, "red_panda"),
        vv_tutorial_take_enemy_card(enemy_deck, "direct_assault"),
        vv_tutorial_take_enemy_card(enemy_deck, "corgi")
    ];
    for (var enemy_i = 0; enemy_i < array_length(tutorial_enemies); enemy_i++) {
        if (!is_undefined(tutorial_enemies[enemy_i])) array_push(enemy_deck, tutorial_enemies[enemy_i]);
    }
    minions = [undefined, undefined];
    tutorial_escape_seen = false;
    tutorial_minion_defeated = false;
    tutorial_leader_attacked = false;
    tutorial_final_leader_attacked = false;
    tutorial_complete_prompt = false;
    tutorial_entry_notice_timer = 0;
    tutorial_move_notice_timer = 0;
    vv_tutorial_set_state(TutorialStep.Intro, "result", "GUIDED TRAINING",
        "This battle teaches the turn\none step at a time.\n\nFollow the highlighted action.\n\nWATCH means the game is showing\nyou something automatically.\n\nNothing will advance while you\nare reading a training message.", true);
}

function vv_tutorial_target_hp() {
    for (var minion_i = 0; minion_i < 2; minion_i++) {
        if (!is_undefined(minions[minion_i])) return minions[minion_i].hp;
    }
    return 0;
}

function vv_tutorial_complete() {
    if (!tutorial_complete_prompt) return false;
    vv_settings_complete_guided_tutorial();
    vv_tutorial_restore_setup();
    tutorial_mode = false;
    tutorial_complete_prompt = false;
    if (!reset_game()) return false;
    setup_active = false;
    return true;
}
