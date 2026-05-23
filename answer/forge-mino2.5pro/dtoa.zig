const std = @import("std");

pub const JSDTOATempMem = extern struct {
    mem: [37]u64,
};

pub const JSATODTempMem = extern struct {
    mem: [27]u64,
};

pub const JS_DTOA_MAX_DIGITS = 101;

pub const JS_DTOA_FORMAT_FREE  = 0 << 0;
pub const JS_DTOA_FORMAT_FIXED = 1 << 0;
pub const JS_DTOA_FORMAT_FRAC  = 2 << 0;
pub const JS_DTOA_FORMAT_MASK  = 3 << 0;

pub const JS_DTOA_EXP_AUTO     = 0 << 2;
pub const JS_DTOA_EXP_ENABLED  = 1 << 2;
pub const JS_DTOA_EXP_DISABLED = 2 << 2;
pub const JS_DTOA_EXP_MASK     = 3 << 2;

pub const JS_DTOA_MINUS_ZERO   = 1 << 4;

pub const JS_ATOD_INT_ONLY       = 1 << 0;
pub const JS_ATOD_ACCEPT_BIN_OCT = 1 << 1;
pub const JS_ATOD_ACCEPT_LEGACY_OCTAL  = 1 << 2;
pub const JS_ATOD_ACCEPT_UNDERSCORES  = 1 << 3;

// Type definitions matching C
const limb_t = u32;
const dlimb_t = u64;
const slimb_t = i32;
const mp_size_t = isize;

const LIMB_LOG2_BITS = 5;
const LIMB_BITS = 1 << LIMB_LOG2_BITS;
const LIMB_DIGITS = 9;
const JS_RADIX_MAX = 36;
const DBIGNUM_LEN_MAX = 52;
const MANT_LEN_MAX = 18;

// Rounding modes
const JS_RNDN = 0;   // round to nearest, ties to even
const JS_RNDNA = 1;  // round to nearest, ties away from zero
const JS_RNDZ = 2;   // round toward zero

// Multi-precision big number structure
// In C, this has a flexible array member. We'll use a pointer to the data.
const mpb_t = struct {
    len: c_int,
    tab: [*]limb_t,
};

// Helper to create mpb_t from raw memory
fn mpb_from_mem(ptr: [*]u64) *mpb_t {
    return @ptrCast(ptr);
}

fn mpb_tab_ptr(r: *mpb_t) [*]limb_t {
    return @ptrCast(@as([*]u8, @ptrCast(r)) + @sizeOf(mpb_t));
}

// Tables from C code
const pow5_table = [17]u32{
    0x00000005, 0x00000019, 0x0000007d, 0x00000271,
    0x00000c35, 0x00003d09, 0x0001312d, 0x0005f5e1,
    0x001dcd65, 0x009502f9, 0x02e90edd, 0x0e8d4a51,
    0x48c27395, 0x6bcc41e9, 0x1afd498d, 0x86f26fc1,
    0xa2bc2ec5,
};

const pow5h_table = [4]u32{
    0x00000001, 0x00000007, 0x00000023, 0x000000b1,
};

const pow5_inv_table = [13]u32{
    0x99999999, 0x47ae147a, 0x0624dd2f, 0xa36e2eb1,
    0x4f8b588e, 0x0c6f7a0b, 0xad7f29ab, 0x5798ee23,
    0x12e0be82, 0xb7cdfd9d, 0x5fd7fe17, 0x19799812,
    0xc25c2684,
};

const MUL_LOG2_RADIX_BASE_LOG2 = 24;

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

const digits_per_limb_table = [JS_RADIX_MAX - 1]u8{
    32,20,16,13,12,11,10,10, 9, 9, 8, 8, 8, 8, 8, 7, 7, 7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
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
    1024,   647,   512,   442,   397,   365,   342,   324,
    309,   297,   286,   277,   269,   263,   256,   251,
    246,   242,   237,   234,   230,   227,   224,   221,
    218,   216,   214,   211,   209,   207,   205,   203,
    202,   200,   199,
};

const min_exponent = [JS_RADIX_MAX - 1]i16{
    -1075,  -679,  -538,  -463,  -416,  -383,  -359,  -340,
    -324,  -311,  -300,  -291,  -283,  -276,  -269,  -263,
    -258,  -254,  -249,  -245,  -242,  -238,  -235,  -232,
    -229,  -227,  -224,  -222,  -220,  -217,  -215,  -214,
    -212,  -210,  -208,
};

// Helper functions from cutils.h
fn clz32(a: u32) c_int {
    return @intCast(@clz(a));
}

fn clz64(a: u64) c_int {
    return @intCast(@clz(a));
}

fn ctz32(a: u32) c_int {
    return @intCast(@ctz(a));
}

fn float64_as_uint64(d: f64) u64 {
    return @bitCast(d);
}

fn uint64_as_float64(u64_val: u64) f64 {
    return @bitCast(u64_val);
}

fn min_int(a: c_int, b: c_int) c_int {
    return if (a < b) a else b;
}

fn max_int(a: c_int, b: c_int) c_int {
    return if (a > b) a else b;
}

fn abs_val(x: c_int) c_int {
    return if (x < 0) -x else x;
}

fn js__strstart(str: [*]const u8, val: [*]const u8, ptr: *[*]const u8) bool {
    var p = str;
    var q = val;
    while (q[0] != 0) {
        if (p[0] != q[0]) return false;
        p += 1;
        q += 1;
    }
    ptr.* = p;
    return true;
}

fn to_digit(c: u8) c_int {
    if (c >= '0' and c <= '9') return @intCast(c - '0');
    if (c >= 'A' and c <= 'Z') return @intCast(c - 'A' + 10);
    if (c >= 'a' and c <= 'z') return @intCast(c - 'a' + 10);
    return 36;
}

// Multi-precision arithmetic functions
export fn mp_add_ui(tab: [*]align(1) limb_t, b: limb_t, n: usize) callconv(.c) limb_t {
    var k = b;
    var i: usize = 0;
    while (i < n) {
        if (k == 0) break;
        const a = tab[i] +% k;
        k = @intFromBool(a < k);
        tab[i] = a;
        i += 1;
    }
    return k;
}

export fn mp_mul1(tabr: [*]align(1) limb_t, taba: [*]align(1) const limb_t, n: limb_t, b: limb_t, l: limb_t) callconv(.c) limb_t {
    var l1 = l;
    var i: limb_t = 0;
    while (i < n) {
        const t: dlimb_t = @as(dlimb_t, taba[i]) *% @as(dlimb_t, b) +% @as(dlimb_t, l1);
        tabr[i] = @as(limb_t, @truncate(t));
        l1 = @as(limb_t, @truncate(t >> LIMB_BITS));
        i += 1;
    }
    return l1;
}

