#!/usr/bin/env python3
"""Build the Never-Lost Rainbow XCursor theme from the Windows .ani sources.

The cursors in neverlost/never-lost-rainbow are Windows animated cursors (RIFF
"ACON" containers of 32x32 .cur frames). X11's Xcursor format is also a
multi-frame animated format, so the artwork, hotspots, and 24-frame animation
survive the trip intact -- only the packaging and the cursor *names* differ.

Two things this does that a plain format conversion does not:

  * Windows picks a cursor by role (Arrow, IBeam, SizeNS...); X11 picks it by
    name, and there are ~90 names in circulation -- modern CSS ones (default,
    pointer, ns-resize), legacy X11 ones (left_ptr, xterm, sb_v_double_arrow),
    and MD5-looking hashes that old toolkits still ask for. Any name we don't
    define falls through to the inherited theme, which is how a rainbow theme
    ends up flashing an Adwaita arrow. ROLES below covers the full set harvested
    from Yaru, which ships the most complete alias list on this machine.

  * The source art is 32x32 pixel art. Scaling it up smoothly turns it to mush,
    so each size in SIZES is baked in with nearest-neighbour, keeping the pixels
    crisp. Clients pick the nearest available size at runtime.
"""

import os
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "neverlost" / "never-lost-rainbow"
THEME = "Never-Lost-Rainbow"
DEST = Path.home() / ".local/share/icons" / THEME

# Nominal sizes baked into each cursor file. 32 is the artwork's native size;
# the rest are integer-ish nearest-neighbour upscales. A client asking for a
# size we don't have (e.g. 24) gets the closest one rather than a blurry resize.
SIZES = [32, 48, 64, 96]

# Which source cursor serves which X11 names.
#
# neverlost/never-lost-rainbow holds exactly the 13 cursors named here; the set's
# other 12 alternates, and the Windows .reg that selected them, were dropped once
# this became Linux-only. See neverlost/readme.md for how this diverges from the
# original Windows scheme, and for where to re-download the full set.
ROLES = [
    (
        "01c (select)",
        # Plain arrow, plus the drag-and-drop and scrollbar-button variants
        # Windows draws as a badged arrow -- no badge art here, so a plain
        # arrow beats an unrelated fallback.
        """default arrow left_ptr top_left_arrow right_ptr draft_large draft_small
           context-menu wayland-cursor wayland_cursor center_ptr
           copy alias link dnd-link dnd-copy
           1081e37283d90000800003c07f3ef6bf 6407b0e94181790501fd1e167b474872
           3085a0e285430894940527032f8b26df 640fb0e74195791501fd1ed57b41487f
           a2a266d0498c3104214a47bd64ab0fc8
           up-arrow down-arrow left-arrow right-arrow
           sb_up_arrow sb_down_arrow sb_left_arrow sb_right_arrow""",
    ),
    (
        "02 (help select)",
        """help question_arrow left_ptr_help whats_this dnd-ask
           5c6cd98b3f3ebcb1f9c7f1c204630408 d9ce0ab605698f320427677b458ad60b""",
    ),
    (
        "03a (work background)",
        """progress left_ptr_watch half-busy
           00000000000000020006000e7e9ffc3f 08e8e1c95fe2fc01f976f1e063a24ccd
           3ecb610c1bf2410f44200f48c40d3599""",
    ),
    ("04b (busy)", "wait watch"),
    (
        "05 (precision)",
        """crosshair cross cross_reverse diamond_cross tcross
           X_cursor x-cursor pirate target dotbox dot_box_mask draped_box icon
           cell plus pencil draft zoom-in zoom-out""",
    ),
    ("06a (text)", "text xterm ibeam vertical-text"),
    (
        "08 (unavailable)",
        """not-allowed crossed_circle forbidden no-drop dnd-no-drop
           03b6e0fcb3499374a867c041f52298f0""",
    ),
    (
        "09b (v resize)",
        """ns-resize n-resize s-resize top_side bottom_side row-resize
           double_arrow v_double_arrow sb_v_double_arrow size-ver size_ver split_v
           00008160000006810000408080010102 2870a09082c103050810ffdffffe0204""",
    ),
    (
        "10b (h resize)",
        """ew-resize e-resize w-resize left_side right_side col-resize
           h_double_arrow sb_h_double_arrow size-hor size_hor split_h
           028006030e0e7ebffc7f7070c0600140 14fef782d02440884392942c11205230""",
    ),
    (
        "11b (nw-se resize)",
        """nwse-resize nw-resize se-resize top_left_corner bottom_right_corner
           bd_double_arrow size-fdiag size_fdiag
           c7088f0f3e6c8088236ef8e1e3e70000""",
    ),
    (
        "12b (ne-sw resize)",
        """nesw-resize ne-resize sw-resize top_right_corner bottom_left_corner
           fd_double_arrow size-bdiag size_bdiag
           fcf1c3c7cd4491d801f1e1c78f100000""",
    ),
    (
        "13b (move)",
        """move fleur all-scroll all-resize size_all dnd-move
           4498f0e0c1937ffe01fd06f973665830 9081237383d90e509aa00f00170e968f
           fcf21c00b30f7e3f83fe0dfd12e71cff""",
    ),
    (
        "15b (link select)",
        """pointer hand hand1 hand2 pointing_hand grab openhand
           grabbing closedhand dnd-none
           9d800788f1b08800ae810202380a0822 e29285e634086352946a0e7090d73106""",
    ),
]

