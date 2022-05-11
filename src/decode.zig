const std = @import("std");
const util = @import("utils.zig");
const spng = util.spng;

const pngDecodeError = error{ cantSetCrc, cantSetFile, noSize, cantDecode, noIhdr };

pub fn decodePng(alloc: std.mem.Allocator, file: *spng.FILE) !util.Image {
    var ctx = spng.spng_ctx_new(0);
    var ihdr: spng.spng_ihdr = undefined;

    if (spng.spng_set_crc_action(ctx, spng.SPNG_CRC_USE, spng.SPNG_CRC_USE) != 0) {
        return pngDecodeError.cantSetCrc;
    }

    if (spng.spng_set_png_file(ctx, file) != 0) {
        return pngDecodeError.cantSetFile;
    }

    if (spng.spng_get_ihdr(ctx, &ihdr) != 0) {
        return pngDecodeError.noIhdr;
    }

    var colortype = spng.SPNG_FMT_RGB8;

    if (ihdr.color_type == 6) {
        colortype = spng.SPNG_FMT_RGBA8;
    }

    var out_size: usize = 0;
    if (spng.spng_decoded_image_size(ctx, colortype, &out_size) != 0) {
        return pngDecodeError.noSize;
    }

    const png_buffer = try alloc.alloc(u8, out_size);

    const r = spng.spng_decode_image(ctx, @ptrCast(*anyopaque, png_buffer), out_size, colortype, 0);
    if (r != 0) {
        std.log.err("{s}", .{spng.spng_strerror(r)});
        return pngDecodeError.cantDecode;
    }

    spng.spng_ctx_free(ctx);

    var image = util.Image{
        .bytes = png_buffer,
        .alpha = null,
        .ihdr = ihdr,
    };

    try image.stripAlpha(alloc);

    return image;
}

fn getMessageLen(bytes: []u8) u32 {
    return std.mem.bigToNative(u32, std.mem.bytesToValue(u32, bytes[4..8]));
}

fn decodeMessage(bytes: []u8) ![]u8 {
    if (!std.mem.eql(u8, bytes[0..4], "BHTM")) {
        return error.NoMagic;
    }
    const message_len = getMessageLen(bytes);
    return bytes[8 .. 8 + message_len];
}

pub fn decode(path: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const file = try util.openFile(try std.cstr.addNullByte(alloc, path));
    defer util.closeFile(file);

    const png_buffer = (try decodePng(alloc, file)).bytes;
    defer alloc.free(png_buffer);

    var ix: usize = 0;
    const decoded = try alloc.alloc(u8, png_buffer.len / 4);
    // defer alloc.free(decoded);

    while (ix < png_buffer.len - 3) : (ix += 4) {
        const v1 = (png_buffer[ix + 0] & 3) << 6;
        const v2 = (png_buffer[ix + 1] & 3) << 4;
        const v3 = (png_buffer[ix + 2] & 3) << 2;
        const v4 = (png_buffer[ix + 3] & 3) << 0;
        decoded[ix / 4] = v1 + v2 + v3 + v4;
    }

    const message = try decodeMessage(decoded);
    std.debug.print("{s}\n", .{message});
}
