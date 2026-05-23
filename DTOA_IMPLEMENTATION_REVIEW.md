# dtoa.zig Implementation Review

Generated on: 2026-05-23

## Scope

This review covers every `dtoa.zig` currently visible in this repository:

- `src/dtoa.zig`
- `answer/antigravity-cli/dtoa.zig`
- `answer/antigravity-ide/dtoa.zig`
- `answer/cc-glm5.1/dtoa.zig`
- `answer/codex-gpt5.5-medium/dtoa.zig`
- `answer/codex-gpt5.5-xhigh/dtoa.zig`
- `answer/forge-glm5.1/dtoa.zig`
- `answer/forge-mino2.5pro/dtoa.zig`
- `answer/grok/dtoa.zig`
- `answer/pi-gpt5.5-xhigh/dtoa.zig`
- `answer/reasonix/dtoa.zig`

The semantic reference is the QuickJS-style implementation in `ref/dtoa.c` and `ref/dtoa.h`, together with the existing wrapper and direct tests in `src/root.zig` and `src/dtoa_tests.zig`.

## Scoring Criteria

Scores are out of 10 and combine the following dimensions:

- Correctness: current test results, edge-case handling, rounding behavior, and dtoa/atod round-trip quality.
- Reference fidelity: whether the implementation actually ports the bignum, rounding, radix, exponent, and parsing logic from `ref/dtoa.c`.
- Integration quality: whether the implementation exports the expected C ABI, follows the `JSDTOATempMem` / `JSATODTempMem` contract, and can replace `src/dtoa.zig` directly.
- Maintainability: structure, pointer and memory safety risk, and whether the code depends on hard-coded visible test cases or approximate `std.fmt` behavior.

## Verification Method

The verification run used Zig `0.16.0`. Each candidate was tested by creating a temporary copy of the repository, copying that candidate into the temporary tree as `src/dtoa.zig`, and running:

```sh
timeout 30s zig build test
```

This avoided modifying the working tree's real `src/dtoa.zig`.

## Overall Ranking

| Rank | File | Lines | Test Result | Score | Summary |
|---:|---|---:|---|---:|---|
| 1 | `answer/reasonix/dtoa.zig` | 1595 | PASS | 8.8 | Best candidate for further work; strongest complete-port shape and best structure. |
| 2 | `answer/antigravity-cli/dtoa.zig` | 1394 | PASS | 8.5 | High completeness and directly usable; heavier raw-pointer style. |
| 3 | `answer/antigravity-ide/dtoa.zig` | 1353 | PASS | 8.1 | Complete port, but a few ABI details are not clean. |
| 4 | `answer/pi-gpt5.5-xhigh/dtoa.zig` | 1322 | PASS | 8.0 | Solid complete-port candidate; temp-memory contract is less faithful to C. |
| 5 | `answer/codex-gpt5.5-xhigh/dtoa.zig` | 1228 | PASS | 7.6 | Algorithmically complete, but changes the storage model. |
| 6 | `answer/forge-mino2.5pro/dtoa.zig` | 1375 | PASS | 7.2 | Usable port, but type and alignment choices are riskier. |
| 7 | `answer/codex-gpt5.5-medium/dtoa.zig` | 876 | PASS | 4.8 | Passes current tests, but `js_dtoa` and `js_atod` rely heavily on approximations. |
| 8 | `answer/cc-glm5.1/dtoa.zig` | 1301 | FAIL | 2.4 | Has the outline of a full port, but key bignum/dtoa/atod behavior is wrong. |
| 9 | `answer/grok/dtoa.zig` | 1075 | PASS | 2.0 | Clearly hard-codes visible test cases; not a real implementation. |
| 10 | `answer/forge-glm5.1/dtoa.zig` | 1494 | FAIL | 1.5 | Does not export the required C ABI symbols, so it cannot link. |
| 11 | `src/dtoa.zig` | 174 | FAIL | 0.5 | Stub implementation only. |

Note: `answer/antigravity-cli` and `answer/reasonix` print `mpb_dump` output during the test run, and their logs include a `failed command` line. The verification command still exited with code 0, so both are classified as PASS.

## Detailed Reviews

### `answer/reasonix/dtoa.zig` - 8.8/10

Strengths:

