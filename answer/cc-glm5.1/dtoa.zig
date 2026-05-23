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

// ---- Internal constants ----
const JS_RNDN: c_int = 0;
const JS_RNDNA: c_int = 1;
const JS_RNDZ: c_int = 2;

const LIMB_BITS: u5 = 32;
const JS_RADIX_MAX: u32 = 36;
const DBIGNUM_LEN_MAX: usize = 52;
const MANT_LEN_MAX: usize = 18;

const limb_t = u32;
const dlimb_t = u64;

// ---- mpb_t access helpers ----
// mpb_t layout: { len: c_int, tab: [N]limb_t }
// Accessed via *anyopaque for C ABI compatibility.

inline fn mpb_len_ptr(r: *anyopaque) *c_int {
    return @ptrCast(@alignCast(r));
}

inline fn mpb_len_val(r: *const anyopaque) c_int {
    return @as(*const c_int, @ptrCast(@alignCast(r))).*;
}

inline fn mpb_tab(r: *anyopaque) [*]limb_t {
    return @ptrCast(@alignCast(@as([*]u8, @ptrCast(r)) + 4));
}

inline fn mpb_tab_const(r: *const anyopaque) [*]const limb_t {
    return @ptrCast(@alignCast(@as([*]const u8, @ptrCast(r)) + 4));
}

// ---- cutils.h replacements ----

inline fn clz32(a: u32) u6 {
    return @intCast(@clz(a));
}

inline fn clz64(a: u64) u7 {
    return @intCast(@clz(a));
}

inline fn ctz32_val(a: u32) u6 {
    return @intCast(@ctz(a));
}

inline fn float64_to_u64(d: f64) u64 {
    return @bitCast(d);
}

inline fn u64_to_float64(u: u64) f64 {
    return @bitCast(u);
}

inline fn max_int(a: c_int, b: c_int) c_int {
    return @max(a, b);
}

inline fn min_int(a: c_int, b: c_int) c_int {
    return @min(a, b);
}

// ---- Bump allocator ----

fn dtoa_malloc(pptr: *[*]u64, size: usize) *anyopaque {
    const ret = pptr.*;
    pptr.* += (size + 7) / 8;
    return @ptrCast(@alignCast(ret));
}

// ---- mp arithmetic (raw limb arrays) ----

export fn mp_add_ui(tab: [*]limb_t, b: limb_t, n: usize) callconv(.c) limb_t {
    var k: limb_t = b;
    for (0..n) |i| {
        if (k == 0) break;
        const a = tab[i] +% k;
        k = if (a < k) 1 else 0;
        tab[i] = a;
    }
    return k;
}

fn mp_mul1(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, l: limb_t) limb_t {
    var carry = l;
    for (0..n) |i| {
        const t: dlimb_t = @as(dlimb_t, taba[i]) * @as(dlimb_t, b) + carry;
        tabr[i] = @truncate(t);
        carry = @truncate(t >> 32);
    }
    return carry;
}

export fn udiv1norm_init(d: limb_t) callconv(.c) limb_t {
    const a1: limb_t = 0 -% d -% 1;
    const a0: limb_t = 0xFFFFFFFF;
    return @as(u32, @truncate((@as(dlimb_t, a1) << 32) | a0)) / d;
}

fn udiv1norm_compute(pr: *limb_t, a1: limb_t, a0_param: limb_t, d: limb_t, d_inv: limb_t) limb_t {
    const n1m: limb_t = @bitCast(@as(i32, @bitCast(a0_param)) >> 31);
    const n_adj: limb_t = a0_param +% (n1m & d);
    var a: dlimb_t = @as(dlimb_t, d_inv) *% (@as(dlimb_t, a1) -% n1m) +% n_adj;
    var q: limb_t = @truncate((a >> 32) +% a1);
    a = (@as(dlimb_t, a1) << 32) | a0_param;
    a -%= @as(dlimb_t, q) *% d -% d;
    const ah: limb_t = @truncate(a >> 32);
    q +%= 1 +% ah;
    pr.* = @truncate(a +% @as(dlimb_t, ah & d));
    return q;
}

fn mp_div1(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r: limb_t) limb_t {
    var rr = r;
    var i: i32 = @intCast(n);
    while (i > 0) {
        i -= 1;
        const a1: dlimb_t = (@as(dlimb_t, rr) << 32) | taba[@intCast(i)];
        tabr[@intCast(i)] = @truncate(a1 / b);
        rr = @truncate(a1 % b);
    }
    return rr;
}

export fn mp_shr(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, high: limb_t) callconv(.c) limb_t {
    const sh: u5 = @intCast(shift);
    const csh: u6 = 32 - @as(u6, sh);
    var l: limb_t = high;
    var i: isize = n - 1;
    while (i >= 0) : (i -= 1) {
        const ui: usize = @intCast(i);
        const a = tab[ui];
        tab_r[ui] = (a >> sh) | (l << @intCast(csh));
        l = a;
    }
    return l & ((@as(limb_t, 1) << sh) - 1);
}

export fn mp_shl(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, low: limb_t) callconv(.c) limb_t {
    const sh: u5 = @intCast(shift);
    const csh: u6 = 32 - @as(u6, sh);
    var l: limb_t = low;
    for (0..@intCast(n)) |ui| {
        const a = tab[ui];
        tab_r[ui] = (a << sh) | l;
        l = a >> @intCast(csh);
    }
    return l;
}

fn mp_div1norm_impl(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r: limb_t, b_inv: limb_t, shift: c_int) limb_t {
    var rr = r;
    if (shift != 0) {
        const sh: u5 = @intCast(shift);
        rr = (rr << sh) | mp_shl(tabr, taba, @intCast(n), @intCast(shift), 0);
    }
    var i: i32 = @intCast(n);
    while (i > 0) {
        i -= 1;
        tabr[@intCast(i)] = udiv1norm_compute(&rr, rr, taba[@intCast(i)], b, b_inv);
    }
    rr >>= @intCast(shift);
    return rr;
}

