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

const slimb_t = i32;
pub const limb_t = u32;
const dlimb_t = u64;

const LIMB_DIGITS = 9;
const JS_RADIX_MAX = 36;

const DBIGNUM_LEN_MAX = 52;
const MANT_LEN_MAX = 18;
const MPB_STORAGE_LEN = DBIGNUM_LEN_MAX + MANT_LEN_MAX + 8;

const JS_RNDN = 0;
const JS_RNDNA = 1;
const JS_RNDZ = 2;

const Mpb = extern struct {
    len: c_int,
    tab: [0]limb_t,
};

const MpbStorage = extern struct {
    len: c_int,
    tab: [MPB_STORAGE_LEN]limb_t,
};

fn asMpb(ptr: *anyopaque) *Mpb {
    return @ptrCast(@alignCast(ptr));
}

fn asConstMpb(ptr: *const anyopaque) *const Mpb {
    return @ptrCast(@alignCast(ptr));
}

fn storageMpb(storage: *MpbStorage) *Mpb {
    return @ptrCast(storage);
}

fn mpbTab(r: *Mpb) [*]limb_t {
    const base: [*]u8 = @ptrCast(r);
    return @ptrCast(@alignCast(base + @offsetOf(Mpb, "tab")));
}

fn mpbTabConst(r: *const Mpb) [*]const limb_t {
    const base: [*]const u8 = @ptrCast(r);
    return @ptrCast(@alignCast(base + @offsetOf(Mpb, "tab")));
}

fn rIndex(radix: c_int) usize {
    return @intCast(radix - 2);
}

fn minInt(a: c_int, b: c_int) c_int {
    return if (a < b) a else b;
}

fn maxInt(a: c_int, b: c_int) c_int {
    return if (a > b) a else b;
}