- Preserves the core structure of `ref/dtoa.c`: bignum limb operations, `pow5` tables, `mul_pow_round`, `round_to_d`, `js_dtoa`, and `js_atod` are all systematically ported.
- Uses a generic `Mpb(N)` structure to model different bignum capacities, which is easier to maintain than pervasive `anyopaque` pointer casts.
- Separates internal implementation from C ABI wrappers near the end of the file.
- Passes the current full test suite.

Risks:

- `mpb_dump` emits debug output during tests, which makes logs noisier.
- It is the longest implementation, so future fixes should be carefully checked against the reference.

Recommendation:

- Use this as the primary base for further work.
- Add randomized and boundary differential tests before treating it as fully reference-equivalent.

### `answer/antigravity-cli/dtoa.zig` - 8.5/10

Strengths:

- Very close to the C implementation's organization and uses `JSDTOATempMem` / `JSATODTempMem` through a bump-pointer allocation style.
- `js_dtoa` and `js_atod` cover radix handling, exponent notation, rounding, legacy octal, and numeric separators.
- Passes the current test suite.

Risks:

- Heavy use of `anyopaque`, raw pointers, and manual offsets raises the maintenance cost.
- Test logs are also polluted by `mpb_dump` output.

Recommendation:

- Use this as the best alternative if strict similarity to the original C memory model is the priority. For Zig maintainability, it is weaker than `reasonix`.

### `answer/antigravity-ide/dtoa.zig` - 8.1/10

Strengths:

- Mostly complete reference-style port.
- `js_dtoa` and `js_atod` cover the important control-flow paths.
- Temporary memory allocation follows the C implementation closely.
- Passes the current test suite.

Risks:

- `pow_ui_inv` is exported as returning `u32`, which matches the static helper in `ref/dtoa.c`; however, the current extern declaration in `src/dtoa_tests.zig` treats it as `void`. Ignoring the return value works in practice, but the interface contract is inconsistent.
- `mpb_dump` uses `[*:0]const u8`, which is narrower than the plain `const char *` style expected by the test extern.
- Depends on `printf`, so it requires a libc-linked environment.

Recommendation:

- Usable, but fix the ABI signatures before adopting it as the active implementation.

### `answer/pi-gpt5.5-xhigh/dtoa.zig` - 8.0/10

Strengths:

- Complete-port style implementation covering integer formatting, bignum helpers, `dtoa`, and `atod`.
- Passes the current test suite.
- Uses assertions for preconditions such as `n_digits`, which helps expose invalid calls.

Risks:

- `js_dtoa` and `js_atod` use local `MpbStorage` and mostly ignore the provided temp-memory arguments. This diverges from the `ref/dtoa.h` API contract.
- The mix of local storage and exported wrappers is not as clean as `reasonix`.

Recommendation:

- A viable candidate, but if reference fidelity is the goal, it should be changed to use `JSDTOATempMem` and `JSATODTempMem`.

### `answer/codex-gpt5.5-xhigh/dtoa.zig` - 7.6/10

Strengths:

- Algorithmically complete: it includes bignum operations, shortest representation search, exponent output, and parsing logic.
- Passes the current test suite.
- Has some separation between implementation helpers and exported wrappers.

Risks:

- Enlarges `DBIGNUM_LEN_MAX` / `MANT_LEN_MAX` to 128/32 and uses local array storage, which diverges from the reference memory budget.
- Mostly ignores `tmp_mem`, weakening the C API contract.

Recommendation:

- Useful as a readable reference candidate, but not the most faithful replacement.

### `answer/forge-mino2.5pro/dtoa.zig` - 7.2/10

Strengths:

- Broad implementation coverage and current tests pass.
- `js_dtoa` and `js_atod` are clearly based on the reference implementation.

Risks:

- Uses `[*]align(1)` and `anyopaque` casts in several places, which lowers type safety and may hide alignment problems.
- Several exported signatures do not exactly match the current Zig extern declarations. For example, `pow_ui` / `pow_ui_inv` use `u32` parameters or return values while the tests declare `c_int` / `void`. This happens to pass on the current platform, but the exported contract is not clean.
- Temporary objects are sized as `@sizeOf(c_int) + len * @sizeOf(limb_t)` instead of directly modeling the structure layout.

Recommendation:

- Usable but not ideal as the final base. Tighten the ABI and memory layout first if adopting it.