export fn mp_div1norm(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r: limb_t, b_inv: limb_t, shift: c_int) callconv(.c) limb_t {
    return mp_div1norm_impl(tabr, taba, n, b, r, b_inv, shift);
}

// ---- mpb operations ----

export fn mpb_renorm(r: *anyopaque) callconv(.c) void {
    const lp = mpb_len_ptr(r);
    const t = mpb_tab(r);
    while (lp.* > 1 and t[@intCast(lp.*)] == 0) {
        lp.* -= 1;
    }
}

export fn mpb_set_u64(r: *anyopaque, m: u64) callconv(.c) void {
    const lp = mpb_len_ptr(r);
    const t = mpb_tab(r);
    t[0] = @truncate(m);
    t[1] = @truncate(m >> 32);
    lp.* = if (t[1] == 0) 1 else 2;
}

export fn mpb_get_u64(r: *anyopaque) callconv(.c) u64 {
    const lp = mpb_len_ptr(r);
    const t = mpb_tab(r);
    if (lp.* == 1) return t[0];
    return t[0] | (@as(u64, t[1]) << 32);
}

export fn mpb_floor_log2(a: *anyopaque) callconv(.c) c_int {
    const lp = mpb_len_ptr(a);
    const t = mpb_tab(a);
    const v = t[@intCast(lp.* - 1)];
    if (v == 0) return -1;
    return lp.* * 32 - 1 - @as(c_int, clz32(v));
}

export fn mpb_get_bit(r: *const anyopaque, pos: c_int) callconv(.c) c_int {
    const l: u32 = @intCast(@as(u32, @bitCast(pos)) / 32);
    const k: u5 = @intCast(@as(u32, @bitCast(pos)) & 31);
    const lp = mpb_len_val(r);
    const t = mpb_tab_const(r);
    if (l >= lp) return 0;
    return @intCast((t[l] >> k) & 1);
}

export fn mpb_shr_round(r: *anyopaque, shift: c_int, rnd_mode: c_int) callconv(.c) void {
    const lp = mpb_len_ptr(r);
    const t = mpb_tab(r);

    if (shift == 0) return;

    if (shift < 0) {
        // left shift
        var sh = -shift;
        const l: c_int = @divTrunc(sh, 32);
        sh = sh & 31;
        if (sh != 0) {
            const shu: u5 = @intCast(sh);
            t[@intCast(lp.*)] = mp_shl(t, t, lp.*, shu, 0);
            lp.* += 1;
            mpb_renorm(r);
        }
        if (l > 0) {
            var i: c_int = lp.* - 1;
            while (i >= 0) : (i -= 1) {
                t[@intCast(i + l)] = t[@intCast(i)];
            }
            var j: c_int = 0;
            while (j < l) : (j += 1) {
                t[@intCast(j)] = 0;
            }
            lp.* += l;
        }
        return;
    }

    // right shift with rounding
    var add_one: c_int = 0;
    switch (rnd_mode) {
        JS_RNDZ => add_one = 0,
        JS_RNDNA => {
            const bit1 = mpb_get_bit(r, shift - 1);
            if (bit1 != 0) add_one = 1 else add_one = 0;
        },
        JS_RNDN => {
            const bit1 = mpb_get_bit(r, shift - 1);
            if (bit1 != 0) {
                var bit2: c_int = 0;
                if (shift >= 2) {
                    const k: c_int = shift - 1;
                    const ll: u32 = @intCast(@as(u32, @bitCast(k)) / 32);
                    const kk: u5 = @intCast(@as(u32, @bitCast(k)) & 31);
                    var i: u32 = 0;
                    while (i < @min(ll, @as(u32, @intCast(lp.*)))) : (i += 1) {
                        if (t[i] != 0) bit2 = 1;
                    }
                    if (ll < lp.*) {
                        if (t[ll] & ((@as(limb_t, 1) << kk) - 1) != 0) {
                            bit2 = 1;
                        }
                    }
                }
                if (bit2 != 0) {
                    add_one = 1;
                } else {
                    add_one = mpb_get_bit(r, shift);
                }
            } else {
                add_one = 0;
            }
        },
        else => add_one = 0,
    }

    var sh = shift;
    const l: u32 = @intCast(@as(u32, @bitCast(sh)) / 32);
    sh = @as(c_int, @bitCast(sh)) & 31;

    if (l >= lp.*) {
        lp.* = 1;
        t[0] = @intCast(add_one);
    } else {
        if (l > 0) {
            lp.* -= @intCast(l);
            var i: u32 = 0;
            while (i < @as(u32, @intCast(lp.*))) : (i += 1) {
                t[i] = t[i + l];
            }
        }
        if (sh != 0) {
            const shu: u5 = @intCast(sh);
            _ = mp_shr(t, t, lp.*, shu, 0);
            mpb_renorm(r);
        }
        if (add_one != 0) {
            const a = mp_add_ui(t, 1, @intCast(lp.*));
            if (a != 0) {
                t[@intCast(lp.*)] = a;
                lp.* += 1;
            }
        }
    }
}

export fn mpb_cmp(a: *const anyopaque, b: *const anyopaque) callconv(.c) c_int {
    const la = mpb_len_val(a);
    const lb = mpb_len_val(b);
    const ta = mpb_tab_const(a);
    const tb = mpb_tab_const(b);
    if (la < lb) return -1;
    if (la > lb) return 1;
    var i: c_int = la - 1;
    while (i >= 0) : (i -= 1) {
        const ui: u32 = @intCast(i);
        if (ta[ui] != tb[ui]) {
            return if (ta[ui] < tb[ui]) -1 else 1;
        }
    }
    return 0;
}

