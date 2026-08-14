display_set_gui_size(1280, 720);
randomize();
gpu_set_texfilter(true);
vv_ui_init();
art_sprites = {};
enemy_leader = make_enemy_leader();

function art_cache_key(_file) {
    var key = string_replace_all(_file, "/", "_");
    key = string_replace_all(key, ".", "_");
    return key;
}

function get_art_sprite(_file) {
    if (_file == "") return -1;
    var key = art_cache_key(_file);
    if (variable_struct_exists(art_sprites, key)) return variable_struct_get(art_sprites, key);

    var sprite_id = -1;
    var full_path = working_directory + _file;
    if (file_exists(full_path)) sprite_id = sprite_add(full_path, 1, false, true, 0, 0);
    else log_add("Artwork could not be loaded: " + _file);

    variable_struct_set(art_sprites, key, sprite_id);
    return sprite_id;
}

reset_game();
background_art_sprite = get_art_sprite(ART_BACKGROUND);
leader_art_sprite = get_art_sprite(enemy_leader.art_file);
