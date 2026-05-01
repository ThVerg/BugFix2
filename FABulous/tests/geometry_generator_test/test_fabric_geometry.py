"""Tests for fabric geometry generation edge cases."""

from pathlib import Path

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