export fn mpb_mul1_base(r: *anyopaque, radix_base: limb_t, b: limb_t) callconv(.c) void {
    const lp = mpb_len_ptr(r);
    const t = mpb_tab(r);
    if (t[0] == 0 and lp.* == 1) {
        t[0] = b;
    } else {
        if (radix_base == 0) {
            // shift left by one limb
            var i: c_int = lp.*;
            while (i >= 0) : (i -= 1) {
                t[@intCast(i + 1)] = t[@intCast(i)];
            }
            t[0] = b;
        } else {
            t[@intCast(lp.*)] = mp_mul1(t, t, @intCast(lp.*), radix_base, b);
        }
        lp.* += 1;
        mpb_renorm(r);
    }
}

export fn mpb_dump(str: [*]const u8, a: *const anyopaque) callconv(.c) void {
    _ = str;
    _ = a;
    // Debug dump - no-op in release
}

// ---- Tables ----

const pow5_table = [17]u32{
    0x00000005, 0x00000019, 0x0000007d, 0x00000271,
    0x00000c35, 0x00003d09, 0x0001312d, 0x0005f5e1,
    0x001dcd65, 0x009502f9, 0x02e90edd, 0x0e8d4a51,
    0x48c27395, 0x6bcc41e9, 0x1afd498d, 0x86f26fc1,
    0xa2bc2ec5,
};

const pow5h_table = [4]u8{ 0x01, 0x07, 0x23, 0xb1 };
const pow5_inv_table = [13]u32{
    0x99999999, 0x47ae147a, 0x0624dd2f, 0xa36e2eb1,
    0x4f8b588e, 0x0c6f7a0b, 0xad7f29ab, 0x5798ee23,
    0x12e0be82, 0xb7cdfd9d, 0x5fd7fe17, 0x19799812,
    0xc25c2684,
};

const digits_per_limb_table = [35]u8{
    32, 20, 16, 13, 12, 11, 10, 10, 9, 9, 8, 8, 8, 8, 8, 7, 7, 7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
};

