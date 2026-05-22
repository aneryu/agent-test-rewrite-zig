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
const JS_RADIX_MAX = 36;
const DBIGNUM_LEN_MAX = 128;
const MANT_LEN_MAX = 32;
const MUL_LOG2_RADIX_BASE_LOG2 = 24;

const slimb_t = i32;
const limb_t = u32;
const dlimb_t = u64;

const Mpb = extern struct {
    len: c_int,
    tab: [DBIGNUM_LEN_MAX]limb_t,
};

const RndMode = enum(c_int) {
    rndn = 0,
    rndna = 1,
    rndz = 2,
};

const pow5_table = [_]u32{
    0x00000005, 0x00000019, 0x0000007d, 0x00000271,
    0x00000c35, 0x00003d09, 0x0001312d, 0x0005f5e1,
    0x001dcd65, 0x009502f9, 0x02e90edd, 0x0e8d4a51,
    0x48c27395, 0x6bcc41e9, 0x1afd498d, 0x86f26fc1,
    0xa2bc2ec5,
};

const pow5h_table = [_]u8{
    0x00000001, 0x00000007, 0x00000023, 0x000000b1,
};

const pow5_inv_table = [_]u32{
    0x99999999, 0x47ae147a, 0x0624dd2f,  0xa36e2eb1,
    0x4f8b588e, 0x0c6f7a0b, 0x0ad7f29ab, 0x5798ee23,
    0x12e0be82, 0xb7cdfd9d, 0x5fd7fe17,  0x19799812,
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
    32, 20, 16, 13, 12, 11, 10, 10, 9, 9, 8, 8, 8, 8, 8, 7, 7, 7,
    7,  7,  7,  7,  6,  6,  6,  6,  6, 6, 6, 6, 6, 6, 6, 6, 6,
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
    54, 35, 28, 24, 22, 20, 19, 18, 17, 17, 16, 16, 15, 15, 15, 14,
    14, 14, 14, 14, 13, 13, 13, 13, 13, 13, 13, 12, 12, 12, 12, 12,
    12, 12, 12,
};

const atod_max_digits_table = [_]u8{
    64, 80, 32, 55, 49, 45, 21, 40, 38, 37, 35, 34, 33, 32, 16, 31,
    30, 30, 29, 29, 28, 28, 27, 27, 27, 26, 26, 26, 26, 25, 12, 25,
    25, 24, 24,
};

const max_exponent = [_]i16{
    1024, 647, 512, 442, 397, 365, 342, 324,
    309,  297, 286, 277, 269, 263, 256, 251,
    246,  242, 237, 234, 230, 227, 224, 221,
    218,  216, 214, 211, 209, 207, 205, 203,
    202,  200, 199,
};

const min_exponent = [_]i16{
    -1075, -679, -538, -463, -416, -383, -359, -340,
    -324,  -311, -300, -291, -283, -276, -269, -263,
    -258,  -254, -249, -245, -242, -238, -235, -232,
    -229,  -227, -224, -222, -220, -217, -215, -214,
    -212,  -210, -208,
};

fn asMpb(ptr: *anyopaque) *Mpb {
    return @ptrCast(@alignCast(ptr));
}

fn asConstMpb(ptr: *const anyopaque) *const Mpb {
    return @ptrCast(@alignCast(ptr));
}

fn clz32(a: u32) c_int {
    return @intCast(@clz(a));
}

fn clz64(a: u64) c_int {
    return @intCast(@clz(a));
}

fn ctz32(a: u32) c_int {
    return @intCast(@ctz(a));
}

fn maxInt(a: c_int, b: c_int) c_int {
    return if (a > b) a else b;
}

fn minInt(a: c_int, b: c_int) c_int {
    return if (a < b) a else b;
}

fn absInt(a: c_int) c_int {
    return if (a < 0) -a else a;
}

fn float64AsUint64(d: f64) u64 {
    return @bitCast(d);
}

fn uint64AsFloat64(a: u64) f64 {
    return @bitCast(a);
}

fn putLit(buf: [*]u8, s: []const u8) usize {
    for (s, 0..) |ch, i| buf[i] = ch;
    return s.len;
}

fn mp_add_ui_impl(tab: [*]limb_t, b: limb_t, n: usize) limb_t {
    var k = b;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        if (k == 0) break;
        const a = tab[i] +% k;
        k = @intFromBool(a < k);
        tab[i] = a;
    }
    return k;
}

fn mp_mul1(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, l0: limb_t) limb_t {
    var l = l0;
    var i: limb_t = 0;
    while (i < n) : (i += 1) {
        const t: dlimb_t = @as(dlimb_t, taba[i]) * @as(dlimb_t, b) + l;
        tabr[i] = @truncate(t);
        l = @truncate(t >> LIMB_BITS);
    }
    return l;
}

fn udiv1norm_init_impl(d: limb_t) limb_t {
    const a1: limb_t = (0 -% d) -% 1;
    const a0: limb_t = std.math.maxInt(limb_t);
    return @truncate(((@as(dlimb_t, a1) << LIMB_BITS) | a0) / d);
}

