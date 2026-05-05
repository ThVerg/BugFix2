"""Tests for fabric geometry generation edge cases."""

import random
from pathlib import Path

import pytest

from fabulous.fabric_definition.define import IO, Direction, Side
from fabulous.fabric_definition.fabric import Fabric
from fabulous.fabric_definition.port import Port
from fabulous.fabric_definition.tile import Tile
from fabulous.geometry_generator.fabric_geometry import FabricGeometry
from fabulous.geometry_generator.geometry_obj import Border


def make_ports() -> list[Port]:
    """Create minimal valid ports on all sides of a tile."""
    return [
        Port(
            Direction.NORTH,
            "NBEG",
            0,
            -1,
            "NEND",
            1,
            "NBEG",
            IO.OUTPUT,
            Side.NORTH,
        ),
        Port(
            Direction.SOUTH,
            "SBEG",
            0,
            1,
            "SEND",
            1,
            "SBEG",
            IO.OUTPUT,
            Side.SOUTH,
        ),
        Port(
            Direction.EAST,
            "EBEG",
            1,
            0,
            "EEND",
            1,
            "EBEG",
            IO.OUTPUT,
            Side.EAST,
        ),
        Port(
            Direction.WEST,
            "WBEG",
            -1,
            0,
            "WEND",
            1,
            "WBEG",
            IO.OUTPUT,
            Side.WEST,
        ),
    ]


def make_tile(name: str) -> Tile:
    """Create a minimal tile with enough side ports to generate geometry."""
    return Tile(name, make_ports(), [], Path("/tmp"), Path("/tmp"), [], False)


def make_fabric(mask: list[list[bool]]) -> Fabric:
    """Build a fabric from a boolean occupancy mask."""
    grid = []
    tile_dic = {}

    for row_idx, row in enumerate(mask):
        fabric_row = []
        for col_idx, occupied in enumerate(row):
            if not occupied:
                fabric_row.append(None)
                continue

            name = f"T_{row_idx}_{col_idx}"
            tile = make_tile(name)
            tile_dic[name] = tile
            fabric_row.append(tile)
        grid.append(fabric_row)

    return Fabric(
        fabric_dir=Path("/tmp/fabric.csv"),
        tile=grid,
        numberOfRows=len(mask),
        numberOfColumns=len(mask[0]),
        tileDic=tile_dic,
        superTileEnable=False,
    )


def assert_wire_locations_are_valid(geometry: FabricGeometry) -> None:
    """Assert generated wire paths contain concrete integer coordinates."""
    for tile_geometry in geometry.tileGeomMap.values():
        for wire_geometry in tile_geometry.wireGeomList:
            for location in wire_geometry.path:
                assert isinstance(location.x, int)
                assert isinstance(location.y, int)


def test_one_row_fabric_generates_without_vertical_neighbour() -> None:
    """A one-row fabric has no vertical neighbour to align to."""
    geometry = FabricGeometry(make_fabric([[True, True, True, True, True, True]]))

    middle_tile = geometry.tileGeomMap["T_0_3"]
    assert middle_tile.border == Border.NORTHSOUTH
    assert middle_tile.neighbourConstraints is None
    assert_wire_locations_are_valid(geometry)


def test_one_column_fabric_generates_without_horizontal_neighbour() -> None:
    """A one-column fabric has no horizontal neighbour to align to."""
    geometry = FabricGeometry(
        make_fabric([[True], [True], [True], [True], [True], [True]])
    )

    middle_tile = geometry.tileGeomMap["T_3_0"]
    assert middle_tile.border == Border.EASTWEST
    assert middle_tile.neighbourConstraints is None
    assert_wire_locations_are_valid(geometry)


def test_t_shape_internal_edges_align_to_in_fabric_neighbours() -> None:
    """Internal T-shape shoulders should use the adjacent in-fabric tile constraints."""
    geometry = FabricGeometry(
        make_fabric(
            [
                [False, True, True, True, False],
                [False, True, True, True, False],
                [True, True, True, True, True],
                [True, True, True, True, True],
            ]
        )
    )

    top_middle = geometry.tileGeomMap["T_0_2"]
    assert top_middle.border == Border.NORTHSOUTH
    assert (
        top_middle.neighbourConstraints
        is geometry.tileGeomMap["T_1_2"].wireConstraints
    )

    left_shoulder = geometry.tileGeomMap["T_1_1"]
    assert left_shoulder.border == Border.EASTWEST
    assert (
        left_shoulder.neighbourConstraints
        is geometry.tileGeomMap["T_1_2"].wireConstraints
    )

    right_shoulder = geometry.tileGeomMap["T_1_3"]
    assert right_shoulder.border == Border.EASTWEST
    assert (
        right_shoulder.neighbourConstraints
        is geometry.tileGeomMap["T_1_2"].wireConstraints
    )

    assert_wire_locations_are_valid(geometry)


