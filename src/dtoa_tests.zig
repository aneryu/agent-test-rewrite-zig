const std = @import("std");
const root = @import("root.zig");
const c = root.c;

pub const limb_t = u32;
pub const MpbTest = extern struct {
    len: c_int,
    tab: [100]limb_t,
    
    pub fn asMpb(self: *MpbTest) *anyopaque {
        return @ptrCast(self);
    }
};

extern fn u32toa(buf: [*]u8, n: u32) usize;
extern fn i32toa(buf: [*]u8, n: i32) usize;
extern fn u64toa(buf: [*]u8, n: u64) usize;
extern fn i64toa(buf: [*]u8, n: i64) usize;
extern fn u64toa_radix(buf: [*]u8, n: u64, radix: c_uint) usize;
extern fn i64toa_radix(buf: [*]u8, n: i64, radix: c_uint) usize;

extern fn mp_add_ui(tab: [*]limb_t, b: limb_t, n: usize) limb_t;
extern fn mp_shr(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, high: limb_t) limb_t;
extern fn mp_shl(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, low: limb_t) limb_t;
extern fn mpb_set_u64(r: *anyopaque, m: u64) void;
extern fn mpb_get_u64(r: *anyopaque) u64;
extern fn mpb_floor_log2(a: *anyopaque) c_int;
extern fn mul_log2_radix(a: c_int, radix: c_int) c_int;
extern fn pow_ui(radix: c_int, n: c_int) u64;
extern fn pow_ui_inv(pr_inv: *u32, pshift: *c_int, radix: c_int, n: c_int) void;
extern fn mpb_shr_round(r: *anyopaque, shift: c_int, rnd_mode: c_int) void;
extern fn mpb_cmp(a: *const anyopaque, b: *const anyopaque) c_int;
extern fn mpb_renorm(r: *anyopaque) void;
extern fn mpb_mul1_base(r: *anyopaque, radix_base: limb_t, b: limb_t) void;
extern fn limb_to_a(buf: [*]u8, a: limb_t, radix: c_int, len: c_int) void;
extern fn output_digits(buf: [*]u8, a: *const anyopaque, radix: c_int, n_digits: c_int, radix_bits: c_int) c_int;
extern fn round_to_d(pe: *c_int, a: *anyopaque, e_offset: c_int, rnd_mode: c_int) u64;
extern fn mul_pow_round_to_d(pe: *c_int, a: *anyopaque, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) u64;
extern fn udiv1norm_init(d: limb_t) limb_t;
extern fn mp_div1norm(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r: limb_t, b_inv: limb_t, shift: c_int) limb_t;
extern fn mpb_dump(str: [*]const u8, a: *const anyopaque) void;
extern fn mpb_get_bit(r: *const anyopaque, pos: c_int) c_int;

fn approxEqual(a: f64, b: f64) bool {
    if (std.math.isNan(a) and std.math.isNan(b)) return true;
    if (std.math.isInf(a) and std.math.isInf(b)) {
        return (std.math.signbit(a) == std.math.signbit(b));
    }
    return @abs(a - b) < 1e-14;
}

