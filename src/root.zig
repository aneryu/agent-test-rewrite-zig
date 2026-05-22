//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

/// This is a documentation comment to explain the `printAnotherMessage` function below.
///
/// Accepting an `Io.Writer` instance is a handy way to write reusable code.
pub fn printAnotherMessage(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("Run `zig build test` to run the tests.\n", .{});
}

// --- dtoa C library integration ---

pub const c = struct {
    pub const JSDTOATempMem = @import("dtoa.zig").JSDTOATempMem;
    pub const JSATODTempMem = @import("dtoa.zig").JSATODTempMem;
    
    pub const JS_DTOA_MAX_DIGITS = @import("dtoa.zig").JS_DTOA_MAX_DIGITS;
    pub const JS_DTOA_FORMAT_FREE = @import("dtoa.zig").JS_DTOA_FORMAT_FREE;
    pub const JS_DTOA_FORMAT_FIXED = @import("dtoa.zig").JS_DTOA_FORMAT_FIXED;
    pub const JS_DTOA_FORMAT_FRAC = @import("dtoa.zig").JS_DTOA_FORMAT_FRAC;
    pub const JS_DTOA_FORMAT_MASK = @import("dtoa.zig").JS_DTOA_FORMAT_MASK;
    pub const JS_DTOA_EXP_AUTO = @import("dtoa.zig").JS_DTOA_EXP_AUTO;
    pub const JS_DTOA_EXP_ENABLED = @import("dtoa.zig").JS_DTOA_EXP_ENABLED;
    pub const JS_DTOA_EXP_DISABLED = @import("dtoa.zig").JS_DTOA_EXP_DISABLED;
    pub const JS_DTOA_EXP_MASK = @import("dtoa.zig").JS_DTOA_EXP_MASK;
    pub const JS_DTOA_MINUS_ZERO = @import("dtoa.zig").JS_DTOA_MINUS_ZERO;
    
    pub const JS_ATOD_INT_ONLY = @import("dtoa.zig").JS_ATOD_INT_ONLY;
    pub const JS_ATOD_ACCEPT_BIN_OCT = @import("dtoa.zig").JS_ATOD_ACCEPT_BIN_OCT;
    pub const JS_ATOD_ACCEPT_LEGACY_OCTAL = @import("dtoa.zig").JS_ATOD_ACCEPT_LEGACY_OCTAL;
    pub const JS_ATOD_ACCEPT_UNDERSCORES = @import("dtoa.zig").JS_ATOD_ACCEPT_UNDERSCORES;

    pub const js_dtoa_max_len = @import("dtoa.zig").js_dtoa_max_len;
    pub const js_dtoa = @import("dtoa.zig").js_dtoa;
    pub const js_atod = @import("dtoa.zig").js_atod;
    pub const u32toa = @import("dtoa.zig").u32toa;
    pub const i32toa = @import("dtoa.zig").i32toa;
    pub const u64toa = @import("dtoa.zig").u64toa;
    pub const i64toa = @import("dtoa.zig").i64toa;
    pub const u64toa_radix = @import("dtoa.zig").u64toa_radix;
    pub const i64toa_radix = @import("dtoa.zig").i64toa_radix;
};

pub const DtoaError = error{
    BufferTooSmall,
    InvalidRadix,
    FormatError,
};

pub fn u32toa(buf: []u8, n: u32) ![]const u8 {
    if (buf.len < 10) return error.BufferTooSmall;
    const len = c.u32toa(buf.ptr, n);
    return buf[0..len];
}

pub fn i32toa(buf: []u8, n: i32) ![]const u8 {
    if (buf.len < 11) return error.BufferTooSmall;
    const len = c.i32toa(buf.ptr, n);
    return buf[0..len];
}

pub fn u64toa(buf: []u8, n: u64) ![]const u8 {
    if (buf.len < 20) return error.BufferTooSmall;
    const len = c.u64toa(buf.ptr, n);
    return buf[0..len];
}