fn udiv1norm(pr: *limb_t, a1: limb_t, a0: limb_t, d: limb_t, d_inv: limb_t) limb_t {
    const n1m_signed: slimb_t = @bitCast(a0);
    const n1m: limb_t = @bitCast(n1m_signed >> (LIMB_BITS - 1));
    const n_adj = a0 +% (n1m & d);
    var a = @as(dlimb_t, d_inv) * @as(dlimb_t, a1 -% n1m) + @as(dlimb_t, n_adj);
    var q: limb_t = @truncate((a >> LIMB_BITS) + a1);

    a = ((@as(dlimb_t, a1) << LIMB_BITS) | a0) -% (@as(dlimb_t, q) * d) -% d;
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
        const a1 = (@as(dlimb_t, r) << LIMB_BITS) | taba[idx];
        tabr[idx] = @truncate(a1 / b);
        r = @truncate(a1 % b);
    }
    return r;
}

fn mp_shr_impl(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, high: limb_t) limb_t {
    var l = high;
    var i = n - 1;
    while (i >= 0) : (i -= 1) {
        const idx: usize = @intCast(i);
        const a = tab[idx];
        tab_r[idx] = (a >> @intCast(shift)) | (l << @intCast(LIMB_BITS - shift));
        l = a;
    }
    return l & ((@as(limb_t, 1) << @intCast(shift)) - 1);
}

