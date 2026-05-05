# BugFix2 — FABulous T-shape geometry workspace + ICESOC end-to-end verification

Working copy of the WIP investigation into the FABulous T-shape fabric geometry bug, plus the ICESOC user project that triggers it. The geometry bug is fixed and the project is now verified end-to-end through both the bare-fabric and SoC simulation flows.

## Layout

```
BugFix2/
├── FABulous/                          ← upstream FABulous (FPGA fabric generator)
│   ├── fabulous/
│   │   ├── fabric_generator/gen_fabric/gen_tile.py          (FIXED: ConfigBits guard)
│   │   └── geometry_generator/{fabric,tile}_geometry.py     (FIXED: thin-fabric / NULL-adjacent border classification)
│   └── tests/geometry_generator_test/                       ← geometry test suite + dev aids
│       ├── test_fabric_geometry.py        (regressions, randomized stress, xfails for disconnected fabrics)
│       ├── dump_random_fabrics.py         (per-fabric metrics dump for the stress corpus)
│       ├── random_fabrics_dump.txt        (committed snapshot, 1314 fabrics, ~440 KB)
│       └── README.md                      (test-suite overview + how to regenerate the dump)
│
├── ICESOC_FABulous_user_project/      ← user project: RISC-V SoC + eFPGA fabric
│   ├── fabric.csv                     (FIXED: added missing EE4BEG/WW4BEG ports to bot tiles)
│   ├── Tile/                          ← per-tile definitions (BELs, switch matrix, ConfigMem)
│   ├── Fabric/                        ← FABulous-generated fabric (eFPGA_top.v, eFPGA.v, …)
│   ├── user_design/                   ← bare-fabric user design (top.v, top_wrapper.v)
│   ├── Test/                          ← bare-fabric simulation flow (Makefile, top_tb.v)
│   ├── icesoc_sim/                    ← full SoC simulation
│   │   ├── rtl_icesoc_with_cores/     ← FlexBex/Ibex CPU cores + UART + eFPGA wrapper
│   │   ├── user_design_icesoc/        ← SoC user_design (no IO counter, just W/E ALU)
│   │   └── Test/                      ← SoC simulation flow (Makefile, top_tb.v)
│   └── .FABulous/                     ← FABulous-generated cache (bel maps, pip lists, bitStreamSpec)
│
├── CLAUDE_HANDOFF.md                  ← original assist-run notes (geometry fix in FABulous)
├── eFPGA_geometry_repo_provided.csv   ← reference geometry CSV from upstream
├── strip_configbits.py                ← legacy band-aid; OBSOLETE (gen_tile.py guard supersedes)
└── README.md                          ← this file
```

## What's in this snapshot

The original FABulous T-shape geometry bug was already fixed when this workspace was inherited (see [CLAUDE_HANDOFF.md](CLAUDE_HANDOFF.md)). The work captured here builds on that foundation to **verify the full chain end-to-end**: from RISC-V machine code → CPU custom-instruction decode → eFPGA accelerator → fabric computation → result writeback.

## End-to-end verification (final state)

| Test | Coverage | Result |
|---|---|---|
| FABulous geometry regression tests | T-shape, 1×N, N×1 fabrics | ✅ pass |
| Geometry randomized stress | 1314 random fabrics | ✅ pass |
| Bare-fabric IO counter | 100 cycles of W_IO + LUT4AB DFFs | ✅ 100/100 |
| Bare-fabric stress patterns | 16 hand + 200 random, 6 outputs each | ✅ 216/216 |
| SoC stress (CPU-bypass) | 16 hand + 200 random, full SoC interconnect | ✅ 216/216 |
| SoC firmware Phase A | 3 back-to-back `efpga op=2` instructions → 3 stores | ✅ 3/3 |
| SoC firmware Phase B | `efpga op=0` (ADD) operand-dependent result | ✅ exact bit-level match |

**Total: 535+ checks, 0 mismatches.** Verifies the full path: geometry → synth → P&R → bit_gen → fabric → SoC interconnect → CPU instruction fetch → CPU pipeline → custom-instruction decode → eFPGA FSM → operand routing → fabric computation → result capture → register writeback → memory store.

## Fixes applied on top of the inherited snapshot

### Real upstream fix (replaces a band-aid)

- **`FABulous/fabulous/fabric_generator/gen_fabric/gen_tile.py:528`** — switch-matrix `ConfigBits` connection now guarded on `tile.globalConfigBits > belConfigBitsCounter` instead of `> 0`. Without this, every `gen_all_tile` regeneration emitted broken zero-width ConfigBits ports that needed to be stripped after the fact. **`strip_configbits.py` is now obsolete.**

### ICESOC SoC RTL fixes (real bugs)