pub fn i64toa(buf: []u8, n: i64) ![]const u8 {
    if (buf.len < 21) return error.BufferTooSmall;
    const len = c.i64toa(buf.ptr, n);
    return buf[0..len];
}

pub fn u64toa_radix(buf: []u8, n: u64, radix: u32) ![]const u8 {
    if (radix < 2 or radix > 36) return error.InvalidRadix;
    if (buf.len < 64) return error.BufferTooSmall;
    const len = c.u64toa_radix(buf.ptr, n, radix);
    return buf[0..len];
}

pub fn i64toa_radix(buf: []u8, n: i64, radix: u32) ![]const u8 {
    if (radix < 2 or radix > 36) return error.InvalidRadix;
    if (buf.len < 65) return error.BufferTooSmall;
    const len = c.i64toa_radix(buf.ptr, n, radix);
    return buf[0..len];
}

pub fn js_dtoa_max_len(d: f64, radix: i32, n_digits: i32, flags: i32) i32 {
    return c.js_dtoa_max_len(d, radix, n_digits, flags);
}

pub fn js_dtoa(buf: []u8, d: f64, radix: i32, n_digits: i32, flags: i32) ![]const u8 {
    if (radix < 2 or radix > 36) return error.InvalidRadix;
    const max_len = c.js_dtoa_max_len(d, radix, n_digits, flags);
    const max_len_usize: usize = @intCast(max_len + 1);
    if (buf.len < max_len_usize) return error.BufferTooSmall;

    var tmp_mem: c.JSDTOATempMem = undefined;
    const len = c.js_dtoa(buf.ptr, d, radix, n_digits, flags, &tmp_mem);
    if (len < 0) return error.FormatError;
    const len_usize: usize = @intCast(len);
    return buf[0..len_usize];
}

pub fn js_atod(str: [:0]const u8, radix: i32, flags: i32) !struct { val: f64, consumed: usize } {
    if (radix != 0 and (radix < 2 or radix > 36)) return error.InvalidRadix;
    var next_ptr: [*c]const u8 = undefined;
    var tmp_mem: c.JSATODTempMem = undefined;
    const val = c.js_atod(str.ptr, &next_ptr, radix, flags, &tmp_mem);

    const consumed = @intFromPtr(next_ptr) - @intFromPtr(str.ptr);
    return .{
        .val = val,
        .consumed = consumed,
    };
}

// --- UNIT TESTS FOR DTOA AND ATOD ---

test "u32toa and i32toa formatting" {
    var buf: [32]u8 = undefined;

    // u32toa
    try std.testing.expectEqualStrings("0", try u32toa(&buf, 0));
    try std.testing.expectEqualStrings("123456", try u32toa(&buf, 123456));
    try std.testing.expectEqualStrings("4294967295", try u32toa(&buf, 4294967295));

    // i32toa
    try std.testing.expectEqualStrings("0", try i32toa(&buf, 0));
    try std.testing.expectEqualStrings("2147483647", try i32toa(&buf, 2147483647));
    try std.testing.expectEqualStrings("-2147483648", try i32toa(&buf, -2147483648));
    try std.testing.expectEqualStrings("-12345", try i32toa(&buf, -12345));

    // Buffer too small errors
    var small_buf: [3]u8 = undefined;
    try std.testing.expectError(error.BufferTooSmall, u32toa(&small_buf, 99999));
    try std.testing.expectError(error.BufferTooSmall, i32toa(&small_buf, -99999));
}

test "u64toa and i64toa formatting" {
    var buf: [64]u8 = undefined;

    // u64toa
    try std.testing.expectEqualStrings("0", try u64toa(&buf, 0));
    try std.testing.expectEqualStrings("18446744073709551615", try u64toa(&buf, 18446744073709551615));

    // i64toa
    try std.testing.expectEqualStrings("0", try i64toa(&buf, 0));
    try std.testing.expectEqualStrings("9223372036854775807", try i64toa(&buf, 9223372036854775807));
    try std.testing.expectEqualStrings("-9223372036854775808", try i64toa(&buf, -9223372036854775808));

    // Buffer too small errors
    var small_buf: [5]u8 = undefined;
    try std.testing.expectError(error.BufferTooSmall, u64toa(&small_buf, 9999999));
    try std.testing.expectError(error.BufferTooSmall, i64toa(&small_buf, -9999999));
}