fn mp_shl_impl(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, low: limb_t) limb_t {
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

fn mp_div1norm_impl(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r0: limb_t, b_inv: limb_t, shift: c_int) limb_t {
    var r = r0;
    if (shift != 0) {
        r = (r << @intCast(shift)) | mp_shl_impl(tabr, taba, n, shift, 0);
    }
    var i: isize = @as(isize, @intCast(n)) - 1;
    while (i >= 0) : (i -= 1) {
        const idx: usize = @intCast(i);
        tabr[idx] = udiv1norm(&r, r, taba[idx], b, b_inv);
    }
    r >>= @intCast(shift);
    return r;
}

fn mpb_renorm_impl(r: *Mpb) void {
    while (r.len > 1 and r.tab[@intCast(r.len - 1)] == 0) {
        r.len -= 1;
    }
}

fn pow_ui_impl(a: c_int, b: c_int) u64 {
    const au: u32 = @intCast(a);
    const bu: u32 = @intCast(b);
    if (bu == 0) return 1;
    if (bu == 1) return au;
    if ((au == 5 or au == 10) and bu <= 17) {
        var r: u64 = pow5_table[bu - 1];
        if (bu >= 14) {
            r |= @as(u64, pow5h_table[bu - 14]) << 32;
        }
        if (au == 10) r <<= @intCast(bu);
        return r;
    }
    var r: u64 = au;
    const n_bits = 32 - clz32(bu);
    var i = n_bits - 2;
    while (i >= 0) : (i -= 1) {
        r *%= r;
        if (((bu >> @intCast(i)) & 1) != 0) r *%= au;
    }
    return r;
}

fn pow_ui_inv_impl(pr_inv: *u32, pshift: *c_int, a: c_int, b: c_int) limb_t {
    var r_inv: u32 = undefined;
    var r: u32 = undefined;
    var shift: c_int = undefined;
    if (a == 5 and b >= 1 and b <= 13) {
        r = pow5_table[@intCast(b - 1)];
        shift = clz32(r);
        r <<= @intCast(shift);
        r_inv = pow5_inv_table[@intCast(b - 1)];
    } else {
        r = @truncate(pow_ui_impl(a, b));
        shift = clz32(r);
        r <<= @intCast(shift);
        r_inv = udiv1norm_init_impl(r);
    }
    pshift.* = shift;
    pr_inv.* = r_inv;
    return r;
}

fn mpb_get_bit_impl(r: *const Mpb, k0: c_int) c_int {
    var k = k0;
    const l: c_int = @intCast(@divTrunc(@as(c_uint, @bitCast(k)), LIMB_BITS));
    k &= LIMB_BITS - 1;
    if (l >= r.len) return 0;
    return @intCast((r.tab[@intCast(l)] >> @intCast(k)) & 1);
}

fn mpb_shr_round_impl(r: *Mpb, shift0: c_int, rnd_mode: c_int) void {
    var shift = shift0;
    if (shift == 0) return;
    if (shift < 0) {
        shift = -shift;
        const l: c_int = @intCast(@divTrunc(@as(c_uint, @bitCast(shift)), LIMB_BITS));
        shift &= LIMB_BITS - 1;
        if (shift != 0) {
            r.tab[@intCast(r.len)] = mp_shl_impl(&r.tab, &r.tab, r.len, shift, 0);
            r.len += 1;
            mpb_renorm_impl(r);
        }
        if (l > 0) {
            var i = r.len - 1;
            while (i >= 0) : (i -= 1) {
                r.tab[@intCast(i + l)] = r.tab[@intCast(i)];
            }
            var j: c_int = 0;
            while (j < l) : (j += 1) r.tab[@intCast(j)] = 0;
            r.len += l;
        }
    } else {
        var add_one: c_int = 0;
        switch (rnd_mode) {
            @intFromEnum(RndMode.rndn), @intFromEnum(RndMode.rndna) => {
                const bit1 = mpb_get_bit_impl(r, shift - 1);
                if (bit1 != 0) {
                    var bit2: limb_t = 1;
                    if (rnd_mode == @intFromEnum(RndMode.rndn)) {
                        bit2 = 0;
                        if (shift >= 2) {
                            var k = shift - 1;
                            const l: c_int = @intCast(@divTrunc(@as(c_uint, @bitCast(k)), LIMB_BITS));
                            k &= LIMB_BITS - 1;
                            var i: c_int = 0;
                            while (i < minInt(l, r.len)) : (i += 1) bit2 |= r.tab[@intCast(i)];
                            if (l < r.len) {
                                bit2 |= r.tab[@intCast(l)] & ((@as(limb_t, 1) << @intCast(k)) - 1);
                            }
                        }
                    }
                    add_one = if (bit2 != 0) 1 else mpb_get_bit_impl(r, shift);
                }
            },
            else => add_one = 0,
        }

        const l: c_int = @intCast(@divTrunc(@as(c_uint, @bitCast(shift)), LIMB_BITS));
        shift &= LIMB_BITS - 1;
        if (l >= r.len) {
            r.len = 1;
            r.tab[0] = @intCast(add_one);
        } else {
            if (l > 0) {
                r.len -= l;
                var i: c_int = 0;
                while (i < r.len) : (i += 1) {
                    r.tab[@intCast(i)] = r.tab[@intCast(i + l)];
                }
            }
            if (shift != 0) {
                _ = mp_shr_impl(&r.tab, &r.tab, r.len, shift, 0);
                mpb_renorm_impl(r);
            }
            if (add_one != 0) {
                const a = mp_add_ui_impl(&r.tab, 1, @intCast(r.len));
                if (a != 0) {
                    r.tab[@intCast(r.len)] = a;
                    r.len += 1;
                }
            }
        }
    }
}

fn mpb_cmp_impl(a: *const Mpb, b: *const Mpb) c_int {
    if (a.len < b.len) return -1;
    if (a.len > b.len) return 1;
    var i = a.len - 1;
    while (i >= 0) : (i -= 1) {
        const idx: usize = @intCast(i);
        if (a.tab[idx] != b.tab[idx]) return if (a.tab[idx] < b.tab[idx]) -1 else 1;
    }
    return 0;
}

fn mpb_set_u64_impl(r: *Mpb, m: u64) void {
    r.tab[0] = @truncate(m);
    r.tab[1] = @truncate(m >> LIMB_BITS);
    r.len = if (r.tab[1] == 0) 1 else 2;
}

fn mpb_get_u64_impl(r: *const Mpb) u64 {
    if (r.len == 1) return r.tab[0];
    return @as(u64, r.tab[0]) | (@as(u64, r.tab[1]) << LIMB_BITS);
}

fn mpb_floor_log2_impl(a: *const Mpb) c_int {
    const v = a.tab[@intCast(a.len - 1)];
    if (v == 0) return -1;
    return a.len * LIMB_BITS - 1 - clz32(v);
}

fn mul_log2_radix_impl(a: c_int, radix: c_int) c_int {
    if ((radix & (radix - 1)) == 0) {
        const radix_bits = 31 - clz32(@intCast(radix));
        var a1 = a;
        if (a1 < 0) a1 -= radix_bits - 1;
        return @divTrunc(a1, radix_bits);
    }
    const mult = mul_log2_radix_table[@intCast(radix - 2)];
    return @intCast((@as(i64, a) * @as(i64, mult)) >> MUL_LOG2_RADIX_BASE_LOG2);
}

fn u32toa_len(buf: [*]u8, n0: u32, len: usize) void {
    var n = n0;
    var i: isize = @as(isize, @intCast(len)) - 1;
    while (i >= 0) : (i -= 1) {
        const digit = n % 10;
        n /= 10;
        buf[@intCast(i)] = @intCast(digit + '0');
    }
}

fn u64toa_bin_len(buf: [*]u8, n0: u64, radix_bits: c_int, len: c_int) void {
    var n = n0;
    const mask = (@as(u64, 1) << @intCast(radix_bits)) - 1;
    var i = len - 1;
    while (i >= 0) : (i -= 1) {
        var digit: u8 = @intCast(n & mask);
        n >>= @intCast(radix_bits);
        digit += if (digit < 10) '0' else 'a' - 10;
        buf[@intCast(i)] = digit;
    }
}

fn limb_to_a_impl(buf: [*]u8, a0: limb_t, radix: c_int, len: c_int) void {
    var a = a0;
    if (radix == 10) {
        u32toa_len(buf, a, @intCast(len));
        return;
    }
    var i = len - 1;
    while (i >= 0) : (i -= 1) {
        var digit: u8 = @intCast(a % @as(limb_t, @intCast(radix)));
        a /= @intCast(radix);
        digit += if (digit < 10) '0' else 'a' - 10;
        buf[@intCast(i)] = digit;
    }
}

pub export fn u32toa(buf: [*]u8, n0: u32) callconv(.c) usize {
    var n = n0;
    var tmp: [10]u8 = undefined;
    var q: usize = tmp.len;
    while (true) {
        q -= 1;
        tmp[q] = @intCast((n % 10) + '0');
        n /= 10;
        if (n == 0) break;
    }
    const len = tmp.len - q;
    for (tmp[q..], 0..) |ch, i| buf[i] = ch;
    return len;
}

pub export fn i32toa(buf: [*]u8, n: i32) callconv(.c) usize {
    if (n >= 0) return u32toa(buf, @intCast(n));
    buf[0] = '-';
    return u32toa(buf + 1, 0 -% @as(u32, @bitCast(n))) + 1;
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
            buf[q] = @intCast(n2 / 10 + '0');
            q += 1;
            n2 %= 10;
        }
        buf[q] = @intCast(n2 + '0');
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
    return u64toa(buf + 1, 0 -% @as(u64, @bitCast(n))) + 1;
}

