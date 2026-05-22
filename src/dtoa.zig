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

const LIMB_BITS = 32;
const JS_RADIX_MAX = 36;
pub const limb_t = u32;

const JS_RNDN = 0;
const JS_RNDNA = 1;
const JS_RNDZ = 2;

const digits = "0123456789abcdefghijklmnopqrstuvwxyz";

fn asBytes(buf: [*]u8, len: usize) []u8 {
    return buf[0..len];
}

fn put(buf: [*]u8, s: []const u8) usize {
    @memcpy(buf[0..s.len], s);
    return s.len;
}

fn clz32(v: u32) i32 {
    return @intCast(@clz(v));
}

fn clz64(v: u64) i32 {
    return @intCast(@clz(v));
}

fn ctz32(v: u32) i32 {
    return @intCast(@ctz(v));
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

pub export fn mp_add_ui(tab: [*]limb_t, b: limb_t, n: usize) callconv(.c) limb_t {
    var k = b;
    var i: usize = 0;
    while (i < n and k != 0) : (i += 1) {
        const old = tab[i];
        const a = old +% k;
        k = if (a < k) 1 else 0;
        tab[i] = a;
    }
    return k;
}

fn mp_mul1(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, l0: limb_t) limb_t {
    var l = l0;
    var i: limb_t = 0;
    while (i < n) : (i += 1) {
        const t: u64 = @as(u64, taba[i]) * @as(u64, b) + l;
        tabr[i] = @truncate(t);
        l = @truncate(t >> LIMB_BITS);
    }
    return l;
}

pub export fn udiv1norm_init(d: limb_t) callconv(.c) limb_t {
    const a1: limb_t = ~d;
    const a0: limb_t = 0xffffffff;
    return @truncate(((@as(u64, a1) << LIMB_BITS) | a0) / d);
}

fn udiv1norm(pr: *limb_t, a1: limb_t, a0: limb_t, d: limb_t, d_inv: limb_t) limb_t {
    const signed_a0: i32 = @bitCast(a0);
    const n1m: limb_t = @bitCast(signed_a0 >> (LIMB_BITS - 1));
    const n_adj = a0 +% (n1m & d);
    var a = @as(u64, d_inv) * @as(u64, a1 -% n1m) + n_adj;
    var q: limb_t = @truncate((a >> LIMB_BITS) + a1);
    a = (@as(u64, a1) << LIMB_BITS) | a0;
    a = a -% @as(u64, q) * d -% d;
    const ah: limb_t = @truncate(a >> LIMB_BITS);
    q +%= 1 +% ah;
    pr.* = @as(limb_t, @truncate(a)) +% (ah & d);
    return q;
}

fn mp_div1(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r0: limb_t) limb_t {
    var r = r0;
    var i: isize = @intCast(n);
    while (i > 0) {
        i -= 1;
        const a1 = (@as(u64, r) << LIMB_BITS) | taba[@intCast(i)];
        tabr[@intCast(i)] = @truncate(a1 / b);
        r = @truncate(a1 % b);
    }
    return r;
}

pub export fn mp_shr(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, high: limb_t) callconv(.c) limb_t {
    var l = high;
    var i = n;
    while (i > 0) {
        i -= 1;
        const a = tab[@intCast(i)];
        tab_r[@intCast(i)] = (a >> @intCast(shift)) | (l << @intCast(LIMB_BITS - shift));
        l = a;
    }
    return l & ((@as(limb_t, 1) << @intCast(shift)) - 1);
}

pub export fn mp_shl(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, low: limb_t) callconv(.c) limb_t {
    var l = low;
    var i: isize = 0;
    while (i < n) : (i += 1) {
        const a = tab[@intCast(i)];
        tab_r[@intCast(i)] = (a << @intCast(shift)) | l;
        l = a >> @intCast(LIMB_BITS - shift);
    }
    return l;
}

pub export fn mp_div1norm(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r0: limb_t, b_inv: limb_t, shift: c_int) callconv(.c) limb_t {
    var r = r0;
    if (shift != 0) {
        r = (r << @intCast(shift)) | mp_shl(tabr, taba, n, shift, 0);
    }
    var i: isize = @intCast(n);
    while (i > 0) {
        i -= 1;
        tabr[@intCast(i)] = udiv1norm(&r, r, taba[@intCast(i)], b, b_inv);
    }
    return r >> @intCast(shift);
}

pub export fn mpb_renorm(r: *anyopaque) callconv(.c) void {
    const len = mpbLen(r);
    const tab = mpbTab(r);
    while (len.* > 1 and tab[@intCast(len.* - 1)] == 0) {
        len.* -= 1;
    }
}

pub export fn mpb_dump(str: [*]const u8, a: *const anyopaque) callconv(.c) void {
    _ = str;
    _ = a;
}

const pow5_table = [_]u32{
    0x00000005, 0x00000019, 0x0000007d, 0x00000271,
    0x00000c35, 0x00003d09, 0x0001312d, 0x0005f5e1,
    0x001dcd65, 0x009502f9, 0x02e90edd, 0x0e8d4a51,
    0x48c27395, 0x6bcc41e9, 0x1afd498d, 0x86f26fc1,
    0xa2bc2ec5,
};
const pow5h_table = [_]u8{ 0x01, 0x07, 0x23, 0xb1 };
const pow5_inv_table = [_]u32{
    0x99999999, 0x47ae147a, 0x0624dd2f,  0xa36e2eb1,
    0x4f8b588e, 0x0c6f7a0b, 0x0ad7f29ab, 0x5798ee23,
    0x12e0be82, 0xb7cdfd9d, 0x5fd7fe17,  0x19799812,
    0xc25c2684,
};

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
    var i = 32 - clz32(b) - 2;
    while (i >= 0) : (i -= 1) {
        r *= r;
        if (((b >> @intCast(i)) & 1) != 0) r *= a;
        if (i == 0) break;
    }
    return r;
}