const radix_base_table = [35]u32{
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

const dtoa_max_digits_table = [35]u8{
    54, 35, 28, 24, 22, 20, 19, 18, 17, 17, 16, 16, 15, 15, 15, 14, 14, 14, 14, 14, 13, 13, 13, 13, 13, 13, 13, 12, 12, 12, 12, 12, 12, 12, 12,
};

const atod_max_digits_table = [35]u8{
    64, 80, 32, 55, 49, 45, 21, 40, 38, 37, 35, 34, 33, 32, 16, 31, 30, 30, 29, 29, 28, 28, 27, 27, 27, 26, 26, 26, 26, 25, 12, 25, 25, 24, 24,
};

const max_exponent_table = [35]i16{
    1024, 647, 512, 442, 397, 365, 342, 324,
    309,  297, 286, 277, 269, 263, 256, 251,
    246,  242, 237, 234, 230, 227, 224, 221,
    218,  216, 214, 211, 209, 207, 205, 203,
    202,  200, 199,
};

const min_exponent_table = [35]i16{
    -1075, -679, -538, -463, -416, -383, -359, -340,
    -324, -311, -300, -291, -283, -276, -269, -263,
    -258, -254, -249, -245, -242, -238, -235, -232,
    -229, -227, -224, -222, -220, -217, -215, -214,
    -212, -210, -208,
};

const mul_log2_radix_table = [35]u32{
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

// ---- mul_log2_radix ----

export fn mul_log2_radix(a: c_int, radix: c_int) callconv(.c) c_int {
    if (radix & (radix - 1) == 0) {
        const radix_bits: c_int = 31 - @as(c_int, clz32(@intCast(radix)));
        var aa = a;
        if (aa < 0) aa -= radix_bits - 1;
        return @divTrunc(aa, radix_bits);
    } else {
        const mult: u32 = mul_log2_radix_table[@intCast(radix - 2)];
        return @intCast((@as(i64, a) * @as(i64, @intCast(mult))) >> 24);
    }
}

// ---- pow_ui, pow_ui_inv ----

export fn pow_ui(radix: c_int, n: c_int) callconv(.c) u64 {
    if (n == 0) return 1;
    if (n == 1) return @intCast(radix);
    if ((radix == 5 or radix == 10) and n <= 17) {
        var r: u64 = pow5_table[@intCast(n - 1)];
        if (n >= 14) r |= @as(u64, pow5h_table[@intCast(n - 14)]) << 32;
        if (radix == 10) r <<= @intCast(n);
        return r;
    }
    var r: u64 = @intCast(radix);
    const n_bits: u6 = 32 - clz32(@intCast(n));
    var i: u6 = n_bits - 2;
    while (true) : (i -= 1) {
        r *%= r;
        if ((@as(u32, @bitCast(n)) >> @intCast(i)) & 1 != 0)
            r *= @intCast(radix);
        if (i == 0) break;
    }
    return r;
}

// Internal helper: returns {normalized_divisor, inv, shift}
fn pow_ui_inv_internal(radix1: c_int, n: c_int) struct { r: u32, r_inv: u32, shift: c_int } {
    if (radix1 == 5 and n >= 1 and n <= 13) {
        var r = pow5_table[@intCast(n - 1)];
        const shift: c_int = @intCast(clz32(r));
        r <<= @intCast(shift);
        return .{ .r = r, .r_inv = pow5_inv_table[@intCast(n - 1)], .shift = shift };
    }
    var r: u32 = @truncate(pow_ui(radix1, n));
    const shift: c_int = @intCast(clz32(r));
    r <<= @intCast(shift);
    return .{ .r = r, .r_inv = udiv1norm_init(r), .shift = shift };
}

export fn pow_ui_inv(pr_inv: *u32, pshift: *c_int, radix: c_int, n: c_int) callconv(.c) void {
    const res = pow_ui_inv_internal(radix, n);
    pr_inv.* = res.r_inv;
    pshift.* = res.shift;
}

// ---- Integer-to-string ----

fn u32toa_len(buf: [*]u8, n: u32, len: usize) void {
    var nn = n;
    var i: isize = @as(isize, @intCast(len)) - 1;
    while (i >= 0) : (i -= 1) {
        buf[@intCast(i)] = @intCast(nn % 10 + '0');
        nn /= 10;
    }
}

fn u64toa_bin_len(buf: [*]u8, n: u64, radix_bits: u5, len: c_int) void {
    var nn = n;
    const mask: u64 = (@as(u64, 1) << radix_bits) - 1;
    var i: isize = @as(isize, @intCast(len)) - 1;
    while (i >= 0) : (i -= 1) {
        var digit: u64 = nn & mask;
        nn >>= radix_bits;
        digit = if (digit < 10) digit + '0' else digit + 'a' - 10;
        buf[@intCast(i)] = @intCast(digit);
    }
}

export fn limb_to_a(buf: [*]u8, a: limb_t, radix: c_int, len: c_int) callconv(.c) void {
    if (radix == 10) {
        u32toa_len(buf, a, @intCast(len));
    } else {
        var nn: limb_t = a;
        const r: u32 = @intCast(radix);
        var i: isize = @as(isize, @intCast(len)) - 1;
        while (i >= 0) : (i -= 1) {
            var digit: limb_t = nn % r;
            nn /= r;
            digit = if (digit < 10) digit + '0' else digit + 'a' - 10;
            buf[@intCast(i)] = @intCast(digit);
        }
    }
}

pub export fn u32toa(buf: [*]u8, n: u32) callconv(.c) usize {
    var buf1: [10]u8 = undefined;
    var nn = n;
    var q: usize = 10;
    while (true) {
        q -= 1;
        buf1[q] = @intCast(nn % 10 + '0');
        nn /= 10;
        if (nn == 0) break;
    }
    const len: usize = 10 - q;
    const src = buf1[q..10][0..len];
    @memcpy(buf, src);
    return len;
}

pub export fn i32toa(buf: [*]u8, n: i32) callconv(.c) usize {
    if (n >= 0) return u32toa(buf, @intCast(n));
    buf[0] = '-';
    return u32toa(buf + 1, @intCast(-@as(i64, n))) + 1;
}

pub export fn u64toa(buf: [*]u8, n: u64) callconv(.c) usize {
    if (n < 0x100000000) return u32toa(buf, @truncate(n));
    var nn = n;
    const frac = nn % 1000000000;
    nn /= 1000000000;
    var q = buf;
    if (nn >= 0x100000000) {
        var n2: u32 = @intCast(nn / 1000000000);
        const n1: u32 = @intCast(nn % 1000000000);
        if (n2 >= 10) {
            q[0] = @intCast(n2 / 10 + '0');
            q += 1;
            n2 %= 10;
        }
        q[0] = @intCast(n2 + '0');
        q += 1;
        u32toa_len(q, n1, 9);
        q += 9;
    } else {
        const l = u32toa(q, @intCast(nn));
        q += l;
    }
    u32toa_len(q, @intCast(frac), 9);
    q += 9;
    return @intFromPtr(q) - @intFromPtr(buf);
}

pub export fn i64toa(buf: [*]u8, n: i64) callconv(.c) usize {
    if (n >= 0) return u64toa(buf, @intCast(n));
    buf[0] = '-';
    return u64toa(buf + 1, @intCast(-@as(i65, n))) + 1;
}

pub export fn u64toa_radix(buf: [*]u8, n: u64, radix: c_uint) callconv(.c) usize {
    if (radix == 10) return u64toa(buf, n);
    if (radix & (radix - 1) == 0) {
        const rb: u5 = @intCast(31 - clz32(@intCast(radix)));
        const l: c_int = if (n == 0) 1 else @intCast((64 - clz64(n) + rb - 1) / rb);
        u64toa_bin_len(buf, n, rb, l);
        return @intCast(l);
    }
    var buf1: [64]u8 = undefined;
    var nn = n;
    const r: u64 = radix;
    var q: usize = 63;
    while (true) {
        var digit: u64 = nn % r;
        nn /= r;
        digit = if (digit < 10) digit + '0' else digit + 'a' - 10;
        buf1[q] = @intCast(digit);
        q -= 1;
        if (nn == 0) break;
    }
    const start = q + 1;
    const len: usize = 64 - start;
    const src = buf1[start..64][0..len];
    @memcpy(buf, src);
    return len;
}

pub export fn i64toa_radix(buf: [*]u8, n: i64, radix: c_uint) callconv(.c) usize {
    if (n >= 0) return u64toa_radix(buf, @intCast(n), radix);
    buf[0] = '-';
    return u64toa_radix(buf + 1, @intCast(-@as(i64, n)), radix) + 1;
}

// ---- output_digits ----

export fn output_digits(buf: [*]u8, a: *const anyopaque, radix: c_int, n_digits1: c_int, dot_pos: c_int) callconv(.c) c_int {
    const a_ptr: *anyopaque = @constCast(a);
    const lp = mpb_len_ptr(a_ptr);
    const t = mpb_tab(a_ptr);
    var n_digits = n_digits1;

    const radix_bits: c_int = if (radix & (radix - 1) == 0) (31 - @as(c_int, clz32(@intCast(radix)))) else 0;
    const dpl: c_int = digits_per_limb_table[@intCast(radix - 2)];

    if (radix_bits != 0) {
        const rb: u5 = @intCast(radix_bits);
        while (true) {
            const n = min_int(n_digits, dpl);
            n_digits -= n;
            u64toa_bin_len(buf + @as(usize, @intCast(n_digits)), t[0], rb, n);
            if (n_digits == 0) break;
            mpb_shr_round(a_ptr, dpl * radix_bits, JS_RNDZ);
        }
    } else {
        const rb = radix_base_table[@intCast(radix - 2)];
        while (n_digits != 0) {
            const n = min_int(n_digits, dpl);
            n_digits -= n;
            const r = mp_div1(t, t, @intCast(lp.*), rb, 0);
            mpb_renorm(a_ptr);
            limb_to_a(buf + @as(usize, @intCast(n_digits)), r, radix, n);
        }
    }

    var len: c_int = n_digits1;
    if (dot_pos != n_digits1) {
        const dp: usize = @intCast(dot_pos);
        const nd1: usize = @intCast(n_digits1);
        std.mem.copyForwards(u8, buf[dp + 1 .. nd1 + 1], buf[dp..nd1]);
        buf[dp] = '.';
        len += 1;
    }
    return len;
}

// ---- mul_pow ----

fn mul_pow(a_ptr: *anyopaque, radix1: c_int, radix_shift: c_int, f_arg: c_int, is_int: bool, e: c_int) c_int {
    const lp = mpb_len_ptr(a_ptr);
    const t = mpb_tab(a_ptr);
    var f = f_arg;
    var e_offset: c_int = -f * radix_shift;

    if (radix1 == 1) return e_offset;

    const d: c_int = digits_per_limb_table[@intCast(radix1 - 2)];

    if (f >= 0) {
        var b: limb_t = 0;
        var n0: c_int = 0;
        while (f != 0) {
            const n = min_int(f, d);
            if (n != n0) {
                b = @truncate(pow_ui(radix1, n));
                n0 = n;
            }
            const h = mp_mul1(t, t, @intCast(lp.*), b, 0);
            if (h != 0) {
                t[@intCast(lp.*)] = h;
                lp.* += 1;
            }
            f -= n;
        }
    } else {
        f = -f;
        const l: c_int = @divTrunc(f + d - 1, d);
        e_offset += l * 32;
        const extra_bits: c_int = if (!is_int)
            max_int(e - mpb_floor_log2(a_ptr), 0)
        else
            max_int(2 + e - e_offset, 0);
        e_offset += extra_bits;
        mpb_shr_round(a_ptr, -(l * 32 + extra_bits), JS_RNDZ);

        var rem: limb_t = 0;
        var n0: c_int = 0;
        var cur_inv: u32 = 0;
        var cur_shift: u5 = 0;
        var cur_b: u32 = 0;
        while (f != 0) {
            const n = min_int(f, d);
            if (n != n0) {
                const res = pow_ui_inv_internal(radix1, n);
                cur_b = res.r;
                cur_inv = res.r_inv;
                cur_shift = @intCast(res.shift);
                n0 = n;
            }
            const r = mp_div1norm_impl(t, t, @intCast(lp.*), cur_b, 0, cur_inv, cur_shift);
            if (r != 0) rem = 1;
            mpb_renorm(a_ptr);
            f -= n;
        }
        if (rem != 0) t[0] |= 1;
    }
    return e_offset;
}

// ---- mul_pow_round ----

fn mul_pow_round(tmp1: *anyopaque, m: u64, e: c_int, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) void {
    mpb_set_u64(tmp1, m);
    const e_offset = mul_pow(tmp1, radix1, radix_shift, f, true, e);
    mpb_shr_round(tmp1, -e + e_offset, rnd_mode);
}

// ---- round_to_d ----

export fn round_to_d(pe: *c_int, a: *anyopaque, e_offset: c_int, rnd_mode: c_int) callconv(.c) u64 {
    const lp = mpb_len_ptr(a);
    const t = mpb_tab(a);

    if (t[0] == 0 and lp.* == 1) {
        pe.* = 0;
        return 0;
    }
    var e: c_int = mpb_floor_log2(a) + 1 - e_offset;
    const prec1: c_int = 53;
    const e_min: c_int = -1021;
    const prec: c_int = if (e < e_min) prec1 - (e_min - e) else prec1;
    mpb_shr_round(a, e + e_offset - prec, rnd_mode);
    var m: u64 = mpb_get_u64(a);
    m <<= @intCast(53 - prec);
    if (m >= @as(u64, 1) << 53) {
        m >>= 1;
        e += 1;
    }
    pe.* = e;
    return m;
}

// ---- mul_pow_round_to_d ----

export fn mul_pow_round_to_d(pe: *c_int, a: *anyopaque, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) callconv(.c) u64 {
    const e_offset = mul_pow(a, radix1, radix_shift, f, false, 55);
    return round_to_d(pe, a, e_offset, rnd_mode);
}

// ---- js_dtoa_max_len ----

pub export fn js_dtoa_max_len(d: f64, radix: c_int, n_digits: c_int, flags: c_int) callconv(.c) c_int {
    const fmt = flags & JS_DTOA_FORMAT_MASK;
    var n: c_int = undefined;
    const a = float64_to_u64(d);
    var e: c_int = @intCast((a >> 52) & 0x7ff);

    if (fmt != JS_DTOA_FORMAT_FRAC) {
        if (fmt == JS_DTOA_FORMAT_FREE) {
            n = dtoa_max_digits_table[@intCast(radix - 2)];
        } else {
            n = n_digits;
        }
        if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_DISABLED) {
            if (e == 0x7ff) {
                n = 0;
            } else {
                e -= 1023;
                n += 10 + @as(c_int, @intCast(@abs(mul_log2_radix(e - 1, radix))));
            }
        } else {
            n += 1 + 1 + 6;
        }
    } else {
        if (e == 0x7ff) {
            n = 0;
        } else {
            e -= 1023;
            if (e < 0) {
                n = 1;
            } else {
                n = 2 + mul_log2_radix(e - 1, radix);
            }
            n += 1 + 1 + 1 + n_digits;
        }
    }
    return @max(n, 9);
}

// ---- js_dtoa ----

pub export fn js_dtoa(buf: [*]u8, d: f64, radix: c_int, n_digits: c_int, flags: c_int, tmp_mem: *JSDTOATempMem) callconv(.c) c_int {
    var mptr: [*]u64 = @ptrCast(tmp_mem);
    const a_full = float64_to_u64(d);
    const sgn: c_int = @intCast(a_full >> 63);
    var e: c_int = @intCast((a_full >> 52) & 0x7ff);
    var m: u64 = a_full & ((@as(u64, 1) << 52) - 1);
    var q = buf;
    const fmt = flags & JS_DTOA_FORMAT_MASK;

    const tmp1 = dtoa_malloc(&mptr, 4 + 4 * DBIGNUM_LEN_MAX);
    const mant_max_alloc = dtoa_malloc(&mptr, 4 + 4 * MANT_LEN_MAX);

    const radix_shift: c_int = @intCast(ctz32_val(@intCast(radix)));
    const radix1: c_int = radix >> @intCast(radix_shift);

    if (e == 0x7ff) {
        if (m == 0) {
            if (sgn != 0) {
                q[0] = '-';
                q += 1;
            }
            const inf_str = "Infinity";
            @memcpy(q[0..8], inf_str[0..8]);
            q += 8;
        } else {
            const nan_str = "NaN";
            @memcpy(q[0..3], nan_str[0..3]);
            q += 3;
        }
        q[0] = 0;
        return @intCast(@intFromPtr(q) - @intFromPtr(buf));
    } else if (e == 0) {
        if (m == 0) {
            mpb_set_u64(tmp1, 0);
            const E: c_int = 1;
            const P: c_int = if (fmt == JS_DTOA_FORMAT_FREE) 1 else if (fmt == JS_DTOA_FORMAT_FRAC) n_digits + 1 else n_digits;
            if (sgn != 0 and (flags & JS_DTOA_MINUS_ZERO) != 0) {
                q[0] = '-';
                q += 1;
            }
            q += @intCast(dtoa_output(q, tmp1, radix, radix1, radix_shift, P, E, fmt, n_digits, flags));
            q[0] = 0;
            return @intCast(@intFromPtr(q) - @intFromPtr(buf));
        }
        const l: u7 = clz64(m) - 11;
        e -= @as(c_int, @intCast(l)) - 1;
        m <<= @intCast(l);
    } else {
        m |= @as(u64, 1) << 52;
    }

    if (sgn != 0) {
        q[0] = '-';
        q += 1;
    }
    e -= 1022;

    // fast path for small integers
    if (fmt == JS_DTOA_FORMAT_FREE and
        e >= 1 and e <= 53 and
        m & ((@as(u64, 1) << @intCast(53 - e)) - 1) == 0 and
        (flags & JS_DTOA_EXP_MASK) != JS_DTOA_EXP_ENABLED)
    {
        m >>= @intCast(53 - e);
        q += u64toa_radix(q, m, @intCast(radix));
        q[0] = 0;
        return @intCast(@intFromPtr(q) - @intFromPtr(buf));
    }

    var E: c_int = 1 + mul_log2_radix(e - 1, radix);
    var P: c_int = undefined;

    if (fmt == JS_DTOA_FORMAT_FREE) {
        const P_max: c_int = dtoa_max_digits_table[@intCast(radix - 2)];
        const E0: c_int = E;
        var E_found: c_int = 0;
        var P_found: c_int = 0;
        var mant_found: u64 = 0;

        P = P_max;
        // First pass: guaranteed to work at P_max
        {
            const mant_max1 = pow_ui(radix, P);
            E = E0;
            while (true) {
                mul_pow_round(tmp1, m, e - 53, radix1, radix_shift, P - E, JS_RNDN);
                const mant = mpb_get_u64(tmp1);
                if (mant < mant_max1) break;
                E += 1;
            }
            var mant = mpb_get_u64(tmp1);
            while (mant % @as(u64, @intCast(radix)) == 0) {
                mant /= @as(u64, @intCast(radix));
                P -= 1;
            }
            P_found = P;
            E_found = E;
            mant_found = mant;
        }
        // Try smaller precision
        while (P_found > 1) {
            P = P_found - 1;
            const mant_max1 = pow_ui(radix, P);
            E = E0;
            while (true) {
                mul_pow_round(tmp1, m, e - 53, radix1, radix_shift, P - E, JS_RNDN);
                const mant = mpb_get_u64(tmp1);
                if (mant < mant_max1) break;
                E += 1;
            }
            // Remove trailing zeros
            var mant = mpb_get_u64(tmp1);
            while (mant % @as(u64, @intCast(radix)) == 0) {
                mant /= @as(u64, @intCast(radix));
                P -= 1;
            }
            // Convert back to check round-trip
            mpb_set_u64(tmp1, mant);
            var e1: c_int = undefined;
            const m1 = mul_pow_round_to_d(&e1, tmp1, radix1, radix_shift, E - P, JS_RNDN);
            if (m1 == m and e1 == e) {
                P_found = P;
                E_found = E;
                mant_found = mant;
            } else {
                break;
            }
        }
        P = P_found;
        E = E_found;
        mpb_set_u64(tmp1, mant_found);
    } else if (fmt == JS_DTOA_FORMAT_FRAC) {
        mul_pow_round(tmp1, m, e - 53, radix1, radix_shift, n_digits, JS_RNDNA);
        const len_out = output_digits(q, tmp1, radix, max_int(E + 1, 1) + n_digits, max_int(E + 1, 1));
        if (q[0] == '0' and len_out >= 2 and q[1] != '.') {
            const l2 = len_out - 1;
            std.mem.copyForwards(u8, q[0..@intCast(l2)], q[1..@intCast(len_out)]);
            q += @intCast(l2);
        } else {
            q += @intCast(len_out);
        }
        q[0] = 0;
        return @intCast(@intFromPtr(q) - @intFromPtr(buf));
    } else {
        // fixed format
        P = n_digits;
        mpb_set_u64(mant_max_alloc, 1);
        const pow_shift = mul_pow(mant_max_alloc, radix1, radix_shift, P, false, 0);
        mpb_shr_round(mant_max_alloc, pow_shift, JS_RNDZ);
        while (true) {
            mul_pow_round(tmp1, m, e - 53, radix1, radix_shift, P - E, JS_RNDNA);
            if (mpb_cmp(tmp1, mant_max_alloc) < 0) break;
            E += 1;
        }
    }

    // Output
    q += @intCast(dtoa_output(q, tmp1, radix, radix1, radix_shift, P, E, fmt, n_digits, flags));
    q[0] = 0;
    return @intCast(@intFromPtr(q) - @intFromPtr(buf));
}

// Shared output formatting for js_dtoa
fn dtoa_output(q_arg: [*]u8, tmp1: *anyopaque, radix: c_int, radix1: c_int, radix_shift: c_int, P: c_int, E_in: c_int, fmt: c_int, n_digits: c_int, flags: c_int) c_int {
    var q = q_arg;
    var E = E_in;
    const E_max: c_int = if (fmt == JS_DTOA_FORMAT_FIXED) n_digits else dtoa_max_digits_table[@intCast(radix - 2)] + 4;

    if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_ENABLED or
        ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_AUTO and (E <= -6 or E > E_max)))
    {
        q += @intCast(output_digits(q, tmp1, radix, P, 1));
        E -= 1;
        if (radix == 10) {
            q[0] = 'e';
        } else if (radix1 == 1 and radix_shift <= 4) {
            E *= radix_shift;
            q[0] = 'p';
        } else {
            q[0] = '@';
        }
        q += 1;
        if (E < 0) {
            q[0] = '-';
            E = -E;
        } else {
            q[0] = '+';
        }
        q += 1;
        q += u32toa(q, @intCast(E));
    } else if (E <= 0) {
        q[0] = '0';
        q[1] = '.';
        q += 2;
        var i: c_int = 0;
        while (i < -E) : (i += 1) {
            q[0] = '0';
            q += 1;
        }
        q += @intCast(output_digits(q, tmp1, radix, P, P));
    } else {
        q += @intCast(output_digits(q, tmp1, radix, P, min_int(P, E)));
        var i: c_int = 0;
        while (i < E - P) : (i += 1) {
            q[0] = '0';
            q += 1;
        }
    }
    return @intCast(@intFromPtr(q) - @intFromPtr(q_arg));
}