fn absInt(a: c_int) c_int {
    return if (a < 0) -a else a;
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

fn float64AsUint64(d: f64) u64 {
    return @bitCast(d);
}

fn uint64AsFloat64(a: u64) f64 {
    return @bitCast(a);
}

fn cStrSpan(p: [*]const u8) []const u8 {
    var n: usize = 0;
    while (p[n] != 0) : (n += 1) {}
    return p[0..n];
}

fn copyLit(buf: [*]u8, q: *usize, comptime lit: []const u8) void {
    var i: usize = 0;
    while (i < lit.len) : (i += 1) {
        buf[q.* + i] = lit[i];
    }
    q.* += lit.len;
}

fn startsWithLit(str: [*]const u8, pos: usize, comptime lit: []const u8) bool {
    var i: usize = 0;
    while (i < lit.len) : (i += 1) {
        if (str[pos + i] != lit[i]) return false;
    }
    return true;
}

pub export fn mp_add_ui(tab: [*]limb_t, b: limb_t, n: usize) callconv(.c) limb_t {
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

fn mpMul1(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, l_in: limb_t) limb_t {
    var l = l_in;
    var i: limb_t = 0;
    while (i < n) : (i += 1) {
        const idx: usize = @intCast(i);
        const t: dlimb_t = @as(dlimb_t, taba[idx]) *% @as(dlimb_t, b) +% @as(dlimb_t, l);
        tabr[idx] = @truncate(t);
        l = @truncate(t >> LIMB_BITS);
    }
    return l;
}

pub export fn udiv1norm_init(d: limb_t) callconv(.c) limb_t {
    const a1: limb_t = -%d -% 1;
    const a0: limb_t = 0xffffffff;
    return @truncate(((@as(dlimb_t, a1) << LIMB_BITS) | @as(dlimb_t, a0)) / @as(dlimb_t, d));
}

fn udiv1norm(pr: *limb_t, a1: limb_t, a0: limb_t, d: limb_t, d_inv: limb_t) limb_t {
    const n1m_i: slimb_t = @as(slimb_t, @bitCast(a0)) >> (LIMB_BITS - 1);
    const n1m: limb_t = @bitCast(n1m_i);
    const n_adj: limb_t = a0 +% (n1m & d);
    var a: dlimb_t = @as(dlimb_t, d_inv) *% @as(dlimb_t, a1 -% n1m) +% @as(dlimb_t, n_adj);
    var q: limb_t = @truncate(a >> LIMB_BITS);
    q +%= a1;

    a = (@as(dlimb_t, a1) << LIMB_BITS) | @as(dlimb_t, a0);
    a = a -% (@as(dlimb_t, q) *% @as(dlimb_t, d)) -% @as(dlimb_t, d);
    const ah: limb_t = @truncate(a >> LIMB_BITS);
    q +%= 1 +% ah;
    const r: limb_t = @as(limb_t, @truncate(a)) +% (ah & d);
    pr.* = r;
    return q;
}

fn mpDiv1(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r_in: limb_t) limb_t {
    var r = r_in;
    var i: usize = @intCast(n);
    while (i > 0) {
        i -= 1;
        const a1: dlimb_t = (@as(dlimb_t, r) << LIMB_BITS) | @as(dlimb_t, taba[i]);
        tabr[i] = @truncate(a1 / @as(dlimb_t, b));
        r = @truncate(a1 % @as(dlimb_t, b));
    }
    return r;
}

pub export fn mp_shr(tab_r: [*]limb_t, tab: [*]const limb_t, n_in: isize, shift_in: c_int, high: limb_t) callconv(.c) limb_t {
    std.debug.assert(shift_in >= 1 and shift_in < LIMB_BITS);
    const n: usize = @intCast(n_in);
    const shift: u5 = @intCast(shift_in);
    var l = high;
    var i = n;
    while (i > 0) {
        i -= 1;
        const a = tab[i];
        tab_r[i] = (a >> shift) | (l << @intCast(LIMB_BITS - shift_in));
        l = a;
    }
    return l & ((@as(limb_t, 1) << shift) -% 1);
}

pub export fn mp_shl(tab_r: [*]limb_t, tab: [*]const limb_t, n_in: isize, shift_in: c_int, low: limb_t) callconv(.c) limb_t {
    std.debug.assert(shift_in >= 1 and shift_in < LIMB_BITS);
    const n: usize = @intCast(n_in);
    const shift: u5 = @intCast(shift_in);
    var l = low;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const a = tab[i];
        tab_r[i] = (a << shift) | l;
        l = a >> @intCast(LIMB_BITS - shift_in);
    }
    return l;
}

pub export fn mp_div1norm(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r_in: limb_t, b_inv: limb_t, shift: c_int) callconv(.c) limb_t {
    var r = r_in;
    if (shift != 0) {
        r = (r << @intCast(shift)) | mp_shl(tabr, taba, @intCast(n), shift, 0);
    }
    var i: usize = @intCast(n);
    while (i > 0) {
        i -= 1;
        tabr[i] = udiv1norm(&r, r, taba[i], b, b_inv);
    }
    r >>= @intCast(shift);
    return r;
}

fn mpbRenorm(r: *Mpb) void {
    const tab = mpbTab(r);
    while (r.len > 1 and tab[@intCast(r.len - 1)] == 0) {
        r.len -= 1;
    }
}

pub export fn mpb_renorm(r: *anyopaque) callconv(.c) void {
    mpbRenorm(asMpb(r));
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
    0x99999999, 0x47ae147a, 0x0624dd2f, 0xa36e2eb1,
    0x4f8b588e, 0x0c6f7a0b, 0xad7f29ab, 0x5798ee23,
    0x12e0be82, 0xb7cdfd9d, 0x5fd7fe17, 0x19799812,
    0xc25c2684,
};

fn powUi(a_in: u32, b_in: u32) u64 {
    const a = a_in;
    const b = b_in;
    if (b == 0) return 1;
    if (b == 1) return a;
    if ((a == 5 or a == 10) and b <= 17) {
        var r: u64 = pow5_table[@intCast(b - 1)];
        if (b >= 14) {
            r |= @as(u64, pow5h_table[@intCast(b - 14)]) << 32;
        }
        if (a == 10) r <<= @intCast(b);
        return r;
    }
    var r: u64 = a;
    const n_bits: c_int = 32 - clz32(b);
    var i: c_int = n_bits - 1;
    while (i > 0) {
        i -= 1;
        r *%= r;
        if (((b >> @intCast(i)) & 1) != 0) r *%= a;
    }
    return r;
}

pub export fn pow_ui(radix: c_int, n: c_int) callconv(.c) u64 {
    return powUi(@intCast(radix), @intCast(n));
}

fn powUiInv(pr_inv: *u32, pshift: *c_int, a: u32, b: u32) u32 {
    var r_inv: u32 = undefined;
    var r: u32 = undefined;
    var shift: c_int = undefined;
    if (a == 5 and b >= 1 and b <= 13) {
        r = pow5_table[@intCast(b - 1)];
        shift = clz32(r);
        r <<= @intCast(shift);
        r_inv = pow5_inv_table[@intCast(b - 1)];
    } else {
        r = @truncate(powUi(a, b));
        shift = clz32(r);
        r <<= @intCast(shift);
        r_inv = udiv1norm_init(r);
    }
    pshift.* = shift;
    pr_inv.* = r_inv;
    return r;
}

pub export fn pow_ui_inv(pr_inv: *u32, pshift: *c_int, radix: c_int, n: c_int) callconv(.c) void {
    _ = powUiInv(pr_inv, pshift, @intCast(radix), @intCast(n));
}

fn mpbGetBit(r: *const Mpb, k_in: c_int) c_int {
    var k = k_in;
    const l: usize = @intCast(@divTrunc(k, LIMB_BITS));
    k &= LIMB_BITS - 1;
    if (l >= @as(usize, @intCast(r.len))) return 0;
    return @intCast((mpbTabConst(r)[l] >> @intCast(k)) & 1);
}

pub export fn mpb_get_bit(r: *const anyopaque, pos: c_int) callconv(.c) c_int {
    return mpbGetBit(asConstMpb(r), pos);
}

fn mpbShrRound(r: *Mpb, shift_in: c_int, rnd_mode: c_int) void {
    var shift = shift_in;
    const tab = mpbTab(r);
    if (shift == 0) return;
    if (shift < 0) {
        shift = -shift;
        const l: c_int = @divTrunc(shift, LIMB_BITS);
        shift &= LIMB_BITS - 1;
        if (shift != 0) {
            tab[@intCast(r.len)] = mp_shl(tab, tab, @intCast(r.len), shift, 0);
            r.len += 1;
            mpbRenorm(r);
        }
        if (l > 0) {
            var i: usize = @intCast(r.len);
            const lu: usize = @intCast(l);
            while (i > 0) {
                i -= 1;
                tab[i + lu] = tab[i];
            }
            i = 0;
            while (i < lu) : (i += 1) tab[i] = 0;
            r.len += l;
        }
    } else {
        var add_one: bool = false;
        switch (rnd_mode) {
            JS_RNDN, JS_RNDNA => {
                const bit1 = mpbGetBit(r, shift - 1);
                if (bit1 != 0) {
                    var bit2: limb_t = 0;
                    if (rnd_mode == JS_RNDNA) {
                        bit2 = 1;
                    } else if (shift >= 2) {
                        var k = shift - 1;
                        const l: c_int = @divTrunc(k, LIMB_BITS);
                        k &= LIMB_BITS - 1;
                        const lim = minInt(l, r.len);
                        var i: c_int = 0;
                        while (i < lim) : (i += 1) bit2 |= tab[@intCast(i)];
                        if (l < r.len) {
                            bit2 |= tab[@intCast(l)] & ((@as(limb_t, 1) << @intCast(k)) -% 1);
                        }
                    }
                    if (bit2 != 0) {
                        add_one = true;
                    } else {
                        add_one = (mpbGetBit(r, shift) != 0);
                    }
                }
            },
            else => add_one = false,
        }

        const l: c_int = @divTrunc(shift, LIMB_BITS);
        shift &= LIMB_BITS - 1;
        if (l >= r.len) {
            r.len = 1;
            tab[0] = if (add_one) 1 else 0;
        } else {
            if (l > 0) {
                r.len -= l;
                var i: c_int = 0;
                while (i < r.len) : (i += 1) {
                    tab[@intCast(i)] = tab[@intCast(i + l)];
                }
            }
            if (shift != 0) {
                _ = mp_shr(tab, tab, @intCast(r.len), shift, 0);
                mpbRenorm(r);
            }
            if (add_one) {
                const a = mp_add_ui(tab, 1, @intCast(r.len));
                if (a != 0) {
                    tab[@intCast(r.len)] = a;
                    r.len += 1;
                }
            }
        }
    }
}

pub export fn mpb_shr_round(r: *anyopaque, shift: c_int, rnd_mode: c_int) callconv(.c) void {
    mpbShrRound(asMpb(r), shift, rnd_mode);
}

fn mpbCmp(a: *const Mpb, b: *const Mpb) c_int {
    if (a.len < b.len) return -1;
    if (a.len > b.len) return 1;
    const at = mpbTabConst(a);
    const bt = mpbTabConst(b);
    var i: usize = @intCast(a.len);
    while (i > 0) {
        i -= 1;
        if (at[i] != bt[i]) return if (at[i] < bt[i]) -1 else 1;
    }
    return 0;
}

pub export fn mpb_cmp(a: *const anyopaque, b: *const anyopaque) callconv(.c) c_int {
    return mpbCmp(asConstMpb(a), asConstMpb(b));
}

fn mpbSetU64(r: *Mpb, m: u64) void {
    const tab = mpbTab(r);
    tab[0] = @truncate(m);
    tab[1] = @truncate(m >> LIMB_BITS);
    r.len = if (tab[1] == 0) 1 else 2;
}

pub export fn mpb_set_u64(r: *anyopaque, m: u64) callconv(.c) void {
    mpbSetU64(asMpb(r), m);
}

fn mpbGetU64(r: *const Mpb) u64 {
    const tab = mpbTabConst(r);
    if (r.len == 1) return tab[0];
    return @as(u64, tab[0]) | (@as(u64, tab[1]) << LIMB_BITS);
}

pub export fn mpb_get_u64(r: *anyopaque) callconv(.c) u64 {
    return mpbGetU64(asConstMpb(r));
}

fn mpbFloorLog2(a: *const Mpb) c_int {
    const tab = mpbTabConst(a);
    const v = tab[@intCast(a.len - 1)];
    if (v == 0) return -1;
    return a.len * LIMB_BITS - 1 - clz32(v);
}

pub export fn mpb_floor_log2(a: *anyopaque) callconv(.c) c_int {
    return mpbFloorLog2(asConstMpb(a));
}

const MUL_LOG2_RADIX_BASE_LOG2 = 24;

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

fn mulLog2Radix(a: c_int, radix: c_int) c_int {
    const uradix: u32 = @intCast(radix);
    if ((uradix & (uradix - 1)) == 0) {
        const radix_bits: c_int = 31 - clz32(uradix);
        var aa = a;
        if (aa < 0) aa -= radix_bits - 1;
        return @divTrunc(aa, radix_bits);
    } else {
        const mult = mul_log2_radix_table[rIndex(radix)];
        return @intCast((@as(i64, a) * @as(i64, mult)) >> MUL_LOG2_RADIX_BASE_LOG2);
    }
}

pub export fn mul_log2_radix(a: c_int, radix: c_int) callconv(.c) c_int {
    return mulLog2Radix(a, radix);
}

fn u32toaLen(buf: [*]u8, n_in: u32, len: usize) void {
    var n = n_in;
    var i = len;
    while (i > 0) {
        i -= 1;
        const digit = n % 10;
        n /= 10;
        buf[i] = @intCast(digit + '0');
    }
}

fn u64toaBinLen(buf: [*]u8, n_in: u64, radix_bits_in: c_uint, len_in: c_int) void {
    var n = n_in;
    const radix_bits: u6 = @intCast(radix_bits_in);
    const mask: u64 = (@as(u64, 1) << radix_bits) - 1;
    var i: c_int = len_in;
    while (i > 0) {
        i -= 1;
        var digit: u8 = @intCast(n & mask);
        n >>= radix_bits;
        if (digit < 10) digit += '0' else digit += 'a' - 10;
        buf[@intCast(i)] = digit;
    }
}

fn limbToA(buf: [*]u8, n_in: limb_t, radix_in: c_int, len_in: c_int) void {
    var n = n_in;
    const len: usize = @intCast(len_in);
    const radix: limb_t = @intCast(radix_in);
    if (radix_in == 10) {
        u32toaLen(buf, n, len);
    } else {
        var i = len;
        while (i > 0) {
            i -= 1;
            var digit: u8 = @intCast(n % radix);
            n /= radix;
            if (digit < 10) digit += '0' else digit += 'a' - 10;
            buf[i] = digit;
        }
    }
}

pub export fn limb_to_a(buf: [*]u8, a: limb_t, radix: c_int, len: c_int) callconv(.c) void {
    limbToA(buf, a, radix, len);
}

pub export fn u32toa(buf: [*]u8, n_in: u32) callconv(.c) usize {
    var n = n_in;
    var tmp: [10]u8 = undefined;
    var pos: usize = tmp.len;
    while (true) {
        pos -= 1;
        tmp[pos] = @intCast((n % 10) + '0');
        n /= 10;
        if (n == 0) break;
    }
    const len = tmp.len - pos;
    var i: usize = 0;
    while (i < len) : (i += 1) buf[i] = tmp[pos + i];
    return len;
}

pub export fn i32toa(buf: [*]u8, n: i32) callconv(.c) usize {
    if (n >= 0) return u32toa(buf, @intCast(n));
    buf[0] = '-';
    const un: u32 = -%@as(u32, @bitCast(n));
    return u32toa(buf + 1, un) + 1;
}

pub export fn u64toa(buf: [*]u8, n_in: u64) callconv(.c) usize {
    var n = n_in;
    if (n < 0x100000000) return u32toa(buf, @truncate(n));

    var q = buf;
    var n1 = n / 1000000000;
    n %= 1000000000;
    if (n1 >= 0x100000000) {
        var n2: u32 = @truncate(n1 / 1000000000);
        n1 %= 1000000000;
        if (n2 >= 10) {
            q[0] = @intCast(n2 / 10 + '0');
            q += 1;
            n2 %= 10;
        }
        q[0] = @intCast(n2 + '0');
        q += 1;
        u32toaLen(q, @truncate(n1), 9);
        q += 9;
    } else {
        q += u32toa(q, @truncate(n1));
    }
    u32toaLen(q, @truncate(n), 9);
    q += 9;
    return @intFromPtr(q) - @intFromPtr(buf);
}

pub export fn i64toa(buf: [*]u8, n: i64) callconv(.c) usize {
    if (n >= 0) return u64toa(buf, @intCast(n));
    buf[0] = '-';
    const un: u64 = -%@as(u64, @bitCast(n));
    return u64toa(buf + 1, un) + 1;
}

pub export fn u64toa_radix(buf: [*]u8, n_in: u64, radix_in: c_uint) callconv(.c) usize {
    var n = n_in;
    const radix = radix_in;
    if (radix == 10) return u64toa(buf, n);
    if ((radix & (radix - 1)) == 0) {
        const radix_bits: c_int = 31 - clz32(radix);
        const l: c_int = if (n == 0) 1 else @divTrunc((64 - clz64(n) + radix_bits - 1), radix_bits);
        u64toaBinLen(buf, n, @intCast(radix_bits), l);
        return @intCast(l);
    }

    var tmp: [41]u8 = undefined;
    var pos: usize = tmp.len;
    while (true) {
        var digit: u8 = @intCast(n % radix);
        n /= radix;
        if (digit < 10) digit += '0' else digit += 'a' - 10;
        pos -= 1;
        tmp[pos] = digit;
        if (n == 0) break;
    }
    const len = tmp.len - pos;
    var i: usize = 0;
    while (i < len) : (i += 1) buf[i] = tmp[pos + i];
    return len;
}

pub export fn i64toa_radix(buf: [*]u8, n: i64, radix: c_uint) callconv(.c) usize {
    if (n >= 0) return u64toa_radix(buf, @intCast(n), radix);
    buf[0] = '-';
    const un: u64 = -%@as(u64, @bitCast(n));
    return u64toa_radix(buf + 1, un, radix) + 1;
}

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

fn outputDigits(buf: [*]u8, a: *Mpb, radix: c_int, n_digits1: c_int, dot_pos: c_int) c_int {
    var n_digits = n_digits1;
    const uradix: u32 = @intCast(radix);
    const radix_bits: c_int = if ((uradix & (uradix - 1)) == 0) 31 - clz32(uradix) else 0;
    const digits_per_limb: c_int = digits_per_limb_table[rIndex(radix)];
    const tab = mpbTab(a);

    if (radix_bits != 0) {
        while (true) {
            const n = minInt(n_digits, digits_per_limb);
            n_digits -= n;
            u64toaBinLen(buf + @as(usize, @intCast(n_digits)), tab[0], @intCast(radix_bits), n);
            if (n_digits == 0) break;
            mpbShrRound(a, digits_per_limb * radix_bits, JS_RNDZ);
        }
    } else {
        while (n_digits != 0) {
            const n = minInt(n_digits, digits_per_limb);
            n_digits -= n;
            const rem = mpDiv1(tab, tab, @intCast(a.len), radix_base_table[rIndex(radix)], 0);
            mpbRenorm(a);
            limbToA(buf + @as(usize, @intCast(n_digits)), rem, radix, n);
        }
    }

    var len = n_digits1;
    if (dot_pos != n_digits1) {
        var i: c_int = n_digits1 - dot_pos;
        while (i > 0) {
            i -= 1;
            buf[@intCast(dot_pos + 1 + i)] = buf[@intCast(dot_pos + i)];
        }
        buf[@intCast(dot_pos)] = '.';
        len += 1;
    }
    return len;
}

pub export fn output_digits(buf: [*]u8, a: *const anyopaque, radix: c_int, n_digits: c_int, dot_pos: c_int) callconv(.c) c_int {
    return outputDigits(buf, @constCast(asConstMpb(a)), radix, n_digits, dot_pos);
}

fn mulPow(a: *Mpb, radix1: c_int, radix_shift: c_int, f_in: c_int, is_int: bool, e: c_int) c_int {
    var f = f_in;
    var e_offset: c_int = -f * radix_shift;
    const tab = mpbTab(a);
    if (radix1 != 1) {
        const d: c_int = digits_per_limb_table[rIndex(radix1)];
        if (f >= 0) {
            var b: limb_t = 0;
            var n0: c_int = 0;
            while (f != 0) {
                const n = minInt(f, d);
                if (n != n0) {
                    b = @truncate(powUi(@intCast(radix1), @intCast(n)));
                    n0 = n;
                }
                const h = mpMul1(tab, tab, @intCast(a.len), b, 0);
                if (h != 0) {
                    tab[@intCast(a.len)] = h;
                    a.len += 1;
                }
                f -= n;
            }
        } else {
            f = -f;
            const l = @divTrunc(f + d - 1, d);
            e_offset += l * LIMB_BITS;
            const extra_bits = if (!is_int)
                maxInt(e - mpbFloorLog2(a), 0)
            else
                maxInt(2 + e - e_offset, 0);
            e_offset += extra_bits;
            mpbShrRound(a, -(l * LIMB_BITS + extra_bits), JS_RNDZ);

            var b: limb_t = 0;
            var b_inv: limb_t = 0;
            var shift: c_int = 0;
            var n0: c_int = 0;
            var rem: limb_t = 0;
            while (f != 0) {
                const n = minInt(f, d);
                if (n != n0) {
                    b = powUiInv(&b_inv, &shift, @intCast(radix1), @intCast(n));
                    n0 = n;
                }
                const r = mp_div1norm(tab, tab, @intCast(a.len), b, 0, b_inv, shift);
                rem |= r;
                mpbRenorm(a);
                f -= n;
            }
            if (rem != 0) tab[0] |= 1;
        }
    }
    return e_offset;
}

fn mulPowRound(tmp1: *Mpb, m: u64, e: c_int, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) void {
    mpbSetU64(tmp1, m);
    const e_offset = mulPow(tmp1, radix1, radix_shift, f, true, e);
    mpbShrRound(tmp1, -e + e_offset, rnd_mode);
}

fn roundToD(pe: *c_int, a: *Mpb, e_offset: c_int, rnd_mode: c_int) u64 {
    const tab = mpbTab(a);
    var e: c_int = undefined;
    var m: u64 = undefined;
    if (tab[0] == 0 and a.len == 1) {
        m = 0;
        e = 0;
    } else {
        const prec1: c_int = 53;
        const e_min: c_int = -1021;
        e = mpbFloorLog2(a) + 1 - e_offset;
        const prec = if (e < e_min) prec1 - (e_min - e) else prec1;
        mpbShrRound(a, e + e_offset - prec, rnd_mode);
        m = mpbGetU64(a);
        const sh = 53 - prec;
        if (sh > 0) {
            if (sh >= 64) {
                m = 0;
            } else {
                m <<= @intCast(sh);
            }
        }
        if (m >= (@as(u64, 1) << 53)) {
            m >>= 1;
            e += 1;
        }
    }
    pe.* = e;
    return m;
}

pub export fn round_to_d(pe: *c_int, a: *anyopaque, e_offset: c_int, rnd_mode: c_int) callconv(.c) u64 {
    return roundToD(pe, asMpb(a), e_offset, rnd_mode);
}

fn mulPowRoundToD(pe: *c_int, a: *Mpb, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) u64 {
    const e_offset = mulPow(a, radix1, radix_shift, f, false, 55);
    return roundToD(pe, a, e_offset, rnd_mode);
}

pub export fn mul_pow_round_to_d(pe: *c_int, a: *anyopaque, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) callconv(.c) u64 {
    return mulPowRoundToD(pe, asMpb(a), radix1, radix_shift, f, rnd_mode);
}

pub export fn js_dtoa_max_len(d: f64, radix: c_int, n_digits: c_int, flags: c_int) callconv(.c) c_int {
    const fmt = flags & JS_DTOA_FORMAT_MASK;
    var n: c_int = undefined;
    if (fmt != JS_DTOA_FORMAT_FRAC) {
        if (fmt == JS_DTOA_FORMAT_FREE) {
            n = dtoa_max_digits_table[rIndex(radix)];
        } else {
            n = n_digits;
        }
        if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_DISABLED) {
            const a = float64AsUint64(d);
            var e: c_int = @intCast((a >> 52) & 0x7ff);
            if (e == 0x7ff) {
                n = 0;
            } else {
                e -= 1023;
                n += 10 + absInt(mulLog2Radix(e - 1, radix));
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
            if (e < 0) n = 1 else n = 2 + mulLog2Radix(e - 1, radix);
            n += 1 + 1 + 1 + n_digits;
        }
    }
    return maxInt(n, 9);
}

pub export fn js_dtoa(buf: [*]u8, d: f64, radix: c_int, n_digits: c_int, flags: c_int, tmp_mem: *JSDTOATempMem) callconv(.c) c_int {
    _ = tmp_mem;
    var tmp1_store: MpbStorage = undefined;
    var mant_max_store: MpbStorage = undefined;
    const tmp1 = storageMpb(&tmp1_store);
    const mant_max = storageMpb(&mant_max_store);

    const fmt = flags & JS_DTOA_FORMAT_MASK;
    const uradix: u32 = @intCast(radix);
    const radix_shift: c_int = ctz32(uradix);
    const radix1: c_int = @intCast(uradix >> @intCast(radix_shift));

    const a = float64AsUint64(d);
    const sgn = (a >> 63) != 0;
    var e: c_int = @intCast((a >> 52) & 0x7ff);
    var m: u64 = a & ((@as(u64, 1) << 52) - 1);
    var q: usize = 0;
    var E: c_int = undefined;
    var P: c_int = undefined;

    if (e == 0x7ff) {
        if (m == 0) {
            if (sgn) {
                buf[q] = '-';
                q += 1;
            }
            copyLit(buf, &q, "Infinity");
        } else {
            copyLit(buf, &q, "NaN");
        }
        buf[q] = 0;
        return @intCast(q);
    }

    const zero_case = (e == 0 and m == 0);
    if (zero_case) {
        tmp1.len = 1;
        mpbTab(tmp1)[0] = 0;
        E = 1;
        if (fmt == JS_DTOA_FORMAT_FREE) {
            P = 1;
        } else if (fmt == JS_DTOA_FORMAT_FRAC) {
            P = n_digits + 1;
        } else {
            P = n_digits;
        }
        if (sgn and (flags & JS_DTOA_MINUS_ZERO) != 0) {
            buf[q] = '-';
            q += 1;
        }
    } else {
        if (e == 0) {
            const l = clz64(m) - 11;
            e -= l - 1;
            m <<= @intCast(l);
        } else {
            m |= @as(u64, 1) << 52;
        }
        if (sgn) {
            buf[q] = '-';
            q += 1;
        }
        e -= 1022;

        if (fmt == JS_DTOA_FORMAT_FREE and
            e >= 1 and e <= 53 and
            (m & ((@as(u64, 1) << @intCast(53 - e)) - 1)) == 0 and
            (flags & JS_DTOA_EXP_MASK) != JS_DTOA_EXP_ENABLED)
        {
            m >>= @intCast(53 - e);
            q += u64toa_radix(buf + q, m, @intCast(radix));
            buf[q] = 0;
            return @intCast(q);
        }

        E = 1 + mulLog2Radix(e - 1, radix);

        if (fmt == JS_DTOA_FORMAT_FREE) {
            const P_max: c_int = dtoa_max_digits_table[rIndex(radix)];
            const E0 = E;
            var E_found: c_int = 0;
            var P_found: c_int = 0;
            var mant_found: u64 = 0;
            P = P_max;
            var first = true;
            while (true) {
                const mant_max1 = powUi(@intCast(radix), @intCast(P));
                E = E0;
                var mant: u64 = undefined;
                while (true) {
                    mulPowRound(tmp1, m, e - 53, radix1, radix_shift, P - E, JS_RNDN);
                    mant = mpbGetU64(tmp1);
                    if (mant < mant_max1) break;
                    E += 1;
                }
                while ((mant % @as(u64, @intCast(radix))) == 0) {
                    mant /= @intCast(radix);
                    P -= 1;
                }

                var ok = false;
                if (first) {
                    ok = true;
                    first = false;
                } else {
                    mpbSetU64(tmp1, mant);
                    var e1: c_int = 0;
                    const m1 = mulPowRoundToD(&e1, tmp1, radix1, radix_shift, E - P, JS_RNDN);
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
            mpbSetU64(tmp1, mant_found);
        } else if (fmt == JS_DTOA_FORMAT_FRAC) {
            std.debug.assert(n_digits >= 0 and n_digits <= JS_DTOA_MAX_DIGITS);
            mulPowRound(tmp1, m, e - 53, radix1, radix_shift, n_digits, JS_RNDNA);
            var len = outputDigits(buf + q, tmp1, radix, maxInt(E + 1, 1) + n_digits, maxInt(E + 1, 1));
            if (buf[q] == '0' and len >= 2 and buf[q + 1] != '.') {
                len -= 1;
                var i: c_int = 0;
                while (i < len) : (i += 1) {
                    buf[q + @as(usize, @intCast(i))] = buf[q + @as(usize, @intCast(i + 1))];
                }
            }
            q += @intCast(len);
            buf[q] = 0;
            return @intCast(q);
        } else {
            std.debug.assert(n_digits >= 1 and n_digits <= JS_DTOA_MAX_DIGITS);
            P = n_digits;
            mant_max.len = 1;
            mpbTab(mant_max)[0] = 1;
            const pow_shift = mulPow(mant_max, radix1, radix_shift, P, false, 0);
            mpbShrRound(mant_max, pow_shift, JS_RNDZ);
            while (true) {
                mulPowRound(tmp1, m, e - 53, radix1, radix_shift, P - E, JS_RNDNA);
                if (mpbCmp(tmp1, mant_max) < 0) break;
                E += 1;
            }
        }
    }

    const E_max: c_int = if (fmt == JS_DTOA_FORMAT_FIXED) n_digits else @as(c_int, dtoa_max_digits_table[rIndex(radix)]) + 4;
    if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_ENABLED or
        ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_AUTO and (E <= -6 or E > E_max)))
    {
        q += @intCast(outputDigits(buf + q, tmp1, radix, P, 1));
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
        q += @intCast(outputDigits(buf + q, tmp1, radix, P, P));
    } else {
        q += @intCast(outputDigits(buf + q, tmp1, radix, P, minInt(P, E)));
        var i: c_int = 0;
        while (i < E - P) : (i += 1) {
            buf[q] = '0';
            q += 1;
        }
    }
    buf[q] = 0;
    return @intCast(q);
}

fn toDigit(c: u8) c_int {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'A' and c <= 'Z') return c - 'A' + 10;
    if (c >= 'a' and c <= 'z') return c - 'a' + 10;
    return 36;
}

