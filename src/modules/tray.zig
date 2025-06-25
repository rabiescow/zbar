const std = @import("std");

// GIO is the GLib library that provides high-level D-Bus support.
// It's included as part of the "gtk4" pkg-config package.
const c = @cImport({
    @cInclude("gtk/gtk.h");
    @cInclude("gio/gio.h");
});

// A struct to hold the state for a single tray icon.
const TrayItem = struct {
    widget: *c.GtkWidget,
    menu: ?*c.GtkWidget = null,
};

// The main Tray module struct.
pub const Tray = struct {
    box: *c.GtkWidget,

    pub fn init() *Tray {
        const tray_box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 5);
        var css_classes = [_]?[*:0]const u8{ "module-box", "tray", null };
        c.gtk_widget_set_css_classes(@ptrCast(tray_box), @ptrCast(&css_classes));

        const self = std.heap.c_allocator.create(Tray) catch @panic("oom");
        self.* = .{ .box = @ptrCast(tray_box) };

        _ = c.g_bus_watch_name(
            c.G_BUS_TYPE_SESSION,
            "org.kde.StatusNotifierWatcher",
            c.G_BUS_NAME_WATCHER_FLAGS_NONE,
            @ptrCast(&on_name_appeared),
            @ptrCast(&on_name_vanished),
            @ptrCast(self),
            null,
        );

        return self;
    }

    fn add_tray_item(self: *Tray, service_name: []const u8) void {
        std.log.info("Adding tray item for service: {s}", .{service_name});
        const icon = c.gtk_image_new_from_icon_name("dialog-information-symbolic");
        c.gtk_box_append(@ptrCast(self.box), @ptrCast(icon));
    }

    // This function is called when the StatusNotifierWatcher service appears on D-Bus.
    fn on_name_appeared(connection: *c.GDBusConnection, _: [*c]const u8, _: [*c]const u8, data: ?*anyopaque) callconv(.C) void {
        const self: *Tray = @ptrCast(@alignCast(data orelse unreachable));
        std.log.info("Tray watcher appeared, connecting...", .{});

        // Now that the watcher service is available, we subscribe to its signals.
        // We are interested in the "StatusNotifierItemRegistered" signal, which tells
        // us when a new application wants to show a tray icon.
        const registered_items = c.g_dbus_connection_call_sync(
            connection,
            "org.kde.StatusNotifierWatcher",
            "/StatusNotifierWatcher",
            "org.freedesktop.DBus.Properties",
            "Get",
            c.g_variant_new("(ss)", "org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierTime"),
            null,
            c.G_DBUS_CALL_FLAGS_NONE,
            -1,
            null,
            null,
        );

        if (registered_items != null) {
            defer c.g_variant_unref(registered_items);

            var variant: *c.GVariant = undefined;
            c.g_variant_get(registered_items, "(v)", &variant);
            defer c.g_variant_unref(variant);

            const iter = c.g_variant_iter_new(variant);
            var service_name_ptr: [*c]const u8 = undefined;
            while (c.g_variant_iter_next(iter, "s", &service_name_ptr) != 0) {
                self.add_tray_item(std.mem.span(service_name_ptr));
            }
            c.g_variant_iter_free(iter);
        }

        _ = c.g_dbus_connection_signal_subscribe(connection, "org.kde.StatusNotifierWatcher", "org.kde.StatusNotifierWatcher", "StatusNotifierItemRegistered", "/StatusNotifierWatcher", null, c.G_DBUS_SIGNAL_FLAGS_NONE, @ptrCast(&on_item_registered), @ptrCast(self), null);
    }

    // This function is called when a tray application disconnects.
    fn on_name_vanished(_: *c.GDBusConnection, _: [*c]const u8, data: ?*anyopaque) callconv(.C) void {
        _ = data;
        std.log.info("Tray watcher vanished.", .{});
        // In a full implementation, we would clear out all existing tray icons here.
    }

    // This is the callback that fires when a new tray icon is registered.
    fn on_item_registered(
        _: *c.GDBusConnection,
        _: [*c]const u8,
        _: [*c]const u8,
        _: [*c]const u8,
        _: [*c]const u8,
        parameters: *c.GVariant,
        _: ?*anyopaque,
        user_data: ?*anyopaque,
    ) callconv(.C) void {
        const self: *Tray = @ptrCast(@alignCast(user_data orelse unreachable));

        // The signal provides the D-Bus service name of the new tray item as a string.
        var service_name_ptr: [*c]const u8 = undefined;
        c.g_variant_get(parameters, "(&s)", &service_name_ptr);
        const service_name = std.mem.span(service_name_ptr);

        std.log.info("New tray item registered: {s}", .{service_name});

        const icon = c.gtk_image_new_from_icon_name("dialog-information-symbolic");
        c.gtk_box_append(@ptrCast(self.box), @ptrCast(icon));
    }
};
