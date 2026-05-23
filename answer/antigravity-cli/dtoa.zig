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

const limb_t = u32;
const slimb_t = i32;
const dlimb_t = u64;

const LIMB_LOG2_BITS = 5;
const LIMB_BITS = 1 << LIMB_LOG2_BITS; // 32
const LIMB_DIGITS = 9;

const JS_RADIX_MAX = 36;

const DBIGNUM_LEN_MAX = 52;
const MANT_LEN_MAX = 18;

const mpb_t = struct {
    len: i32,
    
    pub fn tab(self: *mpb_t) [*]limb_t {
        return @ptrCast(@alignCast(@as([*]u8, @ptrCast(self)) + 4));
    }
    
    pub fn tabConst(self: *const mpb_t) [*]const limb_t {
        return @ptrCast(@alignCast(@as([*]const u8, @ptrCast(self)) + 4));
    }
};

inline fn clz32(a: u32) i32 {
    return @intCast(@clz(a));
}

inline fn clz64(a: u64) i32 {
    return @intCast(@clz(a));
}

inline fn float64_as_uint64(d: f64) u64 {
    return @bitCast(d);
}

inline fn uint64_as_float64(u64_val: u64) f64 {
    return @bitCast(u64_val);
}

fn js__strstart(str: [*]const u8, val: []const u8, ptr: ?*[*]const u8) bool {
    var p = str;
    var i: usize = 0;
    while (i < val.len) : (i += 1) {
        if (p[0] == 0 or p[0] != val[i]) return false;
        p += 1;
    }
    if (ptr) |out_ptr| {
        out_ptr.* = p;
    }
    return true;
}

fn dtoa_malloc(pptr: *[*]u64, size: usize) [*]u8 {
    const ret = pptr.*;
    const u64_size = (size + 7) / 8;
    pptr.* = ret + u64_size;
    return @ptrCast(ret);
}

