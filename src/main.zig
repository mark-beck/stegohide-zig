const std = @import("std");
const decoder = @import("decode.zig");
const encoder = @import("encode.zig");
const clap = @import("clap");
const png = @cImport({
    @cInclude("spng.h");
});

pub fn main() !void {
    const params = comptime [_]clap.Param(clap.Help){
        clap.parseParam("-h, --help             Display this help and exit.") catch unreachable,
        clap.parseParam("-m, --message <STR>    message to encode") catch unreachable,
        clap.parseParam("-o, --out     <STR>    file to output") catch unreachable,
        clap.parseParam("<FILE>                 file to read") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parse(clap.Help, &params, .{ .diagnostic = &diag }) catch |err| {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer args.deinit();

    if (args.flag("--help") or args.positionals().len != 1) {
        try clap.help(std.io.getStdErr().writer(), &params);
    } else {
        if (args.option("--message")) |message| {
            if (args.option("--out")) |outfile| {
                try encoder.encode(args.positionals()[0], message, outfile);
            } else {
                try encoder.encode(args.positionals()[0], message, args.positionals()[0]);
            }
        } else {
            try decoder.decode(args.positionals()[0]);
        }
    }
}