IMAGE_TYPE = 0xFFFD0002
IMAGE_HEADER = 36


def read_xcursor(path):
    """Return [(width, height, xhot, yhot, delay, BGRA bytes)] in frame order."""
    data = path.read_bytes()
    if data[:4] != b"Xcur":
        raise ValueError(f"{path} is not an Xcursor file")
    ntoc = struct.unpack_from("<I", data, 12)[0]
    frames = []
    for i in range(ntoc):
        chunk_type, _subtype, pos = struct.unpack_from("<III", data, 16 + i * 12)
        if chunk_type != IMAGE_TYPE:
            continue
        w, h, xhot, yhot, delay = struct.unpack_from("<IIIII", data, pos + 16)
        pixels = data[pos + IMAGE_HEADER : pos + IMAGE_HEADER + w * h * 4]
        frames.append((w, h, xhot, yhot, delay, pixels))
    return frames


def scale_nearest(frame, size):
    """Nearest-neighbour resample one frame to size x size, hotspot included."""
    w, h, xhot, yhot, delay, pixels = frame
    if (w, h) == (size, size):
        return frame
    out = bytearray(size * size * 4)
    # Precompute the source column for each destination column: the inner loop
    # runs size^2 times per frame across ~1300 frames, so this is worth it.
    cols = [(x * w // size) * 4 for x in range(size)]
    for y in range(size):
        row = (y * h // size) * w * 4
        base = y * size * 4
        for x in range(size):
            src = row + cols[x]
            out[base + x * 4 : base + x * 4 + 4] = pixels[src : src + 4]
    return (size, size, xhot * size // w, yhot * size // h, delay, bytes(out))


def write_xcursor(path, frames_by_size):
    """Write one Xcursor file holding every size, each with its full animation."""
    chunks = [(size, f) for size in sorted(frames_by_size) for f in frames_by_size[size]]
    header = 16 + len(chunks) * 12
    body, toc, pos = [], [], header
    for size, (w, h, xhot, yhot, delay, pixels) in chunks:
        toc.append(struct.pack("<III", IMAGE_TYPE, size, pos))
        body.append(
            struct.pack(
                "<IIIIIIIII",
                IMAGE_HEADER, IMAGE_TYPE, size, 1, w, h, xhot, yhot, delay,
            )
            + pixels
        )
        pos += IMAGE_HEADER + len(pixels)
    path.write_bytes(
        struct.pack("<4sIII", b"Xcur", 16, 0x00010000, len(chunks))
        + b"".join(toc)
        + b"".join(body)
    )


def main():
    if not SRC.is_dir():
        sys.exit(f"missing cursor sources: {SRC}")
    if not shutil.which("uv"):
        sys.exit("uv is not installed (it provides uvx, which runs win2xcur) -- `just init`")

    with tempfile.TemporaryDirectory() as tmp:
        # win2xcur does the .ani -> Xcursor format conversion (RIFF frame
        # extraction, BGRA premultiply, hotspots, per-frame delays).
        print("converting .ani sources ...")
        subprocess.run(
            ["uvx", "--from", "win2xcur", "win2xcur", "-o", tmp,
             *sorted(str(p) for p in SRC.glob("*.ani"))],
            check=True,
        )

        cursors = DEST / "cursors"
        if DEST.exists():
            shutil.rmtree(DEST)
        cursors.mkdir(parents=True)

        for stem, names in ROLES:
            src = Path(tmp) / f"Never-Lost Rainbow {stem}"
            if not src.exists():
                sys.exit(f"win2xcur produced no output for {stem!r}")
            base = read_xcursor(src)
            frames_by_size = {s: [scale_nearest(f, s) for f in base] for s in SIZES}

            primary, *aliases = names.split()
            write_xcursor(cursors / primary, frames_by_size)
            for alias in aliases:
                (cursors / alias).symlink_to(primary)
            print(f"  {primary:<14} {len(base):>2} frames, {len(aliases):>2} aliases")

    (DEST / "index.theme").write_text(
        "[Icon Theme]\n"
        f"Name={THEME}\n"
        "Comment=Never-Lost Rainbow by Kelinmiriel (CC BY), converted from Windows .ani\n"
        "Inherits=Adwaita\n"
    )
    (DEST / "cursor.theme").write_text(f"[Icon Theme]\nInherits={THEME}\n")

    total = sum(f.stat().st_size for f in (DEST / "cursors").iterdir() if not f.is_symlink())
    print(f"\ninstalled {THEME} -> {DEST} ({total // 1024 // 1024} MiB)")


if __name__ == "__main__":
    main()
