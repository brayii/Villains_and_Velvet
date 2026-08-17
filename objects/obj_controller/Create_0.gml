display_set_gui_size(1280, 720);
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
    var validation_self_checks = run_content_validation_self_checks(
        available_leaders, available_scenarios, available_minion_sets, available_heroes);
    if (!validation_self_checks.valid) content_registry_validation = validation_self_checks;
}
if (content_registry_validation.valid) {
    var ai_scoring_self_checks = enemy_ai_run_scoring_self_checks(available_heroes);
    if (!ai_scoring_self_checks.valid) content_registry_validation = ai_scoring_self_checks;
}
if (content_registry_validation.valid) {
    var ai_selection_self_checks = enemy_ai_run_selection_self_checks(available_heroes);
    if (!ai_selection_self_checks.valid) content_registry_validation = ai_selection_self_checks;
}
if (content_registry_validation.valid) {
    var ai_oracle_self_checks = enemy_ai_run_oracle_self_checks(available_heroes);
    if (!ai_oracle_self_checks.valid) content_registry_validation = ai_oracle_self_checks;
}
if (content_registry_validation.valid) {
    var ai_release_self_checks = enemy_ai_run_release_self_checks();
    if (!ai_release_self_checks.valid) content_registry_validation = ai_release_self_checks;
}
if (content_registry_validation.valid) {
    var ai_data_self_checks = vv_ai_data_run_self_checks();
    if (!ai_data_self_checks.valid) content_registry_validation = ai_data_self_checks;
}
if (content_registry_validation.valid) {
    var ai_learning_self_checks = enemy_ai_run_conditional_learning_self_checks(available_heroes);
    if (!ai_learning_self_checks.valid) content_registry_validation = ai_learning_self_checks;
}
if (content_registry_validation.valid) {
    var advance_self_checks = run_minion_advance_self_checks();
    if (!advance_self_checks.valid) content_registry_validation = advance_self_checks;
}
if (content_registry_validation.valid) {
    var reward_self_checks = enemy_ai_run_reward_self_checks();
    if (!reward_self_checks.valid) content_registry_validation = reward_self_checks;
}
if (content_registry_validation.valid) {
    var health_learning_self_checks = enemy_ai_run_health_learning_self_checks();
    if (!health_learning_self_checks.valid) content_registry_validation = health_learning_self_checks;
}
if (content_registry_validation.valid) {
    var rng_self_checks = enemy_ai_run_rng_self_checks();
    if (!rng_self_checks.valid) content_registry_validation = rng_self_checks;
}
if (content_registry_validation.valid) {
    var exploration_self_checks = enemy_ai_run_exploration_self_checks();
    if (!exploration_self_checks.valid) content_registry_validation = exploration_self_checks;
}
if (content_registry_validation.valid) {
    var evaluation_self_checks = enemy_ai_run_evaluation_self_checks(available_heroes);
    if (!evaluation_self_checks.valid) content_registry_validation = evaluation_self_checks;
}
if (content_registry_validation.valid) {
    var stability_self_checks = vv_ai_data_run_stability_self_checks();
    if (!stability_self_checks.valid) content_registry_validation = stability_self_checks;
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
