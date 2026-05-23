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

const LIMB_LOG2_BITS = 5;
const LIMB_BITS = 1 << LIMB_LOG2_BITS;
const slimb_t = i32;
const limb_t = u32;
const dlimb_t = u64;
const LIMB_DIGITS = 9;
const JS_RADIX_MAX = 36;
const DBIGNUM_LEN_MAX = 52;
const MANT_LEN_MAX = 18;

pub const mpb_t = extern struct {
    len: c_int,
    
    pub inline fn get_tab(self: *const mpb_t) [*]const limb_t {
        const ptr = @intFromPtr(self) + @sizeOf(c_int);
        return @ptrFromInt(ptr);
    }
    
    pub inline fn get_tab_mut(self: *mpb_t) [*]limb_t {
        const ptr = @intFromPtr(self) + @sizeOf(c_int);
        return @ptrFromInt(ptr);
    }
};

inline fn toMpb(ptr: *anyopaque) *mpb_t {
    return @ptrCast(@alignCast(ptr));
}

inline fn toMpbConst(ptr: *const anyopaque) *const mpb_t {
    return @ptrCast(@alignCast(ptr));
}

const JS_RNDN = 0;
const JS_RNDNA = 1;
const JS_RNDZ = 2;

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

fn mp_mul1(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, l_in: limb_t) limb_t {
    var l = l_in;
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        const t = @as(u64, taba[i]) * @as(u64, b) + l;
        tabr[i] = @truncate(t);
        l = @truncate(t >> 32);
    }
    return l;
}

pub export fn udiv1norm_init(d: limb_t) callconv(.c) limb_t {
    const a1 = -%d -% 1;
    const a0 = -%@as(u32, 1);
    const val = (@as(u64, a1) << 32) | a0;
    return @truncate(val / d);
}

fn udiv1norm(pr: *limb_t, a1: limb_t, a0: limb_t, d: limb_t, d_inv: limb_t) limb_t {
    const n1m: u32 = @bitCast(@as(i32, @bitCast(a0)) >> 31);
    const n_adj = a0 +% (n1m & d);
    const a = @as(u64, d_inv) *% (a1 -% n1m) +% n_adj;
    var q = @as(u32, @truncate(a >> 32)) +% a1;
    
    var a_val = (@as(u64, a1) << 32) | a0;
    a_val = a_val -% (@as(u64, q) *% d) -% d;
    const ah: u32 = @truncate(a_val >> 32);
    q = q +% 1 +% ah;
    const r = @as(u32, @truncate(a_val)) +% (ah & d);
    pr.* = r;
    return q;
}

fn mp_div1(tabr: [*]limb_t, taba: [*]const limb_t, n: usize, b: limb_t, r_in: limb_t) limb_t {
    var r = r_in;
    var i = @as(isize, @intCast(n)) - 1;
    while (i >= 0) : (i -= 1) {
        const idx = @as(usize, @intCast(i));
        const a1 = (@as(u64, r) << 32) | taba[idx];
        tabr[idx] = @truncate(a1 / b);
        r = @truncate(a1 % b);
    }
    return r;
}

pub export fn mp_shr(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, high: limb_t) callconv(.c) limb_t {
    std.debug.assert(shift >= 1 and shift < 32);
    const u_shift: u5 = @intCast(shift);
    const rev_shift: u5 = @intCast(32 - shift);
    var l = high;
    var i = n - 1;
    while (i >= 0) : (i -= 1) {
        const idx = @as(usize, @intCast(i));
        const a = tab[idx];
        tab_r[idx] = (a >> u_shift) | (l << rev_shift);
        l = a;
    }
    return l & ((@as(u32, 1) << u_shift) - 1);
}

pub export fn mp_shl(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, low: limb_t) callconv(.c) limb_t {
    std.debug.assert(shift >= 1 and shift < 32);
    const u_shift: u5 = @intCast(shift);
    const rev_shift: u5 = @intCast(32 - shift);
    var l = low;
    var i: usize = 0;
    const limit = @as(usize, @intCast(n));
    while (i < limit) : (i += 1) {
        const a = tab[i];
        tab_r[i] = (a << u_shift) | l;
        l = a >> rev_shift;
    }
    return l;
}

pub export fn mp_div1norm(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r_in: limb_t, b_inv: limb_t, shift: c_int) callconv(.c) limb_t {
    var r = r_in;
    if (shift != 0) {
        const u_shift: u5 = @intCast(shift);
        r = (r << u_shift) | mp_shl(tabr, taba, @intCast(n), shift, 0);
    }
    var i = @as(isize, @intCast(n)) - 1;
    while (i >= 0) : (i -= 1) {
        const idx = @as(usize, @intCast(i));
        tabr[idx] = udiv1norm(&r, r, taba[idx], b, b_inv);
    }
    if (shift != 0) {
        const u_shift: u5 = @intCast(shift);
        r >>= u_shift;
    }
    return r;
}

extern fn printf(format: [*:0]const u8, ...) callconv(.c) c_int;

