# Coding Agent Evaluation: dtoa.zig Rewrite Test

This repository is a focused benchmark for evaluating the implementation quality of different coding agents. The task is to rewrite or port a Zig implementation of `dtoa.zig`, using the reference C implementation under `ref/` as the semantic authority.

The benchmark is intentionally narrow: each agent is judged on whether its submitted `dtoa.zig` can satisfy the current Zig test suite, preserve the expected C ABI, and faithfully reproduce the behavior of the reference dtoa/atod implementation instead of merely passing visible examples.

## Repository Layout

- `ref/` contains the reference C implementation and header.
- `src/` contains the active Zig package and tests.
- `src/dtoa.zig` is the current in-tree implementation slot.
- `src/dtoa_tests.zig` contains direct coverage for integer formatting, bignum helpers, dtoa formatting, and atod parsing.
- `answer/` contains candidate `dtoa.zig` submissions from different coding agents.
- `DTOA_IMPLEMENTATION_REVIEW.md` contains the detailed review, ranking, and scoring of the candidate implementations.

## Evaluation Method

Each candidate is tested by copying its `dtoa.zig` into a temporary checkout as `src/dtoa.zig`, then running:

```sh
timeout 30s zig build test
```

The test result is only one input to the final score. Implementations are also reviewed for:

- correctness across dtoa/atod edge cases,
- fidelity to `ref/dtoa.c`,
- compatibility with the expected C ABI,
- use of the provided temporary memory structs,
- maintainability and safety of pointer-heavy code,
- avoidance of hard-coded answers for the visible tests.

## Current dtoa.zig Review Results

The detailed review is in [`DTOA_IMPLEMENTATION_REVIEW.md`](DTOA_IMPLEMENTATION_REVIEW.md). Its current ranking is summarized below.

| Rank | Candidate | Test Result | Score | Cache Hit (Tokens) | Cache Miss (Tokens) | Output / Turns | Cost (USD) | Summary |
|---:|---|---|---:|:---:|:---:|:---:|:---:|---|
| 1 | `answer/reasonix/dtoa.zig` <br>(DeepSeek V4 Pro) | PASS | 8.8 | 9,803,392 | 265,327 | 73 turns | $0.2370 | Best overall candidate; complete port shape and good maintainability. |
| 2 | `answer/antigravity-cli/dtoa.zig` | PASS | 8.5 | — | 6,844,353 | 35,466 tokens | $10.5900 | Strong, C-like port; more raw-pointer-heavy. |
| 3 | `answer/pi-gpt5.5-xhigh/dtoa.zig` | PASS | 8.0 | 4,034,560 | 192,559 | 42,000 tokens | $4.2401 | Solid implementation; does not closely follow the temp-memory contract. |
| 4 | `answer/codex-gpt5.5-xhigh/dtoa.zig` | PASS | 7.6 | 2,394,112 | 150,788 | 29,798 tokens | $2.8449 | Algorithmically complete, but changes the storage model. |
| 5 | `answer/forge-mimo2.5pro/dtoa.zig` | PASS | 7.2 | 7,967,040 | 496,788 | 95,597 tokens | $2.3770 | Usable, but uses riskier type and alignment choices. |
| 6 | `answer/codex-gpt5.5-medium/dtoa.zig` | PASS | 4.8 | — | — | — | — | Passes current tests but relies on approximations. |
| 7 | `answer/cc-glm5.1/dtoa.zig` | FAIL | 2.4 | — | — | — | — | Has a full-port shape but incorrect bignum/dtoa/atod behavior. |
| 8 | `answer/grok/dtoa.zig` | PASS | 2.0 | — | — | — | — | Passes visible tests through hard-coded cases; not a real implementation. |
| 9 | `answer/forge-glm5.1/dtoa.zig` | FAIL | 1.5 | — | — | — | — | Does not export the required C ABI symbols. |
| 10 | `src/dtoa.zig` | FAIL | 0.5 | — | — | — | — | Stub implementation only. |

*Note: Token and cost metrics are recorded during each candidate's autonomous agent evaluation run.*

The current recommendation is to use `answer/reasonix/dtoa.zig` as the primary candidate for further work. `answer/antigravity-cli/dtoa.zig` is the best alternative if the priority is staying close to the original C memory model.

## Running The Tests

Run the active implementation:

```sh
zig build test
```

To evaluate a candidate manually, copy it over `src/dtoa.zig` in a temporary working tree and run the same command. Avoid replacing the real `src/dtoa.zig` unless you intend to change the active implementation.

## Next Improvements

The current test suite catches many basic failures, but it is not enough to prove semantic parity. The next useful step is a differential harness that compares candidate Zig output against `ref/dtoa.c` across randomized `f64` values, all radices from 2 to 36, and combinations of dtoa format flags.
