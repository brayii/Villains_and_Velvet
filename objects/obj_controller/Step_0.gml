// Automatic progress pauses for the full card gesture, including the first touch.
vv_ai_data_update();
var card_gesture_active = !is_undefined(card_popup)
    || pointer_card_down;
var opening_match_menu = false;

if (!card_gesture_active && !setup_active && !game_over
&& device_mouse_check_button_pressed(0, mb_left)) {
    var gesture_x = device_mouse_x_to_gui(0);
    var gesture_y = device_mouse_y_to_gui(0);
    opening_match_menu = !match_menu_active && point_in_rect(gesture_x, gesture_y, match_menu_rect);
    card_gesture_active = !is_undefined(ui_card_at_point(gesture_x, gesture_y));
}

if (!card_gesture_active && !match_menu_active && !opening_match_menu) vv_turn_update();
vv_ui_handle_input();