pub export fn u64toa_radix(buf: [*]u8, n0: u64, radix0: c_uint) callconv(.c) usize {
    var n = n0;
    const radix: u32 = @intCast(radix0);
    if (radix == 10) return u64toa(buf, n);
    if ((radix & (radix - 1)) == 0) {
        const radix_bits = 31 - clz32(radix);
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
    for (tmp[q..], 0..) |ch, i| buf[i] = ch;
    return len;
}

pub export fn i64toa_radix(buf: [*]u8, n: i64, radix: c_uint) callconv(.c) usize {
    if (n >= 0) return u64toa_radix(buf, @intCast(n), radix);
    buf[0] = '-';
    return u64toa_radix(buf + 1, 0 -% @as(u64, @bitCast(n)), radix) + 1;
}

fn output_digits_impl(buf: [*]u8, a: *Mpb, radix: c_int, n_digits1: c_int, dot_pos: c_int) c_int {
    var n_digits = n_digits1;
    const radix_bits = if ((radix & (radix - 1)) == 0) 31 - clz32(@intCast(radix)) else 0;
    const digits_per_limb: c_int = digits_per_limb_table[@intCast(radix - 2)];
    if (radix_bits != 0) {
        while (true) {
            const n = minInt(n_digits, digits_per_limb);
            n_digits -= n;
            u64toa_bin_len(buf + @as(usize, @intCast(n_digits)), a.tab[0], radix_bits, n);
            if (n_digits == 0) break;
            mpb_shr_round_impl(a, digits_per_limb * radix_bits, @intFromEnum(RndMode.rndz));
        }
    } else {
        while (n_digits != 0) {
            const n = minInt(n_digits, digits_per_limb);
            n_digits -= n;
            const r = mp_div1(&a.tab, &a.tab, @intCast(a.len), radix_base_table[@intCast(radix - 2)], 0);
            mpb_renorm_impl(a);
            limb_to_a_impl(buf + @as(usize, @intCast(n_digits)), r, radix, n);
        }
    }

    var len = n_digits1;
    if (dot_pos != n_digits1) {
        var i = n_digits1 - dot_pos - 1;
        while (i >= 0) : (i -= 1) {
            buf[@intCast(dot_pos + 1 + i)] = buf[@intCast(dot_pos + i)];
        }
        buf[@intCast(dot_pos)] = '.';
        len += 1;
    }
    return len;
}

fn mul_pow(a: *Mpb, radix1: c_int, radix_shift: c_int, f0: c_int, is_int: bool, e: c_int) c_int {
    var f = f0;
    var e_offset = -f * radix_shift;
    if (radix1 != 1) {
        const d: c_int = digits_per_limb_table[@intCast(radix1 - 2)];
        if (f >= 0) {
            var b: limb_t = 0;
            var n0: c_int = 0;
            while (f != 0) {
                const n = minInt(f, d);
                if (n != n0) {
                    b = @truncate(pow_ui_impl(radix1, n));
                    n0 = n;
                }
                const h = mp_mul1(&a.tab, &a.tab, @intCast(a.len), b, 0);
                if (h != 0) {
                    a.tab[@intCast(a.len)] = h;
                    a.len += 1;
                }
                f -= n;
            }
        } else {
            f = -f;
            const l = @divTrunc(f + d - 1, d);
            e_offset += l * LIMB_BITS;
            const extra_bits = if (!is_int)
                maxInt(e - mpb_floor_log2_impl(a), 0)
            else
                maxInt(2 + e - e_offset, 0);
            e_offset += extra_bits;
            mpb_shr_round_impl(a, -(l * LIMB_BITS + extra_bits), @intFromEnum(RndMode.rndz));

            var b: limb_t = 0;
            var b_inv: limb_t = 0;
            var shift: c_int = 0;
            var n0: c_int = 0;
            var rem: limb_t = 0;
            while (f != 0) {
                const n = minInt(f, d);
                if (n != n0) {
                    b = pow_ui_inv_impl(&b_inv, &shift, radix1, n);
                    n0 = n;
                }
                const r = mp_div1norm_impl(&a.tab, &a.tab, @intCast(a.len), b, 0, b_inv, shift);
                rem |= r;
                mpb_renorm_impl(a);
                f -= n;
            }
            a.tab[0] |= @intFromBool(rem != 0);
        }
    }
    return e_offset;
}

fn mul_pow_round(tmp1: *Mpb, m: u64, e: c_int, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) void {
    mpb_set_u64_impl(tmp1, m);
    const e_offset = mul_pow(tmp1, radix1, radix_shift, f, true, e);
    mpb_shr_round_impl(tmp1, -e + e_offset, rnd_mode);
}

fn round_to_d_impl(pe: *c_int, a: *Mpb, e_offset: c_int, rnd_mode: c_int) u64 {
    var e: c_int = 0;
    var m: u64 = 0;
    if (!(a.tab[0] == 0 and a.len == 1)) {
        const prec1: c_int = 53;
        const e_min: c_int = -1021;
        e = mpb_floor_log2_impl(a) + 1 - e_offset;
        const prec = if (e < e_min) prec1 - (e_min - e) else prec1;
        mpb_shr_round_impl(a, e + e_offset - prec, rnd_mode);
        m = mpb_get_u64_impl(a);
        const left_shift = 53 - prec;
        if (left_shift >= 64) {
            m = 0;
        } else if (left_shift > 0) {
            m <<= @intCast(left_shift);
        }
        if (m >= (@as(u64, 1) << 53)) {
            m >>= 1;
            e += 1;
        }
    }
    pe.* = e;
    return m;
}

fn mul_pow_round_to_d_impl(pe: *c_int, a: *Mpb, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) u64 {
    const e_offset = mul_pow(a, radix1, radix_shift, f, false, 55);
    return round_to_d_impl(pe, a, e_offset, rnd_mode);
}

pub export fn js_dtoa_max_len(d: f64, radix: c_int, n_digits: c_int, flags: c_int) callconv(.c) c_int {
    const fmt = flags & JS_DTOA_FORMAT_MASK;
    var n: c_int = undefined;
    if (fmt != JS_DTOA_FORMAT_FRAC) {
        n = if (fmt == JS_DTOA_FORMAT_FREE) dtoa_max_digits_table[@intCast(radix - 2)] else n_digits;
        if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_DISABLED) {
            const a = float64AsUint64(d);
            var e: c_int = @intCast((a >> 52) & 0x7ff);
            if (e == 0x7ff) {
                n = 0;
            } else {
                e -= 1023;
                n += 10 + absInt(mul_log2_radix_impl(e - 1, radix));
            }
        } else {
            n += 1 + 1 + 6;
        }
    } else {
        const a = float64AsUint64(d);
        var e: c_int = @intCast((a >> 52) & 0x7ff);
        if (e == 0x7ff) {
            n = 0;
        } else {
            e -= 1023;
            n = if (e < 0) 1 else 2 + mul_log2_radix_impl(e - 1, radix);
            n += 1 + 1 + 1 + n_digits;
        }
    }
    return maxInt(n, 9);
}