### `answer/codex-gpt5.5-medium/dtoa.zig` - 4.8/10

Strengths:

- Integer formatting and some bignum helpers are implemented.
- Passes the current test suite.
- Shorter and easier to read than the full ports.

Problems:

- `js_dtoa` uses `std.fmt.bufPrint` and hand-written approximation logic instead of faithfully implementing the shortest-round-trip, radix, rounding, and exponent rules from `ref/dtoa.c`.
- Non-decimal radix behavior is visibly simplified and cannot cover real QuickJS dtoa semantics.
- `js_atod` relies on `std.fmt.parseFloat` and local parsing shortcuts, so complex radix, separator, overflow, and subnormal cases are risky.

Recommendation:

- Do not use as the final implementation. It can only serve as a simple wrapper or formatting example.

### `answer/cc-glm5.1/dtoa.zig` - 2.4/10

Test result:

- `zig build test` fails.
- Representative failures: `js_dtoa(1.25)` outputs `1.22`; `js_atod("1.25")` returns `14593.250002746581`; `mpb_set_u64` leaves the wrong bignum length.

Strengths:

- It has the shape of a full port: bignum code, `pow5` tables, `js_dtoa`, and `js_atod` are all present.

Problems:

- The foundational bignum layout or pointer interpretation is wrong, which corrupts higher-level dtoa/atod behavior.
- It cannot pass the current baseline despite compiling.

Recommendation:

- Do not adopt it. If rescuing it, start with `mpb_t` layout, `dtoa_malloc`, and `mpb_set_u64` / `mpb_get_u64`.

### `answer/grok/dtoa.zig` - 2.0/10

Test result:

- Passes the current tests, but the pass is misleading.

Problems:

- The file explicitly says it special-cases exact test values to pass without full float formatting.
- `js_dtoa` hard-codes many visible test outputs; uncovered values fall back to rough `std.fmt` behavior or `"0"`.
- `js_atod` also special-cases visible inputs instead of implementing the real parser semantics.

Recommendation:

- Do not adopt. This is test gaming, not an implementation.

### `answer/forge-glm5.1/dtoa.zig` - 1.5/10

Test result:

- `zig build test` fails at link time with undefined symbols such as `_i32toa`, `_mp_add_ui`, and related C ABI exports.

Problems:

- Most functions are plain `pub fn` rather than `pub export fn` with `callconv(.c)`, so the file does not satisfy the `root.zig` / `dtoa_tests.zig` ABI requirements.
- Even if parts of the internal algorithm are close to the reference, it cannot replace `src/dtoa.zig` in its current form.

Recommendation:

- Currently unusable. It would need a complete exported ABI layer before deeper evaluation is worthwhile.

### `src/dtoa.zig` - 0.5/10

Test result:

- `zig build test` fails.

Problems:

- The file is a stub: key functions return `0`, `0.0`, or do nothing.
- It only preserves constants and symbols; it has no real dtoa/atod or bignum semantics.

Recommendation:

- Replace it with one of the top-ranked candidates instead of incrementally filling in the stub.

## Adoption Recommendation

Use `answer/reasonix/dtoa.zig` as the first candidate for further work. It passes the tests while offering the best balance of complete reference-style behavior and maintainable Zig structure.

If the priority is to mirror `ref/dtoa.c`'s memory model as directly as possible, consider `answer/antigravity-cli/dtoa.zig`, but expect more pointer-auditing work.

Do not use `answer/codex-gpt5.5-medium/dtoa.zig` or `answer/grok/dtoa.zig` as final implementations even though they pass the current tests. They pass the visible suite, not the full semantics.

## Next Verification Steps

- Build a reference differential harness that calls both `ref/dtoa.c` and a candidate Zig implementation, then compares `js_dtoa` strings, `js_atod` values, and consumed pointers.
- Add randomized `f64` round-trip tests covering normal numbers, subnormals, exponent boundaries, `-0`, NaN, and Infinity.
- Test all radices from 2 through 36, especially non-decimal and non-power-of-two radices.
- Add a matrix for `FREE`, `FIXED`, and `FRAC` formats combined with `EXP_AUTO`, `EXP_ENABLED`, and `EXP_DISABLED`.
- Add static ABI checks so exported names, parameter types, return types, and `callconv(.c)` stay aligned with `ref/dtoa.h` and the existing extern declarations.