export fn udiv1norm_init(d: limb_t) callconv(.c) limb_t {
    const a1: limb_t = @bitCast(-%@as(i32, @bitCast(d)));
    const a0: limb_t = @bitCast(@as(i32, -1));
    return @truncate(((@as(dlimb_t, a1) << LIMB_BITS) | @as(dlimb_t, a0)) / d);
}

fn udiv1norm(pr: *limb_t, a1: limb_t, a0: limb_t, d: limb_t, d_inv: limb_t) limb_t {
    const n1m: limb_t = @bitCast(@as(i32, @bitCast(a0)) >> (LIMB_BITS - 1));
    const n_adj = a0 +% (n1m & d);
    const a: dlimb_t = @as(dlimb_t, d_inv) * @as(dlimb_t, a1 -% (n1m)) + @as(dlimb_t, n_adj);
    var q: limb_t = @truncate(a >> LIMB_BITS);
    q +%= a1;
    // compute a - q * r and update q so that the remainder is between 0 and d - 1
    const a2: dlimb_t = (@as(dlimb_t, a1) << LIMB_BITS) | @as(dlimb_t, a0);
    const a3: dlimb_t = a2 -% @as(dlimb_t, q) *% @as(dlimb_t, d) -% @as(dlimb_t, d);
    const ah: limb_t = @as(limb_t, @truncate(a3 >> LIMB_BITS));
    q +%= 1 +% ah;
    const r: limb_t = @as(limb_t, @truncate(a3)) +% (ah & d);
    pr.* = r;
    return q;
}

fn mp_div1(tabr: [*]align(1) limb_t, taba: [*]align(1) const limb_t, n: limb_t, b: limb_t, r: limb_t) limb_t {
    var r1 = r;
    var i: slimb_t = @intCast(n - 1);
    while (i >= 0) {
        const a1: dlimb_t = (@as(dlimb_t, r1) << LIMB_BITS) | @as(dlimb_t, taba[@intCast(i)]);
        tabr[@intCast(i)] = @truncate(a1 / b);
        r1 = @truncate(a1 % b);
        i -= 1;
    }
    return r1;
}

export fn mp_div1norm(tabr: [*]align(1) limb_t, taba: [*]align(1) const limb_t, n: limb_t, b: limb_t, r: limb_t, b_inv: limb_t, shift: c_int) callconv(.c) limb_t {
    var r1 = r;
    if (shift != 0) {
        r1 = (r1 << @intCast(shift)) | mp_shl(tabr, taba, @intCast(n), shift, 0);
    }
    var i: slimb_t = @intCast(n - 1);
    while (i >= 0) {
        var rem: limb_t = undefined;
        tabr[@intCast(i)] = udiv1norm(&rem, r1, taba[@intCast(i)], b, b_inv);
        r1 = rem;
        i -= 1;
    }
    r1 >>= @intCast(shift);
    return r1;
}

export fn mp_shr(tab_r: [*]align(1) limb_t, tab: [*]align(1) const limb_t, n: isize, shift: c_int, high: limb_t) callconv(.c) limb_t {
    var l = high;
    var i = n - 1;
    while (i >= 0) {
        const a = tab[@intCast(i)];
        tab_r[@intCast(i)] = (a >> @intCast(shift)) | (l << @intCast(LIMB_BITS - @as(u32, @intCast(shift))));
        l = a;
        i -= 1;
    }
    return l & ((@as(limb_t, 1) << @intCast(shift)) - 1);
}

export fn mp_shl(tab_r: [*]align(1) limb_t, tab: [*]align(1) const limb_t, n: isize, shift: c_int, low: limb_t) callconv(.c) limb_t {
    var l = low;
    var i: isize = 0;
    while (i < n) {
        const a = tab[@intCast(i)];
        tab_r[@intCast(i)] = (a << @intCast(shift)) | l;
        l = a >> @intCast(LIMB_BITS - @as(u32, @intCast(shift)));
        i += 1;
    }
    return l;
}

// MPB operations - using raw memory pointers to match C layout
fn mpb_get_len(a: *const anyopaque) c_int {
    return @as(*align(1) const c_int, @ptrCast(a)).*;
}

fn mpb_set_len(a: *anyopaque, len: c_int) void {
    @as(*align(1) c_int, @ptrCast(a)).* = len;
}

fn mpb_tab(a: *const anyopaque) [*]align(1) const limb_t {
    return @ptrCast(@as([*]const u8, @ptrCast(a)) + @sizeOf(c_int));
}

fn mpb_tab_mut(a: *anyopaque) [*]align(1) limb_t {
    return @ptrCast(@as([*]u8, @ptrCast(a)) + @sizeOf(c_int));
}

export fn mpb_dump(str: [*]const u8, a: *const anyopaque) callconv(.c) void {
    _ = str;
    _ = a;
    // Debug function - no-op in release
}

export fn mpb_renorm(r: *anyopaque) callconv(.c) void {
    const tab = mpb_tab_mut(r);
    var len = mpb_get_len(r);
    while (len > 1 and tab[@intCast(len - 1)] == 0) {
        len -= 1;
    }
    mpb_set_len(r, len);
}

export fn mpb_set_u64(r: *anyopaque, m: u64) callconv(.c) void {
    const tab = mpb_tab_mut(r);
    tab[0] = @truncate(m);
    tab[1] = @intCast(m >> LIMB_BITS);
    if (tab[1] == 0) {
        mpb_set_len(r, 1);
    } else {
        mpb_set_len(r, 2);
    }
}

export fn mpb_get_u64(r: *anyopaque) callconv(.c) u64 {
    const tab = mpb_tab(r);
    const len = mpb_get_len(r);
    if (len == 1) {
        return @as(u64, tab[0]);
    } else {
        return @as(u64, tab[0]) | (@as(u64, tab[1]) << LIMB_BITS);
    }
}

export fn mpb_floor_log2(a: *anyopaque) callconv(.c) c_int {
    const tab = mpb_tab(a);
    const len = mpb_get_len(a);
    const v = tab[@intCast(len - 1)];
    if (v == 0) return -1;
    return @intCast(@as(u32, @intCast(len)) * LIMB_BITS - 1 - @as(u32, @intCast(clz32(v))));
}

