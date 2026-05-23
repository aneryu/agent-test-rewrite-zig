// Tiny float64 printing and parsing library
// Rewritten from Fabrice Bellard's dtoa.c
//
// Copyright (c) 2024 Fabrice Bellard
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

const std = @import("std");

pub const JSDTOATempMem = extern struct {
    mem: [37]u64,
};

pub const JSATODTempMem = extern struct {
    mem: [27]u64,
};

pub const JS_DTOA_MAX_DIGITS = 101;

pub const JS_DTOA_FORMAT_FREE = 0 << 0;
pub const JS_DTOA_FORMAT_FIXED = 1 << 0;
pub const JS_DTOA_FORMAT_FRAC = 2 << 0;
pub const JS_DTOA_FORMAT_MASK = 3 << 0;

pub const JS_DTOA_EXP_AUTO = 0 << 2;
pub const JS_DTOA_EXP_ENABLED = 1 << 2;
pub const JS_DTOA_EXP_DISABLED = 2 << 2;
pub const JS_DTOA_EXP_MASK = 3 << 2;

pub const JS_DTOA_MINUS_ZERO = 1 << 4;

pub const JS_ATOD_INT_ONLY = 1 << 0;
pub const JS_ATOD_ACCEPT_BIN_OCT = 1 << 1;
pub const JS_ATOD_ACCEPT_LEGACY_OCTAL = 1 << 2;
pub const JS_ATOD_ACCEPT_UNDERSCORES = 1 << 3;

// --- Internal constants and types ---

const LIMB_LOG2_BITS: comptime_int = 5;
const LIMB_BITS: comptime_int = 1 << LIMB_LOG2_BITS; // 32
const limb_t = u32;
const slimb_t = i32;
const dlimb_t = u64;

const LIMB_DIGITS: comptime_int = 9;
const JS_RADIX_MAX: comptime_int = 36;
const DBIGNUM_LEN_MAX: comptime_int = 52;
const MANT_LEN_MAX: comptime_int = 18;

const JS_RNDN: c_int = 0; // round to nearest, ties to even
const JS_RNDNA: c_int = 1; // round to nearest, ties away from zero
const JS_RNDZ: c_int = 2; // round toward zero

// mpb_t: the represented number is sum(i, tab[i]*2^(LIMB_BITS * i))
const Mpb = extern struct {
    len: c_int,
    tab: [1]limb_t, // flexible array member - accessed with bounds
};

// --- Helper functions ---

inline fn clz32(a: u32) i32 {
    return @intCast(@clz(a));
}

inline fn clz64(a: u64) i32 {
    return @intCast(@clz(a));
}

inline fn ctz32(a: u32) i32 {
    return @intCast(@ctz(a));
}

inline fn max_int(a: i32, b: i32) i32 {
    return if (a > b) a else b;
}

inline fn min_int(a: i32, b: i32) i32 {
    return if (a < b) a else b;
}

inline fn float64_as_uint64(d: f64) u64 {
    return @bitCast(d);
}

inline fn uint64_as_float64(a: u64) f64 {
    return @bitCast(a);
}

fn js__strstart(str: [*]const u8, val: [*:0]const u8, ptr: ?*[*]const u8) bool {
    var p: [*]const u8 = str;
    var q: [*]const u8 = val;
    while (q[0] != 0) : ({
        p += 1;
        q += 1;
    }) {
        if (p[0] != q[0]) return false;
    }
    if (ptr) |pp| pp.* = p;
    return true;
}

// --- Multi-precision arithmetic ---

pub fn mp_add_ui(tab: [*]limb_t, b: limb_t, n: usize) limb_t {
    var k: limb_t = b;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        if (k == 0) break;
        const a = tab[i] +% k;
        k = if (a < k) 1 else 0;
        tab[i] = a;
    }
    return k;
}

// tabr[] = taba[] * b + l. Return the high carry
fn mp_mul1(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, l: limb_t) limb_t {
    var carry: limb_t = l;
    var i: limb_t = 0;
    while (i < n) : (i += 1) {
        const t: dlimb_t = @as(dlimb_t, taba[i]) * @as(dlimb_t, b) + @as(dlimb_t, carry);
        tabr[i] = @as(limb_t, @truncate(t));
        carry = @as(limb_t, @truncate(t >> LIMB_BITS));
    }
    return carry;
}

// WARNING: d must be >= 2^(LIMB_BITS-1)
pub fn udiv1norm_init(d: limb_t) limb_t {
    const a1: limb_t = 0 -% d -% 1; // wraps: equivalent to C's -d - 1 for uint32_t
    const a0: limb_t = @as(limb_t, 0) -% 1; // wraps: equivalent to C's -1 for uint32_t (0xFFFFFFFF)
    return @as(limb_t, @truncate((@as(dlimb_t, a1) << LIMB_BITS) | @as(dlimb_t, a0) / @as(dlimb_t, d)));
}

// return the quotient and the remainder in '*pr' of 'a1*2^LIMB_BITS+a0 / d'
// with 0 <= a1 < d
fn udiv1norm(pr: *limb_t, a1: limb_t, a0: limb_t, d: limb_t, d_inv: limb_t) limb_t {
    const n1m: limb_t = @bitCast(@as(slimb_t, @bitCast(a0)) >> (LIMB_BITS - 1));
    const n_adj: limb_t = a0 +% (n1m & d);
    var a: dlimb_t = @as(dlimb_t, d_inv) * @as(dlimb_t, @as(limb_t, @truncate(@as(dlimb_t, a1) -% @as(dlimb_t, n1m)))) +% @as(dlimb_t, n_adj);
    var q: limb_t = @as(limb_t, @truncate(a >> LIMB_BITS)) +% a1;

    a = (@as(dlimb_t, a1) << LIMB_BITS) | @as(dlimb_t, a0);
    a = a -% @as(dlimb_t, q) * @as(dlimb_t, d) -% @as(dlimb_t, d);
    const ah: limb_t = @as(limb_t, @truncate(a >> LIMB_BITS));
    q +%= 1 +% ah;
    const r: limb_t = @as(limb_t, @truncate(a)) +% (ah & d);
    pr.* = r;
    return q;
}

fn mp_div1(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r: limb_t) limb_t {
    var rem: limb_t = r;
    var i: slimb_t = @as(slimb_t, @intCast(n)) - 1;
    while (i >= 0) : (i -= 1) {
        const a1: dlimb_t = (@as(dlimb_t, rem) << LIMB_BITS) | @as(dlimb_t, taba[@intCast(i)]);
        tabr[@intCast(i)] = @as(limb_t, @truncate(a1 / @as(dlimb_t, b)));
        rem = @as(limb_t, @truncate(a1 % @as(dlimb_t, b)));
    }
    return rem;
}

// r = (a + high*B^n) >> shift. Return the remainder r (0 <= r < 2^shift).
// 1 <= shift <= LIMB_BITS - 1
pub fn mp_shr(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, high: limb_t) limb_t {
    std.debug.assert(shift >= 1 and shift < LIMB_BITS);
    const uShift: u5 = @intCast(shift);
    var l: limb_t = high;
    var i: isize = n - 1;
    while (i >= 0) : (i -= 1) {
        const a: limb_t = tab[@intCast(i)];
        tab_r[@intCast(i)] = (a >> uShift) | (l << @intCast(LIMB_BITS - shift));
        l = a;
    }
    return l & ((@as(limb_t, 1) << @intCast(uShift)) - 1);
}