export fn mp_add_ui(tab: [*]limb_t, b: limb_t, n: usize) callconv(.c) limb_t {
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

fn mp_mul1(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, l_in: limb_t) limb_t {
    var l = l_in;
    var i: limb_t = 0;
    while (i < n) : (i += 1) {
        const t = @as(dlimb_t, taba[i]) * @as(dlimb_t, b) + l;
        tabr[i] = @truncate(t);
        l = @truncate(t >> LIMB_BITS);
    }
    return l;
}

export fn udiv1norm_init(d: limb_t) callconv(.c) limb_t {
    const a1 = ~d;
    const a0: limb_t = 0xffffffff;
    const numerator = (@as(dlimb_t, a1) << LIMB_BITS) | a0;
    return @intCast(numerator / d);
}

fn udiv1norm(pr: *limb_t, a1: limb_t, a0: limb_t, d: limb_t, d_inv: limb_t) limb_t {
    const n1m: limb_t = @bitCast(@as(i32, @bitCast(a0)) >> (LIMB_BITS - 1));
    const n_adj = a0 +% (n1m & d);
    const a1_minus_n1m = a1 -% n1m;
    const a = @as(dlimb_t, d_inv) *% @as(dlimb_t, a1_minus_n1m) +% n_adj;
    var q = @as(limb_t, @truncate(a >> LIMB_BITS)) +% a1;
    const a2 = ((@as(dlimb_t, a1) << LIMB_BITS) | a0) -% (@as(dlimb_t, q) *% d) -% d;
    const ah: limb_t = @truncate(a2 >> LIMB_BITS);
    q = q +% 1 +% ah;
    const r = @as(limb_t, @truncate(a2)) +% (ah & d);
    pr.* = r;
    return q;
}

fn mp_div1(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r_in: limb_t) limb_t {
    var r = r_in;
    var i = @as(i32, @intCast(n)) - 1;
    while (i >= 0) : (i -= 1) {
        const idx: usize = @intCast(i);
        const a1 = (@as(dlimb_t, r) << LIMB_BITS) | taba[idx];
        tabr[idx] = @truncate(a1 / b);
        r = @truncate(a1 % b);
    }
    return r;
}

export fn mp_shr(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, high: limb_t) callconv(.c) limb_t {
    var l = high;
    const shift_u5: u5 = @intCast(shift);
    const bits_minus_shift_u5: u5 = @intCast(LIMB_BITS - shift);
    var i = n - 1;
    while (i >= 0) : (i -= 1) {
        const idx: usize = @intCast(i);
        const a = tab[idx];
        tab_r[idx] = (a >> shift_u5) | (l << bits_minus_shift_u5);
        l = a;
    }
    return l & ((@as(limb_t, 1) << shift_u5) -% 1);
}

export fn mp_shl(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, low: limb_t) callconv(.c) limb_t {
    var l = low;
    const shift_u5: u5 = @intCast(shift);
    const bits_minus_shift_u5: u5 = @intCast(LIMB_BITS - shift);
    var i: isize = 0;
    while (i < n) : (i += 1) {
        const idx: usize = @intCast(i);
        const a = tab[idx];
        tab_r[idx] = (a << shift_u5) | l;
        l = a >> bits_minus_shift_u5;
    }
    return l;
}

export fn mp_div1norm(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r_in: limb_t, b_inv: limb_t, shift: c_int) callconv(.c) limb_t {
    var r = r_in;
    if (shift != 0) {
        r = (r << @as(u5, @intCast(shift))) | mp_shl(tabr, taba, @intCast(n), shift, 0);
    }
    var i = @as(i32, @intCast(n)) - 1;
    while (i >= 0) : (i -= 1) {
        const idx: usize = @intCast(i);
        tabr[idx] = udiv1norm(&r, r, taba[idx], b, b_inv);
    }
    if (shift != 0) {
        r >>= @as(u5, @intCast(shift));
    }
    return r;
}

export fn mpb_dump(str: [*]const u8, a: *const anyopaque) callconv(.c) void {
    const mpb: *const mpb_t = @ptrCast(@alignCast(a));
    const tab = mpb.tabConst();
    std.debug.print("{s}= 0x", .{std.mem.span(@as([*:0]const u8, @ptrCast(str)))});
    var i = mpb.len - 1;
    while (i >= 0) : (i -= 1) {
        std.debug.print("{x:0>8}", .{tab[@intCast(i)]});
        if (i != 0) {
            std.debug.print("_", .{});
        }
    }
    std.debug.print("\n", .{});
}

export fn mpb_renorm(r_opaque: *anyopaque) callconv(.c) void {
    const r: *mpb_t = @ptrCast(@alignCast(r_opaque));
    const tab = r.tab();
    while (r.len > 1 and tab[@intCast(r.len - 1)] == 0) {
        r.len -= 1;
    }
}

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

export fn pow_ui(radix: c_int, n: c_int) callconv(.c) u64 {
    const a: u32 = @intCast(radix);
    const b: u32 = @intCast(n);
    if (b == 0) return 1;
    if (b == 1) return a;
    
    if ((a == 5 or a == 10) and b <= 17) {
        var r: u64 = pow5_table[b - 1];
        if (b >= 14) {
            r |= @as(u64, pow5h_table[b - 14]) << 32;
        }
        if (a == 10) {
            r <<= @intCast(b);
        }
        return r;
    }
    
    var r = @as(u64, a);
    const n_bits: u5 = @intCast(32 - clz32(b));
    var i = @as(i32, n_bits) - 2;
    while (i >= 0) : (i -= 1) {
        r = r *% r;
        if (((b >> @as(u5, @intCast(i))) & 1) != 0) {
            r = r *% a;
        }
    }
    return r;
}

fn pow_ui_inv_internal(pr_inv: *u32, pshift: *c_int, radix: c_int, n: c_int) u32 {
    const a: u32 = @intCast(radix);
    const b: u32 = @intCast(n);
    var r_inv: u32 = 0;
    var r: u32 = 0;
    var shift: c_int = 0;
    
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
    return r;
}

export fn pow_ui_inv(pr_inv: *u32, pshift: *c_int, radix: c_int, n: c_int) callconv(.c) void {
    _ = pow_ui_inv_internal(pr_inv, pshift, radix, n);
}

const JS_RNDN = 0;
const JS_RNDNA = 1;
const JS_RNDZ = 2;

fn mpb_get_bit_internal(r: *const mpb_t, pos: i32) i32 {
    const k: u32 = @intCast(pos);
    const l = k / LIMB_BITS;
    const bit_idx: u5 = @intCast(k & (LIMB_BITS - 1));
    if (l >= r.len) {
        return 0;
    } else {
        const tab = r.tabConst();
        return @intCast((tab[l] >> bit_idx) & 1);
    }
}

export fn mpb_get_bit(r_opaque: *const anyopaque, pos: c_int) callconv(.c) c_int {
    const r: *const mpb_t = @ptrCast(@alignCast(r_opaque));
    return mpb_get_bit_internal(r, pos);
}

export fn mpb_shr_round(r_opaque: *anyopaque, shift_in: c_int, rnd_mode: c_int) callconv(.c) void {
    const r: *mpb_t = @ptrCast(@alignCast(r_opaque));
    const tab = r.tab();
    var shift = shift_in;

    if (shift == 0) return;
    if (shift < 0) {
        shift = -shift;
        const l = @as(usize, @intCast(shift)) / LIMB_BITS;
        const shift_mod = @as(c_int, @intCast(@as(usize, @intCast(shift)) & (LIMB_BITS - 1)));
        if (shift_mod != 0) {
            tab[@intCast(r.len)] = mp_shl(tab, tab, r.len, shift_mod, 0);
            r.len += 1;
            mpb_renorm(r);
        }
        if (l > 0) {
            var i = r.len - 1;
            while (i >= 0) : (i -= 1) {
                tab[@intCast(i + @as(i32, @intCast(l)))] = tab[@intCast(i)];
            }
            var j: usize = 0;
            while (j < l) : (j += 1) {
                tab[j] = 0;
            }
            r.len += @intCast(l);
        }
    } else {
        var bit1: i32 = 0;
        var bit2: i32 = 0;
        var add_one: i32 = 0;
        
        switch (rnd_mode) {
            JS_RNDZ => {
                add_one = 0;
            },
            JS_RNDN, JS_RNDNA => {
                bit1 = mpb_get_bit_internal(r, shift - 1);
                if (bit1 != 0) {
                    if (rnd_mode == JS_RNDNA) {
                        bit2 = 1;
                    } else {
                        bit2 = 0;
                        if (shift >= 2) {
                            const k = shift - 1;
                            const l = @as(usize, @intCast(k)) / LIMB_BITS;
                            const bit_idx = @as(u5, @intCast(@as(usize, @intCast(k)) & (LIMB_BITS - 1)));
                            
                            var i: usize = 0;
                            const limit = @min(l, @as(usize, @intCast(r.len)));
                            while (i < limit) : (i += 1) {
                                if (tab[i] != 0) bit2 = 1;
                            }
                            if (l < @as(usize, @intCast(r.len))) {
                                if ((tab[l] & ((@as(limb_t, 1) << bit_idx) -% 1)) != 0) bit2 = 1;
                            }
                        }
                    }
                    if (bit2 != 0) {
                        add_one = 1;
                    } else {
                        add_one = mpb_get_bit_internal(r, shift);
                    }
                } else {
                    add_one = 0;
                }
            },
            else => {
                add_one = 0;
            },
        }

        const l = @as(usize, @intCast(shift)) / LIMB_BITS;
        const shift_mod = @as(c_int, @intCast(@as(usize, @intCast(shift)) & (LIMB_BITS - 1)));
        if (l >= @as(usize, @intCast(r.len))) {
            r.len = 1;
            tab[0] = @intCast(add_one);
        } else {
            if (l > 0) {
                r.len -= @intCast(l);
                var i: usize = 0;
                while (i < @as(usize, @intCast(r.len))) : (i += 1) {
                    tab[i] = tab[i + l];
                }
            }
            if (shift_mod != 0) {
                _ = mp_shr(tab, tab, r.len, shift_mod, 0);
                mpb_renorm(r);
            }
            if (add_one != 0) {
                const a = mp_add_ui(tab, 1, @intCast(r.len));
                if (a != 0) {
                    tab[@intCast(r.len)] = a;
                    r.len += 1;
                }
            }
        }
    }
}

export fn mpb_cmp(a_opaque: *const anyopaque, b_opaque: *const anyopaque) callconv(.c) c_int {
    const a: *const mpb_t = @ptrCast(@alignCast(a_opaque));
    const b: *const mpb_t = @ptrCast(@alignCast(b_opaque));
    if (a.len < b.len) return -1;
    if (a.len > b.len) return 1;
    const a_tab = a.tabConst();
    const b_tab = b.tabConst();
    var i = a.len - 1;
    while (i >= 0) : (i -= 1) {
        const idx: usize = @intCast(i);
        if (a_tab[idx] != b_tab[idx]) {
            if (a_tab[idx] < b_tab[idx]) return -1 else return 1;
        }
    }
    return 0;
}

export fn mpb_set_u64(r_opaque: *anyopaque, m: u64) callconv(.c) void {
    const r: *mpb_t = @ptrCast(@alignCast(r_opaque));
    const tab = r.tab();
    tab[0] = @truncate(m);
    tab[1] = @truncate(m >> LIMB_BITS);
    if (tab[1] == 0) {
        r.len = 1;
    } else {
        r.len = 2;
    }
}

export fn mpb_get_u64(r_opaque: *anyopaque) callconv(.c) u64 {
    const r: *mpb_t = @ptrCast(@alignCast(r_opaque));
    const tab = r.tab();
    if (r.len == 1) {
        return tab[0];
    } else {
        return tab[0] | (@as(u64, tab[1]) << LIMB_BITS);
    }
}

fn mpb_floor_log2_internal(a: *mpb_t) i32 {
    const tab = a.tab();
    const v = tab[@intCast(a.len - 1)];
    if (v == 0) {
        return -1;
    } else {
        return @intCast(a.len * LIMB_BITS - 1 - clz32(v));
    }
}

export fn mpb_floor_log2(a_opaque: *anyopaque) callconv(.c) c_int {
    const a: *mpb_t = @ptrCast(@alignCast(a_opaque));
    return mpb_floor_log2_internal(a);
}

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

export fn mul_log2_radix(a: c_int, radix: c_int) callconv(.c) c_int {
    const r_u = @as(u32, @intCast(radix));
    if ((r_u & (r_u - 1)) == 0) {
        const radix_bits = 31 - clz32(r_u);
        var val = a;
        if (val < 0) {
            val -= radix_bits - 1;
        }
        return @divTrunc(val, radix_bits);
    } else {
        const mult = mul_log2_radix_table[@intCast(radix - 2)];
        const result = (@as(i64, a) * mult) >> MUL_LOG2_RADIX_BASE_LOG2;
        return @intCast(result);
    }
}

fn u32toa_len(buf: [*]u8, n_in: u32, len: usize) void {
    var n = n_in;
    var i = @as(i32, @intCast(len)) - 1;
    while (i >= 0) : (i -= 1) {
        const digit = n % 10;
        n = n / 10;
        buf[@intCast(i)] = @intCast(digit + '0');
    }
}

fn u64toa_bin_len(buf: [*]u8, n_in: u64, radix_bits: u32, len: c_int) void {
    var n = n_in;
    const mask = (@as(u32, 1) << @intCast(radix_bits)) - 1;
    const shift: u6 = @intCast(radix_bits);
    var i = len - 1;
    while (i >= 0) : (i -= 1) {
        var digit = @as(u32, @truncate(n)) & mask;
        n >>= shift;
        if (digit < 10) {
            digit += '0';
        } else {
            digit += 'a' - 10;
        }
        buf[@intCast(i)] = @truncate(digit);
    }
}

export fn limb_to_a(buf: [*]u8, a: limb_t, radix: c_int, len: c_int) callconv(.c) void {
    const rad = @as(u32, @intCast(radix));
    var n = a;
    if (rad == 10) {
        u32toa_len(buf, n, @intCast(len));
    } else {
        var i = len - 1;
        while (i >= 0) : (i -= 1) {
            var digit = n % rad;
            n = n / rad;
            if (digit < 10) {
                digit += '0';
            } else {
                digit += 'a' - 10;
            }
            buf[@intCast(i)] = @truncate(digit);
        }
    }
}

pub export fn u32toa(buf: [*]u8, n_val: u32) callconv(.c) usize {
    var n = n_val;
    var buf1: [10]u8 = undefined;
    var idx: usize = 10;
    while (true) {
        idx -= 1;
        buf1[idx] = @truncate(n % 10 + '0');
        n /= 10;
        if (n == 0) break;
    }
    const len = 10 - idx;
    @memcpy(buf[0..len], buf1[idx .. idx + len]);
    return len;
}

pub export fn i32toa(buf: [*]u8, n: i32) callconv(.c) usize {
    if (n >= 0) {
        return u32toa(buf, @intCast(n));
    } else {
        buf[0] = '-';
        const abs_val = -%@as(u32, @bitCast(n));
        return u32toa(buf + 1, abs_val) + 1;
    }
}

pub export fn u64toa(buf: [*]u8, n_val: u64) callconv(.c) usize {
    var n = n_val;
    if (n < 0x100000000) {
        return u32toa(buf, @truncate(n));
    } else {
        var q = buf;
        var n1 = n / 1000000000;
        n %= 1000000000;
        if (n1 >= 0x100000000) {
            var n2 = @as(u32, @truncate(n1 / 1000000000));
            n1 = n1 % 1000000000;
            if (n2 >= 10) {
                q[0] = @truncate(n2 / 10 + '0');
                q += 1;
                n2 %= 10;
            }
            q[0] = @truncate(n2 + '0');
            q += 1;
            u32toa_len(q, @truncate(n1), 9);
            q += 9;
        } else {
            const added = u32toa(q, @truncate(n1));
            q += added;
        }
        u32toa_len(q, @truncate(n), 9);
        q += 9;
        return @intFromPtr(q) - @intFromPtr(buf);
    }
}

pub export fn i64toa(buf: [*]u8, n: i64) callconv(.c) usize {
    if (n >= 0) {
        return u64toa(buf, @intCast(n));
    } else {
        buf[0] = '-';
        const abs_val = -%@as(u64, @bitCast(n));
        return u64toa(buf + 1, abs_val) + 1;
    }
}

pub export fn u64toa_radix(buf: [*]u8, n_val: u64, radix: c_uint) callconv(.c) usize {
    var n = n_val;
    if (radix == 10) {
        return u64toa(buf, n);
    }
    if ((radix & (radix - 1)) == 0) {
        const radix_bits = 31 - clz32(radix);
        var l: c_int = 0;
        if (n == 0) {
            l = 1;
        } else {
            l = @divTrunc(@as(c_int, @intCast(64 - clz64(n))) + @as(c_int, @intCast(radix_bits)) - 1, @as(c_int, @intCast(radix_bits)));
        }
        u64toa_bin_len(buf, n, @intCast(radix_bits), l);
        return @intCast(l);
    } else {
        var buf1: [41]u8 = undefined;
        var idx: usize = 41;
        while (true) {
            idx -= 1;
            var digit = @as(u32, @truncate(n % radix));
            n /= radix;
            if (digit < 10) {
                digit += '0';
            } else {
                digit += 'a' - 10;
            }
            buf1[idx] = @truncate(digit);
            if (n == 0) break;
        }
        const len = 41 - idx;
        @memcpy(buf[0..len], buf1[idx .. idx + len]);
        return len;
    }
}

pub export fn i64toa_radix(buf: [*]u8, n: i64, radix: c_uint) callconv(.c) usize {
    if (n >= 0) {
        return u64toa_radix(buf, @intCast(n), radix);
    } else {
        buf[0] = '-';
        const abs_val = -%@as(u64, @bitCast(n));
        return u64toa_radix(buf + 1, abs_val, radix) + 1;
    }
}

export fn mpb_mul1_base(r_opaque: *anyopaque, radix_base: limb_t, b: limb_t) callconv(.c) void {
    const r: *mpb_t = @ptrCast(@alignCast(r_opaque));
    const tab = r.tab();
    if (tab[0] == 0 and r.len == 1) {
        tab[0] = b;
    } else {
        if (radix_base == 0) {
            var i = r.len;
            while (i >= 0) : (i -= 1) {
                tab[@intCast(i + 1)] = tab[@intCast(i)];
            }
            tab[0] = b;
        } else {
            tab[@intCast(r.len)] = mp_mul1(tab, tab, @intCast(r.len), radix_base, b);
        }
        r.len += 1;
        mpb_renorm(r);
    }
}

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

export fn output_digits(buf: [*]u8, a_opaque: *const anyopaque, radix: c_int, n_digits_in: c_int, dot_pos: c_int) callconv(.c) c_int {
    const a: *mpb_t = @ptrCast(@constCast(@alignCast(a_opaque)));
    const tab = a.tab();
    var n_digits = n_digits_in;
    
    var radix_bits: c_int = 0;
    const rad = @as(u32, @intCast(radix));
    if ((rad & (rad - 1)) == 0) {
        radix_bits = 31 - clz32(rad);
    }
    
    const digits_per_limb = digits_per_limb_table[@intCast(radix - 2)];
    if (radix_bits != 0) {
        while (true) {
            const n = @min(n_digits, @as(c_int, digits_per_limb));
            n_digits -= n;
            u64toa_bin_len(buf + @as(usize, @intCast(n_digits)), tab[0], @intCast(radix_bits), n);
            if (n_digits == 0) break;
            mpb_shr_round(a, @intCast(digits_per_limb * radix_bits), JS_RNDZ);
        }
    } else {
        while (n_digits != 0) {
            const n = @min(n_digits, @as(c_int, digits_per_limb));
            n_digits -= n;
            const r = mp_div1(tab, tab, @intCast(a.len), radix_base_table[@intCast(radix - 2)], 0);
            mpb_renorm(a);
            limb_to_a(buf + @as(usize, @intCast(n_digits)), r, radix, n);
        }
    }
    
    const len = n_digits_in;
    if (dot_pos != n_digits_in) {
        std.mem.copyBackwards(u8, buf[@intCast(dot_pos + 1) .. @intCast(n_digits_in + 1)], buf[@intCast(dot_pos) .. @intCast(n_digits_in)]);
        buf[@intCast(dot_pos)] = '.';
        return len + 1;
    }
    return len;
}

fn mul_pow(a: *mpb_t, radix1: i32, radix_shift: i32, f_in: i32, is_int: bool, e: i32) i32 {
    var f = f_in;
    const tab = a.tab();
    var e_offset = -f * radix_shift;
    if (radix1 != 1) {
        const d = @as(i32, digits_per_limb_table[@intCast(radix1 - 2)]);
        if (f >= 0) {
            var b: u64 = 0;
            var n0: i32 = 0;
            while (f != 0) {
                const n = @min(f, d);
                if (n != n0) {
                    b = pow_ui(radix1, n);
                    n0 = n;
                }
                const h = mp_mul1(tab, tab, @intCast(a.len), @truncate(b), 0);
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
            var extra_bits: i32 = 0;
            if (!is_int) {
                extra_bits = @max(e - mpb_floor_log2_internal(a), 0);
            } else {
                extra_bits = @max(2 + e - e_offset, 0);
            }
            e_offset += extra_bits;
            mpb_shr_round(a, -(l * LIMB_BITS + extra_bits), JS_RNDZ);
            
            var b: u32 = 0;
            var b_inv: u32 = 0;
            var shift: c_int = 0;
            var n0: i32 = 0;
            var rem: limb_t = 0;
            while (f != 0) {
                const n = @min(f, d);
                if (n != n0) {
                    b = pow_ui_inv_internal(&b_inv, &shift, radix1, n);
                    n0 = n;
                }
                const r = mp_div1norm(tab, tab, @intCast(a.len), b, 0, b_inv, shift);
                rem |= r;
                mpb_renorm(a);
                f -= n;
            }
            if (rem != 0) {
                tab[0] |= 1;
            }
        }
    }
    return e_offset;
}

fn mul_pow_round(tmp1: *mpb_t, m: u64, e: i32, radix1: i32, radix_shift: i32, f: i32, rnd_mode: i32) void {
    mpb_set_u64(tmp1, m);
    const e_offset = mul_pow(tmp1, radix1, radix_shift, f, true, e);
    mpb_shr_round(tmp1, -e + e_offset, rnd_mode);
}

export fn round_to_d(pe: *c_int, a_opaque: *anyopaque, e_offset: c_int, rnd_mode: c_int) callconv(.c) u64 {
    const a: *mpb_t = @ptrCast(@alignCast(a_opaque));
    const tab = a.tab();
    var e: c_int = 0;
    var m: u64 = 0;
    
    if (tab[0] == 0 and a.len == 1) {
        m = 0;
        e = 0;
    } else {
        var prec: c_int = 0;
        const prec1 = 53;
        const e_min = -1021;
        e = mpb_floor_log2_internal(a) + 1 - e_offset;
        if (e < e_min) {
            prec = prec1 - (e_min - e);
        } else {
            prec = prec1;
        }
        mpb_shr_round(a, e + e_offset - prec, rnd_mode);
        m = mpb_get_u64(a);
        m <<= @intCast(53 - prec);
        if (m >= (@as(u64, 1) << 53)) {
            m >>= 1;
            e += 1;
        }
    }
    pe.* = e;
    return m;
}

export fn mul_pow_round_to_d(pe: *c_int, a_opaque: *anyopaque, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) callconv(.c) u64 {
    const a: *mpb_t = @ptrCast(@alignCast(a_opaque));
    const e_offset = mul_pow(a, radix1, radix_shift, f, false, 55);
    return round_to_d(pe, a, e_offset, rnd_mode);
}

pub export fn js_dtoa_max_len(d: f64, radix: c_int, n_digits: c_int, flags: c_int) callconv(.c) c_int {
    const fmt = flags & JS_DTOA_FORMAT_MASK;
    var n: c_int = 0;
    var e: c_int = 0;
    var a: u64 = 0;
    
    if (fmt != JS_DTOA_FORMAT_FRAC) {
        if (fmt == JS_DTOA_FORMAT_FREE) {
            n = dtoa_max_digits_table[@intCast(radix - 2)];
        } else {
            n = n_digits;
        }
        if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_DISABLED) {
            a = float64_as_uint64(d);
            e = @intCast((a >> 52) & 0x7ff);
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
        a = float64_as_uint64(d);
        e = @intCast((a >> 52) & 0x7ff);
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

fn output_label(q_in: [*]u8, tmp1: *mpb_t, radix: c_int, P: c_int, E_in: c_int, flags: c_int, n_digits: c_int) [*]u8 {
    var q = q_in;
    var E = E_in;
    const fmt = flags & JS_DTOA_FORMAT_MASK;
    var E_max: c_int = 0;
    if (fmt == JS_DTOA_FORMAT_FIXED) {
        E_max = n_digits;
    } else {
        E_max = dtoa_max_digits_table[@intCast(radix - 2)] + 4;
    }
    
    if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_ENABLED or
        ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_AUTO and (E <= -6 or E > E_max))) {
        q += @intCast(output_digits(q, tmp1, radix, P, 1));
        E -= 1;
        if (radix == 10) {
            q[0] = 'e';
            q += 1;
        } else {
            const radix_shift = @as(u5, @intCast(@ctz(@as(u32, @intCast(radix)))));
            const radix1 = radix >> radix_shift;
            if (radix1 == 1 and radix_shift <= 4) {
                E *= radix_shift;
                q[0] = 'p';
                q += 1;
            } else {
                q[0] = '@';
                q += 1;
            }
        }
        if (E < 0) {
            q[0] = '-';
            q += 1;
            E = -E;
        } else {
            q[0] = '+';
            q += 1;
        }
        q += u32toa(q, @intCast(E));
    } else if (E <= 0) {
        q[0] = '0';
        q[1] = '.';
        q += 2;
        var i: usize = 0;
        while (i < @as(usize, @intCast(-E))) : (i += 1) {
            q[0] = '0';
            q += 1;
        }
        q += @intCast(output_digits(q, tmp1, radix, P, P));
    } else {
        q += @intCast(output_digits(q, tmp1, radix, P, @min(P, E)));
        var i: usize = 0;
        const diff_ep = E - P;
        if (diff_ep > 0) {
            while (i < @as(usize, @intCast(diff_ep))) : (i += 1) {
                q[0] = '0';
                q += 1;
            }
        }
    }
    return q;
}

pub export fn js_dtoa(buf: [*]u8, d: f64, radix: c_int, n_digits: c_int, flags: c_int, tmp_mem: *JSDTOATempMem) callconv(.c) c_int {
    var mptr = @as([*]u64, @ptrCast(&tmp_mem.mem));
    const fmt = flags & JS_DTOA_FORMAT_MASK;
    
    const tmp1: *mpb_t = @ptrCast(@alignCast(dtoa_malloc(&mptr, @sizeOf(mpb_t) + @sizeOf(limb_t) * DBIGNUM_LEN_MAX)));
    const mant_max: *mpb_t = @ptrCast(@alignCast(dtoa_malloc(&mptr, @sizeOf(mpb_t) + @sizeOf(limb_t) * MANT_LEN_MAX)));
    
    const diff = @intFromPtr(mptr) - @intFromPtr(&tmp_mem.mem);
    std.debug.assert(diff <= @sizeOf(JSDTOATempMem));
    
    const radix_shift = @as(u5, @intCast(@ctz(@as(u32, @intCast(radix)))));
    const radix1 = radix >> radix_shift;
    const a = float64_as_uint64(d);
    const sgn = a >> 63;
    var e: c_int = @intCast((a >> 52) & 0x7ff);
    var m = a & (((@as(u64, 1) << 52) - 1));
    var q = buf;
    
    var E: c_int = 0;
    var P: c_int = 0;
    
    blk: {
        if (e == 0x7ff) {
            if (m == 0) {
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
            break :blk;
        } else if (e == 0) {
            if (m == 0) {
                tmp1.len = 1;
                tmp1.tab()[0] = 0;
                E = 1;
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
                q = output_label(q, tmp1, radix, P, E, flags, n_digits);
                break :blk;
            }
            const l = clz64(m) - 11;
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
        
        if (fmt == JS_DTOA_FORMAT_FREE and
            e >= 1 and e <= 53 and
            (m & (((@as(u64, 1) << @intCast(53 - e)) - 1))) == 0 and
            (flags & JS_DTOA_EXP_MASK) != JS_DTOA_EXP_ENABLED) {
            m >>= @intCast(53 - e);
            const added = u64toa_radix(q, m, @intCast(radix));
            q += added;
            break :blk;
        }
        
        E = 1 + mul_log2_radix(e - 1, radix);
        
        if (fmt == JS_DTOA_FORMAT_FREE) {
            const P_max = dtoa_max_digits_table[@intCast(radix - 2)];
            const E0 = E;
            var E_found: c_int = 0;
            var P_found: c_int = 0;
            var mant_found: u64 = 0;
            P = P_max;
            while (true) {
                const mant_max1 = pow_ui(radix, P);
                E = E0;
                while (true) {
                    mul_pow_round(tmp1, m, e - 53, radix1, @intCast(radix_shift), P - E, JS_RNDN);
                    const mant = mpb_get_u64(tmp1);
                    if (mant < mant_max1) break;
                    E += 1;
                }
                var mant = mpb_get_u64(tmp1);
                while ((mant % @as(u64, @intCast(radix))) == 0) {
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
                const m1 = mul_pow_round_to_d(&e1, tmp1, radix1, @intCast(radix_shift), E - P, JS_RNDN);
                if (m1 == m and e1 == e) {
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
            mpb_set_u64(tmp1, mant_found);
        } else if (fmt == JS_DTOA_FORMAT_FRAC) {
            mul_pow_round(tmp1, m, e - 53, radix1, @intCast(radix_shift), n_digits, JS_RNDNA);
            const len = output_digits(q, tmp1, radix, @max(E + 1, 1) + n_digits, @max(E + 1, 1));
            if (q[0] == '0' and len >= 2 and q[1] != '.') {
                const len_usize = @as(usize, @intCast(len - 1));
                std.mem.copyForwards(u8, q[0..len_usize], q[1 .. len_usize + 1]);
                q += @as(usize, @intCast(len - 1));
            } else {
                q += @as(usize, @intCast(len));
            }
            break :blk;
        } else {
            P = n_digits;
            mant_max.len = 1;
            mant_max.tab()[0] = 1;
            const pow_shift = mul_pow(mant_max, radix1, @intCast(radix_shift), P, false, 0);
            mpb_shr_round(mant_max, pow_shift, JS_RNDZ);
            
            while (true) {
                mul_pow_round(tmp1, m, e - 53, radix1, @intCast(radix_shift), P - E, JS_RNDNA);
                if (mpb_cmp(tmp1, mant_max) < 0) break;
                E += 1;
            }
        }
        
        q = output_label(q, tmp1, radix, P, E, flags, n_digits);
    }
    
    q[0] = 0;
    return @intCast(@intFromPtr(q) - @intFromPtr(buf));
}

inline fn to_digit(c: i32) i32 {
    if (c >= '0' and c <= '9') {
        return c - '0';
    } else if (c >= 'A' and c <= 'Z') {
        return c - 'A' + 10;
    } else if (c >= 'a' and c <= 'z') {
        return c - 'a' + 10;
    } else {
        return 36;
    }
}

pub export fn js_atod(str: [*]const u8, pnext: [*c][*c]const u8, radix_in: c_int, flags: c_int, tmp_mem: *JSATODTempMem) callconv(.c) f64 {
    var mptr = @as([*]u64, @ptrCast(&tmp_mem.mem));
    const tmp0: *mpb_t = @ptrCast(@alignCast(dtoa_malloc(&mptr, @sizeOf(mpb_t) + @sizeOf(limb_t) * DBIGNUM_LEN_MAX)));
    
    const diff = @intFromPtr(mptr) - @intFromPtr(&tmp_mem.mem);
    std.debug.assert(diff <= @sizeOf(JSATODTempMem));
    
    const sep = if ((flags & JS_ATOD_ACCEPT_UNDERSCORES) != 0) @as(i32, '_') else 256;
    
    var p = str;
    var p_start = p;
    var is_neg: i32 = 0;
    if (p[0] == '+') {
        p += 1;
        p_start = p;
    } else if (p[0] == '-') {
        is_neg = 1;
        p += 1;
        p_start = p;
    }
    
    var radix = radix_in;
    var dval: f64 = 0;
    
    main_blk: {
        if (p[0] == '0') {
            var handled_prefix = false;
            if ((p[1] == 'x' or p[1] == 'X') and (radix == 0 or radix == 16)) {
                p += 2;
                radix = 16;
                handled_prefix = true;
            } else if ((p[1] == 'o' or p[1] == 'O') and radix == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
                p += 2;
                radix = 8;
                handled_prefix = true;
            } else if ((p[1] == 'b' or p[1] == 'B') and radix == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
                p += 2;
                radix = 2;
                handled_prefix = true;
            } else if ((p[1] >= '0' and p[1] <= '9') and radix == 0 and (flags & JS_ATOD_ACCEPT_LEGACY_OCTAL) != 0) {
                var i: usize = 1;
                while (p[i] >= '0' and p[i] <= '7') : (i += 1) {}
                if (p[i] != '8' and p[i] != '9') {
                    p += 1;
                    radix = 8;
                    handled_prefix = true;
                }
            }
            
            if (handled_prefix) {
                if (to_digit(p[0]) >= radix) {
                    dval = std.math.nan(f64);
                    break :main_blk;
                }
            }
        } else {
            if ((flags & JS_ATOD_INT_ONLY) == 0 and js__strstart(p, "Infinity", &p)) {
                dval = if (is_neg != 0) -std.math.inf(f64) else std.math.inf(f64);
                break :main_blk;
            }
        }
        
        if (radix == 0) radix = 10;
        
        var cur_limb: limb_t = 0;
        var expn_offset: c_int = 0;
        var digit_count: c_int = 0;
        var limb_digit_count: c_int = 0;
        const max_digits = atod_max_digits_table[@intCast(radix - 2)];
        const digits_per_limb = digits_per_limb_table[@intCast(radix - 2)];
        const radix_base = radix_base_table[@intCast(radix - 2)];
        const radix_shift = @as(u5, @intCast(@ctz(@as(u32, @intCast(radix)))));
        const radix1 = radix >> radix_shift;
        const radix_bits: c_int = if (radix1 == 1) radix_shift else 0;
        
        tmp0.len = 1;
        tmp0.tab()[0] = 0;
        var extra_digits: limb_t = 0;
        var pos: c_int = 0;
        var dot_pos: c_int = -1;
        
        while (true) {
            if (p[0] == '.' and (@intFromPtr(p) > @intFromPtr(p_start) or to_digit(p[1]) < radix) and (flags & JS_ATOD_INT_ONLY) == 0) {
                if (p[0] == sep) {
                    dval = std.math.nan(f64);
                    break :main_blk;
                }
                if (dot_pos >= 0) break;
                dot_pos = pos;
                p += 1;
            }
            if (p[0] == sep and @intFromPtr(p) > @intFromPtr(p_start) and p[1] == '0') {
                p += 1;
            }
            if (p[0] != '0') break;
            p += 1;
            pos += 1;
        }
        
        const sig_pos = pos;
        while (true) {
            if (p[0] == '.' and (@intFromPtr(p) > @intFromPtr(p_start) or to_digit(p[1]) < radix) and (flags & JS_ATOD_INT_ONLY) == 0) {
                if (p[0] == sep) {
                    dval = std.math.nan(f64);
                    break :main_blk;
                }
                if (dot_pos >= 0) break;
                dot_pos = pos;
                p += 1;
            }
            if (p[0] == sep and @intFromPtr(p) > @intFromPtr(p_start) and to_digit(p[1]) < radix) {
                p += 1;
            }
            const c = to_digit(p[0]);
            if (c >= radix) break;
            p += 1;
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
                extra_digits |= @as(u32, @intCast(c));
            }
        }
        
        if (limb_digit_count != 0) {
            mpb_mul1_base(tmp0, @truncate(pow_ui(radix, limb_digit_count)), cur_limb);
        }
        
        var is_zero = false;
        if (digit_count == 0) {
            is_zero = true;
            expn_offset = 0;
        } else {
            is_zero = false;
            if (dot_pos < 0) {
                dot_pos = pos;
            }
            expn_offset = sig_pos + digit_count - dot_pos;
        }
        
        if (radix_bits != 0 and extra_digits != 0) {
            tmp0.tab()[0] |= 1;
        }
        
        var expn: c_int = 0;
        var expn_overflow = false;
        var is_bin_exp = false;
        
        if ((flags & JS_ATOD_INT_ONLY) == 0 and
            ((radix == 10 and (p[0] == 'e' or p[0] == 'E')) or
             (radix != 10 and (p[0] == '@' or
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
                dval = std.math.nan(f64);
                break :main_blk;
            }
            expn = c;
            p += 1;
            while (true) {
                if (p[0] == sep and to_digit(p[1]) < 10) {
                    p += 1;
                }
                c = to_digit(p[0]);
                if (c >= 10) break;
                if (!expn_overflow) {
                    if (expn > ((std.math.maxInt(i32) - 2 - 9) / 10)) {
                        expn_overflow = true;
                    } else {
                        expn = expn * 10 + c;
                    }
                }
                p += 1;
            }
            if (exp_is_neg) {
                expn = -expn;
            }
            
            if (!is_zero and expn_overflow) {
                var a: u64 = 0;
                if (exp_is_neg) {
                    a = 0;
                } else {
                    a = @as(u64, 0x7ff) << 52;
                }
                a |= @as(u64, @intCast(is_neg)) << 63;
                dval = uint64_as_float64(a);
                break :main_blk;
            }
        }
        
        if (p == p_start) {
            dval = std.math.nan(f64);
            break :main_blk;
        }
        
        var a: u64 = 0;
        if (is_zero) {
            a = 0;
        } else {
            var expn1: c_int = 0;
            var e: c_int = 0;
            var m: u64 = 0;
            var is_overflow = false;
            var is_underflow = false;
            
            if (radix_bits != 0) {
                if (!is_bin_exp) {
                    expn *= radix_bits;
                }
                expn -= expn_offset * radix_bits;
                expn1 = expn + digit_count * radix_bits;
                if (expn1 >= 1024 + radix_bits) {
                    is_overflow = true;
                } else if (expn1 <= -1075) {
                    is_underflow = true;
                } else {
                    m = round_to_d(&e, tmp0, -expn, JS_RNDN);
                }
            } else {
                expn -= expn_offset;
                expn1 = expn + digit_count;
                if (expn1 >= max_exponent[@intCast(radix - 2)] + 1) {
                    is_overflow = true;
                } else if (expn1 <= min_exponent[@intCast(radix - 2)]) {
                    is_underflow = true;
                } else {
                    m = mul_pow_round_to_d(&e, tmp0, radix1, @intCast(radix_shift), expn, JS_RNDN);
                }
            }
            
            if (is_overflow or e > 1024) {
                a = @as(u64, 0x7ff) << 52;
            } else if (is_underflow or m == 0 or e < -1073) {
                a = 0;
            } else if (e < -1021) {
                a = m >> @intCast(-e - 1021);
            } else {
                a = (@as(u64, @intCast(e + 1022)) << 52) | (m & (((@as(u64, 1) << 52) - 1)));
            }
        }
        
        a |= @as(u64, @intCast(is_neg)) << 63;
        dval = uint64_as_float64(a);
    }
    
    if (pnext != null) {
        pnext.* = p;
    }
    return dval;
}
