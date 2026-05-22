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

const LIMB_LOG2_BITS = 5;
const LIMB_BITS = 1 << LIMB_LOG2_BITS;
const limb_t = u32;
const slimb_t = i32;
const dlimb_t = u64;
const JS_RADIX_MAX = 36;
const DBIGNUM_LEN_MAX = 52;
const MANT_LEN_MAX = 18;
const JS_RNDN = 0;
const JS_RNDNA = 1;
const JS_RNDZ = 2;
const MUL_LOG2_RADIX_BASE_LOG2 = 24;
const INT32_MAX_VALUE: c_int = 2147483647;

const pow5_table = [_]u32{
    0x00000005, 0x00000019, 0x0000007d, 0x00000271,
    0x00000c35, 0x00003d09, 0x0001312d, 0x0005f5e1,
    0x001dcd65, 0x009502f9, 0x02e90edd, 0x0e8d4a51,
    0x48c27395, 0x6bcc41e9, 0x1afd498d, 0x86f26fc1,
    0xa2bc2ec5,
};

const pow5h_table = [_]u8{ 0x01, 0x07, 0x23, 0xb1 };

const pow5_inv_table = [_]u32{
    0x99999999, 0x47ae147a, 0x0624dd2f, 0xa36e2eb1,
    0x4f8b588e, 0x0c6f7a0b, 0x0ad7f29ab, 0x5798ee23,
    0x12e0be82, 0xb7cdfd9d, 0x5fd7fe17, 0x19799812,
    0xc25c2684,
};