// r = (a << shift) + low. 1 <= shift <= LIMB_BITS - 1, 0 <= low < 2^shift.
pub fn mp_shl(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, low: limb_t) limb_t {
    std.debug.assert(shift >= 1 and shift < LIMB_BITS);
    const uShift: u5 = @intCast(shift);
    var l: limb_t = low;
    var i: isize = 0;
    while (i < n) : (i += 1) {
        const a: limb_t = tab[@intCast(i)];
        tab_r[@intCast(i)] = (a << uShift) | l;
        l = a >> @intCast(LIMB_BITS - shift);
    }
    return l;
}

pub fn mp_div1norm(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r: limb_t, b_inv: limb_t, shift: c_int) limb_t {
    var rem: limb_t = r;
    if (shift != 0) {
        rem = (rem << @intCast(shift)) | mp_shl(tabr, taba, @intCast(n), shift, 0);
    }
    var i: slimb_t = @as(slimb_t, @intCast(n)) - 1;
    while (i >= 0) : (i -= 1) {
        tabr[@intCast(i)] = udiv1norm(&rem, rem, taba[@intCast(i)], b, b_inv);
    }
    rem >>= @intCast(shift);
    return rem;
}

// --- mpb operations ---

fn mpb_ptr(r: *anyopaque) [*]limb_t {
    return &mpb_struct(r).tab;
}

fn mpb_const_ptr(r: *const anyopaque) [*]const limb_t {
    return &mpb_const_struct(r).tab;
}

fn mpb_struct(r: *anyopaque) *Mpb {
    return @ptrCast(@alignCast(r));
}

fn mpb_const_struct(r: *const anyopaque) *Mpb {
    return @ptrCast(@alignCast(@constCast(r)));
}

pub fn mpb_dump(str: [*]const u8, a: *const anyopaque) void {
    _ = str;
    _ = a;
    // Debug-only, no-op in Zig rewrite
}

pub fn mpb_renorm(r: *anyopaque) void {
    const s = mpb_struct(r);
    const tab = mpb_ptr(r);
    while (s.len > 1 and tab[@intCast(s.len - 1)] == 0) {
        s.len -= 1;
    }
}

// --- Power of 5 tables ---

const pow5_table = [17]u32{
    0x00000005, 0x00000019, 0x0000007d, 0x00000271,
    0x00000c35, 0x00003d09, 0x0001312d, 0x0005f5e1,
    0x001dcd65, 0x009502f9, 0x02e90edd, 0x0e8d4a51,
    0x48c27395, 0x6bcc41e9, 0x1afd498d, 0x86f26fc1,
    0xa2bc2ec5,
};

const pow5h_table = [4]u8{
    0x00000001, 0x00000007, 0x00000023, 0x000000b1,
};

const pow5_inv_table = [13]u32{
    0x99999999, 0x47ae147a, 0x0624dd2f, 0xa36e2eb1,
    0x4f8b588e, 0x0c6f7a0b, 0xad7f29ab, 0x5798ee23,
    0x12e0be82, 0xb7cdfd9d, 0x5fd7fe17, 0x19799812,
    0xc25c2684,
};

// return a^b
pub fn pow_ui(a_param: c_int, b_param: c_int) u64 {
    if (b_param == 0) return 1;
    if (b_param == 1) return @intCast(a_param);
    const a: u32 = @intCast(a_param);
    const b: u32 = @intCast(b_param);

    if ((a == 5 or a == 10) and b <= 17) {
        var r: u64 = pow5_table[b - 1];
        if (b >= 14) {
            r |= @as(u64, pow5h_table[b - 14]) << 32;
        }
        if (a == 10) r <<= @intCast(b);
        return r;
    }

    var r: u64 = a;
    const n_bits: i32 = 32 - clz32(b);
    var i: i32 = n_bits - 2;
    while (i >= 0) : (i -= 1) {
        r *= r;
        if ((b >> @intCast(i)) & 1 != 0)
            r *= a;
    }
    return r;
}

pub fn pow_ui_inv(pr_inv: *u32, pshift: *c_int, a: c_int, b: c_int) void {
    if (a == 5 and b >= 1 and b <= 13) {
        const r: u32 = pow5_table[@intCast(b - 1)];
        const shift: i32 = clz32(r);
        _ = @as(u32, r << @intCast(shift)); // normalized value (not returned)
        pr_inv.* = pow5_inv_table[@intCast(b - 1)];
        pshift.* = shift;
        return;
    }
    const r: u64 = pow_ui(a, b);
    const shift: i32 = clz32(@as(u32, @truncate(r)));
    const r_shifted: u32 = @as(u32, @truncate(r << @intCast(shift)));
    pr_inv.* = udiv1norm_init(r_shifted);
    pshift.* = shift;
}

// --- mpb get/set operations ---

pub fn mpb_get_bit(r: *const anyopaque, k_param: c_int) c_int {
    const tab = mpb_const_ptr(r);
    const s = mpb_const_struct(r);
    const k: u32 = @intCast(k_param);
    const l: usize = @intCast(k / LIMB_BITS);
    const bit: u5 = @intCast(k & (LIMB_BITS - 1));
    if (l >= @as(usize, @intCast(s.len)))
        return 0
    else
        return @intCast((tab[l] >> bit) & 1);
}