export fn mpb_get_bit(r: *const anyopaque, k: c_int) callconv(.c) c_int {
    const l: u32 = @intCast(@as(u32, @bitCast(k)) / LIMB_BITS);
    const k1 = @as(u32, @bitCast(k)) & (LIMB_BITS - 1);
    const len = mpb_get_len(r);
    if (l >= @as(u32, @intCast(len))) return 0;
    const tab = mpb_tab(r);
    return @intCast((tab[l] >> @intCast(k1)) & 1);
}

export fn mpb_shr_round(r: *anyopaque, shift: c_int, rnd_mode: c_int) callconv(.c) void {
    if (shift == 0) return;
    const tab = mpb_tab_mut(r);
    var len = mpb_get_len(r);
    
    if (shift < 0) {
        var s = -@as(i32, @intCast(shift));
        const l: u32 = @intCast(@as(u32, @bitCast(s)) / LIMB_BITS);
        s = @intCast(@as(u32, @bitCast(s)) & (LIMB_BITS - 1));
        if (s != 0) {
            tab[@intCast(len)] = mp_shl(tab, tab, @intCast(len), s, 0);
            len += 1;
            mpb_set_len(r, len);
            mpb_renorm(r);
            len = mpb_get_len(r);
        }
        if (l > 0) {
            var i: c_int = @intCast(len - 1);
            while (i >= 0) : (i -= 1) {
                tab[@intCast(i + @as(c_int, @intCast(l)))] = tab[@intCast(i)];
            }
            var j: u32 = 0;
            while (j < l) : (j += 1) {
                tab[j] = 0;
            }
            len += @intCast(l);
            mpb_set_len(r, len);
        }
    } else {
        var add_one: c_int = undefined;
        switch (rnd_mode) {
            JS_RNDZ => { add_one = 0; },
            JS_RNDN, JS_RNDNA => {
                const bit1 = mpb_get_bit(r, shift - 1);
                if (bit1 != 0) {
                    var bit2: limb_t = undefined;
                    if (rnd_mode == JS_RNDNA) {
                        bit2 = 1;
                    } else {
                        bit2 = 0;
                        if (shift >= 2) {
                            const k = shift - 1;
                            const l: u32 = @intCast(@as(u32, @bitCast(k)) / LIMB_BITS);
                            const k1 = @as(u32, @bitCast(k)) & (LIMB_BITS - 1);
                            const n = min_int(@intCast(l), len);
                            var i: c_int = 0;
                            while (i < n) : (i += 1) {
                                bit2 |= tab[@intCast(i)];
                            }
                            if (@as(c_int, @intCast(l)) < len) {
                                bit2 |= tab[l] & ((@as(limb_t, 1) << @intCast(k1)) - 1);
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
            else => { add_one = 0; },
        }
        
        const l: u32 = @intCast(@as(u32, @bitCast(shift)) / LIMB_BITS);
        const s = @as(u32, @bitCast(shift)) & (LIMB_BITS - 1);
        if (l >= @as(u32, @intCast(len))) {
            mpb_set_len(r, 1);
            tab[0] = @intCast(add_one);
        } else {
            if (l > 0) {
                len -= @intCast(l);
                mpb_set_len(r, len);
                var i: u32 = 0;
                while (i < @as(u32, @intCast(len))) : (i += 1) {
                    tab[i] = tab[i + l];
                }
            }
            if (s != 0) {
                _ = mp_shr(tab, tab, @intCast(mpb_get_len(r)), @intCast(s), 0);
                mpb_renorm(r);
                len = mpb_get_len(r);
            }
            if (add_one != 0) {
                const a1 = mp_add_ui(tab, 1, @intCast(len));
                if (a1 != 0) {
                    tab[@intCast(len)] = a1;
                    mpb_set_len(r, len + 1);
                }
            }
        }
    }
}

export fn mpb_cmp(a: *const anyopaque, b: *const anyopaque) callconv(.c) c_int {
    const a_len = mpb_get_len(a);
    const b_len = mpb_get_len(b);
    if (a_len < b_len) return -1;
    if (a_len > b_len) return 1;
    const a_tab = mpb_tab(a);
    const b_tab = mpb_tab(b);
    var i: mp_size_t = @intCast(a_len - 1);
    while (i >= 0) : (i -= 1) {
        if (a_tab[@intCast(i)] != b_tab[@intCast(i)]) {
            if (a_tab[@intCast(i)] < b_tab[@intCast(i)]) return -1;
            return 1;
        }
    }
    return 0;
}

export fn mpb_mul1_base(r: *anyopaque, radix_base: limb_t, b: limb_t) callconv(.c) void {
    const tab = mpb_tab_mut(r);
    var len = mpb_get_len(r);
    if (tab[0] == 0 and len == 1) {
        tab[0] = b;
    } else {
        if (radix_base == 0) {
            var i: c_int = @intCast(len);
            while (i >= 0) : (i -= 1) {
                tab[@intCast(i + 1)] = tab[@intCast(i)];
            }
            tab[0] = b;
        } else {
            tab[@intCast(len)] = mp_mul1(tab, tab, @intCast(len), radix_base, b);
        }
        len += 1;
        mpb_set_len(r, len);
        mpb_renorm(r);
    }
}

// pow_ui: compute a^b
export fn pow_ui(a: u32, b: u32) callconv(.c) u64 {
    if (b == 0) return 1;
    if (b == 1) return @as(u64, a);
    if ((a == 5 or a == 10) and b <= 17) {
        var r: u64 = @as(u64, pow5_table[b - 1]);
        if (b >= 14) {
            r |= @as(u64, pow5h_table[b - 14]) << 32;
        }
        if (a == 10) {
            r <<= @intCast(b);
        }
        return r;
    }
    var r: u64 = @as(u64, a);
    const n_bits: u32 = @intCast(32 - @as(u32, @intCast(clz32(b))));
    var i: i32 = @intCast(n_bits - 2);
    while (i >= 0) : (i -= 1) {
        r *= r;
        if ((b >> @intCast(i)) & 1 != 0) {
            r *= @as(u64, a);
        }
    }
    return r;
}

export fn pow_ui_inv(pr_inv: *u32, pshift: *c_int, a: u32, b: u32) callconv(.c) u32 {
    var r_inv: u32 = undefined;
    var r: u32 = undefined;
    var shift: c_int = undefined;
    
    if (a == 5 and b >= 1 and b <= 13) {
        r = pow5_table[b - 1];
        shift = clz32(r);
        r <<= @intCast(shift);
        r_inv = pow5_inv_table[b - 1];
    } else {
        r = @truncate(pow_ui(a, b));
        shift = clz32(r);
        r <<= @intCast(shift);
        r_inv = udiv1norm_init(r);
    }
    pshift.* = shift;
    pr_inv.* = r_inv;
    return r;
}

export fn mul_log2_radix(a: c_int, radix: c_int) callconv(.c) c_int {
    if ((radix & (radix - 1)) == 0) {
        const radix_bits: c_int = @intCast(31 - @as(u32, @intCast(clz32(@intCast(radix)))));
        var a1 = a;
        if (a1 < 0) {
            a1 -= radix_bits - 1;
        }
        return @divTrunc(a1, radix_bits);
    } else {
        const mult: i64 = @intCast(mul_log2_radix_table[@intCast(radix - 2)]);
        return @intCast((@as(i64, a) * mult) >> MUL_LOG2_RADIX_BASE_LOG2);
    }
}

fn u32toa_len(buf: [*]u8, n: u32, len: usize) void {
    var n1 = n;
    var i: usize = len;
    while (i > 0) {
        i -= 1;
        const digit = n1 % 10;
        n1 = n1 / 10;
        buf[i] = @intCast(digit + '0');
    }
}

fn u64toa_bin_len(buf: [*]u8, n: u64, radix_bits: u32, len: c_int) void {
    const mask: u32 = (@as(u32, 1) << @intCast(radix_bits)) - 1;
    var n1 = n;
    var i: c_int = @intCast(len - 1);
    while (i >= 0) : (i -= 1) {
        var digit: u8 = @intCast(@as(u32, @truncate(n1)) & mask);
        n1 >>= @intCast(radix_bits);
        if (digit < 10) {
            digit += '0';
        } else {
            digit += 'a' - 10;
        }
        buf[@intCast(i)] = digit;
    }
}

export fn limb_to_a(buf: [*]u8, n: limb_t, radix: u32, len: c_int) callconv(.c) void {
    if (radix == 10) {
        u32toa_len(buf, n, @intCast(len));
    } else {
        var n1 = n;
        var i: c_int = @intCast(len - 1);
        while (i >= 0) : (i -= 1) {
            var digit: u8 = @intCast(n1 % radix);
            n1 = n1 / radix;
            if (digit < 10) {
                digit += '0';
            } else {
                digit += 'a' - 10;
            }
            buf[@intCast(i)] = digit;
        }
    }
}

export fn output_digits(buf: [*]u8, a: *anyopaque, radix: c_int, n_digits1: c_int, dot_pos: c_int) callconv(.c) c_int {
    var n_digits = n_digits1;
    const radix_bits: c_int = if ((radix & (radix - 1)) == 0)
        @intCast(31 - @as(u32, @intCast(clz32(@intCast(radix)))))
    else
        0;
    const digits_per_limb: c_int = @intCast(digits_per_limb_table[@intCast(radix - 2)]);
    
    if (radix_bits != 0) {
        while (true) {
            const n = min_int(n_digits, digits_per_limb);
            n_digits -= n;
            u64toa_bin_len(buf + @as(usize, @intCast(n_digits)), @as(u64, mpb_tab(a)[0]), @intCast(radix_bits), n);
            if (n_digits == 0) break;
            mpb_shr_round(a, digits_per_limb * radix_bits, JS_RNDZ);
        }
    } else {
        while (n_digits != 0) {
            const n = min_int(n_digits, digits_per_limb);
            n_digits -= n;
            const r = mp_div1(mpb_tab_mut(a), mpb_tab(a), @intCast(mpb_get_len(a)), radix_base_table[@intCast(radix - 2)], 0);
            mpb_renorm(a);
            limb_to_a(buf + @as(usize, @intCast(n_digits)), r, @intCast(radix), n);
        }
    }
    
    var len = n_digits1;
    if (dot_pos != n_digits1) {
        // Insert dot
        var i: usize = @intCast(n_digits1);
        while (i > @as(usize, @intCast(dot_pos))) {
            buf[i] = buf[i - 1];
            i -= 1;
        }
        buf[@intCast(dot_pos)] = '.';
        len += 1;
    }
    return len;
}

fn mul_pow(a: *anyopaque, radix1: c_int, radix_shift: c_int, f: c_int, is_int: bool, e: c_int) c_int {
    var e_offset: c_int = -f * radix_shift;
    if (radix1 != 1) {
        const d: c_int = @intCast(digits_per_limb_table[@intCast(radix1 - 2)]);
        if (f >= 0) {
            var b: limb_t = 0;
            var n0: c_int = 0;
            var f1 = f;
            while (f1 != 0) {
                const n = min_int(f1, d);
                if (n != n0) {
                    b = @truncate(pow_ui(@intCast(radix1), @intCast(n)));
                    n0 = n;
                }
                const h = mp_mul1(mpb_tab_mut(a), mpb_tab(a), @intCast(mpb_get_len(a)), b, 0);
                if (h != 0) {
                    const len = mpb_get_len(a);
                    mpb_tab_mut(a)[@intCast(len)] = h;
                    mpb_set_len(a, len + 1);
                }
                f1 -= n;
            }
        } else {
            var f1 = -f;
            const l: c_int = @intCast(@divTrunc(f1 + d - 1, d));
            e_offset += l * @as(c_int, LIMB_BITS);
            var extra_bits: c_int = undefined;
            if (!is_int) {
                extra_bits = max_int(e - mpb_floor_log2(a), 0);
            } else {
                extra_bits = max_int(2 + e - e_offset, 0);
            }
            e_offset += extra_bits;
            mpb_shr_round(a, -(l * @as(c_int, LIMB_BITS) + extra_bits), JS_RNDZ);
            
            var b: limb_t = 0;
            var b_inv: limb_t = 0;
            var shift: c_int = 0;
            var n0: c_int = 0;
            var rem: limb_t = 0;
            while (f1 != 0) {
                const n = min_int(f1, d);
                if (n != n0) {
                    b = pow_ui_inv(&b_inv, &shift, @intCast(radix1), @intCast(n));
                    n0 = n;
                }
                const r1 = mp_div1norm(mpb_tab_mut(a), mpb_tab(a), @intCast(mpb_get_len(a)), b, 0, b_inv, shift);
                rem |= r1;
                mpb_renorm(a);
                f1 -= n;
            }
            mpb_tab_mut(a)[0] |= @intFromBool(rem != 0);
        }
    }
    return e_offset;
}

fn mul_pow_round(tmp1: *anyopaque, m: u64, e: c_int, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) void {
    mpb_set_u64(tmp1, m);
    const e_offset = mul_pow(tmp1, radix1, radix_shift, f, true, e);
    mpb_shr_round(tmp1, -e + e_offset, rnd_mode);
}

export fn round_to_d(pe: *c_int, a: *anyopaque, e_offset: c_int, rnd_mode: c_int) callconv(.c) u64 {
    const tab = mpb_tab(a);
    if (tab[0] == 0 and mpb_get_len(a) == 1) {
        pe.* = 0;
        return 0;
    }
    
    const e1: c_int = mpb_floor_log2(a) + 1 - e_offset;
    const prec1: c_int = 53;
    const e_min: c_int = -1021;
    var prec: c_int = undefined;
    if (e1 < e_min) {
        prec = prec1 - (e_min - e1);
    } else {
        prec = prec1;
    }
    mpb_shr_round(a, e1 + e_offset - prec, rnd_mode);
    var m1 = mpb_get_u64(a);
    m1 <<= @intCast(53 - prec);
    if (m1 >= @as(u64, 1) << 53) {
        m1 >>= 1;
        pe.* = e1 + 1;
    } else {
        pe.* = e1;
    }
    return m1;
}

export fn mul_pow_round_to_d(pe: *c_int, a: *anyopaque, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) callconv(.c) u64 {
    const e_offset = mul_pow(a, radix1, radix_shift, f, false, 55);
    return round_to_d(pe, a, e_offset, rnd_mode);
}

// Exported API functions
pub export fn js_dtoa_max_len(d: f64, radix: c_int, n_digits: c_int, flags: c_int) callconv(.c) c_int {
    const fmt = flags & JS_DTOA_FORMAT_MASK;
    var n: c_int = undefined;
    const a = float64_as_uint64(d);
    
    if (fmt != JS_DTOA_FORMAT_FRAC) {
        if (fmt == JS_DTOA_FORMAT_FREE) {
            n = @intCast(dtoa_max_digits_table[@intCast(radix - 2)]);
        } else {
            n = n_digits;
        }
        if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_DISABLED) {
            var e: c_int = @intCast((a >> 52) & 0x7ff);
            if (e == 0x7ff) {
                n = 0;
            } else {
                e -= 1023;
                n += 10 + abs_val(mul_log2_radix(e - 1, radix));
            }
        } else {
            n += 1 + 1 + 6;
        }
    } else {
        var e: c_int = @intCast((a >> 52) & 0x7ff);
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
    return max_int(n, 9);
}

fn dtoa_malloc(pptr: *[*]u64, size: usize) [*]u8 {
    const ret: [*]u8 = @ptrCast(pptr.*);
    pptr.* += (size + 7) / 8;
    return ret;
}

pub export fn js_dtoa(buf: [*]u8, d: f64, radix: c_int, n_digits: c_int, flags: c_int, tmp_mem: *JSDTOATempMem) callconv(.c) c_int {
    var mptr: [*]u64 = @ptrCast(&tmp_mem.mem);
    const a = float64_as_uint64(d);
    const sgn: c_int = @intCast(a >> 63);
    var e: c_int = @intCast((a >> 52) & 0x7ff);
    const m1: u64 = a & ((@as(u64, 1) << 52) - 1);
    var q = buf;
    const fmt = flags & JS_DTOA_FORMAT_MASK;
    
    // Allocate temporary storage
    const tmp1_ptr = dtoa_malloc(&mptr, @sizeOf(c_int) + @as(usize, DBIGNUM_LEN_MAX) * @sizeOf(limb_t));
    const mant_max_ptr = dtoa_malloc(&mptr, @sizeOf(c_int) + @as(usize, MANT_LEN_MAX) * @sizeOf(limb_t));
    
    const radix_shift = ctz32(@intCast(radix));
    const radix1 = @as(c_int, @intCast(@as(u32, @intCast(radix)) >> @intCast(radix_shift)));
    
    if (e == 0x7ff) {
        if (m1 == 0) {
            if (sgn != 0) {
                q[0] = '-';
                q += 1;
            }
            @memcpy(q[0..8], "Infinity");
            q += 8;
        } else {
            @memcpy(q[0..3], "NaN");
            q += 3;
        }
        q[0] = 0;
        return @intCast(@intFromPtr(q) - @intFromPtr(buf));
    }
    
    var is_denorm = false;
    if (e == 0) {
        if (m1 == 0) {
            mpb_set_len(@ptrCast(tmp1_ptr), 1);
            mpb_tab_mut(@ptrCast(tmp1_ptr))[0] = 0;
            const E: c_int = 1;
            var P: c_int = undefined;
            if (fmt == JS_DTOA_FORMAT_FREE) {
                P = 1;
            } else if (fmt == JS_DTOA_FORMAT_FRAC) {
                P = n_digits + 1;
            } else {
                P = n_digits;
            }
            if (sgn != 0 and (flags & JS_DTOA_MINUS_ZERO) != 0) {
                q[0] = '-';
                q += 1;
            }
            // goto output
            return output_and_format(q, buf, @ptrCast(tmp1_ptr), radix, P, E, fmt, flags, n_digits, radix1, radix_shift);
        }
        is_denorm = true;
        // denormal number: convert to a normal number
        const l: c_int = @intCast(@as(u32, @intCast(clz64(m1))) - 11);
        e -= l - 1;
    }
    
    if (sgn != 0) {
        q[0] = '-';
        q += 1;
    }
    
    var m: u64 = undefined;
    if (is_denorm) {
        // denormal - shift left to normalize
        const l: c_int = @intCast(@as(u32, @intCast(clz64(m1))) - 11);
        m = m1 << @intCast(l);
    } else {
        // normal number - set implicit bit
        m = m1 | ((@as(u64, 1) << 52));
    }
    e -= 1022;
    
    // Fast path for small integers
    if (fmt == JS_DTOA_FORMAT_FREE and e >= 1 and e <= 53 and
        (m & ((@as(u64, 1) << @intCast(53 - e)) - 1)) == 0 and
        (flags & JS_DTOA_EXP_MASK) != JS_DTOA_EXP_ENABLED) {
        m >>= @intCast(53 - e);
        q += u64toa_radix(q, m, @intCast(radix));
        q[0] = 0;
        return @intCast(@intFromPtr(q) - @intFromPtr(buf));
    }
    
    const E: c_int = 1 + mul_log2_radix(e - 1, radix);
    
    if (fmt == JS_DTOA_FORMAT_FREE) {
        const P_max: c_int = @intCast(dtoa_max_digits_table[@intCast(radix - 2)]);
        const E0 = E;
        var E_found: c_int = 0;
        var P_found: c_int = 0;
        var mant_found: u64 = 0;
        var P: c_int = P_max;
        
        while (true) {
            const mant_max1 = pow_ui(@intCast(radix), @intCast(P));
            var E1 = E0;
            var mant: u64 = undefined;
            while (true) {
                mul_pow_round(@ptrCast(tmp1_ptr), m, e - 53, radix1, radix_shift, P - E1, JS_RNDN);
                mant = mpb_get_u64(@ptrCast(tmp1_ptr));
                if (mant < mant_max1) break;
                E1 += 1;
            }
            var P1 = P;
            while ((mant % @as(u64, @intCast(radix))) == 0) {
                mant /= @as(u64, @intCast(radix));
                P1 -= 1;
            }
            if (P_found == 0) {
                P_found = P1;
                E_found = E1;
                mant_found = mant;
                if (P1 == 1) break;
                P = P1 - 1;
                continue;
            }
            mpb_set_u64(@ptrCast(tmp1_ptr), mant);
            var e1: c_int = undefined;
            const m_found = mul_pow_round_to_d(&e1, @ptrCast(tmp1_ptr), radix1, radix_shift, E1 - P1, JS_RNDN);
            if (m_found == m and e1 == e) {
                P_found = P1;
                E_found = E1;
                mant_found = mant;
                if (P1 == 1) break;
                P = P1 - 1;
            } else {
                break;
            }
        }
        mpb_set_u64(@ptrCast(tmp1_ptr), mant_found);
        return output_and_format(q, buf, @ptrCast(tmp1_ptr), radix, P_found, E_found, fmt, flags, n_digits, radix1, radix_shift);
    } else if (fmt == JS_DTOA_FORMAT_FRAC) {
        mul_pow_round(@ptrCast(tmp1_ptr), m, e - 53, radix1, radix_shift, n_digits, JS_RNDNA);
        var len = output_digits(q, @ptrCast(tmp1_ptr), radix, max_int(E + 1, 1) + n_digits, max_int(E + 1, 1));
        if (q[0] == '0' and len >= 2 and q[1] != '.') {
            len -= 1;
            var i: usize = 0;
            while (i < @as(usize, @intCast(len))) : (i += 1) {
                q[i] = q[i + 1];
            }
        }
        q += @intCast(len);
        q[0] = 0;
        return @intCast(@intFromPtr(q) - @intFromPtr(buf));
    } else {
        const P = n_digits;
        mpb_set_len(@ptrCast(mant_max_ptr), 1);
        mpb_tab_mut(@ptrCast(mant_max_ptr))[0] = 1;
        const pow_shift = mul_pow(@ptrCast(mant_max_ptr), radix1, radix_shift, P, false, 0);
        mpb_shr_round(@ptrCast(mant_max_ptr), pow_shift, JS_RNDZ);
        
        var E1 = E;
        while (true) {
            mul_pow_round(@ptrCast(tmp1_ptr), m, e - 53, radix1, radix_shift, P - E1, JS_RNDNA);
            if (mpb_cmp(@ptrCast(tmp1_ptr), @ptrCast(mant_max_ptr)) < 0) break;
            E1 += 1;
        }
        return output_and_format(q, buf, @ptrCast(tmp1_ptr), radix, P, E1, fmt, flags, n_digits, radix1, radix_shift);
    }
}

fn output_and_format(q: [*]u8, buf: [*]u8, tmp1: *anyopaque, radix: c_int, P: c_int, E: c_int, fmt: c_int, flags: c_int, n_digits: c_int, radix1: c_int, radix_shift: c_int) c_int {
    var q1 = q;
    var E_max: c_int = undefined;
    if (fmt == JS_DTOA_FORMAT_FIXED) {
        E_max = n_digits;
    } else {
        E_max = @as(c_int, @intCast(dtoa_max_digits_table[@intCast(radix - 2)])) + 4;
    }
    
    if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_ENABLED or
        ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_AUTO and (E <= -6 or E > E_max))) {
        q1 += @intCast(output_digits(q1, tmp1, radix, P, 1));
        var E1 = E - 1;
        if (radix == 10) {
            q1[0] = 'e';
            q1 += 1;
        } else if (radix1 == 1 and radix_shift <= 4) {
            E1 *= radix_shift;
            q1[0] = 'p';
            q1 += 1;
        } else {
            q1[0] = '@';
            q1 += 1;
        }
        if (E1 < 0) {
            q1[0] = '-';
            q1 += 1;
            E1 = -E1;
        } else {
            q1[0] = '+';
            q1 += 1;
        }
        q1 += u32toa(q1, @intCast(E1));
    } else if (E <= 0) {
        q1[0] = '0';
        q1[1] = '.';
        q1 += 2;
        var i: c_int = 0;
        while (i < -E) : (i += 1) {
            q1[0] = '0';
            q1 += 1;
        }
        q1 += @intCast(output_digits(q1, tmp1, radix, P, P));
    } else {
        q1 += @intCast(output_digits(q1, tmp1, radix, P, min_int(P, E)));
        var i: c_int = 0;
        while (i < E - P) : (i += 1) {
            q1[0] = '0';
            q1 += 1;
        }
    }
    q1[0] = 0;
    return @intCast(@intFromPtr(q1) - @intFromPtr(buf));
}

pub export fn js_atod(str: [*]const u8, pnext: [*c][*c]const u8, radix: c_int, flags: c_int, tmp_mem: *JSATODTempMem) callconv(.c) f64 {
    var mptr: [*]u64 = @ptrCast(&tmp_mem.mem);
    const tmp0_ptr = dtoa_malloc(&mptr, @sizeOf(c_int) + @as(usize, DBIGNUM_LEN_MAX) * @sizeOf(limb_t));
    
    const sep: c_int = if ((flags & JS_ATOD_ACCEPT_UNDERSCORES) != 0) '_' else 256;
    
    var p = str;
    var p_start = str;
    var is_neg: c_int = 0;
    
    if (p[0] == '+') {
        p += 1;
        p_start = p;
    } else if (p[0] == '-') {
        is_neg = 1;
        p += 1;
        p_start = p;
    }
    
    var radix1 = radix;
    var skip_digit_check = false;
    
    if (p[0] == '0') {
        if ((p[1] == 'x' or p[1] == 'X') and (radix1 == 0 or radix1 == 16)) {
            p += 2;
            radix1 = 16;
        } else if ((p[1] == 'o' or p[1] == 'O') and radix1 == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
            p += 2;
            radix1 = 8;
        } else if ((p[1] == 'b' or p[1] == 'B') and radix1 == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
            p += 2;
            radix1 = 2;
        } else if ((p[1] >= '0' and p[1] <= '9') and radix1 == 0 and (flags & JS_ATOD_ACCEPT_LEGACY_OCTAL) != 0) {
            var i: usize = 1;
            while (p[i] >= '0' and p[i] <= '7') {
                i += 1;
            }
            if (p[i] == '8' or p[i] == '9') {
                // no_prefix: skip digit validity check
                skip_digit_check = true;
            } else {
                p += 1;
                radix1 = 8;
            }
        }
        if (!skip_digit_check) {
            if (to_digit(p[0]) >= radix1) {
                if (pnext) |pn| pn.* = p;
                return std.math.nan(f64);
            }
        }
    } else {
        if ((flags & JS_ATOD_INT_ONLY) == 0) {
            var end: [*]const u8 = undefined;
            if (js__strstart(p, "Infinity", &end)) {
                const a: u64 = @as(u64, @intCast(is_neg)) << 63 | @as(u64, 0x7ff) << 52;
                if (pnext) |pn| pn.* = end;
                return uint64_as_float64(a);
            }
        }
    }
    
    if (radix1 == 0) radix1 = 10;
    
    var cur_limb: limb_t = 0;
    var expn_offset: c_int = 0;
    var digit_count: c_int = 0;
    var limb_digit_count: c_int = 0;
    const max_digits: c_int = @intCast(atod_max_digits_table[@intCast(radix1 - 2)]);
    const digits_per_limb: c_int = @intCast(digits_per_limb_table[@intCast(radix1 - 2)]);
    const radix_base: limb_t = radix_base_table[@intCast(radix1 - 2)];
    const r_shift = ctz32(@intCast(radix1));
    const r1: c_int = @intCast(@as(u32, @intCast(radix1)) >> @intCast(r_shift));
    const radix_bits: c_int = if (r1 == 1) @intCast(r_shift) else 0;
    
    mpb_set_len(@ptrCast(tmp0_ptr), 1);
    mpb_tab_mut(@ptrCast(tmp0_ptr))[0] = 0;
    var extra_digits: limb_t = 0;
    var pos: c_int = 0;
    var dot_pos: c_int = -1;
    
    // Skip leading zeros
    while (true) {
        if (p[0] == '.' and (@intFromPtr(p) > @intFromPtr(p_start) or @as(u32, @intCast(to_digit(p[1]))) < @as(u32, @intCast(radix1))) and (flags & JS_ATOD_INT_ONLY) == 0) {
            if (@as(c_int, @intCast(p[0])) == sep) {
                if (pnext) |pn| pn.* = p;
                return std.math.nan(f64);
            }
            if (dot_pos >= 0) break;
            dot_pos = pos;
            p += 1;
        }
        if (@as(c_int, @intCast(p[0])) == sep and @intFromPtr(p) > @intFromPtr(p_start) and p[1] == '0') {
            p += 1;
        }
        if (p[0] != '0') break;
        p += 1;
        pos += 1;
    }
    
    const sig_pos = pos;
    
    // Parse digits
    while (true) {
        if (p[0] == '.' and (@intFromPtr(p) > @intFromPtr(p_start) or @as(u32, @intCast(to_digit(p[1]))) < @as(u32, @intCast(radix1))) and (flags & JS_ATOD_INT_ONLY) == 0) {
            if (@as(c_int, @intCast(p[0])) == sep) {
                if (pnext) |pn| pn.* = p;
                return std.math.nan(f64);
            }
            if (dot_pos >= 0) break;
            dot_pos = pos;
            p += 1;
        }
        if (@as(c_int, @intCast(p[0])) == sep and @intFromPtr(p) > @intFromPtr(p_start) and @as(u32, @intCast(to_digit(p[1]))) < @as(u32, @intCast(radix1))) {
            p += 1;
        }
        const c: limb_t = @intCast(to_digit(p[0]));
        if (c >= @as(limb_t, @intCast(radix1))) break;
        p += 1;
        pos += 1;
        if (digit_count < max_digits) {
            cur_limb = cur_limb * @as(limb_t, @intCast(radix1)) + c;
            limb_digit_count += 1;
            if (limb_digit_count == digits_per_limb) {
                mpb_mul1_base(@ptrCast(tmp0_ptr), radix_base, cur_limb);
                cur_limb = 0;
                limb_digit_count = 0;
            }
            digit_count += 1;
        } else {
            extra_digits |= c;
        }
    }
    
    if (limb_digit_count != 0) {
        mpb_mul1_base(@ptrCast(tmp0_ptr), @truncate(pow_ui(@intCast(radix1), @intCast(limb_digit_count))), cur_limb);
    }
    
    var is_zero: bool = undefined;
    if (digit_count == 0) {
        is_zero = true;
        expn_offset = 0;
    } else {
        is_zero = false;
        var dp = dot_pos;
        if (dp < 0) dp = pos;
        expn_offset = sig_pos + digit_count - dp;
    }
    
    if (radix_bits != 0 and extra_digits != 0) {
        mpb_tab_mut(@ptrCast(tmp0_ptr))[0] |= 1;
    }
    
    // Parse exponent
    var expn: c_int = 0;
    var expn_overflow = false;
    var is_bin_exp = false;
    
    if ((flags & JS_ATOD_INT_ONLY) == 0 and
        ((radix1 == 10 and (p[0] == 'e' or p[0] == 'E')) or
         (radix1 != 10 and (p[0] == '@' or
                            (radix_bits >= 1 and radix_bits <= 4 and (p[0] == 'p' or p[0] == 'P'))))) and
        @intFromPtr(p) > @intFromPtr(p_start)) {
        is_bin_exp = (p[0] == 'p' or p[0] == 'P');
        p += 1;
        var exp_is_neg = false;
        if (p[0] == '+') {
            p += 1;
        } else if (p[0] == '-') {
            exp_is_neg = true;
            p += 1;
        }
        var c = to_digit(p[0]);
        if (c >= 10) {
            if (pnext) |pn| pn.* = p;
            return std.math.nan(f64);
        }
        expn = c;
        p += 1;
        while (true) {
            if (@as(c_int, @intCast(p[0])) == sep and @as(u32, @intCast(to_digit(p[1]))) < 10) {
                p += 1;
            }
            c = to_digit(p[0]);
            if (c >= 10) break;
            if (!expn_overflow) {
                if (expn > (@as(c_int, std.math.maxInt(i32)) - 2 - 9) / 10) {
                    expn_overflow = true;
                } else {
                    expn = expn * 10 + c;
                }
            }
            p += 1;
        }
        if (exp_is_neg) expn = -expn;
        if (!is_zero and expn_overflow) {
            var a: u64 = undefined;
            if (exp_is_neg) {
                a = 0;
            } else {
                a = @as(u64, 0x7ff) << 52;
            }
            a |= @as(u64, @intCast(is_neg)) << 63;
            if (pnext) |pn| pn.* = p;
            return uint64_as_float64(a);
        }
    }
    
    if (p == p_start) {
        if (pnext) |pn| pn.* = p;
        return std.math.nan(f64);
    }
    
    var a: u64 = undefined;
    if (is_zero) {
        a = 0;
    } else {
        var expn1: c_int = undefined;
        if (radix_bits != 0) {
            var e1 = expn;
            if (!is_bin_exp) e1 *= radix_bits;
            e1 -= expn_offset * radix_bits;
            expn1 = e1 + digit_count * radix_bits;
            if (expn1 >= 1024 + radix_bits) {
                a = @as(u64, 0x7ff) << 52;
                a |= @as(u64, @intCast(is_neg)) << 63;
                if (pnext) |pn| pn.* = p;
                return uint64_as_float64(a);
            } else if (expn1 <= -1075) {
                a = 0;
                a |= @as(u64, @intCast(is_neg)) << 63;
                if (pnext) |pn| pn.* = p;
                return uint64_as_float64(a);
            }
            var e_out: c_int = undefined;
            const m_out = round_to_d(&e_out, @ptrCast(tmp0_ptr), -e1, JS_RNDN);
            a = float_to_uint(e_out, m_out, is_neg);
        } else {
            expn -= expn_offset;
            expn1 = expn + digit_count;
            if (expn1 >= @as(c_int, max_exponent[@intCast(radix1 - 2)]) + 1) {
                a = @as(u64, 0x7ff) << 52;
                a |= @as(u64, @intCast(is_neg)) << 63;
                if (pnext) |pn| pn.* = p;
                return uint64_as_float64(a);
            } else if (expn1 <= @as(c_int, min_exponent[@intCast(radix1 - 2)])) {
                a = 0;
                a |= @as(u64, @intCast(is_neg)) << 63;
                if (pnext) |pn| pn.* = p;
                return uint64_as_float64(a);
            }
            var e_out: c_int = undefined;
            const m_out = mul_pow_round_to_d(&e_out, @ptrCast(tmp0_ptr), r1, @intCast(r_shift), expn, JS_RNDN);
            a = float_to_uint(e_out, m_out, is_neg);
        }
    }
    
    if (pnext) |pn| pn.* = p;
    return uint64_as_float64(a);
}

fn float_to_uint(e: c_int, m: u64, is_neg: c_int) u64 {
    var a: u64 = undefined;
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
    a |= @as(u64, @intCast(is_neg)) << 63;
    return a;
}

pub export fn u32toa(buf: [*]u8, n: u32) callconv(.c) usize {
    var buf1: [10]u8 = undefined;
    var n1 = n;
    var q: usize = 10;
    while (true) {
        q -= 1;
        buf1[q] = @intCast(n1 % 10 + '0');
        n1 /= 10;
        if (n1 == 0) break;
    }
    const len = 10 - q;
    @memcpy(buf[0..len], buf1[q..10]);
    return len;
}

pub export fn i32toa(buf: [*]u8, n: i32) callconv(.c) usize {
    if (n >= 0) {
        return u32toa(buf, @intCast(n));
    } else {
        buf[0] = '-';
        return u32toa(buf + 1, @intCast(-@as(i64, n))) + 1;
    }
}

pub export fn u64toa(buf: [*]u8, n: u64) callconv(.c) usize {
    if (n < 0x100000000) {
        return u32toa(buf, @intCast(n));
    } else {
        var q: usize = 0;
        var n1 = n / 1000000000;
        const n2: u32 = @intCast(n % 1000000000);
        if (n1 >= 0x100000000) {
            const n3: u32 = @intCast(n1 / 1000000000);
            n1 = n1 % 1000000000;
            if (n3 >= 10) {
                buf[q] = @intCast(n3 / 10 + '0');
                q += 1;
            }
            buf[q] = @intCast(@as(u32, @intCast(n3 % 10)) + '0');
            q += 1;
            u32toa_len(buf + q, @intCast(n1), 9);
            q += 9;
        } else {
            q += u32toa(buf + q, @intCast(n1));
        }
        u32toa_len(buf + q, n2, 9);
        q += 9;
        return q;
    }
}

pub export fn i64toa(buf: [*]u8, n: i64) callconv(.c) usize {
    if (n >= 0) {
        return u64toa(buf, @intCast(n));
    } else {
        buf[0] = '-';
        return u64toa(buf + 1, @intCast(-@as(i128, n))) + 1;
    }
}

pub export fn u64toa_radix(buf: [*]u8, n: u64, radix: c_uint) callconv(.c) usize {
    if (radix == 10) return u64toa(buf, n);
    if ((radix & (radix - 1)) == 0) {
        const radix_bits: u32 = @intCast(31 - @as(u32, @intCast(clz32(radix))));
        const l: c_int = if (n == 0) 1 else @intCast((64 - @as(u32, @intCast(clz64(n))) + radix_bits - 1) / radix_bits);
        u64toa_bin_len(buf, n, radix_bits, l);
        return @intCast(l);
    } else {
        var buf1: [41]u8 = undefined;
        var n1 = n;
        var q: usize = 41;
        while (true) {
            q -= 1;
            var digit: u8 = @intCast(n1 % radix);
            n1 /= radix;
            if (digit < 10) {
                digit += '0';
            } else {
                digit += 'a' - 10;
            }
            buf1[q] = digit;
            if (n1 == 0) break;
        }
        const len = 41 - q;
        @memcpy(buf[0..len], buf1[q..41]);
        return len;
    }
}

pub export fn i64toa_radix(buf: [*]u8, n: i64, radix: c_uint) callconv(.c) usize {
    if (n >= 0) {
        return u64toa_radix(buf, @intCast(n), radix);
    } else {
        buf[0] = '-';
        return u64toa_radix(buf + 1, @intCast(-@as(i128, n)), radix) + 1;
    }
}
