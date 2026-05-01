"""Strip the stale zero-width `.ConfigBits(...)` / `.ConfigBits_N(...)`
lines from the four hand-shipped CPU_IO tile wrappers, plus the trailing
comma that precedes them. Modern FABulous omits those ports on switch
matrices that have no config bits."""
from pathlib import Path

ROOT = Path("/home/theofanis/BugFix2/ICESOC_FABulous_user_project/Tile")
TARGETS = [
    "E_CPU_IO/E_CPU_IO.v",
    "W_CPU_IO/W_CPU_IO.v",
    "W_CPU_IO_bot/W_CPU_IO_bot.v",
    "E_CPU_IO_bot/E_CPU_IO_bot.v",
]

for rel in TARGETS:
    path = ROOT / rel
    text = path.read_text()
    # Remove the two zero-width lines.
    new = text.replace(
        "    .ConfigBits(ConfigBits[20-1:20]),\n"
        "    .ConfigBits_N(ConfigBits_N[20-1:20])\n",
        "",
    )
    if new == text:
        print(f"NOT MATCHED in {rel}")
        continue
    # The line that previously ended with `,` before our removed pair was
    # `.RES2_I3(RES2_I3),`. Now it's the LAST port and needs no trailing
    # comma. Remove that comma to make iverilog happy.
    new = new.replace(
        "    .RES2_I3(RES2_I3),\n);", "    .RES2_I3(RES2_I3)\n);"
    )
    path.write_text(new)
    print(f"patched {rel}")