pub export fn js_dtoa(buf: [*]u8, d: f64, radix: c_int, n_digits: c_int, flags: c_int, tmp_mem: *JSDTOATempMem) callconv(.c) c_int {
    _ = tmp_mem;
    var tmp1: Mpb = undefined;
    var mant_max: Mpb = undefined;
    const fmt = flags & JS_DTOA_FORMAT_MASK;
    const radix_shift = ctz32(@intCast(radix));
    const radix1 = radix >> @intCast(radix_shift);
    const a = float64AsUint64(d);
    const sgn: c_int = @intCast(a >> 63);
    var e: c_int = @intCast((a >> 52) & 0x7ff);
    var m = a & ((@as(u64, 1) << 52) - 1);
    var q: usize = 0;
    var E: c_int = undefined;
    var P: c_int = undefined;

    if (e == 0x7ff) {
        if (m == 0) {
            if (sgn != 0) {
                buf[q] = '-';
                q += 1;
            }
            q += putLit(buf + q, "Infinity");
        } else {
            q += putLit(buf + q, "NaN");
        }
        buf[q] = 0;
        return @intCast(q);
    } else if (e == 0) {
        if (m == 0) {
            tmp1.len = 1;
            tmp1.tab[0] = 0;
            E = 1;
            P = if (fmt == JS_DTOA_FORMAT_FREE) 1 else if (fmt == JS_DTOA_FORMAT_FRAC) n_digits + 1 else n_digits;
            if (sgn != 0 and (flags & JS_DTOA_MINUS_ZERO) != 0) {
                buf[q] = '-';
                q += 1;
            }
            return js_dtoa_output(buf, q, &tmp1, radix, n_digits, flags, fmt, E, P);
        }
        const l = clz64(m) - 11;
        e -= l - 1;
        m <<= @intCast(l);
    } else {
        m |= @as(u64, 1) << 52;
    }

    if (sgn != 0) {
        buf[q] = '-';
        q += 1;
    }
    e -= 1022;

    if (fmt == JS_DTOA_FORMAT_FREE and
        e >= 1 and e <= 53 and
        (m & (((@as(u64, 1) << @intCast(53 - e)) - 1))) == 0 and
        (flags & JS_DTOA_EXP_MASK) != JS_DTOA_EXP_ENABLED)
    {
        m >>= @intCast(53 - e);
        q += u64toa_radix(buf + q, m, @intCast(radix));
        buf[q] = 0;
        return @intCast(q);
    }

    E = 1 + mul_log2_radix_impl(e - 1, radix);
    if (fmt == JS_DTOA_FORMAT_FREE) {
        const P_max: c_int = dtoa_max_digits_table[@intCast(radix - 2)];
        const E0 = E;
        var E_found: c_int = 0;
        var P_found: c_int = 0;
        var mant_found: u64 = 0;
        P = P_max;
        while (true) {
            const mant_max1 = pow_ui_impl(radix, P);
            E = E0;
            var mant: u64 = undefined;
            while (true) {
                mul_pow_round(&tmp1, m, e - 53, radix1, radix_shift, P - E, @intFromEnum(RndMode.rndn));
                mant = mpb_get_u64_impl(&tmp1);
                if (mant < mant_max1) break;
                E += 1;
            }
            while ((mant % @as(u64, @intCast(radix))) == 0) {
                mant /= @intCast(radix);
                P -= 1;
            }
            var ok = false;
            if (P_found == 0) {
                ok = true;
            } else {
                mpb_set_u64_impl(&tmp1, mant);
                var e1: c_int = 0;
                const m1 = mul_pow_round_to_d_impl(&e1, &tmp1, radix1, radix_shift, E - P, @intFromEnum(RndMode.rndn));
                ok = (m1 == m and e1 == e);
            }
            if (ok) {
                P_found = P;
                E_found = E;
                mant_found = mant;
                if (P == 1) break;
                P -= 1;
            } else {
                break;
            }
        }
        P = P_found;
        E = E_found;
        mpb_set_u64_impl(&tmp1, mant_found);
    } else if (fmt == JS_DTOA_FORMAT_FRAC) {
        mul_pow_round(&tmp1, m, e - 53, radix1, radix_shift, n_digits, @intFromEnum(RndMode.rndna));
        var len = output_digits_impl(buf + q, &tmp1, radix, maxInt(E + 1, 1) + n_digits, maxInt(E + 1, 1));
        if (buf[q] == '0' and len >= 2 and buf[q + 1] != '.') {
            var i: c_int = 0;
            while (i < len - 1) : (i += 1) {
                buf[q + @as(usize, @intCast(i))] = buf[q + @as(usize, @intCast(i + 1))];
            }
            len -= 1;
        }
        q += @intCast(len);
        buf[q] = 0;
        return @intCast(q);
    } else {
        P = n_digits;
        mant_max.len = 1;
        mant_max.tab[0] = 1;
        const pow_shift = mul_pow(&mant_max, radix1, radix_shift, P, false, 0);
        mpb_shr_round_impl(&mant_max, pow_shift, @intFromEnum(RndMode.rndz));

        while (true) {
            mul_pow_round(&tmp1, m, e - 53, radix1, radix_shift, P - E, @intFromEnum(RndMode.rndna));
            if (mpb_cmp_impl(&tmp1, &mant_max) < 0) break;
            E += 1;
        }
    }

    return js_dtoa_output(buf, q, &tmp1, radix, n_digits, flags, fmt, E, P);
}