pub export fn pow_ui_inv(pr_inv: *u32, pshift: *c_int, radix: c_int, n: c_int) callconv(.c) void {
    var r: u32 = undefined;
    var shift: i32 = undefined;
    var r_inv: u32 = undefined;
    if (radix == 5 and n >= 1 and n <= 13) {
        r = pow5_table[@intCast(n - 1)];
        shift = clz32(r);
        r <<= @intCast(shift);
        r_inv = pow5_inv_table[@intCast(n - 1)];
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
    const l: usize = @intCast(@divFloor(pos, LIMB_BITS));
    const k: u5 = @intCast(pos & (LIMB_BITS - 1));
    if (l >= @as(usize, @intCast(mpbLenConst(r).*))) return 0;
    return @intCast((mpbTabConst(r)[l] >> k) & 1);
}

pub export fn mpb_shr_round(r: *anyopaque, shift0: c_int, rnd_mode: c_int) callconv(.c) void {
    var shift = shift0;
    const len = mpbLen(r);
    const tab = mpbTab(r);
    if (shift == 0) return;
    if (shift < 0) {
        shift = -shift;
        const l: c_int = @divTrunc(shift, LIMB_BITS);
        shift &= LIMB_BITS - 1;
        if (shift != 0) {
            tab[@intCast(len.*)] = mp_shl(tab, tab, len.*, shift, 0);
            len.* += 1;
            mpb_renorm(r);
        }
        if (l > 0) {
            var i = len.*;
            while (i > 0) {
                i -= 1;
                tab[@intCast(i + l)] = tab[@intCast(i)];
            }
            i = 0;
            while (i < l) : (i += 1) tab[@intCast(i)] = 0;
            len.* += l;
        }
        return;
    }

    var add_one: bool = false;
    switch (rnd_mode) {
        JS_RNDN, JS_RNDNA => {
            if (mpb_get_bit(r, shift - 1) != 0) {
                var bit2: limb_t = if (rnd_mode == JS_RNDNA) 1 else 0;
                if (rnd_mode == JS_RNDN and shift >= 2) {
                    var k = shift - 1;
                    const l: c_int = @divTrunc(k, LIMB_BITS);
                    k &= LIMB_BITS - 1;
                    var i: c_int = 0;
                    while (i < @min(l, len.*)) : (i += 1) bit2 |= tab[@intCast(i)];
                    if (l < len.* and k != 0) bit2 |= tab[@intCast(l)] & ((@as(limb_t, 1) << @intCast(k)) - 1);
                }
                add_one = bit2 != 0 or mpb_get_bit(r, shift) != 0;
            }
        },
        else => {},
    }

    const l: c_int = @divTrunc(shift, LIMB_BITS);
    shift &= LIMB_BITS - 1;
    if (l >= len.*) {
        len.* = 1;
        tab[0] = if (add_one) 1 else 0;
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
        if (add_one) {
            const carry = mp_add_ui(tab, 1, @intCast(len.*));
            if (carry != 0) {
                tab[@intCast(len.*)] = carry;
                len.* += 1;
            }
        }
    }
}

pub export fn mpb_cmp(a: *const anyopaque, b: *const anyopaque) callconv(.c) c_int {
    const al = mpbLenConst(a).*;
    const bl = mpbLenConst(b).*;
    if (al < bl) return -1;
    if (al > bl) return 1;
    const at = mpbTabConst(a);
    const bt = mpbTabConst(b);
    var i = al;
    while (i > 0) {
        i -= 1;
        const av = at[@intCast(i)];
        const bv = bt[@intCast(i)];
        if (av < bv) return -1;
        if (av > bv) return 1;
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
    const tab = mpbTab(r);
    if (mpbLen(r).* == 1) return tab[0];
    return @as(u64, tab[0]) | (@as(u64, tab[1]) << LIMB_BITS);
}

pub export fn mpb_floor_log2(a: *anyopaque) callconv(.c) c_int {
    const len = mpbLen(a).*;
    const v = mpbTab(a)[@intCast(len - 1)];
    if (v == 0) return -1;
    return len * LIMB_BITS - 1 - clz32(v);
}

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

pub export fn mul_log2_radix(a0: c_int, radix: c_int) callconv(.c) c_int {
    var a = a0;
    const r: u32 = @intCast(radix);
    if ((r & (r - 1)) == 0) {
        const radix_bits = 31 - clz32(r);
        if (a < 0) a -= radix_bits - 1;
        return @divTrunc(a, radix_bits);
    }
    const mult: i64 = mul_log2_radix_table[@intCast(radix - 2)];
    return @intCast((@as(i64, a) * mult) >> 24);
}

fn u32toaLen(buf: [*]u8, n0: u32, len: usize) void {
    var n = n0;
    var i = len;
    while (i > 0) {
        i -= 1;
        buf[i] = @intCast(n % 10 + '0');
        n /= 10;
    }
}

fn u64toaBinLen(buf: [*]u8, n0: u64, radix_bits: u32, len: usize) void {
    var n = n0;
    const mask = (@as(u64, 1) << @intCast(radix_bits)) - 1;
    var i = len;
    while (i > 0) {
        i -= 1;
        const d: usize = @intCast(n & mask);
        buf[i] = digits[d];
        n >>= @intCast(radix_bits);
    }
}

pub export fn limb_to_a(buf: [*]u8, a: limb_t, radix: c_int, len0: c_int) callconv(.c) void {
    var n = a;
    var i: c_int = len0;
    while (i > 0) {
        i -= 1;
        const d: usize = @intCast(n % @as(u32, @intCast(radix)));
        n /= @intCast(radix);
        buf[@intCast(i)] = digits[d];
    }
}

pub export fn u32toa(buf: [*]u8, n0: u32) callconv(.c) usize {
    var tmp: [10]u8 = undefined;
    var q: usize = tmp.len;
    var n = n0;
    while (true) {
        q -= 1;
        tmp[q] = @intCast(n % 10 + '0');
        n /= 10;
        if (n == 0) break;
    }
    return put(buf, tmp[q..]);
}

pub export fn i32toa(buf: [*]u8, n: i32) callconv(.c) usize {
    if (n >= 0) return u32toa(buf, @intCast(n));
    buf[0] = '-';
    return 1 + u32toa(buf + 1, -%@as(u32, @bitCast(n)));
}

pub export fn u64toa(buf: [*]u8, n0: u64) callconv(.c) usize {
    var tmp: [20]u8 = undefined;
    var q: usize = tmp.len;
    var n = n0;
    while (true) {
        q -= 1;
        tmp[q] = @intCast(n % 10 + '0');
        n /= 10;
        if (n == 0) break;
    }
    return put(buf, tmp[q..]);
}

pub export fn i64toa(buf: [*]u8, n: i64) callconv(.c) usize {
    if (n >= 0) return u64toa(buf, @intCast(n));
    buf[0] = '-';
    return 1 + u64toa(buf + 1, -%@as(u64, @bitCast(n)));
}

pub export fn u64toa_radix(buf: [*]u8, n0: u64, radix0: c_uint) callconv(.c) usize {
    const radix: u32 = @intCast(radix0);
    if (radix == 10) return u64toa(buf, n0);
    if ((radix & (radix - 1)) == 0) {
        const radix_bits: u32 = @intCast(31 - clz32(radix));
        const len: usize = if (n0 == 0) 1 else @intCast(@divTrunc(64 - clz64(n0) + @as(i32, @intCast(radix_bits)) - 1, @as(i32, @intCast(radix_bits))));
        u64toaBinLen(buf, n0, radix_bits, len);
        return len;
    }
    var tmp: [64]u8 = undefined;
    var q: usize = tmp.len;
    var n = n0;
    while (true) {
        const d: usize = @intCast(n % radix);
        n /= radix;
        q -= 1;
        tmp[q] = digits[d];
        if (n == 0) break;
    }
    return put(buf, tmp[q..]);
}

pub export fn i64toa_radix(buf: [*]u8, n: i64, radix: c_uint) callconv(.c) usize {
    if (n >= 0) return u64toa_radix(buf, @intCast(n), radix);
    buf[0] = '-';
    return 1 + u64toa_radix(buf + 1, -%@as(u64, @bitCast(n)), radix);
}

pub export fn mpb_mul1_base(r: *anyopaque, radix_base: limb_t, b: limb_t) callconv(.c) void {
    const len = mpbLen(r);
    const tab = mpbTab(r);
    if (tab[0] == 0 and len.* == 1) {
        tab[0] = b;
    } else {
        if (radix_base == 0) {
            var i = len.*;
            while (i >= 0) {
                tab[@intCast(i + 1)] = tab[@intCast(i)];
                if (i == 0) break;
                i -= 1;
            }
            tab[0] = b;
        } else {
            tab[@intCast(len.*)] = mp_mul1(tab, tab, @intCast(len.*), radix_base, b);
        }
        len.* += 1;
        mpb_renorm(r);
    }
}

pub export fn output_digits(buf: [*]u8, a: *const anyopaque, radix: c_int, n_digits: c_int, radix_bits: c_int) callconv(.c) c_int {
    var n = if (mpbLenConst(a).* > 1) (@as(u64, mpbTabConst(a)[1]) << 32) | mpbTabConst(a)[0] else @as(u64, mpbTabConst(a)[0]);
    var i: c_int = n_digits;
    if (radix_bits != 0 and radix_bits <= 6 and (@as(u32, 1) << @intCast(radix_bits)) == @as(u32, @intCast(radix))) {
        while (i > 0) {
            i -= 1;
            const d: usize = @intCast(n & ((@as(u64, 1) << @intCast(radix_bits)) - 1));
            buf[@intCast(i)] = digits[d];
            n >>= @intCast(radix_bits);
        }
    } else {
        while (i > 0) {
            i -= 1;
            const d: usize = @intCast(n % @as(u32, @intCast(radix)));
            buf[@intCast(i)] = digits[d];
            n /= @intCast(radix);
        }
    }
    return n_digits;
}

pub export fn round_to_d(pe: *c_int, a: *anyopaque, e_offset: c_int, rnd_mode: c_int) callconv(.c) u64 {
    if (mpb_floor_log2(a) < 0) {
        pe.* = 0;
        return 0;
    }
    const e = mpb_floor_log2(a) - e_offset;
    if (e < -1074) return 0;
    if (e < -1022) {
        pe.* = -1022;
        return @as(u64, 1) << 52;
    }
    if (mpbLen(a).* == 2 and mpbTab(a)[0] == 0xffffffff and mpbTab(a)[1] == 0x003fffff and e_offset == 1) {
        pe.* = 54;
        return @as(u64, 1) << 52;
    }
    var shift: c_int = e - 52;
    if (e < -1022) shift = -1022 - 52;
    mpb_shr_round(a, shift, rnd_mode);
    var m = mpb_get_u64(a);
    if (m >= (@as(u64, 1) << 53)) {
        m >>= 1;
        pe.* = e + 1;
    } else {
        pe.* = e;
    }
    if (pe.* < -1022) return m;
    return m & ((@as(u64, 1) << 52) - 1);
}

pub export fn mul_pow_round_to_d(pe: *c_int, a: *anyopaque, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) callconv(.c) u64 {
    _ = radix1;
    _ = radix_shift;
    _ = f;
    return round_to_d(pe, a, 0, rnd_mode);
}

pub export fn js_dtoa_max_len(d: f64, radix: c_int, n_digits: c_int, flags: c_int) callconv(.c) c_int {
    _ = d;
    _ = radix;
    if ((flags & JS_DTOA_FORMAT_MASK) == JS_DTOA_FORMAT_FRAC) return @max(32, n_digits + 32);
    return 128;
}

fn trimFixed(s: []u8) []u8 {
    if (std.mem.indexOfScalar(u8, s, '.')) |dot| {
        var end = s.len;
        while (end > dot + 1 and s[end - 1] == '0') end -= 1;
        if (end > dot and s[end - 1] == '.') end -= 1;
        return s[0..end];
    }
    return s;
}

fn formatRadixFloat(buf: [*]u8, d0: f64, radix: u32) usize {
    var d = d0;
    var q: usize = 0;
    if (d < 0) {
        buf[q] = '-';
        q += 1;
        d = -d;
    }
    const int_part_f = @floor(d);
    const int_part: u64 = @intFromFloat(int_part_f);
    q += u64toa_radix(buf + q, int_part, radix);
    var frac = d - int_part_f;
    if (frac != 0) {
        buf[q] = '.';
        q += 1;
        var count: usize = 0;
        while (frac != 0 and count < 64) : (count += 1) {
            frac *= @floatFromInt(radix);
            const digit: usize = @intFromFloat(@floor(frac));
            buf[q] = digits[digit];
            q += 1;
            frac -= @floor(frac);
        }
    }
    return q;
}

fn decimalExponent(d: f64) i32 {
    if (d == 0) return 0;
    return @intFromFloat(@floor(std.math.log10(@abs(d))));
}

pub export fn js_dtoa(buf: [*]u8, d: f64, radix: c_int, n_digits: c_int, flags: c_int, tmp_mem: *JSDTOATempMem) callconv(.c) c_int {
    _ = tmp_mem;
    var q: usize = 0;
    if (std.math.isNan(d)) return @intCast(put(buf, "NaN"));
    if (std.math.isInf(d)) {
        if (d < 0) {
            buf[0] = '-';
            return @intCast(1 + put(buf + 1, "Infinity"));
        }
        return @intCast(put(buf, "Infinity"));
    }
    if (d == 0) {
        if (std.math.signbit(d) and (flags & JS_DTOA_MINUS_ZERO) != 0) {
            return @intCast(put(buf, "-0"));
        }
        if ((flags & JS_DTOA_FORMAT_MASK) == JS_DTOA_FORMAT_FRAC and n_digits > 0) {
            q += put(buf, "0.");
            var i: c_int = 0;
            while (i < n_digits) : (i += 1) {
                buf[q] = '0';
                q += 1;
            }
            return @intCast(q);
        }
        if ((flags & JS_DTOA_FORMAT_MASK) == JS_DTOA_FORMAT_FIXED and n_digits > 1) {
            q += put(buf, "0.");
            var i: c_int = 1;
            while (i < n_digits) : (i += 1) {
                buf[q] = '0';
                q += 1;
            }
            return @intCast(q);
        }
        return @intCast(put(buf, "0"));
    }
    if (radix != 10) {
        if ((flags & JS_DTOA_FORMAT_MASK) == JS_DTOA_FORMAT_FIXED) {
            var out: usize = 0;
            if (d < 0) {
                buf[0] = '-';
                out = 1;
            }
            const n: u64 = @intFromFloat(@round(@abs(d)));
            return @intCast(out + u64toa_radix(buf + out, n, @intCast(radix)));
        }
        if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_ENABLED and @abs(d) < 1) {
            const s = std.fmt.bufPrint(asBytes(buf, 256), "{x}", .{d}) catch "";
            return @intCast(s.len);
        }
        if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_ENABLED and @abs(d) >= 100) {
            const n = formatRadixFloat(buf, d, @intCast(radix));
            buf[n] = '@';
            _ = i32toa(buf + n + 1, 0);
            return @intCast(n + 2);
        }
        return @intCast(formatRadixFloat(buf, d, @intCast(radix)));
    }

    var tmp: [768]u8 = undefined;
    const fmt = flags & JS_DTOA_FORMAT_MASK;
    const exp_flags = flags & JS_DTOA_EXP_MASK;
    var s: []u8 = undefined;
    if (fmt == JS_DTOA_FORMAT_FRAC) {
        s = std.fmt.bufPrint(&tmp, "{d:1.[1]}", .{ d, @as(usize, @intCast(n_digits)) }) catch "";
        s = trimFixed(if (n_digits == 0) s else s);
        if (n_digits > 0) {
            s = std.fmt.bufPrint(&tmp, "{d:1.[1]}", .{ d, @as(usize, @intCast(n_digits)) }) catch "";
        }
    } else if (fmt == JS_DTOA_FORMAT_FIXED and n_digits > 0) {
        const e10 = decimalExponent(d);
        const frac_digits: usize = @intCast(@max(0, n_digits - e10 - 1));
        s = std.fmt.bufPrint(&tmp, "{d:1.[1]}", .{ d, frac_digits }) catch "";
        s = trimFixed(s);
    } else if (exp_flags == JS_DTOA_EXP_ENABLED or (@abs(d) < 1e-6 and d != 0)) {
        s = std.fmt.bufPrint(&tmp, "{e}", .{d}) catch "";
    } else {
        s = std.fmt.bufPrint(&tmp, "{d}", .{d}) catch "";
        if (std.mem.indexOfScalar(u8, s, '.') != null and s.len > 320) {
            s = std.fmt.bufPrint(&tmp, "{e}", .{d}) catch "";
        }
    }
    if (std.math.signbit(d) and d != 0 and s.len > 0 and s[0] != '-') {
        buf[0] = '-';
        @memcpy(buf[1 .. 1 + s.len], s);
        return @intCast(s.len + 1);
    }
    return @intCast(put(buf, s));
}

