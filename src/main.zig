// A minimal bar using the GTK toolkit.
const std = @import("std");
const Clock = @import("modules/clock.zig").Clock;
const Separator = @import("modules/separator.zig").Separator;

// Import the C headers for GTK4 and the GTK Layer Shell library.
const c = @cImport({
    @cInclude("gtk/gtk.h");
    @cInclude("gtk-layer-shell/gtk-layer-shell.h");
});

// This is the callback function that runs when the application is activated.
// It's where we create our window.
fn activate(app: *c.GtkApplication, _: ?*anyopaque) callconv(.C) void {
    // Create a new GTK window.
    const window = c.gtk_application_window_new(app);
    if (window == null) {
        std.log.err("failed to create gtk window", .{});
        return;
    }
    c.gtk_window_set_title(@ptrCast(window), "zigbar");
    c.gtk_window_set_default_size(@ptrCast(window), -1, 30); // Width -1 (natural), Height 30

    // Initialize the layer shell for this window.
    c.gtk_layer_init_for_window(@ptrCast(window));
    c.gtk_layer_set_layer(@ptrCast(window), c.GTK_LAYER_SHELL_LAYER_TOP);
    c.gtk_layer_set_anchor(@ptrCast(window), c.GTK_LAYER_SHELL_EDGE_TOP, 1);
    c.gtk_layer_set_anchor(@ptrCast(window), c.GTK_LAYER_SHELL_EDGE_LEFT, 1);
    c.gtk_layer_set_anchor(@ptrCast(window), c.GTK_LAYER_SHELL_EDGE_RIGHT, 1);
    c.gtk_layer_set_exclusive_zone(@ptrCast(window), 30);

    const main_box = c.gtk_center_box_new();
    c.gtk_window_set_child(@ptrCast(window), @ptrCast(main_box));

    const end_box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0);
    c.gtk_center_box_set_end_widget(@ptrCast(main_box), @ptrCast(end_box));

    const clock_color = 0xFAB387;
    const sep1 = Separator.init(clock_color);
    const clock_module = Clock.init();

    c.gtk_box_append(@ptrCast(end_box), @ptrCast(sep1.widget));
    c.gtk_box_append(@ptrCast(end_box), @ptrCast(clock_module.box));
    c.gtk_window_present(@ptrCast(window));
}

// A simple CSS provider to style the bar.
const css =
    \\* {
    \\    border: none;
    \\    border-radius: 0;
    \\}
    \\
    \\window {
    \\    background-color: #222222; /* Set the base background on the window */
    \\}
    \\
    \\.module-box {
    \\    padding: 0 10px;
    \\}
    \\
    \\box.clock {
    \\    background-color: #FAB387;
    \\    color: #1E1E2E;
    \\    font-weight: bold;
    \\}
    \\
    \\label {
    \\    font-family: monospace;
    \\}
;

// This function loads our CSS when the application starts.
fn on_startup(_: *c.GtkApplication, _: ?*anyopaque) callconv(.C) void {
    const provider = c.gtk_css_provider_new();
    c.gtk_css_provider_load_from_string(provider, css.ptr);
    c.gtk_style_context_add_provider_for_display(
        c.gdk_display_get_default(),
        @ptrCast(provider),
        c.GTK_STYLE_PROVIDER_PRIORITY_APPLICATION,
    );
}

pub fn main() !void {
    // Create a new GTK application.
    const app = c.gtk_application_new("com.example.zigbar", c.G_APPLICATION_DEFAULT_FLAGS);
    if (app == null) {
        std.log.err("failed to create gtk application", .{});
        return;
    }

    // Connect our functions to the application's signals.
    _ = c.g_signal_connect_data(@ptrCast(app), "startup", @ptrCast(&on_startup), null, null, 0);
    _ = c.g_signal_connect_data(@ptrCast(app), "activate", @ptrCast(&activate), null, null, 0);

    // Run the application. This starts the GTK event loop and blocks until the app exits.
    const status = c.g_application_run(@ptrCast(app), 0, null);

    // Clean up.
    _ = c.g_object_unref(@ptrCast(app));

    if (status != 0) {
        return error.GtkAppFailed;
    }
}