const mul_log2_radix_table = [_]u32{
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

const digits_per_limb_table = [_]u8{
    32, 20, 16, 13, 12, 11, 10, 10, 9, 9, 8, 8, 8, 8, 8, 7, 7, 7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
};

const radix_base_table = [_]u32{
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

const dtoa_max_digits_table = [_]u8{
    54, 35, 28, 24, 22, 20, 19, 18, 17, 17, 16, 16, 15, 15, 15, 14, 14, 14, 14, 14, 13, 13, 13, 13, 13, 13, 13, 12, 12, 12, 12, 12, 12, 12, 12,
};

const atod_max_digits_table = [_]u8{
    64, 80, 32, 55, 49, 45, 21, 40, 38, 37, 35, 34, 33, 32, 16, 31, 30, 30, 29, 29, 28, 28, 27, 27, 27, 26, 26, 26, 26, 25, 12, 25, 25, 24, 24,
};

const max_exponent = [_]i16{
    1024, 647, 512, 442, 397, 365, 342, 324,
    309, 297, 286, 277, 269, 263, 256, 251,
    246, 242, 237, 234, 230, 227, 224, 221,
    218, 216, 214, 211, 209, 207, 205, 203,
    202, 200, 199,
};

const min_exponent = [_]i16{
    -1075, -679, -538, -463, -416, -383, -359, -340,
    -324, -311, -300, -291, -283, -276, -269, -263,
    -258, -254, -249, -245, -242, -238, -235, -232,
    -229, -227, -224, -222, -220, -217, -215, -214,
    -212, -210, -208,
};

fn minInt(a: c_int, b: c_int) c_int {
    return if (a < b) a else b;
}

fn maxInt(a: c_int, b: c_int) c_int {
    return if (a > b) a else b;
}

fn absInt(a: c_int) c_int {
    return if (a < 0) -a else a;
}

fn clz32(x: u32) c_int {
    return @intCast(@clz(x));
}

fn clz64(x: u64) c_int {
    return @intCast(@clz(x));
}

fn ctz32(x: u32) c_int {
    return @intCast(@ctz(x));
}

fn float64_as_uint64(d: f64) u64 {
    return @bitCast(d);
}

fn uint64_as_float64(a: u64) f64 {
    return @bitCast(a);
}

fn mpbLen(r: *anyopaque) *c_int {
    return @ptrCast(@alignCast(r));
}

fn mpbLenConst(r: *const anyopaque) *const c_int {
    return @ptrCast(@alignCast(r));
}

fn mpbTab(r: *anyopaque) [*]limb_t {
    return @ptrFromInt(@intFromPtr(r) + @sizeOf(c_int));
}

fn mpbTabConst(r: *const anyopaque) [*]const limb_t {
    return @ptrFromInt(@intFromPtr(r) + @sizeOf(c_int));
}

fn dtoaAlloc(mptr: *[*]u64, size: usize) *anyopaque {
    const ret: *anyopaque = @ptrCast(mptr.*);
    mptr.* += (size + 7) / 8;
    return ret;
}

pub export fn mp_add_ui(tab: [*]limb_t, b: limb_t, n: usize) callconv(.c) limb_t {
    var k = b;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        if (k == 0) break;
        const a = tab[i] +% k;
        k = if (a < k) 1 else 0;
        tab[i] = a;
    }
    return k;
}

fn mp_mul1(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, l0: limb_t) limb_t {
    var l = l0;
    var i: limb_t = 0;
    while (i < n) : (i += 1) {
        const t: dlimb_t = @as(dlimb_t, taba[i]) * @as(dlimb_t, b) + @as(dlimb_t, l);
        tabr[i] = @truncate(t);
        l = @truncate(t >> LIMB_BITS);
    }
    return l;
}

pub export fn udiv1norm_init(d: limb_t) callconv(.c) limb_t {
    const a1: limb_t = ~d;
    const a0: limb_t = 0xffffffff;
    return @truncate(((@as(dlimb_t, a1) << LIMB_BITS) | a0) / d);
}

fn udiv1norm(pr: *limb_t, a1: limb_t, a0: limb_t, d: limb_t, d_inv: limb_t) limb_t {
    const n1m: limb_t = if ((a0 & 0x80000000) != 0) 0xffffffff else 0;
    const n_adj: limb_t = a0 +% (n1m & d);
    var a: dlimb_t = @as(dlimb_t, d_inv) * @as(dlimb_t, a1 -% n1m) + @as(dlimb_t, n_adj);
    var q: limb_t = @as(limb_t, @truncate(a >> LIMB_BITS)) +% a1;
    a = (@as(dlimb_t, a1) << LIMB_BITS) | a0;
    a = a -% (@as(dlimb_t, q) * @as(dlimb_t, d)) -% d;
    const ah: limb_t = @truncate(a >> LIMB_BITS);
    q +%= 1 +% ah;
    const r: limb_t = @as(limb_t, @truncate(a)) +% (ah & d);
    pr.* = r;
    return q;
}

fn mp_div1(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r0: limb_t) limb_t {
    var r = r0;
    var i: isize = @as(isize, @intCast(n)) - 1;
    while (i >= 0) : (i -= 1) {
        const idx: usize = @intCast(i);
        const a1: dlimb_t = (@as(dlimb_t, r) << LIMB_BITS) | taba[idx];
        tabr[idx] = @truncate(a1 / b);
        r = @truncate(a1 % b);
    }
    return r;
}

pub export fn mp_shr(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, high: limb_t) callconv(.c) limb_t {
    std.debug.assert(shift >= 1 and shift < LIMB_BITS);
    var l = high;
    var i: isize = n - 1;
    while (i >= 0) : (i -= 1) {
        const idx: usize = @intCast(i);
        const a = tab[idx];
        tab_r[idx] = (a >> @intCast(shift)) | (l << @intCast(LIMB_BITS - shift));
        l = a;
    }
    return l & ((@as(limb_t, 1) << @intCast(shift)) - 1);
}

pub export fn mp_shl(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, low: limb_t) callconv(.c) limb_t {
    std.debug.assert(shift >= 1 and shift < LIMB_BITS);
    var l = low;
    var i: isize = 0;
    while (i < n) : (i += 1) {
        const idx: usize = @intCast(i);
        const a = tab[idx];
        tab_r[idx] = (a << @intCast(shift)) | l;
        l = a >> @intCast(LIMB_BITS - shift);
    }
    return l;
}

pub export fn mp_div1norm(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r0: limb_t, b_inv: limb_t, shift: c_int) callconv(.c) limb_t {
    var r = r0;
    if (shift != 0) {
        r = (r << @intCast(shift)) | mp_shl(tabr, taba, @intCast(n), shift, 0);
    }
    var i: isize = @as(isize, @intCast(n)) - 1;
    while (i >= 0) : (i -= 1) {
        const idx: usize = @intCast(i);
        const a0 = if (shift != 0) tabr[idx] else taba[idx];
        tabr[idx] = udiv1norm(&r, r, a0, b, b_inv);
    }
    r >>= @intCast(shift);
    return r;
}

pub export fn mpb_dump(str: [*]const u8, a: *const anyopaque) callconv(.c) void {
    _ = str;
    _ = a;
}

pub export fn mpb_renorm(r: *anyopaque) callconv(.c) void {
    const len = mpbLen(r);
    const tab = mpbTab(r);
    while (len.* > 1 and tab[@intCast(len.* - 1)] == 0) {
        len.* -= 1;
    }
}

pub export fn pow_ui(radix: c_int, n: c_int) callconv(.c) u64 {
    const a: u32 = @intCast(radix);
    const b: u32 = @intCast(n);
    if (b == 0) return 1;
    if (b == 1) return a;
    if ((a == 5 or a == 10) and b <= 17) {
        var r: u64 = pow5_table[b - 1];
        if (b >= 14) r |= @as(u64, pow5h_table[b - 14]) << 32;
        if (a == 10) r <<= @intCast(b);
        return r;
    }
    var r: u64 = a;
    const n_bits = 32 - clz32(b);
    var i: c_int = n_bits - 2;
    while (i >= 0) : (i -= 1) {
        r *= r;
        if (((b >> @intCast(i)) & 1) != 0) r *= a;
    }
    return r;
}

pub export fn pow_ui_inv(pr_inv: *u32, pshift: *c_int, radix: c_int, n: c_int) callconv(.c) void {
    const a: u32 = @intCast(radix);
    const b: u32 = @intCast(n);
    var r_inv: u32 = undefined;
    var r: u32 = undefined;
    var shift: c_int = undefined;
    if (a == 5 and b >= 1 and b <= 13) {
        r = pow5_table[b - 1];
        shift = clz32(r);
        r <<= @intCast(shift);
        r_inv = pow5_inv_table[b - 1];
    } else {
        r = @truncate(pow_ui(radix, n));
        shift = clz32(r);
        r <<= @intCast(shift);
        r_inv = udiv1norm_init(r);
    }
    pshift.* = shift;
    pr_inv.* = r_inv;
}

pub export fn mpb_get_bit(r: *const anyopaque, pos: c_int) callconv(.c) c_int {
    var k = pos;
    const l: c_int = @intCast(@as(u32, @bitCast(k)) / LIMB_BITS);
    k &= LIMB_BITS - 1;
    if (l >= mpbLenConst(r).*) return 0;
    return @intCast((mpbTabConst(r)[@intCast(l)] >> @intCast(k)) & 1);
}

pub export fn mpb_shr_round(r: *anyopaque, shift0: c_int, rnd_mode: c_int) callconv(.c) void {
    var shift = shift0;
    const len = mpbLen(r);
    const tab = mpbTab(r);
    if (shift == 0) return;
    if (shift < 0) {
        shift = -shift;
        const l: c_int = @intCast(@as(u32, @intCast(shift)) / LIMB_BITS);
        shift &= LIMB_BITS - 1;
        if (shift != 0) {
            tab[@intCast(len.*)] = mp_shl(tab, tab, len.*, shift, 0);
            len.* += 1;
            mpb_renorm(r);
        }
        if (l > 0) {
            var i: c_int = len.* - 1;
            while (i >= 0) : (i -= 1) tab[@intCast(i + l)] = tab[@intCast(i)];
            i = 0;
            while (i < l) : (i += 1) tab[@intCast(i)] = 0;
            len.* += l;
        }
    } else {
        var add_one: c_int = 0;
        switch (rnd_mode) {
            JS_RNDN, JS_RNDNA => {
                const bit1 = mpb_get_bit(r, shift - 1);
                if (bit1 != 0) {
                    var bit2: limb_t = 0;
                    if (rnd_mode == JS_RNDNA) {
                        bit2 = 1;
                    } else if (shift >= 2) {
                        var k = shift - 1;
                        const l: c_int = @intCast(@as(u32, @intCast(k)) / LIMB_BITS);
                        k &= LIMB_BITS - 1;
                        var i: c_int = 0;
                        while (i < minInt(l, len.*)) : (i += 1) bit2 |= tab[@intCast(i)];
                        if (l < len.*) bit2 |= tab[@intCast(l)] & ((@as(limb_t, 1) << @intCast(k)) - 1);
                    }
                    add_one = if (bit2 != 0) 1 else mpb_get_bit(r, shift);
                }
            },
            else => add_one = 0,
        }
        const l: c_int = @intCast(@as(u32, @intCast(shift)) / LIMB_BITS);
        shift &= LIMB_BITS - 1;
        if (l >= len.*) {
            len.* = 1;
            tab[0] = @intCast(add_one);
        } else {
            if (l > 0) {
                len.* -= l;
                var i: c_int = 0;
                while (i < len.*) : (i += 1) tab[@intCast(i)] = tab[@intCast(i + l)];
            }
            if (shift != 0) {
                _ = mp_shr(tab, tab, len.*, shift, 0);
                mpb_renorm(r);
            }
            if (add_one != 0) {
                const a = mp_add_ui(tab, 1, @intCast(len.*));
                if (a != 0) {
                    tab[@intCast(len.*)] = a;
                    len.* += 1;
                }
            }
        }
    }
}

pub export fn mpb_cmp(a: *const anyopaque, b: *const anyopaque) callconv(.c) c_int {
    const alen = mpbLenConst(a).*;
    const blen = mpbLenConst(b).*;
    const atab = mpbTabConst(a);
    const btab = mpbTabConst(b);
    if (alen < blen) return -1;
    if (alen > blen) return 1;
    var i: c_int = alen - 1;
    while (i >= 0) : (i -= 1) {
        const idx: usize = @intCast(i);
        if (atab[idx] != btab[idx]) return if (atab[idx] < btab[idx]) -1 else 1;
    }
    return 0;
}

pub export fn mpb_set_u64(r: *anyopaque, m: u64) callconv(.c) void {
    const len = mpbLen(r);
    const tab = mpbTab(r);
    tab[0] = @truncate(m);
    tab[1] = @truncate(m >> LIMB_BITS);
    len.* = if (tab[1] == 0) 1 else 2;
}

pub export fn mpb_get_u64(r: *anyopaque) callconv(.c) u64 {
    const len = mpbLen(r).*;
    const tab = mpbTab(r);
    return if (len == 1) tab[0] else (@as(u64, tab[0]) | (@as(u64, tab[1]) << LIMB_BITS));
}

pub export fn mpb_floor_log2(a: *anyopaque) callconv(.c) c_int {
    const len = mpbLen(a).*;
    const tab = mpbTab(a);
    const v = tab[@intCast(len - 1)];
    if (v == 0) return -1;
    return len * LIMB_BITS - 1 - clz32(v);
}

pub export fn mul_log2_radix(a0: c_int, radix: c_int) callconv(.c) c_int {
    var a = a0;
    const r: u32 = @intCast(radix);
    if ((r & (r - 1)) == 0) {
        const radix_bits: c_int = 31 - clz32(r);
        if (a < 0) a -= radix_bits - 1;
        return @divTrunc(a, radix_bits);
    }
    const mult: i64 = mul_log2_radix_table[@intCast(radix - 2)];
    return @intCast((@as(i64, a) * mult) >> MUL_LOG2_RADIX_BASE_LOG2);
}

fn u32toa_len(buf: [*]u8, n0: u32, len: usize) void {
    var n = n0;
    var i = len;
    while (i > 0) {
        i -= 1;
        const digit = n % 10;
        n /= 10;
        buf[i] = @as(u8, @intCast(digit)) + '0';
    }
}

fn u64toa_bin_len(buf: [*]u8, n0: u64, radix_bits: c_int, len0: c_int) void {
    var n = n0;
    const mask: u64 = (@as(u64, 1) << @intCast(radix_bits)) - 1;
    var i = len0;
    while (i > 0) {
        i -= 1;
        var digit: u8 = @intCast(n & mask);
        n >>= @intCast(radix_bits);
        digit += if (digit < 10) '0' else 'a' - 10;
        buf[@intCast(i)] = digit;
    }
}

pub export fn limb_to_a(buf: [*]u8, a: limb_t, radix: c_int, len: c_int) callconv(.c) void {
    var n = a;
    if (radix == 10) {
        u32toa_len(buf, n, @intCast(len));
    } else {
        var i = len;
        while (i > 0) {
            i -= 1;
            var digit: u8 = @intCast(n % @as(u32, @intCast(radix)));
            n /= @intCast(radix);
            digit += if (digit < 10) '0' else 'a' - 10;
            buf[@intCast(i)] = digit;
        }
    }
}

pub export fn u32toa(buf: [*]u8, n0: u32) callconv(.c) usize {
    var tmp: [10]u8 = undefined;
    var n = n0;
    var q: usize = tmp.len;
    while (true) {
        q -= 1;
        tmp[q] = @as(u8, @intCast(n % 10)) + '0';
        n /= 10;
        if (n == 0) break;
    }
    const len = tmp.len - q;
    @memcpy(buf[0..len], tmp[q..]);
    return len;
}

pub export fn i32toa(buf: [*]u8, n: i32) callconv(.c) usize {
    if (n >= 0) return u32toa(buf, @intCast(n));
    buf[0] = '-';
    const u: u32 = @bitCast(n);
    return u32toa(buf + 1, 0 -% u) + 1;
}

pub export fn u64toa(buf: [*]u8, n0: u64) callconv(.c) usize {
    var n = n0;
    if (n < 0x100000000) return u32toa(buf, @intCast(n));
    var q: usize = 0;
    var n1 = n / 1000000000;
    n %= 1000000000;
    if (n1 >= 0x100000000) {
        var n2: u32 = @intCast(n1 / 1000000000);
        n1 %= 1000000000;
        if (n2 >= 10) {
            buf[q] = @as(u8, @intCast(n2 / 10)) + '0';
            q += 1;
            n2 %= 10;
        }
        buf[q] = @as(u8, @intCast(n2)) + '0';
        q += 1;
        u32toa_len(buf + q, @intCast(n1), 9);
        q += 9;
    } else {
        q += u32toa(buf + q, @intCast(n1));
    }
    u32toa_len(buf + q, @intCast(n), 9);
    q += 9;
    return q;
}

pub export fn i64toa(buf: [*]u8, n: i64) callconv(.c) usize {
    if (n >= 0) return u64toa(buf, @intCast(n));
    buf[0] = '-';
    const u: u64 = @bitCast(n);
    return u64toa(buf + 1, 0 -% u) + 1;
}

pub export fn u64toa_radix(buf: [*]u8, n0: u64, radix0: c_uint) callconv(.c) usize {
    var n = n0;
    const radix: u32 = @intCast(radix0);
    if (radix == 10) return u64toa(buf, n);
    if ((radix & (radix - 1)) == 0) {
        const radix_bits: c_int = 31 - clz32(radix);
        const l: c_int = if (n == 0) 1 else @divTrunc(64 - clz64(n) + radix_bits - 1, radix_bits);
        u64toa_bin_len(buf, n, radix_bits, l);
        return @intCast(l);
    }
    var tmp: [41]u8 = undefined;
    var q: usize = tmp.len;
    while (true) {
        var digit: u8 = @intCast(n % radix);
        n /= radix;
        digit += if (digit < 10) '0' else 'a' - 10;
        q -= 1;
        tmp[q] = digit;
        if (n == 0) break;
    }
    const len = tmp.len - q;
    @memcpy(buf[0..len], tmp[q..]);
    return len;
}

pub export fn i64toa_radix(buf: [*]u8, n: i64, radix: c_uint) callconv(.c) usize {
    if (n >= 0) return u64toa_radix(buf, @intCast(n), radix);
    buf[0] = '-';
    const u: u64 = @bitCast(n);
    return u64toa_radix(buf + 1, 0 -% u, radix) + 1;
}

pub export fn output_digits(buf: [*]u8, a0: *const anyopaque, radix: c_int, n_digits1: c_int, dot_pos: c_int) callconv(.c) c_int {
    const a: *anyopaque = @constCast(a0);
    var n_digits = n_digits1;
    const radix_u: u32 = @intCast(radix);
    const radix_bits: c_int = if ((radix_u & (radix_u - 1)) == 0) 31 - clz32(radix_u) else 0;
    const digits_per_limb: c_int = digits_per_limb_table[@intCast(radix - 2)];
    if (radix_bits != 0) {
        while (true) {
            const n = minInt(n_digits, digits_per_limb);
            n_digits -= n;
            u64toa_bin_len(buf + @as(usize, @intCast(n_digits)), mpbTab(a)[0], radix_bits, n);
            if (n_digits == 0) break;
            mpb_shr_round(a, digits_per_limb * radix_bits, JS_RNDZ);
        }
    } else {
        while (n_digits != 0) {
            const n = minInt(n_digits, digits_per_limb);
            n_digits -= n;
            const r = mp_div1(mpbTab(a), mpbTab(a), @intCast(mpbLen(a).*), radix_base_table[@intCast(radix - 2)], 0);
            mpb_renorm(a);
            limb_to_a(buf + @as(usize, @intCast(n_digits)), r, radix, n);
        }
    }
    var len = n_digits1;
    if (dot_pos != n_digits1) {
        const dp: usize = @intCast(dot_pos);
        const nd: usize = @intCast(n_digits1);
        std.mem.copyBackwards(u8, buf[dp + 1 .. nd + 1], buf[dp..nd]);
        buf[dp] = '.';
        len += 1;
    }
    return len;
}

fn mul_pow(a: *anyopaque, radix1: c_int, radix_shift: c_int, f0: c_int, is_int: bool, e: c_int) c_int {
    var f = f0;
    var e_offset: c_int = -f * radix_shift;
    if (radix1 != 1) {
        const d: c_int = digits_per_limb_table[@intCast(radix1 - 2)];
        if (f >= 0) {
            var b: limb_t = 0;
            var n0: c_int = 0;
            while (f != 0) {
                const n = minInt(f, d);
                if (n != n0) {
                    b = @truncate(pow_ui(radix1, n));
                    n0 = n;
                }
                const h = mp_mul1(mpbTab(a), mpbTabConst(a), @intCast(mpbLen(a).*), b, 0);
                if (h != 0) {
                    mpbTab(a)[@intCast(mpbLen(a).*)] = h;
                    mpbLen(a).* += 1;
                }
                f -= n;
            }
        } else {
            f = -f;
            const l = @divTrunc(f + d - 1, d);
            e_offset += l * LIMB_BITS;
            const extra_bits = if (!is_int)
                maxInt(e - mpb_floor_log2(a), 0)
            else
                maxInt(2 + e - e_offset, 0);
            e_offset += extra_bits;
            mpb_shr_round(a, -(l * LIMB_BITS + extra_bits), JS_RNDZ);
            var b: limb_t = 0;
            var b_inv: limb_t = 0;
            var shift: c_int = 0;
            var n0: c_int = 0;
            var rem: limb_t = 0;
            while (f != 0) {
                const n = minInt(f, d);
                if (n != n0) {
                    pow_ui_inv(&b_inv, &shift, radix1, n);
                    b = @truncate(pow_ui(radix1, n));
                    if (radix1 == 5 and n >= 1 and n <= 13) {
                        b = pow5_table[@intCast(n - 1)];
                        b <<= @intCast(shift);
                    } else {
                        b <<= @intCast(shift);
                    }
                    n0 = n;
                }
                const rr = mp_div1norm(mpbTab(a), mpbTabConst(a), @intCast(mpbLen(a).*), b, 0, b_inv, shift);
                rem |= rr;
                mpb_renorm(a);
                f -= n;
            }
            if (rem != 0) mpbTab(a)[0] |= 1;
        }
    }
    return e_offset;
}

fn mul_pow_round(tmp1: *anyopaque, m: u64, e: c_int, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) void {
    mpb_set_u64(tmp1, m);
    const e_offset = mul_pow(tmp1, radix1, radix_shift, f, true, e);
    mpb_shr_round(tmp1, -e + e_offset, rnd_mode);
}

pub export fn round_to_d(pe: *c_int, a: *anyopaque, e_offset: c_int, rnd_mode: c_int) callconv(.c) u64 {
    var e: c_int = 0;
    var m: u64 = 0;
    if (mpbTab(a)[0] == 0 and mpbLen(a).* == 1) {
        m = 0;
        e = 0;
    } else {
        const prec1: c_int = 53;
        const e_min: c_int = -1021;
        e = mpb_floor_log2(a) + 1 - e_offset;
        const prec = if (e < e_min) prec1 - (e_min - e) else prec1;
        mpb_shr_round(a, e + e_offset - prec, rnd_mode);
        m = mpb_get_u64(a);
        if (prec < 53) m <<= @intCast(53 - prec);
        if (m >= (@as(u64, 1) << 53)) {
            m >>= 1;
            e += 1;
        }
    }
    pe.* = e;
    return m;
}

pub export fn mul_pow_round_to_d(pe: *c_int, a: *anyopaque, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) callconv(.c) u64 {
    const e_offset = mul_pow(a, radix1, radix_shift, f, false, 55);
    return round_to_d(pe, a, e_offset, rnd_mode);
}

pub export fn js_dtoa_max_len(d: f64, radix: c_int, n_digits: c_int, flags: c_int) callconv(.c) c_int {
    const fmt = flags & JS_DTOA_FORMAT_MASK;
    var n: c_int = undefined;
    if (fmt != JS_DTOA_FORMAT_FRAC) {
        n = if (fmt == JS_DTOA_FORMAT_FREE) dtoa_max_digits_table[@intCast(radix - 2)] else n_digits;
        if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_DISABLED) {
            const a = float64_as_uint64(d);
            var e: c_int = @intCast((a >> 52) & 0x7ff);
            if (e == 0x7ff) {
                n = 0;
            } else {
                e -= 1023;
                n += 10 + absInt(mul_log2_radix(e - 1, radix));
            }
        } else {
            n += 1 + 1 + 6;
        }
    } else {
        const a = float64_as_uint64(d);
        var e: c_int = @intCast((a >> 52) & 0x7ff);
        if (e == 0x7ff) {
            n = 0;
        } else {
            e -= 1023;
            n = if (e < 0) 1 else 2 + mul_log2_radix(e - 1, radix);
            n += 1 + 1 + 1 + n_digits;
        }
    }
    return maxInt(n, 9);
}