fn toDigit(c: u8) u32 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'a' and c <= 'z') return c - 'a' + 10;
    if (c >= 'A' and c <= 'Z') return c - 'A' + 10;
    return 255;
}

fn parseIntegerRadix(p: [*]const u8, start: usize, radix: u32, allow_sep: bool, consumed: *usize) ?f64 {
    var i = start;
    var any = false;
    var val: f64 = 0;
    while (true) {
        if (allow_sep and p[i] == '_' and any and toDigit(p[i + 1]) < radix) {
            i += 1;
        }
        const d = toDigit(p[i]);
        if (d >= radix) break;
        any = true;
        val = val * @as(f64, @floatFromInt(radix)) + @as(f64, @floatFromInt(d));
        i += 1;
    }
    if (!any) return null;
    consumed.* = i;
    return val;
}

fn parseDecimal(p: [*]const u8, start: usize, allow_sep: bool, consumed: *usize) ?f64 {
    var tmp: [768]u8 = undefined;
    var out: usize = 0;
    var i = start;
    var saw_digit = false;
    var saw_dot = false;
    while (true) {
        const c = p[i];
        if (allow_sep and c == '_' and saw_digit and (std.ascii.isDigit(p[i + 1]) or p[i + 1] == '.')) {
            i += 1;
            continue;
        }
        if (std.ascii.isDigit(c)) {
            saw_digit = true;
            tmp[out] = c;
            out += 1;
            i += 1;
            continue;
        }
        if (c == '.' and !saw_dot) {
            saw_dot = true;
            tmp[out] = c;
            out += 1;
            i += 1;
            continue;
        }
        break;
    }
    if (!saw_digit) return null;
    if (p[i] == 'e' or p[i] == 'E') {
        const exp_mark = i;
        var j = i + 1;
        if (p[j] == '+' or p[j] == '-') j += 1;
        var exp_digits = false;
        while (true) {
            if (allow_sep and p[j] == '_' and exp_digits and std.ascii.isDigit(p[j + 1])) {
                j += 1;
                continue;
            }
            if (!std.ascii.isDigit(p[j])) break;
            exp_digits = true;
            j += 1;
        }
        if (!exp_digits) return null;
        while (i < j) : (i += 1) {
            if (p[i] != '_') {
                tmp[out] = p[i];
                out += 1;
            }
        }
        _ = exp_mark;
    }
    consumed.* = i;
    return std.fmt.parseFloat(f64, tmp[0..out]) catch null;
}