pub fn mpb_shr_round(r: *anyopaque, shift_param: c_int, rnd_mode: c_int) void {
    if (shift_param == 0) return;
    const s = mpb_struct(r);
    const tab = mpb_ptr(r);

    if (shift_param < 0) {
        // left shift
        var shift: u32 = @intCast(-shift_param);
        const l: usize = @intCast(shift / LIMB_BITS);
        shift = shift & (LIMB_BITS - 1);
        if (shift != 0) {
            const uShift: u5 = @intCast(shift);
            tab[@intCast(s.len)] = mp_shl(tab, tab, @intCast(s.len), @intCast(uShift), 0);
            s.len += 1;
            mpb_renorm(r);
        }
        if (l > 0) {
            var i: isize = @intCast(s.len - 1);
            while (i >= 0) : (i -= 1) {
                tab[@as(usize, @intCast(i + @as(isize, @intCast(l))))] = tab[@intCast(i)];
            }
            var j: usize = 0;
            while (j < l) : (j += 1) {
                tab[j] = 0;
            }
            s.len += @intCast(l);
        }
    } else {
        // right shift with rounding
        var shift: u32 = @intCast(shift_param);
        var add_one: i32 = 0;

        switch (rnd_mode) {
            JS_RNDZ => {
                add_one = 0;
            },
            JS_RNDN, JS_RNDNA => {
                const bit1: limb_t = @intCast(mpb_get_bit(r, @intCast(shift - 1)));
                if (bit1 != 0) {
                    var bit2: limb_t = 0;
                    if (rnd_mode == JS_RNDNA) {
                        bit2 = 1;
                    } else {
                        // bit2 = oring of all the bits after bit1
                        bit2 = 0;
                        if (shift >= 2) {
                            var kk: i32 = @intCast(shift - 1);
                            const ll: usize = @intCast(@divFloor(kk, LIMB_BITS));
                            kk = kk & (LIMB_BITS - 1);
                            const min_l: usize = @intCast(min_int(@intCast(ll), s.len));
                            var ii: usize = 0;
                            while (ii < min_l) : (ii += 1) {
                                bit2 |= tab[ii];
                            }
                            if (ll < @as(usize, @intCast(s.len))) {
                                bit2 |= tab[ll] & ((@as(limb_t, 1) << @intCast(kk)) - 1);
                            }
                        }
                    }
                    if (bit2 != 0) {
                        add_one = 1;
                    } else {
                        // round to even
                        add_one = mpb_get_bit(r, @intCast(shift));
                    }
                } else {
                    add_one = 0;
                }
            },
            else => {
                add_one = 0;
            },
        }

        const l: usize = @intCast(shift / LIMB_BITS);
        shift = shift & (LIMB_BITS - 1);
        if (l >= @as(usize, @intCast(s.len))) {
            s.len = 1;
            tab[0] = @intCast(add_one);
        } else {
            if (l > 0) {
                s.len -= @intCast(l);
                var ii: usize = 0;
                while (ii < @as(usize, @intCast(s.len))) : (ii += 1) {
                    tab[ii] = tab[ii + l];
                }
            }
            if (shift != 0) {
                const uShift: u5 = @intCast(shift);
                _ = mp_shr(tab, tab, @intCast(s.len), @intCast(uShift), 0);
                mpb_renorm(r);
            }
            if (add_one != 0) {
                const a_carry: limb_t = mp_add_ui(tab, 1, @intCast(s.len));
                if (a_carry != 0) {
                    tab[@intCast(s.len)] = a_carry;
                    s.len += 1;
                }
            }
        }
    }
}

pub fn mpb_cmp(a: *const anyopaque, b: *const anyopaque) c_int {
    const sa = mpb_const_struct(a);
    const sb = mpb_const_struct(b);
    const tab_a = mpb_const_ptr(a);
    const tab_b = mpb_const_ptr(b);

    if (sa.len < sb.len) return -1;
    if (sa.len > sb.len) return 1;

    var i: isize = @intCast(sa.len - 1);
    while (i >= 0) : (i -= 1) {
        const idx: usize = @intCast(i);
        if (tab_a[idx] != tab_b[idx]) {
            if (tab_a[idx] < tab_b[idx]) return -1 else return 1;
        }
    }
    return 0;
}

pub fn mpb_set_u64(r: *anyopaque, m: u64) void {
    const s = mpb_struct(r);
    const tab = mpb_ptr(r);
    tab[0] = @as(limb_t, @truncate(m));
    tab[1] = @as(limb_t, @truncate(m >> LIMB_BITS));
    if (tab[1] == 0) {
        s.len = 1;
    } else {
        s.len = 2;
    }
}

pub fn mpb_get_u64(r: *anyopaque) u64 {
    const s = mpb_struct(r);
    const tab = mpb_ptr(r);
    if (s.len == 1) {
        return tab[0];
    } else {
        return tab[0] | (@as(u64, tab[1]) << LIMB_BITS);
    }
}

pub fn mpb_floor_log2(a: *anyopaque) c_int {
    const s = mpb_struct(a);
    const tab = mpb_ptr(a);
    const v: limb_t = tab[@intCast(s.len - 1)];
    if (v == 0)
        return -1
    else
        return s.len * LIMB_BITS - 1 - clz32(v);
}

// --- mul_log2_radix ---

const MUL_LOG2_RADIX_BASE_LOG2: comptime_int = 24;

const mul_log2_radix_table = [JS_RADIX_MAX - 1]u32{
    0x000000, 0xa1849d, 0x000000, 0x6e40d2,
    0x6308c9, 0x5b3065, 0x000000, 0x50c24e,
    0x4d104d, 0x4a0027, 0x4768ce, 0x452e54,
    0x433d00, 0x418677, 0x000000, 0x3ea16b,
    0x3d645a, 0x3c43c2, 0x3b3b9a, 0x3a4899,
    0x39680b, 0x3897b3, 0x37d5af, 0x372069,
    0x367686, 0x35d6df, 0x354072, 0x34b261,
    0x342bea, 0x33ac62, 0x000000, 0x32bfd9,
    0x3251dd, 0x31e8d6, 0x318465,
};

// return floor(a / log2(radix)) for -2048 <= a <= 2047
pub fn mul_log2_radix(a_param: c_int, radix: c_int) c_int {
    if ((radix & (radix - 1)) == 0) {
        var a = a_param;
        const radix_bits: i32 = 31 - clz32(@intCast(radix));
        if (a < 0) a -= radix_bits - 1;
        return @divTrunc(a, radix_bits);
    } else {
        const mult: i32 = @bitCast(mul_log2_radix_table[@intCast(radix - 2)]);
        return @intCast((@as(i64, a_param) * @as(i64, mult)) >> MUL_LOG2_RADIX_BASE_LOG2);
    }
}

// --- Integer-to-string conversion ---

fn u32toa_len(buf: [*]u8, n: u32, len: usize) void {
    var nn = n;
    var i: isize = @intCast(len - 1);
    while (i >= 0) : (i -= 1) {
        const digit: u8 = @intCast(nn % 10);
        nn = nn / 10;
        buf[@intCast(i)] = digit + '0';
    }
}

// for power of 2 radixes. len >= 1
fn u64toa_bin_len(buf: [*]u8, n: u64, radix_bits: u32, len: i32) void {
    const mask: u64 = (@as(u64, 1) << @intCast(radix_bits)) - 1;
    var nn = n;
    var i: isize = @intCast(len - 1);
    while (i >= 0) : (i -= 1) {
        var digit: u8 = @intCast(nn & mask);
        nn >>= @intCast(radix_bits);
        if (digit < 10)
            digit += '0'
        else
            digit += 'a' - 10;
        buf[@intCast(i)] = digit;
    }
}

// len >= 1. 2 <= radix <= 36
pub fn limb_to_a(buf: [*]u8, n: limb_t, radix: c_int, len: c_int) void {
    if (radix == 10) {
        u32toa_len(buf, n, @intCast(len));
    } else {
        var nn = n;
        var i: isize = @intCast(len - 1);
        while (i >= 0) : (i -= 1) {
            var digit: u8 = @intCast(nn % @as(limb_t, @intCast(radix)));
            nn = nn / @as(limb_t, @intCast(radix));
            if (digit < 10)
                digit += '0'
            else
                digit += 'a' - 10;
            buf[@intCast(i)] = digit;
        }
    }
}

pub fn u32toa(buf: [*]u8, n: u32) usize {
    var buf1: [10]u8 = undefined;
    var nn = n;
    var q: [*]u8 = buf1[0..].ptr + 10;
    while (true) {
        q -= 1;
        q[0] = @as(u8, @intCast(nn % 10)) + '0';
        nn /= 10;
        if (nn == 0) break;
    }
    const len: usize = @intFromPtr(buf1[0..].ptr + 10) - @intFromPtr(q);
    std.mem.copyForwards(u8, buf[0..len], q[0..len]);
    return len;
}

