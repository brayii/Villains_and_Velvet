ui_canvas_height = os_type == os_android
    ? clamp(round(1280 * display_get_height() / display_get_width()), 720, 800)
    : 720;
display_set_gui_size(1280, ui_canvas_height);
randomize();
gpu_set_texfilter(true);
vv_ui_init();
vv_settings_init();
vv_ai_data_init();
enemy_ai_baseline_init();
available_leaders = make_enemy_leader_registry();
available_scenarios = make_scenario_registry();
available_minion_sets = make_minion_set_registry();
available_heroes = make_hero_definitions();
content_registry_validation = validate_content_registries(
    available_leaders, available_scenarios, available_minion_sets, available_heroes);
if (content_registry_validation.valid) {
    var ai_release_self_checks = enemy_ai_run_release_self_checks();
    if (!ai_release_self_checks.valid) content_registry_validation = ai_release_self_checks;
}
if (content_registry_validation.valid) {
    var ai_data_self_checks = vv_ai_data_run_self_checks();
    if (!ai_data_self_checks.valid) content_registry_validation = ai_data_self_checks;
}
if (VV_DEVELOPMENT_SELF_CHECKS && content_registry_validation.valid) {
    var development_checks = [
        run_content_validation_self_checks(
            available_leaders, available_scenarios, available_minion_sets, available_heroes),
        enemy_ai_run_scoring_self_checks(available_heroes),
        enemy_ai_run_selection_self_checks(available_heroes),
        enemy_ai_run_oracle_self_checks(available_heroes),
        enemy_ai_run_conditional_learning_self_checks(available_heroes),
        run_minion_advance_self_checks(),
        run_full_assault_self_checks(available_scenarios, available_minion_sets),
        enemy_ai_run_reward_self_checks(),
        enemy_ai_run_health_learning_self_checks(),
        enemy_ai_run_rng_self_checks(),
        enemy_ai_run_exploration_self_checks(),
        enemy_ai_run_evaluation_self_checks(available_heroes),
        vv_ai_data_run_stability_self_checks(),
        enemy_ai_run_future_content_self_checks()
    ];
    for (var check_i = 0; check_i < array_length(development_checks); check_i++) {
        if (!development_checks[check_i].valid) {
            content_registry_validation = development_checks[check_i];
            break;
        }
    }
}
if (!content_registry_validation.valid) {
    show_debug_message("STARTUP VALIDATION FAILED: " + content_registry_validation.message);
}
selected_leader_index = content_registry_validation.valid ? 0 : -1;
selected_scenario_index = content_registry_validation.valid ? 0 : -1;
selected_minion_set_index = content_registry_validation.valid ? 0 : -1;
enemy_leader = content_registry_validation.valid ? available_leaders[0] : undefined;
enemy_scenario = content_registry_validation.valid ? available_scenarios[0] : undefined;
enemy_minion_set = content_registry_validation.valid ? available_minion_sets[0] : undefined;
selected_hero_ids = content_registry_validation.valid ? make_default_hero_selection(available_heroes) : [];
enemy_event_selection = content_registry_validation.valid
    ? make_default_enemy_event_selection(enemy_leader, enemy_scenario)
    : {leader_strikes:[], twists:[]};
log_lines = [];
setup_active = true;
phase = "setup";
refresh_setup_validation();
vv_assets_init();
vv_assets_load_initial();