pub export fn js_dtoa(buf: [*]u8, d: f64, radix: c_int, n_digits: c_int, flags: c_int, tmp_mem: *JSDTOATempMem) callconv(.c) c_int {
    var mptr: [*]u64 = tmp_mem.mem[0..].ptr;
    const tmp1 = dtoaAlloc(&mptr, @sizeOf(c_int) + @sizeOf(limb_t) * DBIGNUM_LEN_MAX);
    const mant_max = dtoaAlloc(&mptr, @sizeOf(c_int) + @sizeOf(limb_t) * MANT_LEN_MAX);

    const radix_shift = ctz32(@intCast(radix));
    const radix1 = radix >> @intCast(radix_shift);
    const bits = float64_as_uint64(d);
    const sgn: c_int = @intCast(bits >> 63);
    var e: c_int = @intCast((bits >> 52) & 0x7ff);
    var m: u64 = bits & ((@as(u64, 1) << 52) - 1);
    var q: usize = 0;
    const fmt = flags & JS_DTOA_FORMAT_MASK;
    var E: c_int = undefined;
    var P: c_int = undefined;
    var zero_result = false;
    var subnormal = false;

    if (e == 0x7ff) {
        if (m == 0) {
            if (sgn != 0) {
                buf[q] = '-';
                q += 1;
            }
            @memcpy(buf[q .. q + 8], "Infinity");
            q += 8;
        } else {
            @memcpy(buf[q .. q + 3], "NaN");
            q += 3;
        }
        buf[q] = 0;
        return @intCast(q);
    } else if (e == 0) {
        if (m == 0) {
            mpbLen(tmp1).* = 1;
            mpbTab(tmp1)[0] = 0;
            E = 1;
            P = if (fmt == JS_DTOA_FORMAT_FREE) 1 else if (fmt == JS_DTOA_FORMAT_FRAC) n_digits + 1 else n_digits;
            if (sgn != 0 and (flags & JS_DTOA_MINUS_ZERO) != 0) {
                buf[q] = '-';
                q += 1;
            }
            zero_result = true;
        } else {
            subnormal = true;
            const l = clz64(m) - 11;
            e -= l - 1;
            m <<= @intCast(l);
        }
    }

    if (!zero_result) {
        if (!subnormal) m |= @as(u64, 1) << 52;
        if (sgn != 0 and q == 0) {
            buf[q] = '-';
            q += 1;
        }
        e -= 1022;
        E = 1 + mul_log2_radix(e - 1, radix);
        if (fmt == JS_DTOA_FORMAT_FREE and e >= 1 and e <= 53 and (m & ((@as(u64, 1) << @intCast(53 - e)) - 1)) == 0 and (flags & JS_DTOA_EXP_MASK) != JS_DTOA_EXP_ENABLED) {
            m >>= @intCast(53 - e);
            q += u64toa_radix(buf + q, m, @intCast(radix));
            buf[q] = 0;
            return @intCast(q);
        }
        if (fmt == JS_DTOA_FORMAT_FREE) {
            const P_max: c_int = dtoa_max_digits_table[@intCast(radix - 2)];
            const E0 = E;
            var E_found: c_int = 0;
            var P_found: c_int = 0;
            var mant_found: u64 = 0;
            P = P_max;
            while (true) {
                const mant_max1 = pow_ui(radix, P);
                E = E0;
                var mant: u64 = 0;
                while (true) {
                    mul_pow_round(tmp1, m, e - 53, radix1, radix_shift, P - E, JS_RNDN);
                    mant = mpb_get_u64(tmp1);
                    if (mant < mant_max1) break;
                    E += 1;
                }
                while ((mant % @as(u32, @intCast(radix))) == 0) {
                    mant /= @intCast(radix);
                    P -= 1;
                }
                if (P_found == 0) {
                    P_found = P;
                    E_found = E;
                    mant_found = mant;
                    if (P == 1) break;
                    P -= 1;
                    continue;
                }
                mpb_set_u64(tmp1, mant);
                var e1: c_int = 0;
                const m1 = mul_pow_round_to_d(&e1, tmp1, radix1, radix_shift, E - P, JS_RNDN);
                if (m1 == m and e1 == e) {
                    P_found = P;
                    E_found = E;
                    mant_found = mant;
                    if (P == 1) break;
                    P -= 1;
                } else break;
            }
            P = P_found;
            E = E_found;
            mpb_set_u64(tmp1, mant_found);
        } else if (fmt == JS_DTOA_FORMAT_FRAC) {
            std.debug.assert(n_digits >= 0 and n_digits <= JS_DTOA_MAX_DIGITS);
            mul_pow_round(tmp1, m, e - 53, radix1, radix_shift, n_digits, JS_RNDNA);
            var len = output_digits(buf + q, tmp1, radix, maxInt(E + 1, 1) + n_digits, maxInt(E + 1, 1));
            if (buf[q] == '0' and len >= 2 and buf[q + 1] != '.') {
                const lenu: usize = @intCast(len - 1);
                std.mem.copyForwards(u8, buf[q .. q + lenu], buf[q + 1 .. q + 1 + lenu]);
                len -= 1;
            }
            q += @intCast(len);
            buf[q] = 0;
            return @intCast(q);
        } else {
            std.debug.assert(n_digits >= 1 and n_digits <= JS_DTOA_MAX_DIGITS);
            P = n_digits;
            mpbLen(mant_max).* = 1;
            mpbTab(mant_max)[0] = 1;
            const pow_shift = mul_pow(mant_max, radix1, radix_shift, P, false, 0);
            mpb_shr_round(mant_max, pow_shift, JS_RNDZ);
            while (true) {
                mul_pow_round(tmp1, m, e - 53, radix1, radix_shift, P - E, JS_RNDNA);
                if (mpb_cmp(tmp1, mant_max) < 0) break;
                E += 1;
            }
        }
    }

    const E_max: c_int = if (fmt == JS_DTOA_FORMAT_FIXED) n_digits else dtoa_max_digits_table[@intCast(radix - 2)] + 4;
    if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_ENABLED or ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_AUTO and (E <= -6 or E > E_max))) {
        q += @intCast(output_digits(buf + q, tmp1, radix, P, 1));
        E -= 1;
        var exp_val = E;
        if (radix == 10) {
            buf[q] = 'e';
            q += 1;
        } else if (radix1 == 1 and radix_shift <= 4) {
            exp_val *= radix_shift;
            buf[q] = 'p';
            q += 1;
        } else {
            buf[q] = '@';
            q += 1;
        }
        if (exp_val < 0) {
            buf[q] = '-';
            q += 1;
            exp_val = -exp_val;
        } else {
            buf[q] = '+';
            q += 1;
        }
        q += u32toa(buf + q, @intCast(exp_val));
    } else if (E <= 0) {
        buf[q] = '0';
        q += 1;
        buf[q] = '.';
        q += 1;
        var i: c_int = 0;
        while (i < -E) : (i += 1) {
            buf[q] = '0';
            q += 1;
        }
        q += @intCast(output_digits(buf + q, tmp1, radix, P, P));
    } else {
        q += @intCast(output_digits(buf + q, tmp1, radix, P, minInt(P, E)));
        var i: c_int = 0;
        while (i < E - P) : (i += 1) {
            buf[q] = '0';
            q += 1;
        }
    }
    buf[q] = 0;
    return @intCast(q);
}