fn mpbMul1Base(r: *Mpb, radix_base: limb_t, a: limb_t) void {
    const tab = mpbTab(r);
    if (tab[0] == 0 and r.len == 1) {
        tab[0] = a;
    } else {
        if (radix_base == 0) {
            var i: usize = @intCast(r.len);
            while (i > 0) {
                i -= 1;
                tab[i + 1] = tab[i];
            }
            tab[0] = a;
        } else {
            tab[@intCast(r.len)] = mpMul1(tab, tab, @intCast(r.len), radix_base, a);
        }
        r.len += 1;
        mpbRenorm(r);
    }
}

pub export fn mpb_mul1_base(r: *anyopaque, radix_base: limb_t, b: limb_t) callconv(.c) void {
    mpbMul1Base(asMpb(r), radix_base, b);
}

fn finishAtod(str: [*]const u8, pnext: [*c][*c]const u8, p: usize, bits_in: u64, is_neg: bool) f64 {
    var bits = bits_in;
    if (is_neg) bits |= @as(u64, 1) << 63;
    if (pnext != null) pnext[0] = @ptrCast(str + p);
    return uint64AsFloat64(bits);
}

fn failAtod(str: [*]const u8, pnext: [*c][*c]const u8, p: usize) f64 {
    if (pnext != null) pnext[0] = @ptrCast(str + p);
    return std.math.nan(f64);
}

