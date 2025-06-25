const std = @import("std");
const c = @cImport(@cInclude("gtk/gtk.h"));

pub const Shapes = struct {
    widget: *c.GtkWidget,

    const DrawData = struct {
        r: f64,
        g: f64,
        b: f64,
    };

    pub fn init(fg_color: u32, draw_func: fn (*c.GtkDrawingArea, *c.cairo_t, c_int, c_int, ?*anyopaque) callconv(.c) void) *Shapes {
        const drawing_area = c.gtk_drawing_area_new();
        const widget: *c.GtkWidget = @ptrCast(drawing_area);

        c.gtk_widget_set_size_request(widget, 15, -1);

        const fg_r = @as(f64, @floatFromInt(fg_color >> 16 & 0xFF)) / 255.0;
        const fg_g = @as(f64, @floatFromInt(fg_color >> 8 & 0xFF)) / 255.0;
        const fg_b = @as(f64, @floatFromInt(fg_color & 0xFF)) / 255.0;

        const draw_data_fg = std.heap.c_allocator.create(DrawData) catch @panic("oom");
        draw_data_fg.* = .{ .r = fg_r, .g = fg_g, .b = fg_b };

        c.gtk_drawing_area_set_draw_func(@ptrCast(drawing_area), @ptrCast(&draw_func), @ptrCast(draw_data_fg), null);

        const self = std.heap.c_allocator.create(Shapes) catch @panic("oom");
        self.* = .{ .widget = widget };
        return self;
    }

    pub fn draw_forward_triangle(
        _: *c.GtkDrawingArea,
        cr: *c.cairo_t,
        width: c_int,
        height: c_int,
        data: ?*anyopaque,
    ) callconv(.C) void {
        const draw_data: *const DrawData = @ptrCast(@alignCast(data orelse unreachable));
        c.cairo_set_source_rgb(cr, draw_data.r, draw_data.g, draw_data.b);
        c.cairo_move_to(cr, 0, 0);
        c.cairo_line_to(cr, @as(f64, @floatFromInt(width)), 0);
        c.cairo_line_to(cr, @as(f64, @floatFromInt(width)), @as(f64, @floatFromInt(height)));
        c.cairo_close_path(cr);

        c.cairo_fill(cr);
    }

    pub fn draw_reverse_triangle(
        _: *c.GtkDrawingArea,
        cr: *c.cairo_t,
        width: c_int,
        height: c_int,
        data: ?*anyopaque,
    ) callconv(.C) void {
        const draw_data: *const DrawData = @ptrCast(@alignCast(data orelse unreachable));
        c.cairo_set_source_rgb(cr, draw_data.r, draw_data.g, draw_data.b);
        c.cairo_move_to(cr, 0, 0);
        c.cairo_line_to(cr, @as(f64, @floatFromInt(width)), @as(f64, @floatFromInt(height)));
        c.cairo_line_to(cr, 0, @as(f64, @floatFromInt(height)));
        c.cairo_close_path(cr);

        c.cairo_fill(cr);
    }
};