# ============================================================================
# Randomized stress harness — reproduces the 250 / 1000 / 64 fabric counts
# documented in CLAUDE_HANDOFF.md. Always run; seeds are fixed so failures
# bisect deterministically.
# ============================================================================


def _random_rectangular_mask(rng: random.Random, max_dim: int = 12) -> list[list[bool]]:
    """All-True 2D mask, 2..max_dim per side."""
    rows = rng.randint(2, max_dim)
    cols = rng.randint(2, max_dim)
    return [[True] * cols for _ in range(rows)]


def _random_t_shape_mask(rng: random.Random, max_dim: int = 12) -> list[list[bool]]:
    """Inverted-T or upright-T fabric: a narrow stem and a wider base.

    Stem width is 1..base_width-2 cells, randomly aligned within the base.
    Stem and base each get 1..max_dim rows. Half the time the T is flipped
    so the wide base is on top instead of the bottom.
    """
    base_cols = rng.randint(3, max_dim)
    stem_cols = rng.randint(1, max(1, base_cols - 2))
    pad_left = rng.randint(0, base_cols - stem_cols)
    stem_rows = rng.randint(1, max_dim)
    base_rows = rng.randint(1, max_dim)
    stem_row = (
        [False] * pad_left
        + [True] * stem_cols
        + [False] * (base_cols - pad_left - stem_cols)
    )
    base_row = [True] * base_cols
    rows = [stem_row[:] for _ in range(stem_rows)] + [
        base_row[:] for _ in range(base_rows)
    ]
    if rng.random() < 0.5:
        rows.reverse()  # base on top instead of bottom
    return rows


def _thin_masks() -> list[list[list[bool]]]:
    """All 1xN and Nx1 fabrics for N in 1..32 (64 total, matches handoff doc)."""
    masks: list[list[list[bool]]] = []
    for n in range(1, 33):
        masks.append([[True] * n])  # 1xN
    for n in range(1, 33):
        masks.append([[True] for _ in range(n)])  # Nx1
    return masks


def _stats_for(geometry: FabricGeometry) -> tuple[int, int, int]:
    """Return (border_tiles, fallback_hits, total_wire_lines) for one fabric.

    A "fallback hit" is a border-axis tile (NORTHSOUTH or EASTWEST) that
    ended up with neighbourConstraints == None, meaning the new
    integer-fallback path in tile_geometry.py.generateDirectWires kicked in
    instead of borrowing wire positions from a same-axis neighbour.
    """
    border = 0
    fallback = 0
    wires = 0
    for tg in geometry.tileGeomMap.values():
        if tg.border in (Border.NORTHSOUTH, Border.EASTWEST, Border.CORNER):
            border += 1
            if (
                tg.border in (Border.NORTHSOUTH, Border.EASTWEST)
                and tg.neighbourConstraints is None
            ):
                fallback += 1
        wires += sum(max(0, len(w.path) - 1) for w in tg.wireGeomList)
        for stair in tg.stairWiresList:
            wires += sum(max(0, len(w.path) - 1) for w in stair.wireGeoms)
    return border, fallback, wires


def test_randomized_rectangular_fabrics() -> None:
    """250 random rectangular fabrics. No tile should hit the fallback."""
    rng = random.Random(0xFAB00010)
    n = 250
    total_border = total_fallback = total_wires = 0
    for _ in range(n):
        geometry = FabricGeometry(make_fabric(_random_rectangular_mask(rng)))
        b, f, w = _stats_for(geometry)
        total_border += b
        total_fallback += f
        total_wires += w
        assert_wire_locations_are_valid(geometry)
    print(
        f"\nRectangular: {n} fabrics, {total_border} border tiles, "
        f"{total_fallback} fallback hits, {total_wires} wire lines"
    )
    # Rectangular fabrics have a same-axis neighbour for every border tile,
    # so the fallback path should never trigger.
    assert total_fallback == 0
    assert total_border > 0


