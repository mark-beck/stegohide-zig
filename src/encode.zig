const std = @import("std");
const util = @import("utils.zig");
const decoder = @import("decode.zig");
const spng = util.spng;

const encodeError = error{
    writefile,
    setfile,
    ihdr,
};

fn encodePng(alloc: std.mem.Allocator, image: *util.Image, outpath: []const u8) !void {
    var ctx = spng.spng_ctx_new(spng.SPNG_CTX_ENCODER);

    try image.addAlpha(alloc);

    var outfile = try util.openFileW(try std.cstr.addNullByte(alloc, outpath));
    defer util.closeFile(outfile);

    // var outfile = spng.fopen(try std.cstr.addNullByte(alloc, outpath), "wb");

    if (spng.spng_set_png_file(ctx, outfile) != 0) {
        std.log.err("setfile error", .{});
        return encodeError.setfile;
    }

    if (spng.spng_set_ihdr(ctx, @ptrCast([*c]spng.spng_ihdr, &image.ihdr)) != 0) {
        std.log.err("ihdr error: ", .{});
        return encodeError.ihdr;
    }

    var res = spng.spng_encode_image(ctx, @ptrCast(*const anyopaque, image.bytes), image.bytes.len, spng.SPNG_FMT_PNG, spng.SPNG_ENCODE_FINALIZE);

    spng.spng_ctx_free(ctx);

    if (res != 0) {
        std.log.err("writefile error: {}", .{res});
        return encodeError.writefile;
    }
}

fn split_message(alloc: std.mem.Allocator, message: []const u8) ![]const u8 {
    var buffer = try alloc.alloc(u8, message.len * 4 + 32);

    const magic = "BHTM";
    const len_bytes = std.mem.asBytes(&std.mem.nativeToBig(u32, @intCast(u32, message.len)));

    for (magic) |s, i| {
        buffer[i * 4 + 0] = (s >> 6) & 3;
        buffer[i * 4 + 1] = (s >> 4) & 3;
        buffer[i * 4 + 2] = (s >> 2) & 3;
        buffer[i * 4 + 3] = (s >> 0) & 3;
    }

    for (len_bytes) |s, i| {
        buffer[i * 4 + 16] = (s >> 6) & 3;
        buffer[i * 4 + 17] = (s >> 4) & 3;
        buffer[i * 4 + 18] = (s >> 2) & 3;
        buffer[i * 4 + 19] = (s >> 0) & 3;
    }

    for (message) |s, i| {
        buffer[i * 4 + 32] = (s >> 6) & 3;
        buffer[i * 4 + 33] = (s >> 4) & 3;
        buffer[i * 4 + 34] = (s >> 2) & 3;
        buffer[i * 4 + 35] = (s >> 0) & 3;
    }
    return buffer;
}

pub fn encode(path: []const u8, message: []const u8, outfile: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();
    const file = try util.openFile(try std.cstr.addNullByte(alloc, path));
    defer util.closeFile(file);

    var image = try decoder.decodePng(alloc, file);
    defer alloc.free(image.bytes);

    const message_buffer = try split_message(alloc, message);
    defer alloc.free(message_buffer);

    for (message_buffer) |byte, i| {
        image.bytes[i] = image.bytes[i] & 0b11111100 | byte;
        std.debug.print("{} ", .{byte});
    }
    std.debug.print("\n", .{});

    try encodePng(alloc, &image, outfile);
}
