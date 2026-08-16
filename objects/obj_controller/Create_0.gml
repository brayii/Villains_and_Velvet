display_set_gui_size(1280, 720);
randomize();
gpu_set_texfilter(true);
vv_ui_init();
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