def test_randomized_t_shape_fabrics() -> None:
    """1000 random T-shape fabrics. Concavity tiles must classify cleanly."""
    rng = random.Random(0xFAB00020)
    n = 1000
    total_border = total_fallback = total_wires = 0
    for _ in range(n):
        geometry = FabricGeometry(make_fabric(_random_t_shape_mask(rng)))
        b, f, w = _stats_for(geometry)
        total_border += b
        total_fallback += f
        total_wires += w
        assert_wire_locations_are_valid(geometry)
    print(
        f"\nT-shape: {n} fabrics, {total_border} border tiles, "
        f"{total_fallback} fallback hits, {total_wires} wire lines"
    )
    assert total_border > 0


def test_thin_fabrics_1xn_and_nx1() -> None:
    """All 1xN and Nx1 fabrics through N=32 (64 total).

    Every interior tile of a thin fabric is a border-axis tile with no
    same-axis neighbour to borrow from, so they all hit the fallback path.
    """
    masks = _thin_masks()
    total_border = total_fallback = total_wires = 0
    for mask in masks:
        geometry = FabricGeometry(make_fabric(mask))
        b, f, w = _stats_for(geometry)
        total_border += b
        total_fallback += f
        total_wires += w
        assert_wire_locations_are_valid(geometry)
    print(
        f"\nThin: {len(masks)} fabrics, {total_border} border tiles, "
        f"{total_fallback} fallback hits, {total_wires} wire lines"
    )
    assert total_border > 0
    assert total_fallback > 0


# ============================================================================
# Negative tests — fabrics that *should* fail under FabricGeometry, plus
# a few atypical-but-valid topologies the fix is expected to handle.
# These are NOT marked slow; they run by default to guard the input contract.
# ============================================================================


def test_empty_mask_raises() -> None:
    """A fabric with zero rows is malformed input.

    `make_fabric([])` builds a `Fabric` with `numberOfRows=0` and
    `numberOfColumns=len(mask[0])` which crashes immediately on the empty list.
    Documents that the geometry generator does not accept this — callers must
    validate inputs upstream.
    """
    with pytest.raises(IndexError):
        FabricGeometry(make_fabric([]))


def test_zero_width_fabric_raises() -> None:
    """A fabric with one row but zero columns is also malformed input.

    Same root cause as the empty-mask case: the generator iterates by row /
    column index assuming `numberOfColumns >= 1`. Zero columns trips an index
    error during border classification.
    """
    with pytest.raises(IndexError):
        FabricGeometry(make_fabric([[]]))


def test_donut_topology_handles_internal_hole() -> None:
    """A 5x5 fabric with a single NULL cell in the middle (a "donut").

    The four tiles immediately around the hole each have a NULL on one of
    their sides, so they should be classified as a single-axis border
    (NORTHSOUTH or EASTWEST, not CORNER) and should successfully borrow
    constraints from a neighbour on the opposite axis-side.

    This is the same shape of regression as the T-shape internal-shoulder
    test but with the concavity pinned in the middle instead of the edge.
    """
    geometry = FabricGeometry(
        make_fabric(
            [
                [True, True, True,  True, True],
                [True, True, True,  True, True],
                [True, True, False, True, True],
                [True, True, True,  True, True],
                [True, True, True,  True, True],
            ]
        )
    )
    # Hole-adjacent tiles get a single-axis border classification.
    assert geometry.tileGeomMap["T_1_2"].border == Border.NORTHSOUTH  # above hole
    assert geometry.tileGeomMap["T_3_2"].border == Border.NORTHSOUTH  # below
    assert geometry.tileGeomMap["T_2_1"].border == Border.EASTWEST    # left
    assert geometry.tileGeomMap["T_2_3"].border == Border.EASTWEST    # right
    # And those tiles should each have valid neighbour constraints (their
    # NORTHSOUTH/EASTWEST lookup succeeds via the new fall-through-to-other-side
    # logic).
    for name in ("T_1_2", "T_3_2", "T_2_1", "T_2_3"):
        assert geometry.tileGeomMap[name].neighbourConstraints is not None
    assert_wire_locations_are_valid(geometry)


def _count_islands(mask: list[list[bool]]) -> int:
    """Count 4-connected components of `True` cells in `mask`.

    A "fabric island" is a maximal set of `True` cells reachable from one
    another via N/S/E/W steps. A fabric with >1 island is physically
    disconnected — the geometry generator should reject it.
    """
    if not mask or not mask[0]:
        return 0
    rows, cols = len(mask), len(mask[0])
    seen = [[False] * cols for _ in range(rows)]
    islands = 0
    for r0 in range(rows):
        for c0 in range(cols):
            if not mask[r0][c0] or seen[r0][c0]:
                continue
            islands += 1
            stack = [(r0, c0)]
            while stack:
                r, c = stack.pop()
                if not (0 <= r < rows and 0 <= c < cols):
                    continue
                if seen[r][c] or not mask[r][c]:
                    continue
                seen[r][c] = True
                stack.extend(((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)))
    return islands


