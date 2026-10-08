# Native currency wrapping fix

The actual pause screen displayed 200币 vertically, one character per line, because generic label() enabled word wrapping and the expanding time label consumed the row. Preserved native before screenshot: ../manual_route/pause-money-wrap-defect.png.

The shared ROLE_QUANTITY style now disables autowrap for Labels, giving HBox layout the true single-line minimum width. This narrowly fixes the same quantity role used by pause/inventory/trade; it does not change wording, balances, font files or page widths.

Godot 4.7.2 headless: pause_ui_test.gd 14/0 (new real layout checks in all three requested sizes), inventory_ui_test.gd 9/0, shop_trade_ui_test.gd 20/0; all exit 0. Command: `Godot --headless --path game --script res://tests/<name>.gd`.

Actual paused saved game through CUA at 1280×720, 1920×1080, 1366×768 shows readable single-line `200 币`, balanced time/money row and accessible controls. Full native-window PNGs are adjacent; not viewport-only crops. Final style approval remains with the user.