// ---- js_atod ----

fn to_digit(c: u8) u32 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'A' and c <= 'Z') return c - 'A' + 10;
    if (c >= 'a' and c <= 'z') return c - 'a' + 10;
    return 36;
}

fn strstart(str: [*]const u8, val: [*:0]const u8, ptr: ?*[*]const u8) bool {
    var p: usize = 0;
    var q: usize = 0;
    while (val[q] != 0) {
        if (str[p] != val[q]) return false;
        p += 1;
        q += 1;
    }
    if (ptr) |pp| pp.* = str + p;
    return true;
}

pub export fn js_atod(str_arg: [*]const u8, pnext_raw: *[*c]const u8, radix: c_int, flags: c_int, tmp_mem: *JSATODTempMem) callconv(.c) f64 {
    // pnext_raw is a pointer to a nullable pointer; at end, we write the position back
    var mptr: [*]u64 = @ptrCast(tmp_mem);
    const tmp0 = dtoa_malloc(&mptr, 4 + 4 * DBIGNUM_LEN_MAX);

    const sep: u8 = if (flags & JS_ATOD_ACCEPT_UNDERSCORES != 0) '_' else 255;
    var p: [*]const u8 = str_arg;
    var p_start: [*]const u8 = undefined;

    var is_neg: bool = false;
    if (p[0] == '+') {
        p += 1;
        p_start = p;
    } else if (p[0] == '-') {
        is_neg = true;
        p += 1;
        p_start = p;
    } else {
        p_start = p;
    }

    var my_radix: c_int = radix;

    if (p[0] == '0') {
        if ((p[1] == 'x' or p[1] == 'X') and (my_radix == 0 or my_radix == 16)) {
            p += 2;
            my_radix = 16;
        } else if ((p[1] == 'o' or p[1] == 'O') and my_radix == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
            p += 2;
            my_radix = 8;
        } else if ((p[1] == 'b' or p[1] == 'B') and my_radix == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
            p += 2;
            my_radix = 2;
        } else if (p[1] >= '0' and p[1] <= '9' and my_radix == 0 and (flags & JS_ATOD_ACCEPT_LEGACY_OCTAL) != 0) {
            var i: usize = 1;
            while (p[i] >= '0' and p[i] <= '7') : (i += 1) {}
            if (p[i] == '8' or p[i] == '9') {
                // not octal
            } else {
                p += 1;
                my_radix = 8;
            }
        } else {
            // no prefix
        }
        if (my_radix == 8 or my_radix == 16 or my_radix == 2) {
            if (to_digit(p[0]) >= my_radix) {
                pnext_raw.* = p;
                return std.math.nan(f64);
            }
        }
    } else {
        if (flags & JS_ATOD_INT_ONLY == 0) {
            var endp: [*]const u8 = undefined;
            if (strstart(p, "Infinity", &endp)) {
                p = endp;
                const a: u64 = if (is_neg) (@as(u64, 0x7ff) << 52) | (@as(u64, 1) << 63) else @as(u64, 0x7ff) << 52;
                pnext_raw.* = p;
                return u64_to_float64(a);
            }
        }
    }

    if (my_radix == 0) my_radix = 10;

    const dpl: c_int = digits_per_limb_table[@intCast(my_radix - 2)];
    const max_digits: c_int = atod_max_digits_table[@intCast(my_radix - 2)];
    const radix_base = radix_base_table[@intCast(my_radix - 2)];
    const radix_shift_i: c_int = @intCast(ctz32_val(@intCast(my_radix)));
    const radix1: c_int = my_radix >> @intCast(radix_shift_i);
    const radix_bits: c_int = if (radix1 == 1) radix_shift_i else 0;

    mpb_set_u64(tmp0, 0);
    var cur_limb: limb_t = 0;
    var expn_offset: c_int = 0;
    var digit_count: c_int = 0;
    var limb_digit_count: c_int = 0;
    var extra_digits: limb_t = 0;
    var pos: c_int = 0;
    var dot_pos: c_int = -1;

    // skip leading zeros
    while (true) {
        if (p[0] == '.' and (@intFromPtr(p) > @intFromPtr(p_start) or to_digit(p[1]) < my_radix) and flags & JS_ATOD_INT_ONLY == 0) {
            if (p[0] == sep) {
                pnext_raw.* = p;
                return std.math.nan(f64);
            }
            if (dot_pos >= 0) break;
            dot_pos = pos;
            p += 1;
        }
        if (p[0] == sep and @intFromPtr(p) > @intFromPtr(p_start) and p[1] == '0') p += 1;
        if (p[0] != '0') break;
        p += 1;
        pos += 1;
    }

    const sig_pos = pos;
    const t0 = mpb_tab(tmp0);

    while (true) {
        if (p[0] == '.' and (@intFromPtr(p) > @intFromPtr(p_start) or to_digit(p[1]) < my_radix) and flags & JS_ATOD_INT_ONLY == 0) {
            if (p[0] == sep) break;
            if (dot_pos >= 0) break;
            dot_pos = pos;
            p += 1;
        }
        if (p[0] == sep and @intFromPtr(p) > @intFromPtr(p_start) and to_digit(p[1]) < my_radix) p += 1;
        const c: u32 = to_digit(p[0]);
        if (c >= my_radix) break;
        p += 1;
        pos += 1;
        if (digit_count < max_digits) {
            cur_limb = cur_limb * @as(u32, @intCast(my_radix)) + c;
            limb_digit_count += 1;
            if (limb_digit_count == dpl) {
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
        const pw = @as(u32, @truncate(pow_ui(my_radix, limb_digit_count)));
        mpb_mul1_base(tmp0, pw, cur_limb);
    }

    const is_zero = digit_count == 0;
    if (!is_zero) {
        if (dot_pos < 0) dot_pos = pos;
        expn_offset = sig_pos + digit_count - dot_pos;
    }

    if (radix_bits != 0 and extra_digits != 0) {
        t0[0] |= 1;
    }

    // parse exponent
    var expn: c_int = 0;
    var expn_overflow: bool = false;
    var is_bin_exp: bool = false;

    if (flags & JS_ATOD_INT_ONLY == 0 and
        @intFromPtr(p) > @intFromPtr(p_start) and
        ((my_radix == 10 and (p[0] == 'e' or p[0] == 'E')) or
         (my_radix != 10 and (p[0] == '@' or (radix_bits >= 1 and radix_bits <= 4 and (p[0] == 'p' or p[0] == 'P'))))))
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
        var cc: u32 = to_digit(p[0]);
        if (cc >= 10) {
            pnext_raw.* = p;
            return std.math.nan(f64);
        }
        expn = @intCast(cc);
        p += 1;
        while (true) {
            if (p[0] == sep and to_digit(p[1]) < 10) p += 1;
            cc = to_digit(p[0]);
            if (cc >= 10) break;
            if (!expn_overflow) {
                if (expn > (std.math.maxInt(i32) - 2 - 9) / 10) {
                    expn_overflow = true;
                } else {
                    expn = expn * 10 + @as(c_int, @intCast(cc));
                }
            }
            p += 1;
        }
        if (exp_is_neg) expn = -expn;
        if (!is_zero and expn_overflow) {
            const a_ret: u64 = if (exp_is_neg) 0 else @as(u64, 0x7ff) << 52;
            var res: u64 = a_ret;
            if (is_neg) res |= @as(u64, 1) << 63;
            pnext_raw.* = p;
            return u64_to_float64(res);
        }
    }

    if (p == p_start) {
        pnext_raw.* = p;
        return std.math.nan(f64);
    }

    var a: u64 = 0;
    if (is_zero) {
        a = 0;
    } else {
        var pe: c_int = undefined;
        if (radix_bits != 0) {
            var my_expn = expn;
            if (!is_bin_exp) my_expn *= radix_bits;
            my_expn -= expn_offset * radix_bits;
            const expn1 = my_expn + digit_count * radix_bits;
            if (expn1 >= 1024 + radix_bits) {
                a = @as(u64, 0x7ff) << 52;
            } else if (expn1 <= -1075) {
                a = 0;
            } else {
                const mm = round_to_d(&pe, tmp0, -my_expn, JS_RNDN);
                // Need to reconstruct float from (mm, pe)
                a = finish_float(mm, pe);
            }
        } else {
            expn -= expn_offset;
            const expn1 = expn + digit_count;
            if (expn1 >= max_exponent_table[@intCast(my_radix - 2)] + 1) {
                a = @as(u64, 0x7ff) << 52;
            } else if (expn1 <= min_exponent_table[@intCast(my_radix - 2)]) {
                a = 0;
            } else {
                const mm = mul_pow_round_to_d(&pe, tmp0, radix1, radix_shift_i, expn, JS_RNDN);
                a = finish_float(mm, pe);
            }
        }
        if (a == 0 and !is_zero) {
            // check for actual underflow (m was non-zero but result is zero)
        }
    }

    if (is_neg) a |= @as(u64, 1) << 63;
    pnext_raw.* = p;
    return u64_to_float64(a);
}

fn finish_float(m: u64, e: c_int) u64 {
    if (m == 0) return 0;
    if (e > 1024) return @as(u64, 0x7ff) << 52;
    if (e < -1073) return 0;
    if (e < -1021) return m >> @intCast(-e - 1021);
    return (@as(u64, @intCast(e + 1022)) << 52) | (m & ((@as(u64, 1) << 52) - 1));
}
