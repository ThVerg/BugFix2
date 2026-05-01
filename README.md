# BugFix2 — FABulous T-shape geometry workspace

Working copy of the WIP investigation into the T-shape fabric geometry bug
in FABulous, plus the ICESOC user project that triggers it.

## Layout

- `FABulous/` — fork of [FPGA-Research/FABulous](https://github.com/FPGA-Research/FABulous)
  with uncommitted changes for the geometry fix:
  - `fabulous/geometry_generator/fabric_geometry.py` — T-shape border classification
    + neighbour lookup + identity comparison fix.
  - `fabulous/geometry_generator/tile_geometry.py` — fall-back when a border
    tile has no axis neighbour (1xN / Nx1 fabrics, T-shape shoulders).
  - `tests/geometry_generator_test/test_fabric_geometry.py` — new regression
    tests for 1xN, Nx1, and T-shape internal shoulders.
- `ICESOC_FABulous_user_project/` — fork of [enrica-schmidt/ICESOC_FABulous_user_project](https://github.com/enrica-schmidt/ICESOC_FABulous_user_project),
  with project-side patches:
  - `Tile/E_CPU_IO/E_CPU_IO.v`, `Tile/W_CPU_IO/W_CPU_IO.v`,
    `Tile/W_CPU_IO_bot/W_CPU_IO_bot.v`, `Tile/E_CPU_IO_bot/E_CPU_IO_bot.v` —
    stripped stale zero-width `.ConfigBits(...)`/`.ConfigBits_N(...)` from
    the switch-matrix instantiations (modern FABulous omits those ports
    when the switch matrix has no config bits).
  - `Tile/E_CPU_IO_bot/E_CPU_IO_bot_switch_matrix.list`,
    `Tile/W_CPU_IO_bot/W_CPU_IO_bot_switch_matrix.list` — added
    `WW4BEG[0..15] -> EE4END[0..15]` / `EE4BEG[0..15] -> WW4END[0..15]`
    pass-throughs (mirrors `IAmMarcelJung/ICESOC_FABulous_user_project@fix/add-missing-tile-ports`).
  - `icesoc_sim/Test/Makefile` — updated `copy_files` to source tile
    wrappers from `Tile/` and `Fabric/` instead of the stale snapshot in
    `rtl_icesoc_with_cores/original_fabric_files/`.
- `CLAUDE_HANDOFF.md` — note from the assist run that introduced the
  thin-fabric handling (1xN / Nx1) and the `==`→`is` correctness fix.
- `eFPGA_geometry_repo_provided.csv` — copy of the geometry CSV that
  shipped with the upstream ICESOC project (kept for reference / diffing
  against regenerated geometry).
- `strip_configbits.py` — one-shot helper that produced the four CPU_IO
  wrapper patches.

## Setting up

The two source trees are detached from their upstreams in this snapshot.
To resume work with full git history:

```bash
cd FABulous && git init && git remote add origin https://github.com/FPGA-Research/FABulous.git && git fetch origin && git reset origin/main -- :/  # then `git status` shows the WIP changes
cd ../ICESOC_FABulous_user_project && git init && git remote add origin https://github.com/enrica-schmidt/ICESOC_FABulous_user_project.git && git fetch origin && git reset origin/main -- :/
```

For the Python environments (excluded from the snapshot):

```bash
cd FABulous && uv sync     # creates .venv with all deps
```

OSS CAD Suite (yosys, nextpnr-generic, iverilog) is expected at the path
in `~/.fabulous/.env`.

## End-to-end status (at snapshot time)

- `gen_geometry` succeeds on the T-shape ICESOC fabric (was crashing on
  upstream main).
- Tests in `tests/geometry_generator_test/test_fabric_geometry.py` pass
  (and fail on unpatched code — verified).
- Yosys synthesis + nextpnr-fabulous PnR + bit_gen succeed end-to-end on
  the ICESOC project's `top.v`.
- Iverilog simulation hits unrelated project-side drift (legacy
  `models_pack.v`, `*_tile.v` duplicate module declarations); patches
  staged but the testbench port list in `Test/top_tb.v` mismatches the
  generated `eFPGA_top.v` and would need further reconciliation. The
  `icesoc_sim/Test` flow is closer (matches generated port names) and is
  the more promising place to continue.