fn js_dtoa_output(buf: [*]u8, q0: usize, tmp1: *Mpb, radix: c_int, n_digits: c_int, flags: c_int, fmt: c_int, E0: c_int, P: c_int) c_int {
    var q = q0;
    var E = E0;
    const E_max: c_int = if (fmt == JS_DTOA_FORMAT_FIXED) n_digits else dtoa_max_digits_table[@intCast(radix - 2)] + 4;
    const radix_shift = ctz32(@intCast(radix));
    const radix1 = radix >> @intCast(radix_shift);
    if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_ENABLED or
        ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_AUTO and (E <= -6 or E > E_max)))
    {
        q += @intCast(output_digits_impl(buf + q, tmp1, radix, P, 1));
        E -= 1;
        if (radix == 10) {
            buf[q] = 'e';
            q += 1;
        } else if (radix1 == 1 and radix_shift <= 4) {
            E *= radix_shift;
            buf[q] = 'p';
            q += 1;
        } else {
            buf[q] = '@';
            q += 1;
        }
        if (E < 0) {
            buf[q] = '-';
            q += 1;
            E = -E;
        } else {
            buf[q] = '+';
            q += 1;
        }
        q += u32toa(buf + q, @intCast(E));
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
        q += @intCast(output_digits_impl(buf + q, tmp1, radix, P, P));
    } else {
        q += @intCast(output_digits_impl(buf + q, tmp1, radix, P, minInt(P, E)));
        var i: c_int = 0;
        while (i < E - P) : (i += 1) {
            buf[q] = '0';
            q += 1;
        }
    }
    buf[q] = 0;
    return @intCast(q);
}

fn to_digit(c: u8) c_int {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'A' and c <= 'Z') return c - 'A' + 10;
    if (c >= 'a' and c <= 'z') return c - 'a' + 10;
    return 36;
}

fn startsWithAt(str: [*]const u8, pos: usize, lit: []const u8) bool {
    for (lit, 0..) |ch, i| {
        if (str[pos + i] != ch) return false;
    }
    return true;
}

fn mpb_mul1_base_impl(r: *Mpb, radix_base: limb_t, a: limb_t) void {
    if (r.tab[0] == 0 and r.len == 1) {
        r.tab[0] = a;
    } else {
        if (radix_base == 0) {
            var i = r.len;
            while (i >= 0) : (i -= 1) {
                r.tab[@intCast(i + 1)] = r.tab[@intCast(i)];
            }
            r.tab[0] = a;
        } else {
            r.tab[@intCast(r.len)] = mp_mul1(&r.tab, &r.tab, @intCast(r.len), radix_base, a);
        }
        r.len += 1;
        mpb_renorm_impl(r);
    }
}