- **`icesoc_sim/rtl_icesoc_with_cores/eFPGA_CPU_top.v`** — connected `eFPGA_top.resetn` to `~wb_rst_i`. Was unconnected (Z); single-line fix that blocked all bitstream loading.
- **`icesoc_sim/rtl_icesoc_with_cores/eFPGA_CPU_top.v`** — replaced naive `OPA_I({W_OPA, E_OPA})` concat with per-row interleave + bit-reverse mapping. The fabric expects W/E bits interleaved per Y-row.
- **`icesoc_sim/rtl_icesoc_with_cores/icesoc/icesoc_top.v`** — moved `master_data_*_to_inter_ro` wire decls above first use (iverilog declaration-before-use); tied off floating `irq_ack_1_o`/`irq_id_1_o` (ibex_top doesn't drive those).

### Project-side fabric definition fix

- **`ICESOC_FABulous_user_project/fabric.csv`** — added missing `EAST,EE4BEG,4,0,NULL,4` to W_CPU_IO_bot and `WEST,WW4BEG,-4,0,NULL,4` to E_CPU_IO_bot. Without those ports, the bot tiles couldn't terminate the W4/E4 east-going chain, breaking W6/E6 routing for row Y=9 (transition row) — bottom-of-stem CPU_IO BELs produced X outputs.

### Project-side housekeeping

- **`Fabric/models_pack.v`** — replaced two duplicate `LHQD1` definitions with a single canonical `config_latch (D, E, Q, QN)` matching newer FABulous's primitive name.
- **`Test/Makefile`** — `copy_files` now skips `*_tile.v` (legacy duplicates of canonical `*.v` modules).
- **`Test/top_tb.v`** — rewrote the `eFPGA_top` instantiation to match the current single-bus signature with row-interleave; added 16-pattern + 200-random stress phases + RegFile warmup.
- **`user_design/top.v`** (bare-fabric) — extended to use the RegFile tile via inferred `reg [3:0] regfile [0:31]`.

### Testbench-side scaffolding (sim-only overrides)

- **`icesoc_sim/rtl_icesoc_with_cores/eFPGA_CPU_top.v`** added two override paths:
  - `tb_sw_force/data/strobe`: bypasses UART for fast bitstream load (~250us instead of ~20s sim time).
  - `tb_drive_ops + tb_W_OPA/W_OPB/E_OPA/E_OPB`: drives operand busses directly for deterministic SoC stress patterns. Default off; harmless in synthesis.

## Setting up

The workspace IS a single git repo at this directory. Two source trees inside (`FABulous/` and `ICESOC_FABulous_user_project/`) are forked from upstream but tracked as a single combined snapshot here.

Toolchain (saved at `~/oss-cad-suite/`, `~/.local/bin/`, `BugFix2/FABulous/.venv/`):
- **OSS CAD Suite** — yosys, nextpnr-generic (with `--uarch fabulous`), iverilog, vvp.
- **uv 0.11.8 + FABulous venv** — provides `bit_gen` and the `FABulous` CLI.
- **`~/.fabulous/.env`** — `FAB_OSS_CAD_SUITE=/home/h__t_/oss-cad-suite`.
- **System packages** — `make`, `bzip2`, `python3-tk` (apt).

Activation:
```bash
source ~/oss-cad-suite/environment      # already in ~/.bashrc
```

## Running the tests

### Bare-fabric (`ICESOC_FABulous_user_project/Test/`)

```bash
cd ICESOC_FABulous_user_project/Test
make build_test_design
make run_simulation VVP_ARGS="+bitstream_hex=build/top.hex"   # ~5s, no FST
```

### ICESOC SoC (`ICESOC_FABulous_user_project/icesoc_sim/Test/`)

```bash
cd ICESOC_FABulous_user_project/icesoc_sim/Test
make build_test_design
make run_icesoc_simulation VVP_ARGS="+bitstream_hex=build_icesoc/top.hex +mem_hex=mem.hex"   # ~5s, no FST
```

To regenerate fabric files after editing `fabric.csv` or `Tile/*`:

```bash
cd FABulous
SETUPTOOLS_SCM_PRETEND_VERSION_FOR_FABULOUS_FPGA=0.0.0+local \
  uv run --frozen FABulous \
  -p ../ICESOC_FABulous_user_project \
  run "load_fabric; gen_all_tile; gen_fabric; gen_bitStream_spec"
```

## What's NOT verified (scope notes)

- **UART bitstream load path** — bypassed via `tb_sw_force` for speed (~20s sim → ~250us). The Config FSM and SelfWrite mechanism are verified via the resulting fabric behavior.
- **DSP MULADD instantiation** — module-name signature collision: synth's `prims.v` MULADD has `.CLK` + parameters; fabric's `Tile/DSP/DSP_bot/MULADD.v` has `.UserCLK` + `.ConfigBits`. Same name, incompatible signatures, can't share one source between iverilog and yosys.
- **BRAM (RAM_IO) data access from user_design** — `top_wrapper.v` has the BEL placements but doesn't route the FAB2RAM_*/RAM2FAB_* signals to user-design ports. Wrapper extension needed.
- **Real OS / serious firmware** — only ~10 hand-encoded RISC-V instructions exercised. Enough to prove the data path; not a real workload.

## See also

- [CLAUDE_HANDOFF.md](CLAUDE_HANDOFF.md) — geometry fix that landed before this work
- [FABulous/README.md](FABulous/README.md) — upstream FABulous documentation
- [ICESOC_FABulous_user_project/README.md](ICESOC_FABulous_user_project/README.md) — ICESOC project deep dive
- [ICESOC_FABulous_user_project/Test/README.md](ICESOC_FABulous_user_project/Test/README.md) — bare-fabric test flow
- [ICESOC_FABulous_user_project/icesoc_sim/Test/README.md](ICESOC_FABulous_user_project/icesoc_sim/Test/README.md) — SoC test flow