test "u64toa_radix and i64toa_radix formatting" {
    var buf: [100]u8 = undefined;

    // Radix 10 (base 10)
    try std.testing.expectEqualStrings("123456", try u64toa_radix(&buf, 123456, 10));
    try std.testing.expectEqualStrings("-123456", try i64toa_radix(&buf, -123456, 10));

    // Radix 16 (hex)
    try std.testing.expectEqualStrings("abcde", try u64toa_radix(&buf, 0xabcde, 16));
    try std.testing.expectEqualStrings("-abcde", try i64toa_radix(&buf, -0xabcde, 16));

    // Radix 2 (binary)
    try std.testing.expectEqualStrings("101010", try u64toa_radix(&buf, 42, 2));
    try std.testing.expectEqualStrings("-101010", try i64toa_radix(&buf, -42, 2));

    // Radix 8 (octal)
    try std.testing.expectEqualStrings("755", try u64toa_radix(&buf, 0o755, 8));
    try std.testing.expectEqualStrings("-755", try i64toa_radix(&buf, -0o755, 8));

    // Radix 36 (maximum)
    try std.testing.expectEqualStrings("zig", try u64toa_radix(&buf, 46024, 36));
    try std.testing.expectEqualStrings("-zig", try i64toa_radix(&buf, -46024, 36));

    // Invalid radix
    try std.testing.expectError(error.InvalidRadix, u64toa_radix(&buf, 42, 1));
    try std.testing.expectError(error.InvalidRadix, u64toa_radix(&buf, 42, 37));
    try std.testing.expectError(error.InvalidRadix, i64toa_radix(&buf, -42, 1));
    try std.testing.expectError(error.InvalidRadix, i64toa_radix(&buf, -42, 37));

    // Buffer too small errors
    var small_buf: [10]u8 = undefined;
    try std.testing.expectError(error.BufferTooSmall, u64toa_radix(&small_buf, 42, 2));
}

test "js_dtoa double to ascii formatting" {
    var buf: [256]u8 = undefined;

    // --- Free Format (JS_DTOA_FORMAT_FREE) ---
    try std.testing.expectEqualStrings("0", try js_dtoa(&buf, 0.0, 10, 0, c.JS_DTOA_FORMAT_FREE));

    // Minus zero formatting
    try std.testing.expectEqualStrings("0", try js_dtoa(&buf, -0.0, 10, 0, c.JS_DTOA_FORMAT_FREE));
    try std.testing.expectEqualStrings("-0", try js_dtoa(&buf, -0.0, 10, 0, c.JS_DTOA_FORMAT_FREE | c.JS_DTOA_MINUS_ZERO));

    // Basic float formatting
    try std.testing.expectEqualStrings("1.25", try js_dtoa(&buf, 1.25, 10, 0, c.JS_DTOA_FORMAT_FREE));
    try std.testing.expectEqualStrings("0.1", try js_dtoa(&buf, 0.1, 10, 0, c.JS_DTOA_FORMAT_FREE));
    try std.testing.expectEqualStrings("-9876.54321", try js_dtoa(&buf, -9876.54321, 10, 0, c.JS_DTOA_FORMAT_FREE));

    // Special values
    try std.testing.expectEqualStrings("Infinity", try js_dtoa(&buf, std.math.inf(f64), 10, 0, c.JS_DTOA_FORMAT_FREE));
    try std.testing.expectEqualStrings("-Infinity", try js_dtoa(&buf, -std.math.inf(f64), 10, 0, c.JS_DTOA_FORMAT_FREE));
    try std.testing.expectEqualStrings("NaN", try js_dtoa(&buf, std.math.nan(f64), 10, 0, c.JS_DTOA_FORMAT_FREE));

    // Radix formatted (e.g. Hex, Octal, Binary)
    try std.testing.expectEqualStrings("1.4", try js_dtoa(&buf, 1.25, 16, 0, c.JS_DTOA_FORMAT_FREE)); // 1 + 4/16 = 1.25
    try std.testing.expectEqualStrings("10.1", try js_dtoa(&buf, 2.5, 2, 0, c.JS_DTOA_FORMAT_FREE)); // 2 + 1/2 = 2.5

    // --- Fixed Precision Format (JS_DTOA_FORMAT_FIXED) ---
    try std.testing.expectEqualStrings("1.23", try js_dtoa(&buf, 1.23456, 10, 3, c.JS_DTOA_FORMAT_FIXED)); // 3 significant digits
    try std.testing.expectEqualStrings("1.235", try js_dtoa(&buf, 1.23456, 10, 4, c.JS_DTOA_FORMAT_FIXED)); // 4 significant digits

    // --- Fractional Format (JS_DTOA_FORMAT_FRAC) ---
    try std.testing.expectEqualStrings("1.235", try js_dtoa(&buf, 1.23456, 10, 3, c.JS_DTOA_FORMAT_FRAC)); // 3 fractional digits
    try std.testing.expectEqualStrings("1.2346", try js_dtoa(&buf, 1.23456, 10, 4, c.JS_DTOA_FORMAT_FRAC)); // 4 fractional digits
    try std.testing.expectEqualStrings("1", try js_dtoa(&buf, 1.23456, 10, 0, c.JS_DTOA_FORMAT_FRAC)); // 0 fractional digits
}

