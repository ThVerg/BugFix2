# Claude Handoff: FABulous T-Shape / Thin-Fabric Geometry Fix

## Context

The workspace root is `/home/theofanis/BugFix2`. The main code checkout is
`/home/theofanis/BugFix2/FABulous`. The user project is
`/home/theofanis/BugFix2/ICESOC_FABulous_user_project`.

The original issue was FABulator geometry generation for a T-shaped fabric with
internal `NULL` regions. A previous fix made tiles next to internal `NULL` cells
count as border tiles. I then tested random fabric sizes and found that `1xN` and
`Nx1` fabrics still failed because a border-axis tile can have no in-fabric
neighbour to borrow wire constraints from.

## Code Changes Made

1. `FABulous/fabulous/geometry_generator/fabric_geometry.py`
   - Changed neighbour-constraint lookup from value equality to identity:
     `if tileGeom is queried:`
   - Reason: `TileGeometry` is a dataclass, so two distinct geometry objects with
     identical default fields can compare equal. Neighbour constraints must be
     assigned to the exact queried geometry object, not another tile type that
     happens to compare equal.

2. `FABulous/fabulous/geometry_generator/tile_geometry.py`
   - Added `alignNorthSouth` and `alignEastWest` booleans:
     - Only use `neighbourConstraints` when the tile is on that border axis and
       `neighbourConstraints is not None`.
     - Otherwise, fall back to local wire spacing.
   - Replaced `next(..., None)` and `next(..., 0)` with integer fallbacks based
     on the current wire position.
   - Reason: middle tiles in `1xN` fabrics are `NORTHSOUTH` border tiles but have
     no vertical neighbour; middle tiles in `Nx1` fabrics are `EASTWEST` border
     tiles but have no horizontal neighbour. They should still generate geometry.

3. `FABulous/tests/geometry_generator_test/test_fabric_geometry.py`
   - Added regression tests for:
     - `1xN` fabric generation with no vertical neighbour.
     - `Nx1` fabric generation with no horizontal neighbour.
     - T-shape internal shoulder tiles aligning to adjacent in-fabric neighbours.

## Verification Run

Focused tests:

```bash
cd /home/theofanis/BugFix2/FABulous
uv run pytest tests/geometry_generator_test/test_fabric_geometry.py -q
# 3 passed

uv run pytest tests/cli_test/test_cli.py::test_gen_geometry -q
# 1 passed

uv run ruff check fabulous/geometry_generator/fabric_geometry.py fabulous/geometry_generator/tile_geometry.py tests/geometry_generator_test/test_fabric_geometry.py
# All checks passed
```

Randomized stress harness:

- `250` random rectangular fabrics passed.
- `1000` random T-shaped fabrics passed.
- `64` one-row or one-column fabrics passed (`1x1` through `1x32`, and `1x1`
  through `32x1`).
- `75,210` border tiles checked.
- `930` border tiles had no same-axis neighbour and used the new fallback path.
- `2,506,264` aggregate wire lines generated.

Real user-project sanity check:

- Parsed `/home/theofanis/BugFix2/ICESOC_FABulous_user_project/fabric.csv`.
- Regenerated geometry stats:
  - rows `16`
  - columns `15`
  - width `4649`
  - height `4770`
  - lines `114310`
- The regenerated temp CSV matched the existing
  `/home/theofanis/BugFix2/ICESOC_FABulous_user_project/eFPGA_geometry.csv`
  byte-for-byte.

## Notes

- The user project still has pre-existing modified files:
  - `ICESOC_FABulous_user_project/eFPGA_geometry.csv`
  - `ICESOC_FABulous_user_project/Tile/LUT4AB/LUT4c_frame_config_dffesr.json`
  - `ICESOC_FABulous_user_project/Tile/LUT4AB/MUX8LUT_frame_config_mux.json`
- I did not revert those.
- The workspace root itself is not a git repo; `FABulous` and
  `ICESOC_FABulous_user_project` are separate git checkouts.
