display_set_gui_size(1280, 720);
randomize();
gpu_set_texfilter(true);
vv_ui_init();
enemy_leader = make_enemy_leader();
reset_game();
vv_assets_init();
vv_assets_load_initial();
