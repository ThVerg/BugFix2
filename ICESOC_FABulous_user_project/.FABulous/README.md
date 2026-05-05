# .FABulous/ — generated cache

**Do not hand-edit anything here.** This is FABulous's cache of derived data structures used by the rest of the build flow. Regenerate by running:

```bash
cd ../../FABulous
SETUPTOOLS_SCM_PRETEND_VERSION_FOR_FABULOUS_FPGA=0.0.0+local \
  uv run --frozen FABulous \
  -p ../ICESOC_FABulous_user_project \
  run "load_fabric; gen_bitStream_spec"
```

## Files

| File | Size | Role |
|---|---|---|
| **`bitStreamSpec.bin`** | ~10 MB | Python pickle of the bitstream specification. Read by `bit_gen` to translate FASM → bitstream. |
| **`bitStreamSpec.csv`** | ~10 MB | Same data in CSV form (for inspection). |
| **`pips.txt`** | ~10 MB | Programmable interconnect points (every routable wire pair in the fabric). Used by **nextpnr-fabulous** during routing. |
| **`bel.txt`** | ~84 KB | BEL placement map. Lists every BEL on the fabric with its (X,Y) coordinate, type, and pins. Used by **nextpnr-fabulous** during placement. |
| **`bel.v2.txt`** | ~384 KB | Extended BEL descriptors (newer format). |
| **`template.pcf`** | ~5 KB | Physical-constraint-file template. |

## Why these are huge

`pips.txt` enumerates every possible wire-to-wire connection in the fabric — the fabric has ~14 rows × 15 cols × ~hundreds of pips per tile. `bitStreamSpec.csv` enumerates every config bit and which fabric primitive it controls.

Both files are derived from `fabric.csv` + `Tile/*` definitions. Regenerated whenever those change.

## Don't commit modified versions thoughtlessly

These get regenerated frequently during development. The git status will show them as modified after any `gen_bitStream_spec` run, but the diff might just be timestamps or numerical noise. If a reviewer asks "why did `.FABulous/bitStreamSpec.csv` change?" the answer is usually "I re-ran gen_bitStream_spec after editing fabric.csv" — that's fine to commit if the underlying source change is real.
