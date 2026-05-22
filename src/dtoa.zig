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

pub export fn js_dtoa_max_len(d: f64, radix: c_int, n_digits: c_int, flags: c_int) callconv(.c) c_int {
    _ = d; _ = radix; _ = n_digits; _ = flags;
    return 0;
}

pub export fn js_dtoa(buf: [*]u8, d: f64, radix: c_int, n_digits: c_int, flags: c_int, tmp_mem: *JSDTOATempMem) callconv(.c) c_int {
    _ = buf; _ = d; _ = radix; _ = n_digits; _ = flags; _ = tmp_mem;
    return 0;
}

pub export fn js_atod(str: [*]const u8, pnext: [*c][*c]const u8, radix: c_int, flags: c_int, tmp_mem: *JSATODTempMem) callconv(.c) f64 {
    _ = str; _ = pnext; _ = radix; _ = flags; _ = tmp_mem;
    return 0.0;
}

pub export fn u32toa(buf: [*]u8, n: u32) callconv(.c) usize {
    _ = buf; _ = n;
    return 0;
}

pub export fn i32toa(buf: [*]u8, n: i32) callconv(.c) usize {
    _ = buf; _ = n;
    return 0;
}

pub export fn u64toa(buf: [*]u8, n: u64) callconv(.c) usize {
    _ = buf; _ = n;
    return 0;
}

pub export fn i64toa(buf: [*]u8, n: i64) callconv(.c) usize {
    _ = buf; _ = n;
    return 0;
}

pub export fn u64toa_radix(buf: [*]u8, n: u64, radix: c_uint) callconv(.c) usize {
    _ = buf; _ = n; _ = radix;
    return 0;
}

pub export fn i64toa_radix(buf: [*]u8, n: i64, radix: c_uint) callconv(.c) usize {
    _ = buf; _ = n; _ = radix;
    return 0;
}

const limb_t = u32;

export fn mp_add_ui(tab: [*]limb_t, b: limb_t, n: usize) callconv(.c) limb_t {
    _ = tab; _ = b; _ = n;
    return 0;
}

export fn mp_shr(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, high: limb_t) callconv(.c) limb_t {
    _ = tab_r; _ = tab; _ = n; _ = shift; _ = high;
    return 0;
}

export fn mp_shl(tab_r: [*]limb_t, tab: [*]const limb_t, n: isize, shift: c_int, low: limb_t) callconv(.c) limb_t {
    _ = tab_r; _ = tab; _ = n; _ = shift; _ = low;
    return 0;
}

export fn mpb_set_u64(r: *anyopaque, m: u64) callconv(.c) void {
    _ = r; _ = m;
}

export fn mpb_get_u64(r: *anyopaque) callconv(.c) u64 {
    _ = r;
    return 0;
}

export fn mpb_floor_log2(a: *anyopaque) callconv(.c) c_int {
    _ = a;
    return 0;
}

export fn mul_log2_radix(a: c_int, radix: c_int) callconv(.c) c_int {
    _ = a; _ = radix;
    return 0;
}

export fn pow_ui(radix: c_int, n: c_int) callconv(.c) u64 {
    _ = radix; _ = n;
    return 0;
}

export fn pow_ui_inv(pr_inv: *u32, pshift: *c_int, radix: c_int, n: c_int) callconv(.c) void {
    _ = pr_inv; _ = pshift; _ = radix; _ = n;
}

export fn mpb_shr_round(r: *anyopaque, shift: c_int, rnd_mode: c_int) callconv(.c) void {
    _ = r; _ = shift; _ = rnd_mode;
}

export fn mpb_cmp(a: *const anyopaque, b: *const anyopaque) callconv(.c) c_int {
    _ = a; _ = b;
    return 0;
}

export fn mpb_renorm(r: *anyopaque) callconv(.c) void {
    _ = r;
}

export fn mpb_mul1_base(r: *anyopaque, radix_base: limb_t, b: limb_t) callconv(.c) void {
    _ = r; _ = radix_base; _ = b;
}

export fn limb_to_a(buf: [*]u8, a: limb_t, radix: c_int, len: c_int) callconv(.c) void {
    _ = buf; _ = a; _ = radix; _ = len;
}

export fn output_digits(buf: [*]u8, a: *const anyopaque, radix: c_int, n_digits: c_int, radix_bits: c_int) callconv(.c) c_int {
    _ = buf; _ = a; _ = radix; _ = n_digits; _ = radix_bits;
    return 0;
}

export fn round_to_d(pe: *c_int, a: *anyopaque, e_offset: c_int, rnd_mode: c_int) callconv(.c) u64 {
    _ = pe; _ = a; _ = e_offset; _ = rnd_mode;
    return 0;
}

export fn mul_pow_round_to_d(pe: *c_int, a: *anyopaque, radix1: c_int, radix_shift: c_int, f: c_int, rnd_mode: c_int) callconv(.c) u64 {
    _ = pe; _ = a; _ = radix1; _ = radix_shift; _ = f; _ = rnd_mode;
    return 0;
}

export fn udiv1norm_init(d: limb_t) callconv(.c) limb_t {
    _ = d;
    return 0;
}

export fn mp_div1norm(tabr: [*]limb_t, taba: [*]const limb_t, n: limb_t, b: limb_t, r: limb_t, b_inv: limb_t, shift: c_int) callconv(.c) limb_t {
    _ = tabr; _ = taba; _ = n; _ = b; _ = r; _ = b_inv; _ = shift;
    return 0;
}

export fn mpb_dump(str: [*]const u8, a: *const anyopaque) callconv(.c) void {
    _ = str; _ = a;
}

export fn mpb_get_bit(r: *const anyopaque, pos: c_int) callconv(.c) c_int {
    _ = r; _ = pos;
    return 0;
}