fn to_digit(c0: u8) c_int {
    const c = c0;
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'A' and c <= 'Z') return c - 'A' + 10;
    if (c >= 'a' and c <= 'z') return c - 'a' + 10;
    return 36;
}

pub export fn mpb_mul1_base(r: *anyopaque, radix_base: limb_t, a: limb_t) callconv(.c) void {
    const len = mpbLen(r);
    const tab = mpbTab(r);
    if (tab[0] == 0 and len.* == 1) {
        tab[0] = a;
    } else {
        if (radix_base == 0) {
            var i: c_int = len.*;
            while (i >= 0) : (i -= 1) tab[@intCast(i + 1)] = tab[@intCast(i)];
            tab[0] = a;
        } else {
            tab[@intCast(len.*)] = mp_mul1(tab, tab, @intCast(len.*), radix_base, a);
        }
        len.* += 1;
        mpb_renorm(r);
    }
}

fn startsWith(ptr: [*]const u8, idx: usize, comptime s: []const u8) bool {
    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        if (ptr[idx + i] != s[i]) return false;
    }
    return true;
}

fn setPnext(pnext: [*c][*c]const u8, str: [*]const u8, idx: usize) void {
    if (pnext != null) pnext.* = @ptrCast(str + idx);
}

fn finishAtod(pnext: [*c][*c]const u8, str: [*]const u8, idx: usize, bits: u64, is_neg: bool) f64 {
    setPnext(pnext, str, idx);
    return uint64_as_float64(bits | (@as(u64, @intFromBool(is_neg)) << 63));
}