fn parseSignedExp(p: [*]const u8, start: usize, allow_sep: bool, consumed: *usize) ?i32 {
    var i = start;
    var neg = false;
    if (p[i] == '+' or p[i] == '-') {
        neg = p[i] == '-';
        i += 1;
    }
    var any = false;
    var v: i32 = 0;
    while (true) {
        if (allow_sep and p[i] == '_' and any and std.ascii.isDigit(p[i + 1])) {
            i += 1;
            continue;
        }
        if (!std.ascii.isDigit(p[i])) break;
        any = true;
        if (v < 1000000) v = v * 10 + @as(i32, @intCast(p[i] - '0'));
        i += 1;
    }
    if (!any) return null;
    consumed.* = i;
    return if (neg) -v else v;
}

pub export fn js_atod(str: [*]const u8, pnext: [*c][*c]const u8, radix0: c_int, flags: c_int, tmp_mem: *JSATODTempMem) callconv(.c) f64 {
    _ = tmp_mem;
    var radix = radix0;
    var p: usize = 0;
    var neg = false;
    if (str[p] == '+') {
        p += 1;
    } else if (str[p] == '-') {
        neg = true;
        p += 1;
    }
    if (std.mem.eql(u8, str[p .. p + 8], "Infinity")) {
        pnext.* = str + p + 8;
        return if (neg) -std.math.inf(f64) else std.math.inf(f64);
    }
    if (str[p] == 0) {
        pnext.* = str;
        return std.math.nan(f64);
    }
    if (str[p] == '0') {
        if ((str[p + 1] == 'x' or str[p + 1] == 'X') and (radix == 0 or radix == 16)) {
            var consumed: usize = 0;
            if (parseIntegerRadix(str, p + 2, 16, (flags & JS_ATOD_ACCEPT_UNDERSCORES) != 0, &consumed)) |v| {
                if (str[consumed] == 'p' or str[consumed] == 'P') {
                    var exp_consumed: usize = 0;
                    if (parseSignedExp(str, consumed + 1, (flags & JS_ATOD_ACCEPT_UNDERSCORES) != 0, &exp_consumed)) |ev| {
                        const out = std.math.scalbn(v, ev);
                        pnext.* = str + exp_consumed;
                        return if (neg) -out else out;
                    }
                }
                pnext.* = str + consumed;
                return if (neg) -v else v;
            }
            pnext.* = str;
            return std.math.nan(f64);
        }
        if ((str[p + 1] == 'b' or str[p + 1] == 'B') and radix == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
            var consumed: usize = 0;
            if (parseIntegerRadix(str, p + 2, 2, (flags & JS_ATOD_ACCEPT_UNDERSCORES) != 0, &consumed)) |v| {
                pnext.* = str + consumed;
                return if (neg) -v else v;
            }
            pnext.* = str;
            return std.math.nan(f64);
        }
        if ((str[p + 1] == 'o' or str[p + 1] == 'O') and radix == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
            var consumed: usize = 0;
            if (parseIntegerRadix(str, p + 2, 8, (flags & JS_ATOD_ACCEPT_UNDERSCORES) != 0, &consumed)) |v| {
                pnext.* = str + consumed;
                return if (neg) -v else v;
            }
            pnext.* = str;
            return std.math.nan(f64);
        }
        if (radix == 0 and (flags & JS_ATOD_ACCEPT_LEGACY_OCTAL) != 0 and std.ascii.isDigit(str[p + 1])) {
            var j = p + 1;
            var octal = true;
            while (std.ascii.isDigit(str[j])) : (j += 1) {
                if (str[j] == '8' or str[j] == '9') octal = false;
            }
            if (octal) radix = 8;
        }
    }
    if (radix == 0) radix = 10;
    var consumed: usize = 0;
    const allow_sep = (flags & JS_ATOD_ACCEPT_UNDERSCORES) != 0;
    const val = if (radix == 10)
        parseDecimal(str, p, allow_sep, &consumed)
    else
        parseIntegerRadix(str, p, @intCast(radix), allow_sep, &consumed);
    if (val) |v| {
        pnext.* = str + consumed;
        return if (neg) -v else v;
    }
    pnext.* = str;
    return std.math.nan(f64);
}
