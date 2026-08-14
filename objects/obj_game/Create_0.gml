display_set_gui_size(1280, 720);
randomize();
gpu_set_texfilter(true);

COL_BG = make_color_rgb(18, 25, 36);
COL_PANEL = make_color_rgb(31, 42, 57);
COL_EDGE = make_color_rgb(91, 111, 139);
COL_TEXT = make_color_rgb(239, 244, 252);
COL_MUTED = make_color_rgb(164, 178, 198);
COL_ACCENT = make_color_rgb(70, 190, 180);
COL_DANGER = make_color_rgb(224, 82, 92);
COL_GOLD = make_color_rgb(242, 190, 72);
COL_LEGAL = make_color_rgb(114, 221, 130);

leader_rect = {x:16, y:16, w:520, h:99};
minion_rects = [{x:560, y:50, w:170, h:245}, {x:780, y:50, w:170, h:245}];
build_rects = [];
hand_rects = [];
for (var layout_i = 0; layout_i < 3; layout_i++) {
    array_push(build_rects, {x:240 + layout_i * 245, y:305, w:240, h:200});
    array_push(hand_rects, {x:240 + layout_i * 245, y:520, w:240, h:195});
}
action_rect = {x:1025, y:628, w:235, h:68};
restart_rect = {x:525, y:470, w:230, h:70};

debug_event_log = false;
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