pub fn i32toa(buf: [*]u8, n: i32) usize {
    if (n >= 0) {
        return u32toa(buf, @intCast(n));
    } else {
        buf[0] = '-';
        return u32toa(buf + 1, @intCast(-@as(i64, n))) + 1;
    }
}

pub fn u64toa(buf: [*]u8, n: u64) usize {
    if (n < 0x100000000) {
        return u32toa(buf, @as(u32, @truncate(n)));
    } else {
        var n1: u64 = n / 1000000000;
        const n0: u64 = n % 1000000000;
        var q: [*]u8 = buf;

        if (n1 >= 0x100000000) {
            var n2: u32 = @intCast(n1 / 1000000000);
            n1 = n1 % 1000000000;
            // at most two digits
            if (n2 >= 10) {
                q[0] = @as(u8, @intCast(n2 / 10)) + '0';
                q += 1;
                n2 = n2 % 10;
            }
            q[0] = @as(u8, @intCast(n2)) + '0';
            q += 1;
            u32toa_len(q, @as(u32, @truncate(n1)), 9);
            q += 9;
        } else {
            const ll = u32toa(q, @as(u32, @truncate(n1)));
            q += ll;
        }
        u32toa_len(q, @as(u32, @truncate(n0)), 9);
        q += 9;
        return @intFromPtr(q) - @intFromPtr(buf);
    }
}

pub fn i64toa(buf: [*]u8, n: i64) usize {
    if (n >= 0) {
        return u64toa(buf, @intCast(n));
    } else {
        buf[0] = '-';
        return u64toa(buf + 1, @intCast(-@as(i128, n))) + 1;
    }
}

pub fn u64toa_radix(buf: [*]u8, n: u64, radix: c_uint) usize {
    if (radix == 10) return u64toa(buf, n);
    if ((radix & (radix - 1)) == 0) {
        const radix_bits: i32 = 31 - clz32(@intCast(radix));
        var l: i32 = undefined;
        if (n == 0)
            l = 1
        else
            l = @intCast(@divFloor(64 - clz64(n) + radix_bits - 1, radix_bits));
        u64toa_bin_len(buf, n, @intCast(radix_bits), l);
        return @intCast(l);
    } else {
        var buf1: [41]u8 = undefined; // maximum length for radix = 3
        var nn = n;
        var q: [*]u8 = buf1[0..].ptr + 41;
        while (true) {
            var digit: u8 = @intCast(nn % @as(u64, radix));
            nn = nn / @as(u64, radix);
            if (digit < 10)
                digit += '0'
            else
                digit += 'a' - 10;
            q -= 1;
            q[0] = digit;
            if (nn == 0) break;
        }
        const len: usize = @intFromPtr(buf1[0..].ptr + 41) - @intFromPtr(q);
        std.mem.copyForwards(u8, buf[0..len], q[0..len]);
        return len;
    }
}

pub fn i64toa_radix(buf: [*]u8, n: i64, radix: c_uint) usize {
    if (n >= 0) {
        return u64toa_radix(buf, @intCast(n), radix);
    } else {
        buf[0] = '-';
        return u64toa_radix(buf + 1, @intCast(-@as(i128, n)), radix) + 1;
    }
}

// --- Lookup tables ---

const digits_per_limb_table = [JS_RADIX_MAX - 1]u8{
    32, 20, 16, 13, 12, 11, 10, 10, 9, 9, 8, 8, 8, 8, 8, 7, 7, 7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
};

const radix_base_table = [JS_RADIX_MAX - 1]u32{
    0x00000000, 0xcfd41b91, 0x00000000, 0x48c27395,
    0x81bf1000, 0x75db9c97, 0x40000000, 0xcfd41b91,
    0x3b9aca00, 0x8c8b6d2b, 0x19a10000, 0x309f1021,
    0x57f6c100, 0x98c29b81, 0x00000000, 0x18754571,
    0x247dbc80, 0x3547667b, 0x4c4b4000, 0x6b5a6e1d,
    0x94ace180, 0xcaf18367, 0x0b640000, 0x0e8d4a51,
    0x1269ae40, 0x17179149, 0x1cb91000, 0x23744899,
    0x2b73a840, 0x34e63b41, 0x40000000, 0x4cfa3cc1,
    0x5c13d840, 0x6d91b519, 0x81bf1000,
};

const dtoa_max_digits_table = [JS_RADIX_MAX - 1]u8{
    54, 35, 28, 24, 22, 20, 19, 18, 17, 17, 16, 16, 15, 15, 15, 14, 14, 14, 14, 14, 13, 13, 13, 13, 13, 13, 13, 12, 12, 12, 12, 12, 12, 12, 12,
};

const atod_max_digits_table = [JS_RADIX_MAX - 1]u8{
    64, 80, 32, 55, 49, 45, 21, 40, 38, 37, 35, 34, 33, 32, 16, 31, 30, 30, 29, 29, 28, 28, 27, 27, 27, 26, 26, 26, 26, 25, 12, 25, 25, 24, 24,
};

const max_exponent = [JS_RADIX_MAX - 1]i16{
    1024, 647, 512, 442, 397, 365, 342, 324,
    309,  297, 286, 277, 269, 263, 256, 251,
    246,  242, 237, 234, 230, 227, 224, 221,
    218,  216, 214, 211, 209, 207, 205, 203,
    202,  200, 199,
};

const min_exponent = [JS_RADIX_MAX - 1]i16{
    -1075, -679, -538, -463, -416, -383, -359, -340,
    -324,  -311, -300, -291, -283, -276, -269, -263,
    -258,  -254, -249, -245, -242, -238, -235, -232,
    -229,  -227, -224, -222, -220, -217, -215, -214,
    -212,  -210, -208,
};

// --- output_digits ---

// n_digits >= 1. 0 <= dot_pos <= n_digits. If dot_pos == n_digits,
// the dot is not displayed. 'a' is modified.
pub fn output_digits(buf: [*]u8, a: *anyopaque, radix: c_int, n_digits1_param: c_int, dot_pos_param: c_int) c_int {
    const tab = mpb_ptr(a);
    const s = mpb_struct(a);
    var n_digits: i32 = n_digits1_param;
    const dot_pos: i32 = dot_pos_param;
    var radix_bits: i32 = 0;

    if ((radix & (radix - 1)) == 0) {
        radix_bits = 31 - clz32(@intCast(radix));
    }

    const digits_per_limb: i32 = digits_per_limb_table[@intCast(radix - 2)];

    if (radix_bits != 0) {
        while (true) {
            const nn: i32 = min_int(n_digits, digits_per_limb);
            n_digits -= nn;
            u64toa_bin_len(buf + @as(usize, @intCast(n_digits)), tab[0], @as(u32, @intCast(radix_bits)), nn);
            if (n_digits == 0) break;
            mpb_shr_round(a, digits_per_limb * radix_bits, JS_RNDZ);
        }
    } else {
        var rr: limb_t = 0;
        while (n_digits != 0) {
            const nn: i32 = min_int(n_digits, digits_per_limb);
            n_digits -= nn;
            rr = mp_div1(tab, tab, @intCast(s.len), radix_base_table[@intCast(radix - 2)], 0);
            mpb_renorm(a);
            limb_to_a(buf + @as(usize, @intCast(n_digits)), rr, radix, nn);
        }
    }

    // add the dot
    var len: i32 = n_digits1_param;
    if (dot_pos != n_digits1_param) {
        // dest starts at dot_pos+1, src starts at dot_pos, they overlap
        // so we must copy backwards (like C's memmove)
        var j: i32 = n_digits1_param;
        while (j > dot_pos) : (j -= 1) {
            buf[@intCast(j)] = buf[@intCast(j - 1)];
        }
        buf[@intCast(dot_pos)] = '.';
        len += 1;
    }
    return len;
}