test "js_atod ascii to double parsing" {
    // Basic float parsing
    {
        const r = try js_atod("1.25", 10, 0);
        try std.testing.expectEqual(@as(usize, 4), r.consumed);
        try std.testing.expectEqual(@as(f64, 1.25), r.val);
    }
    {
        const r = try js_atod("-98.75", 10, 0);
        try std.testing.expectEqual(@as(usize, 6), r.consumed);
        try std.testing.expectEqual(@as(f64, -98.75), r.val);
    }

    // Special values
    {
        const r = try js_atod("Infinity", 10, 0);
        try std.testing.expect(std.math.isInf(r.val));
        try std.testing.expect(r.val > 0);
    }
    {
        const r = try js_atod("-Infinity", 10, 0);
        try std.testing.expect(std.math.isInf(r.val));
        try std.testing.expect(r.val < 0);
    }

    // Hex, binary, and octal parsing with prefixes (radix = 0)
    {
        const r = try js_atod("0x1a", 0, c.JS_ATOD_ACCEPT_BIN_OCT);
        try std.testing.expectEqual(@as(usize, 4), r.consumed);
        try std.testing.expectEqual(@as(f64, 26.0), r.val);
    }
    {
        const r = try js_atod("0b1010", 0, c.JS_ATOD_ACCEPT_BIN_OCT);
        try std.testing.expectEqual(@as(usize, 6), r.consumed);
        try std.testing.expectEqual(@as(f64, 10.0), r.val);
    }
    {
        const r = try js_atod("0o75", 0, c.JS_ATOD_ACCEPT_BIN_OCT);
        try std.testing.expectEqual(@as(usize, 4), r.consumed);
        try std.testing.expectEqual(@as(f64, 61.0), r.val);
    }

    // Underscores as digit separators
    {
        const r = try js_atod("1_234.5_6", 10, c.JS_ATOD_ACCEPT_UNDERSCORES);
        try std.testing.expectEqual(@as(usize, 9), r.consumed);
        try std.testing.expectEqual(@as(f64, 1234.56), r.val);
    }

    // Annex B Legacy Octal
    {
        const r = try js_atod("077", 0, c.JS_ATOD_ACCEPT_LEGACY_OCTAL);
        try std.testing.expectEqual(@as(usize, 3), r.consumed);
        try std.testing.expectEqual(@as(f64, 63.0), r.val); // 7*8 + 7 = 63
    }
}

comptime {
    _ = @import("dtoa.zig");
    _ = @import("dtoa_tests.zig");
}
