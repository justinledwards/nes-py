# Research Notes

## Benchmark Notes

### Headless stepping comparison

Machine-local comparison performed on April 23, 2026 using:

- Python `3.12.9` for both environments
- ROM: shared bundled reference ROM
- Warmup: `500` frames
- Measured frames per run: `3000`
- Repeats: `3`
- Input: no-op / controller state `0`

Results:

| Project | Median FPS | Mean FPS | Median ms/frame |
| --- | ---: | ---: | ---: |
| `nes-py` | `1233.6` | `1228.6` | `0.811` |
| `cynes` | `727.5` | `728.4` | `1.375` |

Additional `cynes` batch-call check:

| Project | API | Median FPS | Mean FPS | Median ms/frame |
| --- | --- | ---: | ---: | ---: |
| `cynes` | `step(frames=3000)` | `744.6` | `743.9` | `1.343` |

Interpretation:

- For the current Python-facing single-frame stepping workload, `nes-py` is about `1.70x` faster than `cynes`.
- Even using `cynes` batched stepping, `nes-py` remained faster on this ROM and workload.

### Non-headless / rendered comparison

Rendered comparison performed on April 23, 2026 using:

- Python `3.12.9`
- ROM: shared bundled reference ROM
- Visible window on both emulators
- No-op input
- `cynes` window size normalized to `256x240` using `scaling_factor=1`
- Warmup: `100` frames
- Measured frames per run: `1000`
- Repeats: `3`

Results:

| Project | Median FPS | Mean FPS | Median ms/frame |
| --- | ---: | ---: | ---: |
| `nes-py` rendered | `290.8` | `293.9` | `3.439` |
| `cynes` windowed | `120.0` | `120.0` | `8.333` |

Interpretation:

- With rendering enabled, `nes-py` is about `2.42x` faster than `cynes` on this workload.
- The rendered overhead is substantial for both projects relative to headless stepping, but much larger for `cynes`.

### pyglet fix note

The original `nes-py` rendered benchmark failed on macOS when using `pyglet 1.5.21`, but the failure only appeared after closing one window and opening another in the same process.

Observed crash:

```text
AttributeError: ObjCInstance b'PygletDelegate' has no attribute b'initWithAttributes_'
```

This matched the macOS lifecycle bug discussed in:

- pyglet issue `#1089`
- pyglet PR `#1208`

Updating `pyglet` to `2.1.14` fixed the repeated close/reopen crash in this environment without requiring changes to `nes-py` viewer code.

### ROM compatibility note

A ROM from the sibling `../rom` directory was not usable as a common benchmark input because `nes-py` rejects it during ROM validation with:

```text
ValueError: ROM header zero fill bytes are not zero.
```

For apples-to-apples timing, a shared bundled reference ROM was used instead.

## Memory Mapping Notes

### Can the existing RAM mapping helper be ported from `cynes` to `nes-py`?

Yes, mostly.

`nes-py` exposes a live NumPy buffer at `env.ram`, created in `nes_py/nes_env.py`, so the work-RAM style mapping from the sibling RAM helper can be reused for the standard CPU RAM-backed addresses.

Relevant implementation details:

- `env.ram` is initialized from `_ram_buffer()` in `nes_py/nes_env.py`
- the C API returns a RAM pointer from `Memory(...)` in `nes_py/nes/src/lib_nes_env.cpp`
- the underlying buffer is `0x800` bytes in `nes_py/nes/include/main_bus.hpp`
- read/write behavior is validated in `nes_py/tests/test_nes_env.py`

### Important limitation vs `cynes`

`cynes` exposes a generic Python memory API over a larger addressable region.

`nes-py` does **not** expose a full Python bus API. It exposes only the internal CPU RAM buffer:

- Directly exposed: `$0000-$07FF`
- Mirrored CPU RAM `$0800-$1FFF`: can be mapped manually with `address & 0x07FF`
- Mapper / cartridge RAM `$6000-$7FFF`: implemented in C++ but not surfaced through `env.ram`
- PPU/APU/register space: not surfaced as a Python memory map

### Practical consequence

For game-state constants that live in CPU RAM, the same mapping style works fine in `nes-py`, for example:

- `0x000E` player state
- `0x0009` frame counter
- `0x075A` lives
- `0x0086` player X on screen
- `0x00CE` player Y on screen

Example usage:

```python
from nes_py import NESEnv

env = NESEnv("<reference-rom-path>")
obs, info = env.reset()

lives = env.ram[0x075A]
player_state = env.ram[0x000E]
env.ram[0x075A] = 3

env.close()
```