def _is_disconnected(mask: list[list[bool]]) -> bool:
    """A fabric is disconnected if it has 0 or >=2 islands.

    A 1-tile fabric counts as 1 island for this helper but is still
    degenerate in the "no neighbours" sense; that case is asserted
    separately by the isolated-tile test.
    """
    return _count_islands(mask) != 1


# ---------------------------------------------------------------------------
# Aspirational xfail tests for fabric topologies the generator should reject.
#
# `xfail(strict=True)` means: this test is expected to fail today (the
# generator doesn't validate connectivity). The mark suppresses the failure
# in CI, but if the test ever starts passing — i.e. someone adds a
# connectivity check upstream and `FabricGeometry(...)` raises — pytest
# reports XPASS and strict mode flips it to a hard FAIL, forcing whoever
# fixed the bug to come delete the xfail label.
#
# Each test first asserts via `_count_islands` that its mask is genuinely
# disconnected, so the test can't silently rot if the mask is edited.
# ---------------------------------------------------------------------------


@pytest.mark.xfail(
    reason=(
        "FabricGeometry doesn't validate connectivity. Any fabric split into "
        "disconnected islands has no routable inter-region wires and no "
        "coherent bitstream-load path, so the generator should reject it. "
        "Currently it silently builds independent geometries for each island. "
        "When connectivity validation is added upstream, this test starts "
        "passing and the xfail mark should be removed."
    ),
    strict=True,
)
def test_disconnected_islands_should_be_rejected() -> None:
    """Two 2x2 fabric islands separated by an all-NULL row."""
    mask = [
        [True,  True],
        [True,  True],
        [False, False],
        [True,  True],
        [True,  True],
    ]
    assert _count_islands(mask) == 2, "test mask is not actually disconnected"
    with pytest.raises((ValueError, RuntimeError)):
        FabricGeometry(make_fabric(mask))


@pytest.mark.xfail(
    reason=(
        "Same connectivity-validation gap as above, but a horizontal split "
        "(two side-by-side islands separated by an all-NULL column). When "
        "connectivity validation lands this should also start passing."
    ),
    strict=True,
)
def test_horizontally_disconnected_islands_should_be_rejected() -> None:
    """Two 2x2 fabric islands separated by a column of NULLs."""
    mask = [
        [True, True, False, True, True],
        [True, True, False, True, True],
    ]
    assert _count_islands(mask) == 2, "test mask is not actually disconnected"
    with pytest.raises((ValueError, RuntimeError)):
        FabricGeometry(make_fabric(mask))


@pytest.mark.xfail(
    reason=(
        "Single isolated tile completely surrounded by NULL is also a "
        "degenerate disconnected fabric — the generator should reject it. "
        "Currently it builds geometry for the lone CORNER tile and stops."
    ),
    strict=True,
)
def test_single_isolated_tile_should_be_rejected() -> None:
    """One tile floating in a sea of NULL.

    Counts as 1 island for `_count_islands` but is degenerate: the lone
    tile has no in-fabric neighbour on any side.
    """
    mask = [
        [False, False, False, False, False],
        [False, False, False, False, False],
        [False, False, True,  False, False],
        [False, False, False, False, False],
        [False, False, False, False, False],
    ]
    assert _count_islands(mask) == 1, "isolated-tile test mask is malformed"
    # All four neighbours of the lone tile must be NULL.
    assert not mask[1][2] and not mask[3][2] and not mask[2][1] and not mask[2][3]
    with pytest.raises((ValueError, RuntimeError)):
        FabricGeometry(make_fabric(mask))


def test_l_shape_inner_corner_is_correctly_classified() -> None:
    """L-shaped fabric: stem is one column wide, base is the bottom row.

    Tile T_2_1 sits at the inner corner of the L (NULL above, real tile
    below and to the right), so its only NULL adjacency is on the north
    side. The new classification widens NORTHSOUTH to include that case.
    """
    geometry = FabricGeometry(
        make_fabric(
            [
                [True, False, False],
                [True, False, False],
                [True, True,  True ],
            ]
        )
    )
    # Stem column (single-cell-wide) is EASTWEST border throughout
    assert geometry.tileGeomMap["T_1_0"].border == Border.EASTWEST
    # Inner corner: NULL above, real to right and below → NORTHSOUTH
    assert geometry.tileGeomMap["T_2_1"].border == Border.NORTHSOUTH
    assert_wire_locations_are_valid(geometry)