// --- mul_pow ---

// return (a, e_offset) such that a = a * (radix1*2^radix_shift)^f *
//   2^-e_offset. 'f' can be negative.
fn mul_pow(a: *anyopaque, radix1: c_int, radix_shift: c_int, f_param: c_int, is_int: bool, e: c_int) i32 {
    const tab = mpb_ptr(a);
    const s = mpb_struct(a);
    var f: i32 = f_param;
    var e_offset: i32 = -f * radix_shift;

    if (radix1 != 1) {
        const d: i32 = digits_per_limb_table[@intCast(radix1 - 2)];
        if (f >= 0) {
            var h: limb_t = 0;
            var b: limb_t = 0;
            var n0: i32 = 0;
            while (f != 0) {
                const nn: i32 = min_int(f, d);
                if (nn != n0) {
                    b = @as(limb_t, @truncate(pow_ui(radix1, nn)));
                    n0 = nn;
                }
                h = mp_mul1(tab, tab, @intCast(s.len), b, 0);
                if (h != 0) {
                    tab[@intCast(s.len)] = h;
                    s.len += 1;
                }
                f -= nn;
            }
        } else {
            var extra_bits: i32 = 0;
            const ll: i32 = @divFloor((-f) + d - 1, d); // high bound for number of limbs
            e_offset += ll * LIMB_BITS;
            if (!is_int) {
                extra_bits = max_int(e - mpb_floor_log2(a), 0);
            } else {
                extra_bits = max_int(2 + e - e_offset, 0);
            }
            e_offset += extra_bits;
            mpb_shr_round(a, -(ll * LIMB_BITS + extra_bits), JS_RNDZ);

            f = -f;
            var b: limb_t = 0;
            var b_inv: limb_t = 0;
            var shift: c_int = 0;
            var n0: i32 = 0;
            var rem: limb_t = 0;
            while (f != 0) {
                const nn: i32 = min_int(f, d);
                if (nn != n0) {
                    // Compute normalized divisor for division
                    const raw_r: u64 = pow_ui(radix1, nn);
                    const raw_shift: i32 = clz32(@as(u32, @truncate(raw_r)));
                    b = @as(limb_t, @truncate(raw_r << @intCast(raw_shift)));
                    // Get inverse from table or compute it
                    if (radix1 == 5 and nn >= 1 and nn <= 13) {
                        b_inv = pow5_inv_table[@intCast(nn - 1)];
                        shift = raw_shift;
                    } else {
                        b_inv = udiv1norm_init(b);
                        shift = raw_shift;
                    }
                    n0 = nn;
                }
                const r_div: limb_t = mp_div1norm(tab, tab, @intCast(s.len), b, 0, b_inv, shift);
                rem |= r_div;
                mpb_renorm(a);
                f -= nn;
            }
            // if the remainder is non zero, use it for rounding
            tab[0] |= @intFromBool(rem != 0);
        }
    }
    return e_offset;
}

// tmp1 = round(m*2^e*radix^f). 'tmp0' is a temporary storage
fn mul_pow_round(tmp1: *anyopaque, m: u64, e: c_int, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) void {
    mpb_set_u64(tmp1, m);
    const e_offset: i32 = mul_pow(tmp1, radix1, radix_shift, f, true, e);
    mpb_shr_round(tmp1, -e + e_offset, rnd_mode);
}

// return round(a*2^e_offset) rounded as a float64. 'a' is modified
pub fn round_to_d(pe: *c_int, a: *anyopaque, e_offset: c_int, rnd_mode: c_int) u64 {
    const tab = mpb_ptr(a);
    const s = mpb_struct(a);
    var e: i32 = 0;
    var m: u64 = 0;

    if (tab[0] == 0 and s.len == 1) {
        // zero result
        m = 0;
        e = 0; // don't care
    } else {
        e = mpb_floor_log2(a) + 1 - e_offset;
        const prec1: i32 = 53;
        const e_min: i32 = -1021;
        var prec: i32 = prec1;
        if (e < e_min) {
            // subnormal result or zero
            prec = prec1 - (e_min - e);
        }
        mpb_shr_round(a, e + e_offset - prec, rnd_mode);
        m = mpb_get_u64(a);
        m <<= @intCast(53 - prec);
        // mantissa overflow due to rounding
        if (m >= @as(u64, 1) << 53) {
            m >>= 1;
            e += 1;
        }
    }
    pe.* = e;
    return m;
}

// return (m, e) such that m*2^(e-53) = round(a * radix^f) with 2^52
//   <= m < 2^53 or m = 0.
//   'a' is modified.
pub fn mul_pow_round_to_d(pe: *c_int, a: *anyopaque, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) u64 {
    const e_offset: i32 = mul_pow(a, radix1, radix_shift, f, false, 55);
    return round_to_d(pe, a, e_offset, rnd_mode);
}

// --- Memory allocator (bump allocator from temp mem) ---

fn dtoa_malloc(pptr: *[*]u64, size: usize) *anyopaque {
    const ret: [*]u64 = pptr.*;
    pptr.* = @ptrFromInt(@intFromPtr(ret) + ((size + 7) / 8) * 8);
    return @ptrCast(ret);
}

// --- js_dtoa_max_len ---

pub fn js_dtoa_max_len(d: f64, radix: c_int, n_digits: c_int, flags: c_int) c_int {
    const fmt: i32 = flags & JS_DTOA_FORMAT_MASK;
    var n: i32 = 0;

    if (fmt != JS_DTOA_FORMAT_FRAC) {
        if (fmt == JS_DTOA_FORMAT_FREE) {
            n = dtoa_max_digits_table[@intCast(radix - 2)];
        } else {
            n = n_digits;
        }
        if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_DISABLED) {
            // no exponential
            const a: u64 = float64_as_uint64(d);
            var ee: i32 = @intCast((a >> 52) & 0x7ff);
            if (ee == 0x7ff) {
                // NaN, Infinity
                n = 0;
            } else {
                ee -= 1023;
                n += 10 + @as(i32, @intCast(@abs(mul_log2_radix(ee - 1, radix))));
            }
        } else {
            // extra: sign, 1 dot and exponent "e-1000"
            n += 1 + 1 + 6;
        }
    } else {
        const a: u64 = float64_as_uint64(d);
        var ee: i32 = @intCast((a >> 52) & 0x7ff);
        if (ee == 0x7ff) {
            // NaN, Infinity
            n = 0;
        } else {
            // high bound for the integer part
            ee -= 1023;
            // x < 2^(e + 1)
            if (ee < 0) {
                n = 1;
            } else {
                n = 2 + mul_log2_radix(ee - 1, radix);
            }
            // sign, extra digit, 1 dot
            n += 1 + 1 + 1 + n_digits;
        }
    }
    return max_int(n, 9); // also include NaN and [-]Infinity
}

