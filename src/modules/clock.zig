const std = @import("std");
const c = @cImport(@cInclude("gtk/gtk.h"));
const ctime = @cImport(@cInclude("time.h"));

pub const Clock = struct {
    box: *c.GtkWidget,
    label: *c.GtkWidget,

    pub fn init() *Clock {
        const module_box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 0);
        const time_label = c.gtk_label_new(null);

        c.gtk_box_append(@ptrCast(module_box), @ptrCast(time_label));
        var css_classes = [_]?[*:0]const u8{ "module-box", "clock", null };
        c.gtk_widget_set_css_classes(@ptrCast(module_box), @ptrCast(&css_classes));

        const self = std.heap.c_allocator.create(Clock) catch @panic("failed to allocate clock");
        self.* = .{
            .box = @ptrCast(module_box),
            .label = @ptrCast(time_label),
        };

        self.update();
        _ = c.g_timeout_add_seconds(1, @ptrCast(&update_callback), @ptrCast(self));
        return self;
    }

    pub fn update_callback(data: ?*anyopaque) callconv(.C) c.gboolean {
        const self: *Clock = @ptrCast(@alignCast(data orelse unreachable));
        self.update();
        return @intFromBool(c.G_SOURCE_CONTINUE);
    }

    pub fn update(self: *Clock) void {
        var buf: [100]u8 = undefined;
        var now: ctime.time_t = undefined;
        _ = ctime.time(&now);
        const timeinfo = ctime.localtime(&now);
        const time_format = c.strftime(&buf, buf.len, "%H:%M:%S", @ptrCast(timeinfo));
        if (time_format > 0) {
            c.gtk_label_set_text(@ptrCast(self.label), &buf);
        }
    }
};
