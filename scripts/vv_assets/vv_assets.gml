/// Ownership, loading, caching, and cleanup for dynamically loaded artwork.

function vv_assets_init() {
    art_sprites = {};
    background_art_sprite = -1;
    leader_art_sprite = -1;
}

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

function vv_assets_load_initial() {
    background_art_sprite = get_art_sprite(ART_BACKGROUND);
    leader_art_sprite = is_undefined(enemy_leader) ? -1 : get_art_sprite(enemy_leader.art_file);
}

function vv_assets_cleanup() {
    var keys = variable_struct_get_names(art_sprites);
    for (var key_i = 0; key_i < array_length(keys); key_i++) {
        var sprite_id = variable_struct_get(art_sprites, keys[key_i]);
        if (sprite_id >= 0 && sprite_exists(sprite_id)) sprite_delete(sprite_id);
    }
    art_sprites = {};
    background_art_sprite = -1;
    leader_art_sprite = -1;
}
