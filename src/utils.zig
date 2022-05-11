const std = @import("std");
pub const spng = @cImport({
    @cInclude("spng.h");
});

pub const Image = struct {
    bytes: []u8,
    alpha: ?[]u8,
    ihdr: spng.spng_ihdr,

    pub fn stripAlpha(image: *Image, alloc: std.mem.Allocator) !void {
        if (image.ihdr.color_type == 6) {
            const rgb_bytes = try alloc.alloc(u8, image.bytes.len - image.bytes.len / 4);
            const alpha_bytes = try alloc.alloc(u8, image.bytes.len / 4);

            var rgb_index: usize = 0;
            var alpha_index: usize = 0;
            for (image.bytes) |byte, i| {
                if (i % 4 == 3) {
                    alpha_bytes[alpha_index] = byte;
                    alpha_index += 1;
                } else {
                    rgb_bytes[rgb_index] = byte;
                    rgb_index += 1;
                }
            }

            alloc.free(image.bytes);
            image.bytes = rgb_bytes;
            image.alpha = alpha_bytes;
        }
    }

    pub fn addAlpha(self: *Image, alloc: std.mem.Allocator) !void {
        if (self.alpha) |alpha| {
            const buffer = try alloc.alloc(u8, self.bytes.len + alpha.len);
            var rgb_index: usize = 0;
            var alpha_index: usize = 0;
            for (buffer) |_, i| {
                if (i % 4 == 3) {
                    buffer[i] = alpha[alpha_index];
                    alpha_index += 1;
                } else {
                    buffer[i] = self.bytes[rgb_index];
                    rgb_index += 1;
                }
            }
            alloc.free(self.bytes);
            alloc.free(alpha);
            self.bytes = buffer;
            self.alpha = null;
        }
    }
};

pub fn openFile(path: [*c]const u8) !*spng.FILE {
    var file = spng.fopen(path, "rb");
    if (file == 0) {
        return error.FileNotFound;
    }
    return file;
}

pub fn openFileW(path: [*c]const u8) !*spng.FILE {
    var file = spng.fopen(path, "wb");
    if (file == 0) {
        return error.FileNotFound;
    }
    return file;
}

pub fn closeFile(file: [*c]spng.FILE) void {
    const err = spng.fclose(file);
    if (err != 0) {
        return;
    }
}