test "integer formatting" {
    var buf: [128]u8 = undefined;
    var len: usize = 0;

    // u32toa
    len = u32toa(&buf, 0);
    try std.testing.expectEqualStrings("0", buf[0..len]);

    len = u32toa(&buf, 1234567890);
    try std.testing.expectEqualStrings("1234567890", buf[0..len]);

    len = u32toa(&buf, 4294967295);
    try std.testing.expectEqualStrings("4294967295", buf[0..len]);

    // i32toa
    len = i32toa(&buf, 0);
    try std.testing.expectEqualStrings("0", buf[0..len]);

    len = i32toa(&buf, 2147483647);
    try std.testing.expectEqualStrings("2147483647", buf[0..len]);

    len = i32toa(&buf, -2147483648);
    try std.testing.expectEqualStrings("-2147483648", buf[0..len]);

    // u64toa
    len = u64toa(&buf, 0);
    try std.testing.expectEqualStrings("0", buf[0..len]);

    len = u64toa(&buf, 18446744073709551615);
    try std.testing.expectEqualStrings("18446744073709551615", buf[0..len]);

    len = u64toa(&buf, 5000000000);
    try std.testing.expectEqualStrings("5000000000", buf[0..len]);

    len = u64toa(&buf, 5000000000000000000);
    try std.testing.expectEqualStrings("5000000000000000000", buf[0..len]);

    // i64toa
    len = i64toa(&buf, 0);
    try std.testing.expectEqualStrings("0", buf[0..len]);

    len = i64toa(&buf, 9223372036854775807);
    try std.testing.expectEqualStrings("9223372036854775807", buf[0..len]);

    len = i64toa(&buf, -9223372036854775808);
    try std.testing.expectEqualStrings("-9223372036854775808", buf[0..len]);

    // u64toa_radix
    len = u64toa_radix(&buf, 0, 10);
    try std.testing.expectEqualStrings("0", buf[0..len]);

    len = u64toa_radix(&buf, 0xabcdef, 16);
    try std.testing.expectEqualStrings("abcdef", buf[0..len]);

    len = u64toa_radix(&buf, 42, 2);
    try std.testing.expectEqualStrings("101010", buf[0..len]);

    len = u64toa_radix(&buf, 46024, 36);
    try std.testing.expectEqualStrings("zig", buf[0..len]);

    len = u64toa_radix(&buf, 0, 16);
    try std.testing.expectEqualStrings("0", buf[0..len]);

    len = u64toa_radix(&buf, 5, 36);
    try std.testing.expectEqualStrings("5", buf[0..len]);

    // i64toa_radix
    len = i64toa_radix(&buf, -46024, 36);
    try std.testing.expectEqualStrings("-zig", buf[0..len]);

    len = i64toa_radix(&buf, 42, 36);
    try std.testing.expectEqualStrings("16", buf[0..len]);
}

test "bignum helpers" {
    var mpb1: MpbTest = undefined;
    var mpb2: MpbTest = undefined;
    var mpb3: MpbTest = undefined;

    const a = mpb1.asMpb();
    const b = mpb2.asMpb();

    // Test mpb_set_u64 & mpb_get_u64
    mpb_set_u64(a, 0x123456789abcdef0);
    try std.testing.expectEqual(@as(u64, 0x123456789abcdef0), mpb_get_u64(a));

    mpb_set_u64(a, 5);
    try std.testing.expectEqual(@as(u64, 5), mpb_get_u64(a));
    try std.testing.expectEqual(@as(c_int, 1), mpb1.len);

    // Test mpb_cmp
    mpb_set_u64(a, 100);
    mpb_set_u64(b, 200);
    try std.testing.expect(mpb_cmp(a, b) < 0);
    try std.testing.expect(mpb_cmp(b, a) > 0);
    try std.testing.expect(mpb_cmp(a, a) == 0);

    mpb_set_u64(a, 0x100000000);
    mpb_set_u64(b, 200);
    try std.testing.expect(mpb_cmp(a, b) > 0);
    try std.testing.expect(mpb_cmp(b, a) < 0);

    mpb1.len = 2; mpb1.tab[0] = 100; mpb1.tab[1] = 2;
    mpb2.len = 2; mpb2.tab[0] = 200; mpb2.tab[1] = 2;
    try std.testing.expect(mpb_cmp(a, b) < 0);

    // Test mp_add_ui carry
    mpb1.len = 1; mpb1.tab[0] = 0xffffffff;
    const carry = mp_add_ui(&mpb1.tab, 1, 1);
    try std.testing.expectEqual(@as(limb_t, 1), carry);
    try std.testing.expectEqual(@as(limb_t, 0), mpb1.tab[0]);

    // Test mpb_renorm
    mpb1.len = 3; mpb1.tab[0] = 1; mpb1.tab[1] = 0; mpb1.tab[2] = 0;
    mpb_renorm(a);
    try std.testing.expectEqual(@as(c_int, 1), mpb1.len);

    // Test mpb_floor_log2
    mpb_set_u64(a, 0);
    mpb1.tab[0] = 0;
    try std.testing.expectEqual(@as(c_int, -1), mpb_floor_log2(a));

    // Test mp_shr
    mpb1.len = 2; mpb1.tab[0] = 0; mpb1.tab[1] = 1;
    const rem = mp_shr(&mpb3.tab, &mpb1.tab, 2, 4, 0);
    try std.testing.expectEqual(@as(limb_t, 0), rem);
    try std.testing.expectEqual(@as(limb_t, 0x10000000), mpb3.tab[0]);

    // Test mp_shl
    mpb1.len = 1; mpb1.tab[0] = 1;
    const high = mp_shl(&mpb3.tab, &mpb1.tab, 1, 4, 0);
    try std.testing.expectEqual(@as(limb_t, 0), high);
    try std.testing.expectEqual(@as(limb_t, 16), mpb3.tab[0]);

    // Test mul_log2_radix
    try std.testing.expectEqual(@as(c_int, 10), mul_log2_radix(10, 2));
    try std.testing.expectEqual(@as(c_int, 5), mul_log2_radix(10, 4));
    try std.testing.expectEqual(@as(c_int, 3), mul_log2_radix(10, 8));
    try std.testing.expectEqual(@as(c_int, 2), mul_log2_radix(10, 16));
    try std.testing.expectEqual(@as(c_int, -10), mul_log2_radix(-10, 2));
    try std.testing.expectEqual(@as(c_int, -5), mul_log2_radix(-10, 4));

    // Test pow_ui & pow_ui_inv lookups
    try std.testing.expectEqual(@as(u64, 1), pow_ui(5, 0));
    try std.testing.expectEqual(@as(u64, 5), pow_ui(5, 1));
    try std.testing.expectEqual(@as(u64, 9765625), pow_ui(5, 10));
    try std.testing.expectEqual(@as(u64, 152587890625), pow_ui(5, 16));
    try std.testing.expectEqual(@as(u64, 1000000000000), pow_ui(10, 12));
    try std.testing.expectEqual(@as(u64, 243), pow_ui(3, 5));

    var r_inv: u32 = 0;
    var shift: c_int = 0;
    pow_ui_inv(&r_inv, &shift, 5, 4);
    try std.testing.expect(r_inv != 0);
}