// --- js_dtoa ---

pub fn js_dtoa(buf: [*]u8, d: f64, radix: c_int, n_digits: c_int, flags: c_int, tmp_mem: *JSDTOATempMem) c_int {
    var mptr: [*]u64 = @ptrCast(tmp_mem);
    const a: u64 = float64_as_uint64(d);
    const sgn: i32 = @intCast(a >> 63);
    var ee: i32 = @intCast((a >> 52) & 0x7ff);
    var m: u64 = a & ((@as(u64, 1) << 52) - 1);
    var q: [*]u8 = buf;
    const fmt: i32 = flags & JS_DTOA_FORMAT_MASK;

    const radix_shift: i32 = ctz32(@intCast(radix));
    const radix1: i32 = @intCast(@as(u32, @intCast(radix)) >> @intCast(radix_shift));

    const tmp1: *anyopaque = dtoa_malloc(&mptr, @sizeOf(Mpb) + @sizeOf(limb_t) * DBIGNUM_LEN_MAX);
    const mant_max: *anyopaque = dtoa_malloc(&mptr, @sizeOf(Mpb) + @sizeOf(limb_t) * MANT_LEN_MAX);

    if (ee == 0x7ff) {
        if (m == 0) {
            if (sgn != 0) {
                q[0] = '-';
                q += 1;
            }
            std.mem.copyForwards(u8, q[0..8], "Infinity");
            q += 8;
        } else {
            std.mem.copyForwards(u8, q[0..3], "NaN");
            q += 3;
        }
        q[0] = 0;
        return @intCast(@intFromPtr(q) - @intFromPtr(buf));
    } else if (ee == 0) {
        if (m == 0) {
            mpb_struct(tmp1).len = 1;
            mpb_ptr(tmp1)[0] = 0;
            const E: i32 = 1;
            var P: i32 = undefined;
            if (fmt == JS_DTOA_FORMAT_FREE)
                P = 1
            else if (fmt == JS_DTOA_FORMAT_FRAC)
                P = n_digits + 1
            else
                P = n_digits;
            // "-0" is displayed as "0" if JS_DTOA_MINUS_ZERO is not present
            if (sgn != 0 and (flags & JS_DTOA_MINUS_ZERO) != 0) {
                q[0] = '-';
                q += 1;
            }
            // jump to output
            return js_dtoa_output(buf, q, tmp1, radix, radix1, radix_shift, P, E, fmt, n_digits, flags);
        }
        // denormal number: convert to a normal number
        const l: i32 = clz64(m) - 11;
        ee -= l - 1;
        m <<= @intCast(l);
    } else {
        m |= @as(u64, 1) << 52;
    }

    if (sgn != 0) {
        q[0] = '-';
        q += 1;
    }
    // remove the bias
    ee -= 1022;
    // d = 2^(e-53)*m

    // USE_FAST_INT path
    if (fmt == JS_DTOA_FORMAT_FREE and
        ee >= 1 and ee <= 53 and
        (m & ((@as(u64, 1) << @intCast(53 - ee)) - 1)) == 0 and
        (flags & JS_DTOA_EXP_MASK) != JS_DTOA_EXP_ENABLED)
    {
        m >>= @intCast(53 - ee);
        // 'm' is never zero
        const ll = u64toa_radix(q, m, @intCast(radix));
        q += ll;
        q[0] = 0;
        return @intCast(@intFromPtr(q) - @intFromPtr(buf));
    }

    // this choice of E implies F=round(x*B^(P-E) is such as:
    // B^(P-1) <= F < 2.B^P.
    var E: i32 = 1 + mul_log2_radix(ee - 1, radix);
    var P: i32 = undefined;

    if (fmt == JS_DTOA_FORMAT_FREE) {
        const P_max: i32 = dtoa_max_digits_table[@intCast(radix - 2)];
        const E0: i32 = E;
        var E_found: i32 = 0;
        var P_found: i32 = 0;
        var mant_found: u64 = 0;

        // find the minimum number of digits by successive tries
        P = P_max; // P_max is guaranteed to work
        while (true) {
            // mant_max always fits on 64 bits
            const mant_max1: u64 = pow_ui(radix, P);
            // compute the mantissa in base B
            E = E0;
            var mant: u64 = undefined;
            while (true) {
                mul_pow_round(tmp1, m, ee - 53, radix1, radix_shift, P - E, JS_RNDN);
                mant = mpb_get_u64(tmp1);
                if (mant < mant_max1) break;
                E += 1; // at most one iteration is possible
            }
            // remove useless trailing zero digits
            while (mant % @as(u64, @intCast(radix)) == 0) {
                mant = mant / @as(u64, @intCast(radix));
                P -= 1;
            }
            // guaranteed to work for P = P_max
            if (P_found == 0) {
                P_found = P;
                E_found = E;
                mant_found = mant;
                if (P == 1) break;
                P -= 1; // try lower exponent
            } else {
                // convert back to base 2
                mpb_set_u64(tmp1, mant);
                var e1: c_int = 0;
                const m1: u64 = mul_pow_round_to_d(&e1, tmp1, radix1, radix_shift, E - P, JS_RNDN);
                if (m1 == m and e1 == ee) {
                    P_found = P;
                    E_found = E;
                    mant_found = mant;
                    if (P == 1) break;
                    P -= 1;
                } else {
                    break;
                }
            }
        }
        P = P_found;
        E = E_found;
        mpb_set_u64(tmp1, mant_found);
    } else if (fmt == JS_DTOA_FORMAT_FRAC) {
        std.debug.assert(n_digits >= 0 and n_digits <= JS_DTOA_MAX_DIGITS);
        // frac is rounded using RNDNA
        mul_pow_round(tmp1, m, ee - 53, radix1, radix_shift, n_digits, JS_RNDNA);

        // we add one extra digit on the left and remove it if needed
        // to avoid testing if the result is < radix^P
        var len: i32 = output_digits(q, tmp1, radix, max_int(E + 1, 1) + n_digits, max_int(E + 1, 1));
        if (q[0] == '0' and len >= 2 and q[1] != '.') {
            len -= 1;
            std.mem.copyForwards(u8, q[0..@intCast(len)], q[1..@intCast(len + 1)]);
        }
        q += @intCast(len);
        q[0] = 0;
        return @intCast(@intFromPtr(q) - @intFromPtr(buf));
    } else {
        // fixed format
        std.debug.assert(n_digits >= 1 and n_digits <= JS_DTOA_MAX_DIGITS);
        P = n_digits;
        // mant_max = radix^P
        mpb_struct(mant_max).len = 1;
        mpb_ptr(mant_max)[0] = 1;
        const pow_shift: i32 = mul_pow(mant_max, radix1, radix_shift, P, false, 0);
        mpb_shr_round(mant_max, pow_shift, JS_RNDZ);

        while (true) {
            // fixed and frac are rounded using RNDNA
            mul_pow_round(tmp1, m, ee - 53, radix1, radix_shift, P - E, JS_RNDNA);
            if (mpb_cmp(tmp1, mant_max) < 0) break;
            E += 1; // at most one iteration is possible
        }
    }

    return js_dtoa_output(buf, q, tmp1, radix, radix1, radix_shift, P, E, fmt, n_digits, flags);
}