pub export fn js_atod(str: [*]const u8, pnext: [*c][*c]const u8, radix0: c_int, flags: c_int, tmp_mem: *JSATODTempMem) callconv(.c) f64 {
    _ = tmp_mem;
    var radix = radix0;
    var tmp0: Mpb = undefined;
    const sep: c_int = if ((flags & JS_ATOD_ACCEPT_UNDERSCORES) != 0) '_' else 256;
    var p: usize = 0;
    var p_start: usize = 0;
    var is_neg: c_int = 0;

    if (str[p] == '+') {
        p += 1;
        p_start = p;
    } else if (str[p] == '-') {
        is_neg = 1;
        p += 1;
        p_start = p;
    }

    if (str[p] == '0') {
        if ((str[p + 1] == 'x' or str[p + 1] == 'X') and (radix == 0 or radix == 16)) {
            p += 2;
            radix = 16;
        } else if ((str[p + 1] == 'o' or str[p + 1] == 'O') and radix == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
            p += 2;
            radix = 8;
        } else if ((str[p + 1] == 'b' or str[p + 1] == 'B') and radix == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
            p += 2;
            radix = 2;
        } else if ((str[p + 1] >= '0' and str[p + 1] <= '9') and radix == 0 and (flags & JS_ATOD_ACCEPT_LEGACY_OCTAL) != 0) {
            var i: usize = 1;
            while (str[p + i] >= '0' and str[p + i] <= '7') : (i += 1) {}
            if (!(str[p + i] == '8' or str[p + i] == '9')) {
                p += 1;
                radix = 8;
            }
        }
        if (radix != 0 and (radix == 16 or radix == 8 or radix == 2) and p >= 2 and to_digit(str[p]) >= radix) {
            return atodFail(str, p, pnext);
        }
    } else if ((flags & JS_ATOD_INT_ONLY) == 0 and startsWithAt(str, p, "Infinity")) {
        p += "Infinity".len;
        return atodDone(str, p, pnext, (@as(u64, 0x7ff) << 52) | (@as(u64, @intCast(is_neg)) << 63));
    }
    if (radix == 0) radix = 10;

    var cur_limb: limb_t = 0;
    var expn_offset: c_int = 0;
    var digit_count: c_int = 0;
    var limb_digit_count: c_int = 0;
    const max_digits: c_int = atod_max_digits_table[@intCast(radix - 2)];
    const digits_per_limb: c_int = digits_per_limb_table[@intCast(radix - 2)];
    const radix_base = radix_base_table[@intCast(radix - 2)];
    const radix_shift = ctz32(@intCast(radix));
    const radix1 = radix >> @intCast(radix_shift);
    const radix_bits: c_int = if (radix1 == 1) radix_shift else 0;

    tmp0.len = 1;
    tmp0.tab[0] = 0;
    var extra_digits: limb_t = 0;
    var pos: c_int = 0;
    var dot_pos: c_int = -1;

    while (true) {
        if (str[p] == '.' and (p > p_start or to_digit(str[p + 1]) < radix) and (flags & JS_ATOD_INT_ONLY) == 0) {
            if (dot_pos >= 0) break;
            dot_pos = pos;
            p += 1;
        }
        if (@as(c_int, str[p]) == sep and p > p_start and str[p + 1] == '0') p += 1;
        if (str[p] != '0') break;
        p += 1;
        pos += 1;
    }

    const sig_pos = pos;
    while (true) {
        if (str[p] == '.' and (p > p_start or to_digit(str[p + 1]) < radix) and (flags & JS_ATOD_INT_ONLY) == 0) {
            if (dot_pos >= 0) break;
            dot_pos = pos;
            p += 1;
        }
        if (@as(c_int, str[p]) == sep and p > p_start and to_digit(str[p + 1]) < radix) p += 1;
        const c = to_digit(str[p]);
        if (c >= radix) break;
        p += 1;
        pos += 1;
        if (digit_count < max_digits) {
            cur_limb = cur_limb * @as(limb_t, @intCast(radix)) + @as(limb_t, @intCast(c));
            limb_digit_count += 1;
            if (limb_digit_count == digits_per_limb) {
                mpb_mul1_base_impl(&tmp0, radix_base, cur_limb);
                cur_limb = 0;
                limb_digit_count = 0;
            }
            digit_count += 1;
        } else {
            extra_digits |= @intCast(c);
        }
    }
    if (limb_digit_count != 0) {
        mpb_mul1_base_impl(&tmp0, @truncate(pow_ui_impl(radix, limb_digit_count)), cur_limb);
    }

    const is_zero = digit_count == 0;
    if (!is_zero) {
        if (dot_pos < 0) dot_pos = pos;
        expn_offset = sig_pos + digit_count - dot_pos;
    }
    if (radix_bits != 0 and extra_digits != 0) tmp0.tab[0] |= 1;

    var expn: c_int = 0;
    var expn_overflow = false;
    var is_bin_exp = false;
    if ((flags & JS_ATOD_INT_ONLY) == 0 and
        ((radix == 10 and (str[p] == 'e' or str[p] == 'E')) or
            (radix != 10 and (str[p] == '@' or (radix_bits >= 1 and radix_bits <= 4 and (str[p] == 'p' or str[p] == 'P'))))) and
        p > p_start)
    {
        is_bin_exp = (str[p] == 'p' or str[p] == 'P');
        p += 1;
        var exp_is_neg = false;
        if (str[p] == '+') {
            p += 1;
        } else if (str[p] == '-') {
            exp_is_neg = true;
            p += 1;
        }
        var c = to_digit(str[p]);
        if (c >= 10) return atodFail(str, p, pnext);
        expn = c;
        p += 1;
        while (true) {
            if (@as(c_int, str[p]) == sep and to_digit(str[p + 1]) < 10) p += 1;
            c = to_digit(str[p]);
            if (c >= 10) break;
            if (!expn_overflow) {
                if (expn > @divTrunc(std.math.maxInt(c_int) - 2 - 9, 10)) {
                    expn_overflow = true;
                } else {
                    expn = expn * 10 + c;
                }
            }
            p += 1;
        }
        if (exp_is_neg) expn = -expn;
        if (!is_zero and expn_overflow) {
            const a: u64 = if (exp_is_neg) 0 else @as(u64, 0x7ff) << 52;
            return atodDone(str, p, pnext, a | (@as(u64, @intCast(is_neg)) << 63));
        }
    }

    if (p == p_start) return atodFail(str, p, pnext);

    var a: u64 = 0;
    if (!is_zero) {
        var e: c_int = 0;
        var m: u64 = 0;
        if (radix_bits != 0) {
            if (!is_bin_exp) expn *= radix_bits;
            expn -= expn_offset * radix_bits;
            const expn1 = expn + digit_count * radix_bits;
            if (expn1 >= 1024 + radix_bits) {
                a = @as(u64, 0x7ff) << 52;
                return atodDone(str, p, pnext, a | (@as(u64, @intCast(is_neg)) << 63));
            } else if (expn1 <= -1075) {
                a = 0;
                return atodDone(str, p, pnext, a | (@as(u64, @intCast(is_neg)) << 63));
            }
            m = round_to_d_impl(&e, &tmp0, -expn, @intFromEnum(RndMode.rndn));
        } else {
            expn -= expn_offset;
            const expn1 = expn + digit_count;
            if (expn1 >= max_exponent[@intCast(radix - 2)] + 1) {
                a = @as(u64, 0x7ff) << 52;
                return atodDone(str, p, pnext, a | (@as(u64, @intCast(is_neg)) << 63));
            } else if (expn1 <= min_exponent[@intCast(radix - 2)]) {
                a = 0;
                return atodDone(str, p, pnext, a | (@as(u64, @intCast(is_neg)) << 63));
            }
            m = mul_pow_round_to_d_impl(&e, &tmp0, radix1, radix_shift, expn, @intFromEnum(RndMode.rndn));
        }
        if (m == 0) {
            a = 0;
        } else if (e > 1024) {
            a = @as(u64, 0x7ff) << 52;
        } else if (e < -1073) {
            a = 0;
        } else if (e < -1021) {
            a = m >> @intCast(-e - 1021);
        } else {
            a = (@as(u64, @intCast(e + 1022)) << 52) | (m & ((@as(u64, 1) << 52) - 1));
        }
    }
    return atodDone(str, p, pnext, a | (@as(u64, @intCast(is_neg)) << 63));
}