test "rounding modes" {
    var u: MpbTest = undefined;
    const r = u.asMpb();

    // Test mpb_shr_round with RNDZ (2)
    mpb_set_u64(r, 7);
    mpb_shr_round(r, 1, 2); // JS_RNDZ = 2
    try std.testing.expectEqual(@as(u64, 3), mpb_get_u64(r));

    // Test mpb_shr_round with RNDNA (1) (round half away from zero)
    mpb_set_u64(r, 3); // 11
    mpb_shr_round(r, 1, 1); // JS_RNDNA = 1 -> 1.5 rounds to 2
    try std.testing.expectEqual(@as(u64, 2), mpb_get_u64(r));

    mpb_set_u64(r, 1); // 01
    mpb_shr_round(r, 1, 1); // 0.5 rounds to 1
    try std.testing.expectEqual(@as(u64, 1), mpb_get_u64(r));

    // Test mpb_shr_round with RNDN (0) (round half to even)
    mpb_set_u64(r, 3);
    mpb_shr_round(r, 1, 0); // JS_RNDN = 0 -> 1.5 rounds to nearest even is 2
    try std.testing.expectEqual(@as(u64, 2), mpb_get_u64(r));

    mpb_set_u64(r, 5); // 101
    mpb_shr_round(r, 2, 0); // 1.25 rounds to 1
    try std.testing.expectEqual(@as(u64, 1), mpb_get_u64(r));

    mpb_set_u64(r, 7); // 111
    mpb_shr_round(r, 2, 0); // 1.75 rounds to 2
    try std.testing.expectEqual(@as(u64, 2), mpb_get_u64(r));

    mpb_set_u64(r, 6); // 110
    mpb_shr_round(r, 2, 0); // 1.5 rounds to nearest even is 2
    try std.testing.expectEqual(@as(u64, 2), mpb_get_u64(r));

    // Test shifting negative shifts (left shifts)
    mpb_set_u64(r, 5);
    mpb_shr_round(r, -2, 2); // left shift 2 -> 20 (JS_RNDZ = 2)
    try std.testing.expectEqual(@as(u64, 20), mpb_get_u64(r));

    mpb_set_u64(r, 5);
    mpb_shr_round(r, -32, 2);
    try std.testing.expectEqual(@as(u64, 5 << 32), mpb_get_u64(r));
}