pub export fn js_atod(str: [*]const u8, pnext: [*c][*c]const u8, radix_in: c_int, flags: c_int, tmp_mem: *JSATODTempMem) callconv(.c) f64 {
    _ = tmp_mem;
    var tmp0_store: MpbStorage = undefined;
    const tmp0 = storageMpb(&tmp0_store);
    const tab0 = mpbTab(tmp0);

    var radix = radix_in;
    var p: usize = 0;
    var is_neg = false;
    var p_start: usize = 0;

    if (str[p] == '+') {
        p += 1;
        p_start = p;
    } else if (str[p] == '-') {
        is_neg = true;
        p += 1;
        p_start = p;
    } else {
        p_start = p;
    }

    var sep: c_int = if ((flags & JS_ATOD_ACCEPT_UNDERSCORES) != 0) '_' else 256;

    if (str[p] == '0') {
        if ((str[p + 1] == 'x' or str[p + 1] == 'X') and (radix == 0 or radix == 16)) {
            p += 2;
            radix = 16;
            if (toDigit(str[p]) >= radix) return failAtod(str, pnext, p);
        } else if ((str[p + 1] == 'o' or str[p + 1] == 'O') and radix == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
            p += 2;
            radix = 8;
            if (toDigit(str[p]) >= radix) return failAtod(str, pnext, p);
        } else if ((str[p + 1] == 'b' or str[p + 1] == 'B') and radix == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
            p += 2;
            radix = 2;
            if (toDigit(str[p]) >= radix) return failAtod(str, pnext, p);
        } else if ((str[p + 1] >= '0' and str[p + 1] <= '9') and radix == 0 and (flags & JS_ATOD_ACCEPT_LEGACY_OCTAL) != 0) {
            sep = 256;
            var i: usize = 1;
            while (str[p + i] >= '0' and str[p + i] <= '7') : (i += 1) {}
            if (!(str[p + i] == '8' or str[p + i] == '9')) {
                p += 1;
                radix = 8;
                if (toDigit(str[p]) >= radix) return failAtod(str, pnext, p);
            }
        }
    } else {
        if ((flags & JS_ATOD_INT_ONLY) == 0 and startsWithLit(str, p, "Infinity")) {
            p += "Infinity".len;
            return finishAtod(str, pnext, p, @as(u64, 0x7ff) << 52, is_neg);
        }
    }
    if (radix == 0) radix = 10;

    var cur_limb: limb_t = 0;
    var expn_offset: c_int = 0;
    var digit_count: c_int = 0;
    var limb_digit_count: c_int = 0;
    const max_digits: c_int = atod_max_digits_table[rIndex(radix)];
    const digits_per_limb: c_int = digits_per_limb_table[rIndex(radix)];
    const radix_base: limb_t = radix_base_table[rIndex(radix)];
    const radix_shift: c_int = ctz32(@intCast(radix));
    const radix1: c_int = @intCast(@as(u32, @intCast(radix)) >> @intCast(radix_shift));
    const radix_bits: c_int = if (radix1 == 1) radix_shift else 0;

    tmp0.len = 1;
    tab0[0] = 0;
    var extra_digits: limb_t = 0;
    var pos: c_int = 0;
    var dot_pos: c_int = -1;

    while (true) {
        if (str[p] == '.' and (p > p_start or toDigit(str[p + 1]) < radix) and (flags & JS_ATOD_INT_ONLY) == 0) {
            if (dot_pos >= 0) break;
            dot_pos = pos;
            p += 1;
        }
        if (sep <= 255 and str[p] == @as(u8, @intCast(sep)) and p > p_start and str[p + 1] == '0') p += 1;
        if (str[p] != '0') break;
        p += 1;
        pos += 1;
    }

    const sig_pos = pos;
    while (true) {
        if (str[p] == '.' and (p > p_start or toDigit(str[p + 1]) < radix) and (flags & JS_ATOD_INT_ONLY) == 0) {
            if (dot_pos >= 0) break;
            dot_pos = pos;
            p += 1;
        }
        if (sep <= 255 and str[p] == @as(u8, @intCast(sep)) and p > p_start and toDigit(str[p + 1]) < radix) p += 1;
        const c = toDigit(str[p]);
        if (c >= radix) break;
        p += 1;
        pos += 1;
        if (digit_count < max_digits) {
            cur_limb = cur_limb *% @as(limb_t, @intCast(radix)) +% @as(limb_t, @intCast(c));
            limb_digit_count += 1;
            if (limb_digit_count == digits_per_limb) {
                mpbMul1Base(tmp0, radix_base, cur_limb);
                cur_limb = 0;
                limb_digit_count = 0;
            }
            digit_count += 1;
        } else {
            extra_digits |= @intCast(c);
        }
    }
    if (limb_digit_count != 0) {
        mpbMul1Base(tmp0, @truncate(powUi(@intCast(radix), @intCast(limb_digit_count))), cur_limb);
    }

    const is_zero: bool = (digit_count == 0);
    if (is_zero) {
        expn_offset = 0;
    } else {
        if (dot_pos < 0) dot_pos = pos;
        expn_offset = sig_pos + digit_count - dot_pos;
    }

    if (radix_bits != 0 and extra_digits != 0) tab0[0] |= 1;

    var expn: c_int = 0;
    var expn_overflow = false;
    var is_bin_exp = false;
    if ((flags & JS_ATOD_INT_ONLY) == 0 and
        ((radix == 10 and (str[p] == 'e' or str[p] == 'E')) or
            (radix != 10 and (str[p] == '@' or
                (radix_bits >= 1 and radix_bits <= 4 and (str[p] == 'p' or str[p] == 'P'))))) and
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
        var c = toDigit(str[p]);
        if (c >= 10) return failAtod(str, pnext, p);
        expn = c;
        p += 1;
        while (true) {
            if (sep <= 255 and str[p] == @as(u8, @intCast(sep)) and toDigit(str[p + 1]) < 10) p += 1;
            c = toDigit(str[p]);
            if (c >= 10) break;
            if (!expn_overflow) {
                if (expn > @divTrunc((2147483647 - 2 - 9), 10)) {
                    expn_overflow = true;
                } else {
                    expn = expn * 10 + c;
                }
            }
            p += 1;
        }
        if (exp_is_neg) expn = -expn;
        if (!is_zero and expn_overflow) {
            const bits: u64 = if (exp_is_neg) 0 else (@as(u64, 0x7ff) << 52);
            return finishAtod(str, pnext, p, bits, is_neg);
        }
    }

    if (p == p_start) return failAtod(str, pnext, p);

    var bits: u64 = 0;
    if (is_zero) {
        bits = 0;
    } else {
        var e: c_int = 0;
        var m: u64 = 0;
        var forced: enum { none, underflow, overflow } = .none;
        if (radix_bits != 0) {
            if (!is_bin_exp) expn *= radix_bits;
            expn -= expn_offset * radix_bits;
            const expn1 = expn + digit_count * radix_bits;
            if (expn1 >= 1024 + radix_bits) {
                forced = .overflow;
            } else if (expn1 <= -1075) {
                forced = .underflow;
            } else {
                m = roundToD(&e, tmp0, -expn, JS_RNDN);
            }
        } else {
            expn -= expn_offset;
            const expn1 = expn + digit_count;
            if (expn1 >= @as(c_int, max_exponent[rIndex(radix)]) + 1) {
                forced = .overflow;
            } else if (expn1 <= @as(c_int, min_exponent[rIndex(radix)])) {
                forced = .underflow;
            } else {
                m = mulPowRoundToD(&e, tmp0, radix1, radix_shift, expn, JS_RNDN);
            }
        }

        if (forced == .underflow) {
            bits = 0;
        } else if (forced == .overflow) {
            bits = @as(u64, 0x7ff) << 52;
        } else if (m == 0) {
            bits = 0;
        } else if (e > 1024) {
            bits = @as(u64, 0x7ff) << 52;
        } else if (e < -1073) {
            bits = 0;
        } else if (e < -1021) {
            bits = m >> @intCast(-e - 1021);
        } else {
            bits = (@as(u64, @intCast(e + 1022)) << 52) | (m & ((@as(u64, 1) << 52) - 1));
        }
    }

    return finishAtod(str, pnext, p, bits, is_neg);
}

pub export fn mpb_dump(str: [*]const u8, a_any: *const anyopaque) callconv(.c) void {
    _ = str;
    _ = a_any;
}