fn atodDone(str: [*]const u8, p: usize, pnext: [*c][*c]const u8, a: u64) f64 {
    if (pnext) |pp| pp.* = str + p;
    return uint64AsFloat64(a);
}

fn atodFail(str: [*]const u8, p: usize, pnext: [*c][*c]const u8) f64 {
    if (pnext) |pp| pp.* = str + p;
    return std.math.nan(f64);
}

export fn mp_add_ui(tab: [*]limb_t, b: limb_t, n: usize) callconv(.c) limb_t {
    return mp_add_ui_impl(tab, b, n);
}

export fn mp_shr(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, high: limb_t) callconv(.c) limb_t {
    return mp_shr_impl(tab_r, tab, n, shift, high);
}

export fn mp_shl(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, low: limb_t) callconv(.c) limb_t {
    return mp_shl_impl(tab_r, tab, n, shift, low);
}

export fn mpb_set_u64(r: *anyopaque, m: u64) callconv(.c) void {
    mpb_set_u64_impl(asMpb(r), m);
}

export fn mpb_get_u64(r: *anyopaque) callconv(.c) u64 {
    return mpb_get_u64_impl(asMpb(r));
}

export fn mpb_floor_log2(a: *anyopaque) callconv(.c) c_int {
    return mpb_floor_log2_impl(asMpb(a));
}

export fn mul_log2_radix(a: c_int, radix: c_int) callconv(.c) c_int {
    return mul_log2_radix_impl(a, radix);
}

export fn pow_ui(radix: c_int, n: c_int) callconv(.c) u64 {
    return pow_ui_impl(radix, n);
}

export fn pow_ui_inv(pr_inv: *u32, pshift: *c_int, radix: c_int, n: c_int) callconv(.c) void {
    _ = pow_ui_inv_impl(pr_inv, pshift, radix, n);
}

export fn mpb_shr_round(r: *anyopaque, shift: c_int, rnd_mode: c_int) callconv(.c) void {
    mpb_shr_round_impl(asMpb(r), shift, rnd_mode);
}

export fn mpb_cmp(a: *const anyopaque, b: *const anyopaque) callconv(.c) c_int {
    return mpb_cmp_impl(asConstMpb(a), asConstMpb(b));
}

export fn mpb_renorm(r: *anyopaque) callconv(.c) void {
    mpb_renorm_impl(asMpb(r));
}

export fn mpb_mul1_base(r: *anyopaque, radix_base: limb_t, b: limb_t) callconv(.c) void {
    mpb_mul1_base_impl(asMpb(r), radix_base, b);
}

export fn limb_to_a(buf: [*]u8, a: limb_t, radix: c_int, len: c_int) callconv(.c) void {
    limb_to_a_impl(buf, a, radix, len);
}

export fn output_digits(buf: [*]u8, a: *const anyopaque, radix: c_int, n_digits: c_int, dot_pos: c_int) callconv(.c) c_int {
    return output_digits_impl(buf, @constCast(asConstMpb(a)), radix, n_digits, dot_pos);
}

export fn round_to_d(pe: *c_int, a: *anyopaque, e_offset: c_int, rnd_mode: c_int) callconv(.c) u64 {
    return round_to_d_impl(pe, asMpb(a), e_offset, rnd_mode);
}

export fn mul_pow_round_to_d(pe: *c_int, a: *anyopaque, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) callconv(.c) u64 {
    return mul_pow_round_to_d_impl(pe, asMpb(a), radix1, radix_shift, f, rnd_mode);
}

export fn udiv1norm_init(d: limb_t) callconv(.c) limb_t {
    return udiv1norm_init_impl(d);
}

export fn mp_div1norm(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r: limb_t, b_inv: limb_t, shift: c_int) callconv(.c) limb_t {
    return mp_div1norm_impl(tabr, taba, n, b, r, b_inv, shift);
}

export fn mpb_dump(str: [*]const u8, a: *const anyopaque) callconv(.c) void {
    _ = str;
    _ = a;
}

export fn mpb_get_bit(r: *const anyopaque, pos: c_int) callconv(.c) c_int {
    return mpb_get_bit_impl(asConstMpb(r), pos);
}