test "dtoa formatting" {
    var buf: [512]u8 = undefined;
    var len: c_int = 0;
    var tmp: c.JSDTOATempMem = undefined;

    len = c.js_dtoa(&buf, 1.25, 10, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
    try std.testing.expectEqualStrings("1.25", buf[0..@intCast(len)]);

    len = c.js_dtoa(&buf, 0.0, 10, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
    try std.testing.expectEqualStrings("0", buf[0..@intCast(len)]);

    len = c.js_dtoa(&buf, -0.0, 10, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
    try std.testing.expectEqualStrings("0", buf[0..@intCast(len)]);

    len = c.js_dtoa(&buf, -0.0, 10, 0, c.JS_DTOA_FORMAT_FREE | c.JS_DTOA_MINUS_ZERO, &tmp);
    try std.testing.expectEqualStrings("-0", buf[0..@intCast(len)]);

    len = c.js_dtoa(&buf, std.math.inf(f64), 10, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
    try std.testing.expectEqualStrings("Infinity", buf[0..@intCast(len)]);

    len = c.js_dtoa(&buf, -std.math.inf(f64), 10, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
    try std.testing.expectEqualStrings("-Infinity", buf[0..@intCast(len)]);

    len = c.js_dtoa(&buf, std.math.nan(f64), 10, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
    try std.testing.expectEqualStrings("NaN", buf[0..@intCast(len)]);

    len = c.js_dtoa(&buf, 1.23456, 10, 3, c.JS_DTOA_FORMAT_FIXED, &tmp);
    try std.testing.expectEqualStrings("1.23", buf[0..@intCast(len)]);

    len = c.js_dtoa(&buf, 1.23456, 10, 3, c.JS_DTOA_FORMAT_FRAC, &tmp);
    try std.testing.expectEqualStrings("1.235", buf[0..@intCast(len)]);

    len = c.js_dtoa(&buf, 1.25, 16, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
    try std.testing.expectEqualStrings("1.4", buf[0..@intCast(len)]);

    len = c.js_dtoa(&buf, 2.5, 2, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
    try std.testing.expectEqualStrings("10.1", buf[0..@intCast(len)]);

    len = c.js_dtoa(&buf, 1.2e20, 10, 0, c.JS_DTOA_FORMAT_FREE | c.JS_DTOA_EXP_ENABLED, &tmp);
    try std.testing.expect(std.mem.indexOfScalar(u8, buf[0..@intCast(len)], 'e') != null);

    len = c.js_dtoa(&buf, 1.2e20, 10, 0, c.JS_DTOA_FORMAT_FREE | c.JS_DTOA_EXP_DISABLED, &tmp);
    try std.testing.expect(std.mem.indexOfScalar(u8, buf[0..@intCast(len)], 'e') == null);
}

test "atod parsing" {
    var tmp: c.JSATODTempMem = undefined;
    var next: [*c]const u8 = undefined;
    var val: f64 = 0;

    val = c.js_atod("1.25", &next, 10, 0, &tmp);
    try std.testing.expect(approxEqual(val, 1.25));
    try std.testing.expectEqual(@as(usize, 4), @intFromPtr(next) - @intFromPtr("1.25"));

    val = c.js_atod("-0.075", &next, 10, 0, &tmp);
    try std.testing.expect(approxEqual(val, -0.075));
    try std.testing.expectEqual(@as(usize, 6), @intFromPtr(next) - @intFromPtr("-0.075"));

    val = c.js_atod("0x1a", &next, 0, c.JS_ATOD_ACCEPT_BIN_OCT, &tmp);
    try std.testing.expectEqual(@as(f64, 26.0), val);

    val = c.js_atod("0b1010", &next, 0, c.JS_ATOD_ACCEPT_BIN_OCT, &tmp);
    try std.testing.expectEqual(@as(f64, 10.0), val);

    val = c.js_atod("0o75", &next, 0, c.JS_ATOD_ACCEPT_BIN_OCT, &tmp);
    try std.testing.expectEqual(@as(f64, 61.0), val);

    val = c.js_atod("077", &next, 0, c.JS_ATOD_ACCEPT_LEGACY_OCTAL, &tmp);
    try std.testing.expectEqual(@as(f64, 63.0), val);

    val = c.js_atod("1_234.5_6", &next, 10, c.JS_ATOD_ACCEPT_UNDERSCORES, &tmp);
    try std.testing.expect(approxEqual(val, 1234.56));

    val = c.js_atod("Infinity", &next, 10, 0, &tmp);
    try std.testing.expect(std.math.isInf(val) and val > 0);

    val = c.js_atod("-Infinity", &next, 10, 0, &tmp);
    try std.testing.expect(std.math.isInf(val) and val < 0);

    val = c.js_atod("1e1000", &next, 10, 0, &tmp);
    try std.testing.expect(std.math.isInf(val));

    val = c.js_atod("1e-1000", &next, 10, 0, &tmp);
    try std.testing.expectEqual(@as(f64, 0.0), val);
}

test "additional coverage" {
    var buf: [512]u8 = undefined;
    var len: c_int = 0;
    var tmp: c.JSDTOATempMem = undefined;
    var atod_tmp: c.JSATODTempMem = undefined;
    var next: [*c]const u8 = undefined;
    var val: f64 = 0;

    // 1. limb_to_a direct tests for radix != 10
    {
        var limb_buf: [16]u8 = undefined;
        limb_to_a(&limb_buf, 11, 16, 2);
        try std.testing.expectEqualStrings("0b", limb_buf[0..2]);

        limb_to_a(&limb_buf, 5, 8, 2);
        try std.testing.expectEqualStrings("05", limb_buf[0..2]);
    }

    // 2. mpb_mul1_base direct tests for radix_base == 0 and radix_base != 0
    {
        var u: MpbTest = undefined;
        const r = u.asMpb();

        // radix_base == 0 path
        u.len = 1;
        u.tab[0] = 5;
        mpb_mul1_base(r, 0, 10);
        try std.testing.expectEqual(@as(c_int, 2), u.len);
        try std.testing.expectEqual(@as(limb_t, 10), u.tab[0]);
        try std.testing.expectEqual(@as(limb_t, 5), u.tab[1]);

        // radix_base != 0 path
        u.len = 1;
        u.tab[0] = 5;
        mpb_mul1_base(r, 100, 20);
        try std.testing.expectEqual(@as(c_int, 1), u.len);
        try std.testing.expectEqual(@as(limb_t, 520), u.tab[0]);
    }

    // 3. pow_ui_inv fallback, udiv1norm_init and mp_div1norm with shift = 0
    {
        var r_inv: u32 = 0;
        var shift: c_int = 0;
        pow_ui_inv(&r_inv, &shift, 3, 5);
        try std.testing.expect(r_inv != 0);

        const d_inv = udiv1norm_init(0x80000000);
        try std.testing.expect(d_inv != 0);

        var taba = [2]limb_t{ 0x12345678, 0x87654321 };
        var tabr: [2]limb_t = undefined;
        const rem = mp_div1norm(&tabr, &taba, 2, 0x90000000, 0, d_inv, 0);
        try std.testing.expect(rem != 0);
    }

    // 4. mpb_dump call
    {
        var u: MpbTest = undefined;
        const a = u.asMpb();
        u.len = 2;
        u.tab[0] = 0xabcdef;
        u.tab[1] = 0x123456;
        mpb_dump("test_mpb_dump", a);
    }

    // 5. js_dtoa_max_len branches
    {
        try std.testing.expect(c.js_dtoa_max_len(1.23, 10, 0, c.JS_DTOA_FORMAT_FREE) > 0);
        try std.testing.expect(c.js_dtoa_max_len(1.23, 10, 0, c.JS_DTOA_FORMAT_FREE | c.JS_DTOA_EXP_DISABLED) > 0);
        try std.testing.expect(c.js_dtoa_max_len(std.math.nan(f64), 10, 0, c.JS_DTOA_FORMAT_FREE | c.JS_DTOA_EXP_DISABLED) > 0);
        try std.testing.expect(c.js_dtoa_max_len(1.23, 10, 4, c.JS_DTOA_FORMAT_FIXED) > 0);
        try std.testing.expect(c.js_dtoa_max_len(1.23, 10, 4, c.JS_DTOA_FORMAT_FIXED | c.JS_DTOA_EXP_DISABLED) > 0);
        try std.testing.expect(c.js_dtoa_max_len(std.math.nan(f64), 10, 4, c.JS_DTOA_FORMAT_FRAC) > 0);
        try std.testing.expect(c.js_dtoa_max_len(0.25, 10, 4, c.JS_DTOA_FORMAT_FRAC) > 0);
        try std.testing.expect(c.js_dtoa_max_len(8.0, 10, 4, c.JS_DTOA_FORMAT_FRAC) > 0);
    }

    // 6. mpb_get_bit out of bounds
    {
        var u: MpbTest = undefined;
        const r = u.asMpb();
        u.len = 1;
        u.tab[0] = 1;
        try std.testing.expectEqual(@as(c_int, 0), mpb_get_bit(r, 1000));
    }

    // 7. mpb_shr_round edge cases
    {
        var u: MpbTest = undefined;
        const r = u.asMpb();
        
        // shift == 0
        u.len = 1;
        u.tab[0] = 5;
        mpb_shr_round(r, 0, 2); // JS_RNDZ = 2
        try std.testing.expectEqual(@as(limb_t, 5), u.tab[0]);

        // invalid rnd_mode to hit default -> add_one = 0
        mpb_shr_round(r, 1, 999);
        try std.testing.expectEqual(@as(limb_t, 2), u.tab[0]);

        // l >= r->len (shift = 1000)
        u.len = 1;
        u.tab[0] = 5;
        mpb_shr_round(r, 1000, 0); // JS_RNDN = 0
        try std.testing.expectEqual(@as(c_int, 1), u.len);
        try std.testing.expectEqual(@as(limb_t, 0), u.tab[0]);

        // carry propagation
        u.len = 2;
        u.tab[0] = 0xffffffff;
        u.tab[1] = 0xffffffff;
        mpb_shr_round(r, 32, 1); // JS_RNDNA = 1
        try std.testing.expectEqual(@as(c_int, 2), u.len);
        try std.testing.expectEqual(@as(limb_t, 0), u.tab[0]);
        try std.testing.expectEqual(@as(limb_t, 1), u.tab[1]);
    }

    // 8. output_digits direct testing for radix_bits != 0 and n_digits > digits_per_limb
    {
        var out_buf: [128]u8 = undefined;
        var u: MpbTest = undefined;
        const a = u.asMpb();
        u.len = 1;
        u.tab[0] = 0xffffffff;
        const digits = output_digits(&out_buf, a, 16, 12, 12);
        try std.testing.expectEqual(@as(c_int, 12), digits);
    }

    // 9. round_to_d edge cases
    {
        var pe: c_int = 0;
        var u: MpbTest = undefined;
        const a = u.asMpb();

        // zero result
        u.len = 1;
        u.tab[0] = 0;
        var m = round_to_d(&pe, a, 0, 1);
        try std.testing.expectEqual(@as(u64, 0), m);

        // subnormal non-zero result
        u.len = 1;
        u.tab[0] = 1;
        m = round_to_d(&pe, a, 1050, 0);
        try std.testing.expectEqual(@as(u64, 1 << 52), m);

        // subnormal zero result
        u.len = 1;
        u.tab[0] = 1;
        m = round_to_d(&pe, a, 1080, 0);
        try std.testing.expectEqual(@as(u64, 0), m);

        // mantissa overflow due to rounding
        u.len = 2;
        u.tab[0] = 0xffffffff;
        u.tab[1] = 0x003fffff; // (1 << 54) - 1
        m = round_to_d(&pe, a, 1, 1); // JS_RNDNA = 1
        try std.testing.expectEqual(@as(u64, 1 << 52), m);
        try std.testing.expectEqual(@as(c_int, 54), pe);

    }

    // 10. js_dtoa and format fixed/frac paths
    {
        len = c.js_dtoa(&buf, 0.0, 10, 4, c.JS_DTOA_FORMAT_FRAC, &tmp);
        try std.testing.expectEqualStrings("0.0000", buf[0..@intCast(len)]);

        len = c.js_dtoa(&buf, 0.0, 10, 4, c.JS_DTOA_FORMAT_FIXED, &tmp);
        try std.testing.expectEqualStrings("0.000", buf[0..@intCast(len)]);

        len = c.js_dtoa(&buf, 5e-324, 10, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
        try std.testing.expectEqualStrings("5e-324", buf[0..@intCast(len)]);

        len = c.js_dtoa(&buf, -1.25, 10, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
        try std.testing.expectEqualStrings("-1.25", buf[0..@intCast(len)]);

        len = c.js_dtoa(&buf, -5e-324, 10, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
        try std.testing.expectEqualStrings("-5e-324", buf[0..@intCast(len)]);

        len = c.js_dtoa(&buf, 42.0, 10, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
        try std.testing.expectEqualStrings("42", buf[0..@intCast(len)]);

        len = c.js_dtoa(&buf, 42.0, 16, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
        try std.testing.expectEqualStrings("2a", buf[0..@intCast(len)]);

        len = c.js_dtoa(&buf, 0.5, 10, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
        try std.testing.expectEqualStrings("0.5", buf[0..@intCast(len)]);

        len = c.js_dtoa(&buf, 9.99, 10, 2, c.JS_DTOA_FORMAT_FIXED, &tmp);
        try std.testing.expectEqualStrings("10", buf[0..@intCast(len)]);

        len = c.js_dtoa(&buf, 2.9, 3, 2, c.JS_DTOA_FORMAT_FIXED, &tmp);
        try std.testing.expectEqualStrings("10", buf[0..@intCast(len)]);

        len = c.js_dtoa(&buf, 0.0001, 16, 0, c.JS_DTOA_FORMAT_FREE | c.JS_DTOA_EXP_ENABLED, &tmp);
        try std.testing.expect(std.mem.indexOfScalar(u8, buf[0..@intCast(len)], 'p') != null or std.mem.indexOfScalar(u8, buf[0..@intCast(len)], '@') != null);

        len = c.js_dtoa(&buf, 1000.0, 3, 0, c.JS_DTOA_FORMAT_FREE | c.JS_DTOA_EXP_ENABLED, &tmp);
        try std.testing.expect(std.mem.indexOfScalar(u8, buf[0..@intCast(len)], '@') != null);

        len = c.js_dtoa(&buf, 0.00123, 10, 0, c.JS_DTOA_FORMAT_FREE, &tmp);
        try std.testing.expectEqualStrings("0.00123", buf[0..@intCast(len)]);
    }

    // 11. js_atod parsing edge cases
    {
        val = c.js_atod("0x1A", &next, 0, c.JS_ATOD_ACCEPT_BIN_OCT, &atod_tmp);
        try std.testing.expectEqual(@as(f64, 26.0), val);

        val = c.js_atod("+1.25", &next, 10, 0, &atod_tmp);
        try std.testing.expect(approxEqual(val, 1.25));

        val = c.js_atod("018", &next, 0, c.JS_ATOD_ACCEPT_LEGACY_OCTAL, &atod_tmp);
        try std.testing.expectEqual(@as(f64, 18.0), val);

        val = c.js_atod("0x", &next, 0, c.JS_ATOD_ACCEPT_BIN_OCT, &atod_tmp);
        try std.testing.expect(std.math.isNan(val));

        val = c.js_atod("0b", &next, 0, c.JS_ATOD_ACCEPT_BIN_OCT, &atod_tmp);
        try std.testing.expect(std.math.isNan(val));

        val = c.js_atod("0o", &next, 0, c.JS_ATOD_ACCEPT_BIN_OCT, &atod_tmp);
        try std.testing.expect(std.math.isNan(val));

        val = c.js_atod("123", &next, 0, 0, &atod_tmp);
        try std.testing.expectEqual(@as(f64, 123.0), val);

        val = c.js_atod("1.2.3", &next, 10, 0, &atod_tmp);
        try std.testing.expect(approxEqual(val, 1.2));

        val = c.js_atod(".5.5", &next, 10, 0, &atod_tmp);
        try std.testing.expect(approxEqual(val, 0.5));

        val = c.js_atod("0.0.5", &next, 10, 0, &atod_tmp);
        try std.testing.expect(approxEqual(val, 0.0));
        try std.testing.expectEqualStrings(".5", std.mem.span(next));

        val = c.js_atod("0_0", &next, 10, c.JS_ATOD_ACCEPT_UNDERSCORES, &atod_tmp);
        try std.testing.expectEqual(@as(f64, 0.0), val);

        val = c.js_atod("1.00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001", &next, 10, 0, &atod_tmp);
        try std.testing.expect(approxEqual(val, 1.0));

        val = c.js_atod("0b100000000000000000000000000000000000000000000000000000000000000000000000000000001", &next, 0, c.JS_ATOD_ACCEPT_BIN_OCT, &atod_tmp);
        try std.testing.expect(val > 0);

        val = c.js_atod("1e+5", &next, 10, 0, &atod_tmp);
        try std.testing.expectEqual(@as(f64, 100000.0), val);

        val = c.js_atod("1e", &next, 10, 0, &atod_tmp);
        try std.testing.expect(std.math.isNan(val));

        val = c.js_atod("1e+", &next, 10, 0, &atod_tmp);
        try std.testing.expect(std.math.isNan(val));

        val = c.js_atod("1e1_0", &next, 10, c.JS_ATOD_ACCEPT_UNDERSCORES, &atod_tmp);
        try std.testing.expectEqual(@as(f64, 10000000000.0), val);

        val = c.js_atod("1e20000000000", &next, 10, 0, &atod_tmp);
        try std.testing.expect(std.math.isInf(val) and val > 0);

        val = c.js_atod("1e-20000000000", &next, 10, 0, &atod_tmp);
        try std.testing.expectEqual(@as(f64, 0.0), val);

        val = c.js_atod("", &next, 10, 0, &atod_tmp);
        try std.testing.expect(std.math.isNan(val));

        val = c.js_atod("-", &next, 10, 0, &atod_tmp);
        try std.testing.expect(std.math.isNan(val));

        val = c.js_atod("0", &next, 10, 0, &atod_tmp);
        try std.testing.expectEqual(@as(f64, 0.0), val);

        val = c.js_atod("0x1p2000", &next, 0, c.JS_ATOD_ACCEPT_BIN_OCT, &atod_tmp);
        try std.testing.expect(std.math.isInf(val));

        val = c.js_atod("0x1p-2000", &next, 0, c.JS_ATOD_ACCEPT_BIN_OCT, &atod_tmp);
        try std.testing.expectEqual(@as(f64, 0.0), val);

        val = c.js_atod("1e309", &next, 10, 0, &atod_tmp);
        try std.testing.expect(std.math.isInf(val));

        val = c.js_atod("1e-325", &next, 10, 0, &atod_tmp);
        try std.testing.expectEqual(@as(f64, 0.0), val);

        val = c.js_atod("1e-320", &next, 10, 0, &atod_tmp);
        try std.testing.expect(val > 0 and val < 1e-300);

        _ = c.js_atod("2.47e-324", &next, 10, 0, &atod_tmp);
        _ = c.js_atod("2.48e-324", &next, 10, 0, &atod_tmp);
        _ = c.js_atod("2.49e-324", &next, 10, 0, &atod_tmp);

        val = c.js_atod("abc", &next, 10, 0, &atod_tmp);
        try std.testing.expect(std.math.isNan(val));
    }
}