pub export fn mpb_dump(str: [*:0]const u8, a_ptr: *const anyopaque) callconv(.c) void {
    const a = toMpbConst(a_ptr);
    const a_tab = a.get_tab();
    _ = printf("%s= 0x", str);
    var i = @as(isize, a.len) - 1;
    while (i >= 0) : (i -= 1) {
        _ = printf("%08x", a_tab[@intCast(i)]);
        if (i != 0) _ = printf("_");
    }
    _ = printf("\n");
}

pub export fn mpb_renorm(r_ptr: *anyopaque) callconv(.c) void {
    const r = toMpb(r_ptr);
    const r_tab = r.get_tab();
    while (r.len > 1 and r_tab[@intCast(r.len - 1)] == 0) {
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

pub export fn pow_ui(radix: c_int, n: c_int) callconv(.c) u64 {
    const a = @as(u32, @intCast(radix));
    const b = @as(u32, @intCast(n));
    if (b == 0) return 1;
    if (b == 1) return a;
    if ((a == 5 or a == 10) and b <= 17) {
        var r = @as(u64, pow5_table[b - 1]);
        if (b >= 14) {
            r |= @as(u64, pow5h_table[b - 14]) << 32;
        }
        if (a == 10) {
            const shift: u6 = @intCast(b);
            r <<= shift;
        }
        return r;
    }
    var r = @as(u64, a);
    const n_bits = 32 - @clz(b);
    var i = @as(i32, @intCast(n_bits)) - 2;
    while (i >= 0) : (i -= 1) {
        r = r *% r;
        const sh: u5 = @intCast(i);
        if (((b >> sh) & 1) != 0) {
            r = r *% a;
        }
    }
    return r;
}

pub export fn pow_ui_inv(pr_inv: *u32, pshift: *c_int, radix: c_int, n: c_int) callconv(.c) u32 {
    const a = @as(u32, @intCast(radix));
    const b = @as(u32, @intCast(n));
    var r_inv: u32 = 0;
    var r: u32 = 0;
    var shift: c_int = 0;
    if (a == 5 and b >= 1 and b <= 13) {
        r = pow5_table[b - 1];
        shift = @intCast(@clz(r));
        const sh: u5 = @intCast(shift);
        r <<= sh;
        r_inv = pow5_inv_table[b - 1];
    } else {
        const p = pow_ui(radix, n);
        r = @truncate(p);
        shift = @intCast(@clz(r));
        const sh: u5 = @intCast(shift);
        r <<= sh;
        r_inv = udiv1norm_init(r);
    }
    pshift.* = shift;
    pr_inv.* = r_inv;
    return r;
}

pub export fn mpb_get_bit(r_ptr: *const anyopaque, pos: c_int) callconv(.c) c_int {
    const r = toMpbConst(r_ptr);
    const r_tab = r.get_tab();
    const l = @as(usize, @intCast(@as(u32, @bitCast(pos)) / 32));
    const k: u5 = @intCast(@as(u32, @bitCast(pos)) & 31);
    if (l >= @as(usize, @intCast(r.len))) return 0;
    return @intCast((r_tab[l] >> k) & 1);
}

pub export fn mpb_shr_round(r_ptr: *anyopaque, shift_in: c_int, rnd_mode: c_int) callconv(.c) void {
    const r = toMpb(r_ptr);
    const r_tab = r.get_tab_mut();
    var shift = shift_in;

    if (shift == 0) return;
    if (shift < 0) {
        shift = -shift;
        const l = @as(usize, @intCast(@as(u32, @bitCast(shift)) / 32));
        shift = shift & 31;
        if (shift != 0) {
            r_tab[@intCast(r.len)] = mp_shl(r_tab, r_tab, r.len, shift, 0);
            r.len += 1;
            mpb_renorm(r);
        }
        if (l > 0) {
            var i = r.len - 1;
            while (i >= 0) : (i -= 1) {
                const idx = @as(usize, @intCast(i));
                r_tab[idx + l] = r_tab[idx];
            }
            var i_zero: usize = 0;
            while (i_zero < l) : (i_zero += 1) {
                r_tab[i_zero] = 0;
            }
            r.len += @intCast(l);
        }
    } else {
        var bit1: c_int = 0;
        var bit2: u32 = 0;
        var add_one: c_int = 0;

        switch (rnd_mode) {
            JS_RNDZ => {
                add_one = 0;
            },
            JS_RNDN, JS_RNDNA => {
                bit1 = mpb_get_bit(r, shift - 1);
                if (bit1 != 0) {
                    if (rnd_mode == JS_RNDNA) {
                        bit2 = 1;
                    } else {
                        bit2 = 0;
                        if (shift >= 2) {
                            const k = shift - 1;
                            const l_pos = @as(usize, @intCast(@as(u32, @bitCast(k)) / 32));
                            const k_rem: u5 = @intCast(@as(u32, @bitCast(k)) & 31);
                            var i: usize = 0;
                            const limit = @min(l_pos, @as(usize, @intCast(r.len)));
                            while (i < limit) : (i += 1) {
                                bit2 |= r_tab[i];
                            }
                            if (l_pos < @as(usize, @intCast(r.len))) {
                                bit2 |= r_tab[l_pos] & ((@as(u32, 1) << k_rem) - 1);
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
            else => {
                add_one = 0;
            },
        }

        const l = @as(usize, @intCast(@as(u32, @bitCast(shift)) / 32));
        shift = shift & 31;
        if (l >= @as(usize, @intCast(r.len))) {
            r.len = 1;
            r_tab[0] = @intCast(add_one);
        } else {
            if (l > 0) {
                r.len -= @intCast(l);
                var i: usize = 0;
                const limit = @as(usize, @intCast(r.len));
                while (i < limit) : (i += 1) {
                    r_tab[i] = r_tab[i + l];
                }
            }
            if (shift != 0) {
                _ = mp_shr(r_tab, r_tab, r.len, shift, 0);
                mpb_renorm(r);
            }
            if (add_one != 0) {
                const a = mp_add_ui(r_tab, 1, @intCast(r.len));
                if (a != 0) {
                    r_tab[@intCast(r.len)] = a;
                    r.len += 1;
                }
            }
        }
    }
}

pub export fn mpb_cmp(a_ptr: *const anyopaque, b_ptr: *const anyopaque) callconv(.c) c_int {
    const a = toMpbConst(a_ptr);
    const b = toMpbConst(b_ptr);
    if (a.len < b.len) return -1;
    if (a.len > b.len) return 1;
    const a_tab = a.get_tab();
    const b_tab = b.get_tab();
    var i = @as(isize, a.len) - 1;
    while (i >= 0) : (i -= 1) {
        const idx = @as(usize, @intCast(i));
        if (a_tab[idx] != b_tab[idx]) {
            if (a_tab[idx] < b_tab[idx]) return -1 else return 1;
        }
    }
    return 0;
}

pub export fn mpb_set_u64(r_ptr: *anyopaque, m: u64) callconv(.c) void {
    const r = toMpb(r_ptr);
    const r_tab = r.get_tab_mut();
    r_tab[0] = @truncate(m);
    r_tab[1] = @truncate(m >> 32);
    if (r_tab[1] == 0) {
        r.len = 1;
    } else {
        r.len = 2;
    }
}

pub export fn mpb_get_u64(r_ptr: *anyopaque) callconv(.c) u64 {
    const r = toMpb(r_ptr);
    const r_tab = r.get_tab();
    if (r.len == 1) {
        return r_tab[0];
    } else {
        return r_tab[0] | (@as(u64, r_tab[1]) << 32);
    }
}

pub export fn mpb_floor_log2(a_ptr: *anyopaque) callconv(.c) c_int {
    const a = toMpb(a_ptr);
    const a_tab = a.get_tab();
    const v = a_tab[@intCast(a.len - 1)];
    if (v == 0) return -1;
    const clz_val = @clz(v);
    return a.len * 32 - 1 - @as(c_int, @intCast(clz_val));
}

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

pub export fn mul_log2_radix(a: c_int, radix: c_int) callconv(.c) c_int {
    const uradix = @as(u32, @intCast(radix));
    if ((uradix & (uradix - 1)) == 0) {
        const radix_bits = 31 - @clz(uradix);
        var val = a;
        if (a < 0) {
            val -= @as(c_int, @intCast(radix_bits)) - 1;
        }
        return @divTrunc(val, @as(c_int, @intCast(radix_bits)));
    } else {
        const mult = mul_log2_radix_table[uradix - 2];
        const prod = @as(i64, a) * @as(i64, mult);
        return @intCast(prod >> 24);
    }
}

pub export fn mpb_mul1_base(r_ptr: *anyopaque, radix_base: limb_t, b: limb_t) callconv(.c) void {
    const r = toMpb(r_ptr);
    const r_tab = r.get_tab_mut();
    if (r_tab[0] == 0 and r.len == 1) {
        r_tab[0] = b;
    } else {
        if (radix_base == 0) {
            var i = r.len;
            while (i >= 0) : (i -= 1) {
                const idx = @as(usize, @intCast(i));
                r_tab[idx + 1] = r_tab[idx];
            }
            r_tab[0] = b;
        } else {
            r_tab[@intCast(r.len)] = mp_mul1(r_tab, r_tab, @intCast(r.len), radix_base, b);
        }
        r.len += 1;
        mpb_renorm(r);
    }
}

fn u32toa_len(buf: [*]u8, n_in: u32, len: usize) void {
    var n = n_in;
    var i = @as(isize, @intCast(len)) - 1;
    while (i >= 0) : (i -= 1) {
        const digit = n % 10;
        n = n / 10;
        buf[@as(usize, @intCast(i))] = @as(u8, @intCast(digit)) + '0';
    }
}

fn u64toa_bin_len(buf: [*]u8, n_in: u64, radix_bits: u32, len: c_int) void {
    var n = n_in;
    const mask = (@as(u32, 1) << @as(u5, @intCast(radix_bits))) - 1;
    var i = len - 1;
    const r_bits: u6 = @intCast(radix_bits);
    while (i >= 0) : (i -= 1) {
        const digit = @as(u32, @truncate(n)) & mask;
        n >>= r_bits;
        buf[@as(usize, @intCast(i))] = if (digit < 10) @as(u8, @intCast(digit)) + '0' else @as(u8, @intCast(digit)) + 'a' - 10;
    }
}

pub export fn limb_to_a(buf: [*]u8, a: limb_t, radix: c_int, len: c_int) callconv(.c) void {
    var n = a;
    const uradix = @as(u32, @intCast(radix));
    if (uradix == 10) {
        u32toa_len(buf, n, @intCast(len));
    } else {
        var i = len - 1;
        while (i >= 0) : (i -= 1) {
            const digit = n % uradix;
            n = n / uradix;
            buf[@as(usize, @intCast(i))] = if (digit < 10) @as(u8, @intCast(digit)) + '0' else @as(u8, @intCast(digit)) + 'a' - 10;
        }
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

pub export fn output_digits(buf: [*]u8, a_ptr: *const anyopaque, radix: c_int, n_digits1: c_int, dot_pos: c_int) callconv(.c) c_int {
    const a = @constCast(toMpbConst(a_ptr));
    const a_tab = a.get_tab_mut();
    var n_digits = n_digits1;
    var radix_bits: u32 = 0;
    const uradix = @as(u32, @intCast(radix));
    if ((uradix & (uradix - 1)) == 0) {
        radix_bits = 31 - @clz(uradix);
    }
    const digits_per_limb = @as(c_int, @intCast(digits_per_limb_table[uradix - 2]));
    if (radix_bits != 0) {
        while (true) {
            const n = @min(n_digits, digits_per_limb);
            n_digits -= n;
            u64toa_bin_len(buf + @as(usize, @intCast(n_digits)), a_tab[0], radix_bits, n);
            if (n_digits == 0) break;
            mpb_shr_round(a, digits_per_limb * @as(c_int, @intCast(radix_bits)), JS_RNDZ);
        }
    } else {
        const base = radix_base_table[uradix - 2];
        while (n_digits != 0) {
            const n = @min(n_digits, digits_per_limb);
            n_digits -= n;
            const r = mp_div1(a_tab, a_tab, @intCast(a.len), base, 0);
            mpb_renorm(a);
            limb_to_a(buf + @as(usize, @intCast(n_digits)), r, radix, n);
        }
    }

    var len = n_digits1;
    if (dot_pos != n_digits1) {
        const u_dot = @as(usize, @intCast(dot_pos));
        const u_len = @as(usize, @intCast(n_digits1));
        var i = u_len - 1;
        while (i >= u_dot) {
            buf[i + 1] = buf[i];
            if (i == u_dot) break;
            i -= 1;
        }
        buf[u_dot] = '.';
        len += 1;
    }
    return len;
}

pub export fn round_to_d(pe: *c_int, a_ptr: *anyopaque, e_offset: c_int, rnd_mode: c_int) callconv(.c) u64 {
    const a = toMpb(a_ptr);
    const a_tab = a.get_tab();
    var e: c_int = 0;
    var m: u64 = 0;

    if (a_tab[0] == 0 and a.len == 1) {
        m = 0;
        e = 0;
    } else {
        var prec: c_int = 0;
        const prec1 = 53;
        const e_min = -1021;
        e = mpb_floor_log2(a) + 1 - e_offset;
        if (e < e_min) {
            prec = prec1 - (e_min - e);
        } else {
            prec = prec1;
        }
        mpb_shr_round(a, e + e_offset - prec, rnd_mode);
        m = mpb_get_u64(a);
        const shift: u6 = @intCast(53 - prec);
        m <<= shift;
        if (m >= (@as(u64, 1) << 53)) {
            m >>= 1;
            e += 1;
        }
    }
    pe.* = e;
    return m;
}

fn mul_pow(a: *mpb_t, radix1: c_int, radix_shift: c_int, f_in: c_int, is_int: bool, e: c_int) c_int {
    var f = f_in;
    const a_tab = a.get_tab_mut();
    var e_offset = -f * radix_shift;
    if (radix1 != 1) {
        const d = @as(c_int, @intCast(digits_per_limb_table[@intCast(radix1 - 2)]));
        if (f >= 0) {
            var b: u64 = 0;
            var n0: c_int = 0;
            while (f != 0) {
                const n = @min(f, d);
                if (n != n0) {
                    b = pow_ui(radix1, n);
                    n0 = n;
                }
                const h = mp_mul1(a_tab, a_tab, @intCast(a.len), @truncate(b), 0);
                if (h != 0) {
                    a_tab[@intCast(a.len)] = h;
                    a.len += 1;
                }
                f -= n;
            }
        } else {
            f = -f;
            const l = @divTrunc(f + d - 1, d);
            e_offset += l * 32;
            var extra_bits: c_int = 0;
            if (!is_int) {
                extra_bits = @max(e - mpb_floor_log2(a), 0);
            } else {
                extra_bits = @max(2 + e - e_offset, 0);
            }
            e_offset += extra_bits;
            mpb_shr_round(a, -(l * 32 + extra_bits), JS_RNDZ);

            var b: u32 = 0;
            var b_inv: u32 = 0;
            var shift: c_int = 0;
            var n0: c_int = 0;
            var rem: u32 = 0;
            while (f != 0) {
                const n = @min(f, d);
                if (n != n0) {
                    b = pow_ui_inv(&b_inv, &shift, radix1, n);
                    n0 = n;
                }
                const r = mp_div1norm(a_tab, a_tab, @intCast(a.len), b, 0, b_inv, shift);
                rem |= r;
                mpb_renorm(a);
                f -= n;
            }
            if (rem != 0) {
                a_tab[0] |= 1;
            }
        }
    }
    return e_offset;
}

fn mul_pow_round(tmp1: *mpb_t, m: u64, e: c_int, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) void {
    mpb_set_u64(tmp1, m);
    const e_offset = mul_pow(tmp1, radix1, radix_shift, f, true, e);
    mpb_shr_round(tmp1, -e + e_offset, rnd_mode);
}

pub export fn mul_pow_round_to_d(pe: *c_int, a_ptr: *anyopaque, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) callconv(.c) u64 {
    const a = toMpb(a_ptr);
    const e_offset = mul_pow(a, radix1, radix_shift, f, false, 55);
    return round_to_d(pe, a, e_offset, rnd_mode);
}

pub export fn u32toa(buf: [*]u8, n_in: u32) callconv(.c) usize {
    var n = n_in;
    var buf1: [10]u8 = undefined;
    var idx: usize = 10;
    while (true) {
        idx -= 1;
        buf1[idx] = @as(u8, @intCast(n % 10)) + '0';
        n /= 10;
        if (n == 0) break;
    }
    const len = 10 - idx;
    var i: usize = 0;
    while (i < len) : (i += 1) {
        buf[i] = buf1[idx + i];
    }
    return len;
}

pub export fn i32toa(buf: [*]u8, n: i32) callconv(.c) usize {
    if (n >= 0) {
        return u32toa(buf, @as(u32, @intCast(n)));
    } else {
        buf[0] = '-';
        const abs_val = -%@as(u32, @bitCast(n));
        return u32toa(buf + 1, abs_val) + 1;
    }
}

pub export fn u64toa(buf: [*]u8, n_in: u64) callconv(.c) usize {
    var n = n_in;
    if (n < 0x100000000) {
        return u32toa(buf, @truncate(n));
    } else {
        var n1 = n / 1000000000;
        n = n % 1000000000;
        var offset: usize = 0;
        if (n1 >= 0x100000000) {
            var n2 = @as(u32, @truncate(n1 / 1000000000));
            n1 = n1 % 1000000000;
            if (n2 >= 10) {
                buf[offset] = @as(u8, @intCast(n2 / 10)) + '0';
                offset += 1;
                n2 %= 10;
            }
            buf[offset] = @as(u8, @intCast(n2)) + '0';
            offset += 1;
            u32toa_len(buf + offset, @truncate(n1), 9);
            offset += 9;
        } else {
            offset += u32toa(buf + offset, @truncate(n1));
        }
        u32toa_len(buf + offset, @truncate(n), 9);
        offset += 9;
        return offset;
    }
}

pub export fn i64toa(buf: [*]u8, n: i64) callconv(.c) usize {
    if (n >= 0) {
        return u64toa(buf, @as(u64, @intCast(n)));
    } else {
        buf[0] = '-';
        const abs_val = -%@as(u64, @bitCast(n));
        return u64toa(buf + 1, abs_val) + 1;
    }
}

pub export fn u64toa_radix(buf: [*]u8, n_in: u64, radix: c_uint) callconv(.c) usize {
    var n = n_in;
    if (radix == 10) {
        return u64toa(buf, n);
    }
    if ((radix & (radix - 1)) == 0) {
        const radix_bits = 31 - @clz(radix);
        var l: c_int = 0;
        if (n == 0) {
            l = 1;
        } else {
            const clz_val = @clz(n);
            l = @divTrunc(@as(c_int, @intCast(64 - clz_val)) + @as(c_int, @intCast(radix_bits)) - 1, @as(c_int, @intCast(radix_bits)));
        }
        u64toa_bin_len(buf, n, radix_bits, l);
        return @intCast(l);
    } else {
        var buf1: [41]u8 = undefined;
        var idx: usize = 41;
        while (true) {
            idx -= 1;
            const digit = @as(u32, @truncate(n % radix));
            n /= radix;
            buf1[idx] = if (digit < 10) @as(u8, @intCast(digit)) + '0' else @as(u8, @intCast(digit)) + 'a' - 10;
            if (n == 0) break;
        }
        const len = 41 - idx;
        var i: usize = 0;
        while (i < len) : (i += 1) {
            buf[i] = buf1[idx + i];
        }
        return len;
    }
}

pub export fn i64toa_radix(buf: [*]u8, n: i64, radix: c_uint) callconv(.c) usize {
    if (n >= 0) {
        return u64toa_radix(buf, @as(u64, @intCast(n)), radix);
    } else {
        buf[0] = '-';
        const abs_val = -%@as(u64, @bitCast(n));
        return u64toa_radix(buf + 1, abs_val, radix) + 1;
    }
}

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
            a = @bitCast(d);
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
        a = @bitCast(d);
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

fn dtoa_malloc(pptr: *[*]u64, size: usize) *anyopaque {
    const ret = pptr.*;
    pptr.* += (size + 7) / 8;
    return @ptrCast(ret);
}

fn output_goto(buf: [*]u8, tmp1: *mpb_t, radix: c_int, P_in: c_int, E_in: c_int, fmt: c_int, n_digits: c_int, flags: c_int) usize {
    var q = buf;
    const P = P_in;
    var E = E_in;
    var E_max: c_int = 0;
    if (fmt == JS_DTOA_FORMAT_FIXED) {
        E_max = n_digits;
    } else {
        E_max = @as(c_int, @intCast(dtoa_max_digits_table[@intCast(radix - 2)])) + 4;
    }
    const radix_shift = @as(c_int, @intCast(@ctz(@as(u32, @intCast(radix)))));
    const radix1 = radix >> @as(u5, @intCast(radix_shift));

    if ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_ENABLED or
        ((flags & JS_DTOA_EXP_MASK) == JS_DTOA_EXP_AUTO and (E <= -6 or E > E_max))) {
        q += @as(usize, @intCast(output_digits(q, tmp1, radix, P, 1)));
        E -= 1;
        if (radix == 10) {
            q[0] = 'e';
            q += 1;
        } else if (radix1 == 1 and radix_shift <= 4) {
            E *= radix_shift;
            q[0] = 'p';
            q += 1;
        } else {
            q[0] = '@';
            q += 1;
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
        const limit = @as(usize, @intCast(-E));
        while (i < limit) : (i += 1) {
            q[0] = '0';
            q += 1;
        }
        q += @as(usize, @intCast(output_digits(q, tmp1, radix, P, P)));
    } else {
        q += @as(usize, @intCast(output_digits(q, tmp1, radix, P, @min(P, E))));
        var i: usize = 0;
        const limit = @as(usize, @intCast(@max(E - P, 0)));
        while (i < limit) : (i += 1) {
            q[0] = '0';
            q += 1;
        }
    }
    return @intFromPtr(q) - @intFromPtr(buf);
}

pub export fn js_dtoa(buf: [*]u8, d: f64, radix: c_int, n_digits: c_int, flags: c_int, tmp_mem: *JSDTOATempMem) callconv(.c) c_int {
    var mptr = @as([*]u64, @ptrCast(&tmp_mem.mem));
    const tmp1 = @as(*mpb_t, @ptrCast(@alignCast(dtoa_malloc(&mptr, @sizeOf(mpb_t) + @sizeOf(limb_t) * DBIGNUM_LEN_MAX))));
    const mant_max = @as(*mpb_t, @ptrCast(@alignCast(dtoa_malloc(&mptr, @sizeOf(mpb_t) + @sizeOf(limb_t) * MANT_LEN_MAX))));

    const radix_shift = @as(c_int, @intCast(@ctz(@as(u32, @intCast(radix)))));
    const radix1 = radix >> @as(u5, @intCast(radix_shift));
    const a = @as(u64, @bitCast(d));
    const sgn = a >> 63;
    var e = @as(c_int, @intCast((a >> 52) & 0x7ff));
    var m = a & (((@as(u64, 1)) << 52) - 1);
    var q = buf;
    const fmt = flags & JS_DTOA_FORMAT_MASK;

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
        q[0] = 0;
        return @intCast(@intFromPtr(q) - @intFromPtr(buf));
    } else if (e == 0) {
        if (m == 0) {
            tmp1.len = 1;
            tmp1.get_tab_mut()[0] = 0;
            const E: c_int = 1;
            var P: c_int = 0;
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
            q += @intCast(output_goto(q, tmp1, radix, P, E, fmt, n_digits, flags));
            q[0] = 0;
            return @intCast(@intFromPtr(q) - @intFromPtr(buf));
        }
        const l = @as(c_int, @intCast(@clz(m))) - 11;
        e -= l - 1;
        m <<= @as(u6, @intCast(l));
    } else {
        m |= (@as(u64, 1)) << 52;
    }
    if (sgn != 0) {
        q[0] = '-';
        q += 1;
    }
    e -= 1022;

    if (fmt == JS_DTOA_FORMAT_FREE and
        e >= 1 and e <= 53 and
        (m & (((@as(u64, 1)) << @as(u6, @intCast(53 - e))) - 1)) == 0 and
        (flags & JS_DTOA_EXP_MASK) != JS_DTOA_EXP_ENABLED) {
        m >>= @as(u6, @intCast(53 - e));
        q += u64toa_radix(q, m, @intCast(radix));
        q[0] = 0;
        return @intCast(@intFromPtr(q) - @intFromPtr(buf));
    }

    var E = 1 + mul_log2_radix(e - 1, radix);

    var P: c_int = 0;
    if (fmt == JS_DTOA_FORMAT_FREE) {
        const P_max = @as(c_int, @intCast(dtoa_max_digits_table[@intCast(radix - 2)]));
        const E0 = E;
        var E_found: c_int = 0;
        var P_found: c_int = 0;
        var mant_found: u64 = 0;
        P = P_max;
        while (true) {
            const mant_max1 = pow_ui(radix, P);
            E = E0;
            while (true) {
                mul_pow_round(tmp1, m, e - 53, radix1, radix_shift, P - E, JS_RNDN);
                const mant = mpb_get_u64(tmp1);
                if (mant < mant_max1) break;
                E += 1;
            }
            var mant = mpb_get_u64(tmp1);
            const uradix = @as(u32, @intCast(radix));
            while ((mant % uradix) == 0) {
                mant /= uradix;
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
            } else {
                break;
            }
        }
        P = P_found;
        E = E_found;
        mpb_set_u64(tmp1, mant_found);
    } else if (fmt == JS_DTOA_FORMAT_FRAC) {
        mul_pow_round(tmp1, m, e - 53, radix1, radix_shift, n_digits, JS_RNDNA);
        const len = output_digits(q, tmp1, radix, @max(E + 1, 1) + n_digits, @max(E + 1, 1));
        if (q[0] == '0' and len >= 2 and q[1] != '.') {
            const u_len = @as(usize, @intCast(len - 1));
            var i: usize = 0;
            while (i < u_len) : (i += 1) {
                q[i] = q[i + 1];
            }
            q += u_len;
        } else {
            q += @as(usize, @intCast(len));
        }
        q[0] = 0;
        return @intCast(@intFromPtr(q) - @intFromPtr(buf));
    } else {
        P = n_digits;
        const mant_max_tab = mant_max.get_tab_mut();
        mant_max.len = 1;
        mant_max_tab[0] = 1;
        const pow_shift = mul_pow(mant_max, radix1, radix_shift, P, false, 0);
        mpb_shr_round(mant_max, pow_shift, JS_RNDZ);

        while (true) {
            mul_pow_round(tmp1, m, e - 53, radix1, radix_shift, P - E, JS_RNDNA);
            if (mpb_cmp(tmp1, mant_max) < 0) break;
            E += 1;
        }
    }

    q += @intCast(output_goto(q, tmp1, radix, P, E, fmt, n_digits, flags));
    q[0] = 0;
    return @intCast(@intFromPtr(q) - @intFromPtr(buf));
}

fn js__strstart(str: [*]const u8, val: []const u8, pnext: [*c][*c]const u8) bool {
    var i: usize = 0;
    while (i < val.len) : (i += 1) {
        if (str[i] != val[i]) return false;
    }
    if (@intFromPtr(pnext) != 0) {
        pnext.* = str + val.len;
    }
    return true;
}

inline fn to_digit(c: u8) u32 {
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
    const tmp0 = @as(*mpb_t, @ptrCast(@alignCast(dtoa_malloc(&mptr, @sizeOf(mpb_t) + @sizeOf(limb_t) * DBIGNUM_LEN_MAX))));
    var sep = if ((flags & JS_ATOD_ACCEPT_UNDERSCORES) != 0) @as(u32, '_') else 256;

    var radix = radix_in;
    var p = str;
    var is_neg: c_int = 0;
    if (p[0] == '+') {
        p += 1;
    } else if (p[0] == '-') {
        is_neg = 1;
        p += 1;
    }
    const p_start = p;

    var has_prefix = false;
    if (p[0] == '0') {
        if ((p[1] == 'x' or p[1] == 'X') and (radix == 0 or radix == 16)) {
            p += 2;
            radix = 16;
            has_prefix = true;
        } else if ((p[1] == 'o' or p[1] == 'O') and radix == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
            p += 2;
            radix = 8;
            has_prefix = true;
        } else if ((p[1] == 'b' or p[1] == 'B') and radix == 0 and (flags & JS_ATOD_ACCEPT_BIN_OCT) != 0) {
            p += 2;
            radix = 2;
            has_prefix = true;
        } else if ((p[1] >= '0' and p[1] <= '9') and radix == 0 and (flags & JS_ATOD_ACCEPT_LEGACY_OCTAL) != 0) {
            var i: usize = 1;
            while (p[i] >= '0' and p[i] <= '7') : (i += 1) {}
            if (p[i] == '8' or p[i] == '9') {
                // no_prefix
            } else {
                sep = 256;
                p += 1;
                radix = 8;
                has_prefix = true;
            }
        }
        if (has_prefix) {
            if (to_digit(p[0]) >= @as(u32, @intCast(radix))) {
                if (@intFromPtr(pnext) != 0) pnext.* = p;
                return std.math.nan(f64);
            }
        }
    } else {
        if ((flags & JS_ATOD_INT_ONLY) == 0 and js__strstart(p, "Infinity", pnext)) {
            const inf_val = if (is_neg != 0) -std.math.inf(f64) else std.math.inf(f64);
            return inf_val;
        }
    }
    if (radix == 0) radix = 10;

    var cur_limb: u32 = 0;
    var expn_offset: c_int = 0;
    var digit_count: c_int = 0;
    var limb_digit_count: c_int = 0;
    const max_digits = @as(c_int, @intCast(atod_max_digits_table[@intCast(radix - 2)]));
    const digits_per_limb = @as(c_int, @intCast(digits_per_limb_table[@intCast(radix - 2)]));
    const radix_base = radix_base_table[@intCast(radix - 2)];
    const radix_shift = @as(c_int, @intCast(@ctz(@as(u32, @intCast(radix)))));
    const radix1 = radix >> @as(u5, @intCast(radix_shift));
    const radix_bits = if (radix1 == 1) radix_shift else 0;

    tmp0.len = 1;
    tmp0.get_tab_mut()[0] = 0;
    var extra_digits: u32 = 0;
    var pos: c_int = 0;
    var dot_pos: c_int = -1;

    // skip leading zeros
    while (true) {
        if (p[0] == '.' and (@intFromPtr(p) > @intFromPtr(p_start) or to_digit(p[1]) < @as(u32, @intCast(radix))) and (flags & JS_ATOD_INT_ONLY) == 0) {
            if (p[0] == sep) {
                if (@intFromPtr(pnext) != 0) pnext.* = p;
                return std.math.nan(f64);
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
        if (p[0] == '.' and (@intFromPtr(p) > @intFromPtr(p_start) or to_digit(p[1]) < @as(u32, @intCast(radix))) and (flags & JS_ATOD_INT_ONLY) == 0) {
            if (p[0] == sep) {
                if (@intFromPtr(pnext) != 0) pnext.* = p;
                return std.math.nan(f64);
            }
            if (dot_pos >= 0) break;
            dot_pos = pos;
            p += 1;
        }
        if (p[0] == sep and @intFromPtr(p) > @intFromPtr(p_start) and to_digit(p[1]) < @as(u32, @intCast(radix))) {
            p += 1;
        }
        const c = to_digit(p[0]);
        if (c >= @as(u32, @intCast(radix))) break;
        p += 1;
        pos += 1;
        if (digit_count < max_digits) {
            cur_limb = cur_limb *% @as(u32, @intCast(radix)) +% c;
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
        tmp0.get_tab_mut()[0] |= 1;
    }

    var expn: c_int = 0;
    var expn_overflow = false;
    var is_bin_exp = false;

    if ((flags & JS_ATOD_INT_ONLY) == 0 and
        ((radix == 10 and (p[0] == 'e' or p[0] == 'E')) or
         (radix != 10 and (p[0] == '@' or
                          (radix_bits >= 1 and radix_bits <= 4 and (p[0] == 'p' or p[0] == 'P'))))) and
        @intFromPtr(p) > @intFromPtr(p_start)) {
        var exp_is_neg = false;
        is_bin_exp = (p[0] == 'p' or p[0] == 'P');
        p += 1;
        if (p[0] == '+') {
            p += 1;
        } else if (p[0] == '-') {
            exp_is_neg = true;
            p += 1;
        }
        var c = to_digit(p[0]);
        if (c >= 10) {
            if (@intFromPtr(pnext) != 0) pnext.* = p;
            return std.math.nan(f64);
        }
        expn = @intCast(c);
        p += 1;
        while (true) {
            if (p[0] == sep and to_digit(p[1]) < 10) {
                p += 1;
            }
            c = to_digit(p[0]);
            if (c >= 10) break;
            if (!expn_overflow) {
                if (expn > ((2147483647 - 2 - 9) / 10)) {
                    expn_overflow = true;
                } else {
                    expn = expn * 10 + @as(c_int, @intCast(c));
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
            if (@intFromPtr(pnext) != 0) pnext.* = p;
            return @bitCast(a);
        }
    }

    if (p == p_start) {
        if (@intFromPtr(pnext) != 0) pnext.* = p;
        return std.math.nan(f64);
    }

    var a: u64 = 0;
    if (is_zero) {
        a = 0;
    } else {
        var e: c_int = 0;
        var expn1: c_int = 0;
        var m: u64 = 0;
        if (radix_bits != 0) {
            if (!is_bin_exp) {
                expn = expn * radix_bits;
            }
            expn -= expn_offset * radix_bits;
            expn1 = expn + digit_count * radix_bits;
            if (expn1 >= 1024 + radix_bits) {
                a = @as(u64, 0x7ff) << 52;
            } else if (expn1 <= -1075) {
                a = 0;
            } else {
                m = round_to_d(&e, tmp0, -expn, JS_RNDN);
                a = calculate_float(m, e);
            }
        } else {
            expn -= expn_offset;
            expn1 = expn + digit_count;
            if (expn1 >= max_exponent[@intCast(radix - 2)] + 1) {
                a = @as(u64, 0x7ff) << 52;
            } else if (expn1 <= min_exponent[@intCast(radix - 2)]) {
                a = 0;
            } else {
                m = mul_pow_round_to_d(&e, tmp0, radix1, radix_shift, expn, JS_RNDN);
                a = calculate_float(m, e);
            }
        }
    }

    a |= @as(u64, @intCast(is_neg)) << 63;
    if (@intFromPtr(pnext) != 0) pnext.* = p;
    return @bitCast(a);
}

fn calculate_float(m: u64, e: c_int) u64 {
    if (m == 0) {
        return 0;
    } else if (e > 1024) {
        return @as(u64, 0x7ff) << 52;
    } else if (e < -1073) {
        return 0;
    } else if (e < -1021) {
        const shift: u6 = @intCast(-e - 1021);
        return m >> shift;
    } else {
        return (@as(u64, @intCast(e + 1022)) << 52) | (m & (((@as(u64, 1)) << 52) - 1));
    }
}
