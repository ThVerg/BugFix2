# Geometry generator tests

Tests for `fabulous/geometry_generator/` — the module that turns a parsed
`Fabric` into per-tile geometry (wire paths, border classifications,
neighbour constraints) consumed by FABulator and the bitstream-spec writer.

## Files

| File | Role |
|---|---|
| `test_fabric_geometry.py` | The pytest suite. Hand-crafted regressions, randomized stress tests, boundary cases, and aspirational xfails. |
| `dump_random_fabrics.py` | Standalone script that re-runs the stress-test corpus and dumps a per-fabric report (mask + metrics). Useful when investigating a regression. |
| `random_fabrics_dump.txt` | Snapshot of `dump_random_fabrics.py`'s output (1314 fabrics, ~440 KB). Regenerate by running the script. |

## Test categories in `test_fabric_geometry.py`

### Hand-crafted regressions
- `test_one_row_fabric_generates_without_vertical_neighbour` — `1xN` thin fabric; every tile is `NORTHSOUTH` border but has no vertical neighbour to borrow constraints from.
- `test_one_column_fabric_generates_without_horizontal_neighbour` — symmetric `Nx1` case.
- `test_t_shape_internal_edges_align_to_in_fabric_neighbours` — T-shape internal-shoulder tile borrows constraints from the in-fabric neighbour on the other side of its NULL adjacency.

### Randomized stress (run by default, ~10s total)
- `test_randomized_rectangular_fabrics` — 250 random rectangles, seed `0xFAB00010`. Asserts no fallback path triggers (rectangles always have a same-axis neighbour).
- `test_randomized_t_shape_fabrics` — 1000 random T-shapes (incl. 1-wide stems, both orientations), seed `0xFAB00020`. Concavity tiles must classify and route cleanly.
- `test_thin_fabrics_1xn_and_nx1` — every `1xN` and `Nx1` fabric for `N=1..32` (64 fabrics, deterministic). Asserts the fallback-hit count equals the closed-form `Σ_{N=3..32} (N−2) × 2 = 930`.

### Boundary / negative
- `test_empty_mask_raises` — `[]` raises `IndexError`.
- `test_zero_width_fabric_raises` — `[[]]` raises `IndexError`.
- `test_donut_topology_handles_internal_hole` — 5x5 with center NULL; hole-adjacent tiles classified `NORTHSOUTH`/`EASTWEST` and get neighbour constraints.
- `test_l_shape_inner_corner_is_correctly_classified` — inner corner of an L has only one NULL adjacency; gets a single-axis border classification.

### Aspirational xfails (`strict=True`)
The geometry generator currently doesn't validate fabric connectivity. These three tests assert it *should* reject disconnected fabrics, and are marked `xfail(strict=True)` to flag this as a known gap. When connectivity validation is added in `FabricGeometry.__init__`, the tests flip to `XPASS` and the strict mark turns CI red, forcing the marks to be removed.

- `test_disconnected_islands_should_be_rejected` — vertical NULL-row split between two `2x2` islands.
- `test_horizontally_disconnected_islands_should_be_rejected` — horizontal NULL-column split.
- `test_single_isolated_tile_should_be_rejected` — single tile in a 5x5 NULL sea.

A `_count_islands(mask)` BFS helper is defined in the test file and used by each xfail test to assert its mask is genuinely disconnected before invoking the generator. Lifting that helper into `FabricGeometry.__init__` (and raising `ValueError` when it returns `!= 1`) is the suggested fix.

## Running

```bash
cd FABulous
SETUPTOOLS_SCM_PRETEND_VERSION_FOR_FABULOUS_FPGA=0.0.0+local \
    uv run --frozen pytest tests/geometry_generator_test/test_fabric_geometry.py -v
```

Expected: `10 passed, 3 xfailed` in ~11s.

## Inspecting the stress corpus

`dump_random_fabrics.py` reproduces every fabric the stress tests generate, with per-fabric metrics. Useful when a stress test fails and you want to see *which* fabric broke and what its topology was.

```bash
cd FABulous
SETUPTOOLS_SCM_PRETEND_VERSION_FOR_FABULOUS_FPGA=0.0.0+local \
    uv run --frozen python tests/geometry_generator_test/dump_random_fabrics.py
```

Writes `random_fabrics_dump.txt` next to the script. Each fabric is rendered as:

```
--- #0001  21x4  occupied=57  border=36  fallback=8  wires=456
    classes: {'CORNER': 5, 'NORTHSOUTH': 3, 'EASTWEST': 28, 'NONE': 21}
    mask:
        ####
        ####
        ...
```

Fields: `dims · occupied tiles · border-tile count · fallback-path hits · total wire lines`, then a Counter of border classifications, then the ASCII-art mask (`#` = tile, `.` = NULL).

Section totals at the bottom of each section match the per-section summary lines printed by the test suite exactly. The committed `random_fabrics_dump.txt` is a reference snapshot; the seeds are fixed so re-running produces a byte-identical (modulo trailing newline) file.