fn js_dtoa_output(buf: [*]u8, q_start: [*]u8, tmp1: *anyopaque, radix: c_int, radix1: c_int, radix_shift: c_int, P: i32, E: i32, fmt: i32, n_digits: c_int, flags: c_int) c_int {
    var q = q_start;
    var EE = E;
    const PP = P;

    var E_max: i32 = undefined;
    if (fmt == JS_DTOA_FORMAT_FIXED)
        E_max = n_digits
    else
        E_max = dtoa_max_digits_table[@intCast(radix - 2)] + 4;

    if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_ENABLED or
        ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_AUTO and (EE <= -6 or EE > E_max)))
    {
        q += @intCast(output_digits(q, tmp1, radix, PP, 1));
        EE -= 1;
        if (radix == 10) {
            q[0] = 'e';
            q += 1;
        } else if (radix1 == 1 and radix_shift <= 4) {
            EE *= radix_shift;
            q[0] = 'p';
            q += 1;
        } else {
            q[0] = '@';
            q += 1;
        }
        if (EE < 0) {
            q[0] = '-';
            q += 1;
            EE = -EE;
        } else {
            q[0] = '+';
            q += 1;
        }
        q += u32toa(q, @intCast(EE));
    } else if (EE <= 0) {
        q[0] = '0';
        q += 1;
        q[0] = '.';
        q += 1;
        var i: i32 = 0;
        while (i < -EE) : (i += 1) {
            q[0] = '0';
            q += 1;
        }
        q += @intCast(output_digits(q, tmp1, radix, PP, PP));
    } else {
        const written: usize = @intCast(output_digits(q, tmp1, radix, PP, min_int(PP, EE)));
        q += @intCast(written);
        var i: i32 = 0;
        while (i < EE - PP) : (i += 1) {
            q[0] = '0';
            q += 1;
        }
    }
    q[0] = 0;
    return @intCast(@intFromPtr(q) - @intFromPtr(buf));
}

// --- js_atod ---

fn to_digit(c: u8) i32 {
    if (c >= '0' and c <= '9')
        return c - '0'
    else if (c >= 'A' and c <= 'Z')
        return c - 'A' + 10
    else if (c >= 'a' and c <= 'z')
        return c - 'a' + 10
    else
        return 36;
}

// r = r * radix_base + a. radix_base = 0 means radix_base = 2^32
pub fn mpb_mul1_base(r: *anyopaque, radix_base: limb_t, b_param: limb_t) void {
    const tab = mpb_ptr(r);
    const s = mpb_struct(r);

    if (tab[0] == 0 and s.len == 1) {
        tab[0] = b_param;
    } else {
        if (radix_base == 0) {
            var i: isize = @intCast(s.len);
            while (i >= 0) : (i -= 1) {
                tab[@intCast(i + 1)] = tab[@intCast(i)];
            }
            tab[0] = b_param;
        } else {
            tab[@intCast(s.len)] = mp_mul1(tab, tab, @intCast(s.len), radix_base, b_param);
        }
        s.len += 1;
        mpb_renorm(r);
    }
}