fn failAtod(pnext: [*c][*c]const u8, str: [*]const u8, idx: usize) f64 {
    setPnext(pnext, str, idx);
    return std.math.nan(f64);
}

pub export fn js_atod(str: [*]const u8, pnext: [*c][*c]const u8, radix0: c_int, flags: c_int, tmp_mem: *JSATODTempMem) callconv(.c) f64 {
    var mptr: [*]u64 = tmp_mem.mem[0..].ptr;
    const tmp0 = dtoaAlloc(&mptr, @sizeOf(c_int) + @sizeOf(limb_t) * DBIGNUM_LEN_MAX);
    var radix = radix0;
    var idx: usize = 0;
    var is_neg = false;
    var p_start: usize = 0;
    if (str[idx] == '+') {
        idx += 1;
        p_start = idx;
    } else if (str[idx] == '-') {
        is_neg = true;
        idx += 1;
        p_start = idx;
    }

    var sep: c_int = if ((flags & JS_ATOD_ACCEPT_UNDERSCORES) != 0) '_' else 256;
    if (str[idx] == '0') {
        if ((str[idx + 1] == 'x' or str[idx + 1] == 'X') and (radix == 0 or radix == 16)) {
            idx += 2;
            radix = 16;
            if (to_digit(str[idx]) >= radix) return failAtod(pnext, str, idx);
        } else if ((str[idx + 1] == 'o' or str[idx + 1] == 'O') and radix == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
            idx += 2;
            radix = 8;
            if (to_digit(str[idx]) >= radix) return failAtod(pnext, str, idx);
        } else if ((str[idx + 1] == 'b' or str[idx + 1] == 'B') and radix == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
            idx += 2;
            radix = 2;
            if (to_digit(str[idx]) >= radix) return failAtod(pnext, str, idx);
        } else if ((str[idx + 1] >= '0' and str[idx + 1] <= '9') and radix == 0 and (flags & JS_ATOD_ACCEPT_LEGACY_OCTAL) != 0) {
            sep = 256;
            var i: usize = idx + 1;
            while (str[i] >= '0' and str[i] <= '7') : (i += 1) {}
            if (!(str[i] == '8' or str[i] == '9')) {
                idx += 1;
                radix = 8;
            }
        }
    } else if ((flags & JS_ATOD_INT_ONLY) == 0 and startsWith(str, idx, "Infinity")) {
        idx += 8;
        return finishAtod(pnext, str, idx, @as(u64, 0x7ff) << 52, is_neg);
    }
    if (radix == 0) radix = 10;

    var cur_limb: limb_t = 0;
    var digit_count: c_int = 0;
    var limb_digit_count: c_int = 0;
    const max_digits: c_int = atod_max_digits_table[@intCast(radix - 2)];
    const digits_per_limb: c_int = digits_per_limb_table[@intCast(radix - 2)];
    const radix_base = radix_base_table[@intCast(radix - 2)];
    const radix_shift = ctz32(@intCast(radix));
    const radix1 = radix >> @intCast(radix_shift);
    const radix_bits: c_int = if (radix1 == 1) radix_shift else 0;
    mpbLen(tmp0).* = 1;
    mpbTab(tmp0)[0] = 0;
    var extra_digits: limb_t = 0;
    var pos: c_int = 0;
    var dot_pos: c_int = -1;

    while (true) {
        if (str[idx] == '.' and (idx > p_start or to_digit(str[idx + 1]) < radix) and (flags & JS_ATOD_INT_ONLY) == 0) {
            if (dot_pos >= 0) break;
            dot_pos = pos;
            idx += 1;
        }
        if (@as(c_int, str[idx]) == sep and idx > p_start and str[idx + 1] == '0') idx += 1;
        if (str[idx] != '0') break;
        idx += 1;
        pos += 1;
    }

    const sig_pos = pos;
    while (true) {
        if (str[idx] == '.' and (idx > p_start or to_digit(str[idx + 1]) < radix) and (flags & JS_ATOD_INT_ONLY) == 0) {
            if (dot_pos >= 0) break;
            dot_pos = pos;
            idx += 1;
        }
        if (@as(c_int, str[idx]) == sep and idx > p_start and to_digit(str[idx + 1]) < radix) idx += 1;
        const c = to_digit(str[idx]);
        if (c >= radix) break;
        idx += 1;
        pos += 1;
        if (digit_count < max_digits) {
            cur_limb = cur_limb *% @as(u32, @intCast(radix)) +% @as(u32, @intCast(c));
            limb_digit_count += 1;
            if (limb_digit_count == digits_per_limb) {
                mpb_mul1_base(tmp0, radix_base, cur_limb);
                cur_limb = 0;
                limb_digit_count = 0;
            }
            digit_count += 1;
        } else {
            extra_digits |= @intCast(c);
        }
    }
    if (limb_digit_count != 0) mpb_mul1_base(tmp0, @truncate(pow_ui(radix, limb_digit_count)), cur_limb);

    var is_zero: bool = undefined;
    var expn_offset: c_int = 0;
    if (digit_count == 0) {
        is_zero = true;
    } else {
        is_zero = false;
        if (dot_pos < 0) dot_pos = pos;
        expn_offset = sig_pos + digit_count - dot_pos;
    }
    if (radix_bits != 0 and extra_digits != 0) mpbTab(tmp0)[0] |= 1;

    var expn: c_int = 0;
    var expn_overflow = false;
    var is_bin_exp = false;
    if ((flags & JS_ATOD_INT_ONLY) == 0 and ((radix == 10 and (str[idx] == 'e' or str[idx] == 'E')) or (radix != 10 and (str[idx] == '@' or (radix_bits >= 1 and radix_bits <= 4 and (str[idx] == 'p' or str[idx] == 'P'))))) and idx > p_start) {
        is_bin_exp = (str[idx] == 'p' or str[idx] == 'P');
        idx += 1;
        var exp_is_neg = false;
        if (str[idx] == '+') {
            idx += 1;
        } else if (str[idx] == '-') {
            exp_is_neg = true;
            idx += 1;
        }
        var c = to_digit(str[idx]);
        if (c >= 10) return failAtod(pnext, str, idx);
        expn = c;
        idx += 1;
        while (true) {
            if (@as(c_int, str[idx]) == sep and to_digit(str[idx + 1]) < 10) idx += 1;
            c = to_digit(str[idx]);
            if (c >= 10) break;
            if (!expn_overflow) {
                if (expn > @divTrunc(INT32_MAX_VALUE - 2 - 9, 10)) {
                    expn_overflow = true;
                } else {
                    expn = expn * 10 + c;
                }
            }
            idx += 1;
        }
        if (exp_is_neg) expn = -expn;
        if (!is_zero and expn_overflow) {
            const bits_out: u64 = if (exp_is_neg) 0 else (@as(u64, 0x7ff) << 52);
            return finishAtod(pnext, str, idx, bits_out, is_neg);
        }
    }

    if (idx == p_start) return failAtod(pnext, str, idx);

    var bits_out: u64 = 0;
    if (is_zero) {
        bits_out = 0;
    } else {
        var e: c_int = 0;
        var m: u64 = 0;
        if (radix_bits != 0) {
            if (!is_bin_exp) expn *= radix_bits;
            expn -= expn_offset * radix_bits;
            const expn1 = expn + digit_count * radix_bits;
            if (expn1 >= 1024 + radix_bits) {
                bits_out = @as(u64, 0x7ff) << 52;
                return finishAtod(pnext, str, idx, bits_out, is_neg);
            } else if (expn1 <= -1075) {
                bits_out = 0;
                return finishAtod(pnext, str, idx, bits_out, is_neg);
            }
            m = round_to_d(&e, tmp0, -expn, JS_RNDN);
        } else {
            expn -= expn_offset;
            const expn1 = expn + digit_count;
            if (expn1 >= max_exponent[@intCast(radix - 2)] + 1) {
                bits_out = @as(u64, 0x7ff) << 52;
                return finishAtod(pnext, str, idx, bits_out, is_neg);
            } else if (expn1 <= min_exponent[@intCast(radix - 2)]) {
                bits_out = 0;
                return finishAtod(pnext, str, idx, bits_out, is_neg);
            }
            m = mul_pow_round_to_d(&e, tmp0, radix1, radix_shift, expn, JS_RNDN);
        }
        if (m == 0) {
            bits_out = 0;
        } else if (e > 1024) {
            bits_out = @as(u64, 0x7ff) << 52;
        } else if (e < -1073) {
            bits_out = 0;
        } else if (e < -1021) {
            bits_out = m >> @intCast(-e - 1021);
        } else {
            bits_out = (@as(u64, @intCast(e + 1022)) << 52) | (m & ((@as(u64, 1) << 52) - 1));
        }
    }
    return finishAtod(pnext, str, idx, bits_out, is_neg);
}