pub fn js_atod(str: [*]const u8, pnext: [*c][*c]const u8, radix: c_int, flags: c_int, tmp_mem: *JSATODTempMem) f64 {
    var mptr: [*]u64 = @ptrCast(tmp_mem);

    const tmp0: *anyopaque = dtoa_malloc(&mptr, @sizeOf(Mpb) + @sizeOf(limb_t) * DBIGNUM_LEN_MAX);

    // optional separator between digits
    var sep_valid: bool = (flags & JS_ATOD_ACCEPT_UNDERSCORES) != 0;
    const sep_char: u8 = '_';

    var p: [*]const u8 = str;
    var p_start: [*]const u8 = undefined;
    var is_neg: i32 = 0;

    if (p[0] == '+') {
        p += 1;
        p_start = p;
    } else if (p[0] == '-') {
        is_neg = 1;
        p += 1;
        p_start = p;
    } else {
        p_start = p;
    }

    var radix_local: i32 = radix;

    if (p[0] == '0') {
        if ((p[1] == 'x' or p[1] == 'X') and
            (radix_local == 0 or radix_local == 16))
        {
            p += 2;
            radix_local = 16;
        } else if ((p[1] == 'o' or p[1] == 'O') and
            radix_local == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0)
        {
            p += 2;
            radix_local = 8;
        } else if ((p[1] == 'b' or p[1] == 'B') and
            radix_local == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0)
        {
            p += 2;
            radix_local = 2;
        } else if (p[1] >= '0' and p[1] <= '9' and
            radix_local == 0 and (flags & JS_ATOD_ACCEPT_LEGACY_OCTAL) != 0)
        {
            var ii: usize = 1;
            while (p[ii] >= '0' and p[ii] <= '7') : (ii += 1) {}
            if (p[ii] == '8' or p[ii] == '9') {
                // not octal, fall through to no_prefix
            } else {
                p += 1;
                radix_local = 8;
                sep_valid = false;
            }
        } else {
            // no prefix - do nothing
        }
        // there must be a digit after the prefix
        if (radix_local != radix and radix_local != 0) {
            // We set a new radix from a prefix - check digit
            if (to_digit(p[0]) >= radix_local) {
                // fail: no digit after prefix
                if (pnext != null) pnext.* = p;
                return std.math.nan(f64);
            }
        }
    } else {
        if ((flags & JS_ATOD_INT_ONLY) == 0) {
            var ptr2: [*]const u8 = undefined;
            if (js__strstart(p, "Infinity", &ptr2)) {
                // overflow
                var aa: u64 = @as(u64, 0x7ff) << 52;
                if (is_neg != 0) aa |= @as(u64, 1) << 63;
                if (pnext != null) pnext.* = ptr2;
                return uint64_as_float64(aa);
            }
        }
    }

    if (radix_local == 0) radix_local = 10;

    var cur_limb: limb_t = 0;
    var expn_offset: i32 = 0;
    var digit_count: i32 = 0;
    var limb_digit_count: i32 = 0;
    const max_digits: i32 = atod_max_digits_table[@intCast(radix_local - 2)];
    const digits_per_limb: i32 = digits_per_limb_table[@intCast(radix_local - 2)];
    const radix_base: limb_t = radix_base_table[@intCast(radix_local - 2)];
    const rs: i32 = ctz32(@intCast(radix_local));
    const radix_shift_local: i32 = rs;
    const radix1_local: i32 = @intCast(@as(u32, @intCast(radix_local)) >> @intCast(rs));
    var radix_bits: i32 = 0;
    if (radix1_local == 1) {
        radix_bits = radix_shift_local;
    } else {
        radix_bits = 0;
    }
    mpb_struct(tmp0).len = 1;
    mpb_ptr(tmp0)[0] = 0;
    var extra_digits: limb_t = 0;
    var pos: i32 = 0;
    var dot_pos: i32 = -1;

    // skip leading zeros
    while (true) {
        if (p[0] == '.' and (@intFromPtr(p) > @intFromPtr(p_start) or to_digit(p[1]) < radix_local) and
            (flags & JS_ATOD_INT_ONLY) == 0)
        {
            if (sep_valid and p[0] == sep_char) {
                if (pnext != null) pnext.* = p;
                return std.math.nan(f64);
            }
            if (dot_pos >= 0) break;
            dot_pos = pos;
            p += 1;
        }
        if (sep_valid and p[0] == sep_char and @intFromPtr(p) > @intFromPtr(p_start) and p[1] == '0')
            p += 1;
        if (p[0] != '0') break;
        p += 1;
        pos += 1;
    }

    const sig_pos: i32 = pos;
    while (true) {
        if (p[0] == '.' and (@intFromPtr(p) > @intFromPtr(p_start) or to_digit(p[1]) < radix_local) and
            (flags & JS_ATOD_INT_ONLY) == 0)
        {
            if (sep_valid and p[0] == sep_char) {
                if (pnext != null) pnext.* = p;
                return std.math.nan(f64);
            }
            if (dot_pos >= 0) break;
            dot_pos = pos;
            p += 1;
        }
        if (sep_valid and p[0] == sep_char and @intFromPtr(p) > @intFromPtr(p_start) and to_digit(p[1]) < radix_local)
            p += 1;
        const c: limb_t = @intCast(to_digit(p[0]));
        if (c >= @as(limb_t, @intCast(radix_local))) break;
        p += 1;
        pos += 1;
        if (digit_count < max_digits) {
            cur_limb = cur_limb * @as(limb_t, @intCast(radix_local)) + c;
            limb_digit_count += 1;
            if (limb_digit_count == digits_per_limb) {
                mpb_mul1_base(tmp0, radix_base, cur_limb);
                cur_limb = 0;
                limb_digit_count = 0;
            }
            digit_count += 1;
        } else {
            extra_digits |= c;
        }
    }

    if (limb_digit_count != 0) {
        mpb_mul1_base(tmp0, @as(limb_t, @truncate(pow_ui(radix_local, limb_digit_count))), cur_limb);
    }

    const is_zero: bool = (digit_count == 0);
    if (is_zero) {
        expn_offset = 0;
    } else {
        if (dot_pos < 0) dot_pos = pos;
        expn_offset = sig_pos + digit_count - dot_pos;
    }

    // Use the extra digits for rounding if the base is a power of two.
    // Otherwise they are just truncated.
    if (radix_bits != 0 and extra_digits != 0) {
        mpb_ptr(tmp0)[0] |= 1;
    }

    // parse the exponent, if any
    var expn: i32 = 0;
    var expn_overflow: bool = false;
    var is_bin_exp: bool = false;
    if ((flags & JS_ATOD_INT_ONLY) == 0 and
        ((radix_local == 10 and (p[0] == 'e' or p[0] == 'E')) or
         (radix_local != 10 and (p[0] == '@' or
          (radix_bits >= 1 and radix_bits <= 4 and (p[0] == 'p' or p[0] == 'P'))))) and
        @intFromPtr(p) > @intFromPtr(p_start))
    {
        is_bin_exp = (p[0] == 'p' or p[0] == 'P');
        p += 1;
        var exp_is_neg: bool = false;
        if (p[0] == '+') {
            p += 1;
        } else if (p[0] == '-') {
            exp_is_neg = true;
            p += 1;
        }
        var cc: i32 = to_digit(p[0]);
        if (cc >= 10) {
            // fail
            if (pnext != null) pnext.* = p;
            return std.math.nan(f64);
        }
        expn = cc;
        p += 1;
        while (true) {
            if (sep_valid and p[0] == sep_char and to_digit(p[1]) < 10)
                p += 1;
            cc = to_digit(p[0]);
            if (cc >= 10) break;
            if (!expn_overflow) {
                if (expn > ((std.math.maxInt(i32) - 2 - 9) / 10)) {
                    expn_overflow = true;
                } else {
                    expn = expn * 10 + cc;
                }
            }
            p += 1;
        }
        if (exp_is_neg) expn = -expn;
        // if zero result, the exponent can be arbitrarily large
        if (!is_zero and expn_overflow) {
            var aa: u64 = undefined;
            if (exp_is_neg)
                aa = 0
            else
                aa = @as(u64, 0x7ff) << 52; // infinity
            if (is_neg != 0) aa |= @as(u64, 1) << 63;
            if (pnext != null) pnext.* = p;
            return uint64_as_float64(aa);
        }
    }

    if (@intFromPtr(p) == @intFromPtr(p_start)) {
        if (pnext != null) pnext.* = p;
        return std.math.nan(f64);
    }

    var aa: u64 = 0;
    if (is_zero) {
        aa = 0;
    } else {
        if (radix_bits != 0) {
            var local_expn: i32 = expn;
            if (!is_bin_exp)
                local_expn *= radix_bits;
            local_expn -= expn_offset * radix_bits;
            const expn1: i32 = local_expn + digit_count * radix_bits;
            if (expn1 >= 1024 + radix_bits) {
                aa = @as(u64, 0x7ff) << 52; // overflow
            } else if (expn1 <= -1075) {
                aa = 0; // underflow
            } else {
                var pe: c_int = 0;
                const mm: u64 = round_to_d(&pe, tmp0, -local_expn, JS_RNDN);
                if (mm == 0) {
                    aa = 0;
                } else if (pe > 1024) {
                    aa = @as(u64, 0x7ff) << 52;
                } else if (pe < -1073) {
                    aa = 0;
                } else if (pe < -1021) {
                    // subnormal
                    aa = mm >> @intCast(-pe - 1021);
                } else {
                    aa = (@as(u64, @intCast(pe + 1022)) << 52) | (mm & ((@as(u64, 1) << 52) - 1));
                }
            }
        } else {
            const local_expn: i32 = expn - expn_offset;
            const expn1: i32 = local_expn + digit_count;
            if (expn1 >= max_exponent[@intCast(radix_local - 2)] + 1) {
                aa = @as(u64, 0x7ff) << 52; // overflow
            } else if (expn1 <= min_exponent[@intCast(radix_local - 2)]) {
                aa = 0; // underflow
            } else {
                var pe: c_int = 0;
                const mm: u64 = mul_pow_round_to_d(&pe, tmp0, radix1_local, radix_shift_local, local_expn, JS_RNDN);
                if (mm == 0) {
                    aa = 0;
                } else if (pe > 1024) {
                    aa = @as(u64, 0x7ff) << 52;
                } else if (pe < -1073) {
                    aa = 0;
                } else if (pe < -1021) {
                    // subnormal
                    aa = mm >> @intCast(-pe - 1021);
                } else {
                    aa = (@as(u64, @intCast(pe + 1022)) << 52) | (mm & ((@as(u64, 1) << 52) - 1));
                }
            }
        }
    }

    if (is_neg != 0) aa |= @as(u64, 1) << 63;
    if (pnext != null) pnext.* = p;
    return uint64_as_float64(aa);
}
