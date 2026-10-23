"""Build and verify the RhythmShapes release zip. Dev-only."""

import argparse
import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
VERSION = (ROOT / "script" / "RhythmShapes" / "version.lua").read_text(encoding="utf-8")
VERSION = VERSION.split("return", 1)[1].strip().strip('"').strip("'")
NAME = f"RhythmShapesForAviutl2-v{VERSION}"

REQUIRED = [
    "script/RhythmShapes/RhythmShapes.obj2",
    "script/RhythmShapes/version.lua",
    "script/RhythmShapes/rs_util.lua",
    "script/RhythmShapes/rs_audio.lua",
    "script/RhythmShapes/rs_beat.lua",
    "script/RhythmShapes/rs_grid.lua",
    "script/RhythmShapes/rs_motion.lua",
    "script/RhythmShapes/rs_layout.lua",
    "script/RhythmShapes/rs_shape.lua",
    "script/RhythmShapes/rs_preset.lua",
    "script/RhythmShapes/rs_host.lua",
    "README.md",
    "INSTALL.md",
    "CHANGELOG.md",
    "LICENSE",
]

FORBIDDEN = ("/tests/", "/tools/", "/.github/", "/.git/", "ProbeAudio")


def notes():
    text = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    header = f"## [{VERSION}]"
    start = text.find(header)
    if start < 0:
        raise SystemExit(f"changelog section missing: {header}")
    rest = text[start + len(header):]
    nxt = rest.find("\n## ")
    body = rest[:nxt] if nxt >= 0 else rest
    return f"RhythmShapes {VERSION}\n{body.strip()}\n"


def zip_paths():
    mapping = []
    for rel in REQUIRED:
        src = ROOT / rel
        if not src.is_file():
            raise SystemExit(f"missing {rel}")
        if rel.startswith("script/RhythmShapes/"):
            dest = f"{NAME}/RhythmShapes/{src.name}"
        else:
            dest = f"{NAME}/{src.name}"
        mapping.append((src, dest))
    return mapping


def build(dest: pathlib.Path):
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        dest.unlink()
    with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for src, name in zip_paths():
            zf.write(src, name)
    return dest


def verify(path: pathlib.Path):
    with zipfile.ZipFile(path) as zf:
        names = zf.namelist()
    joined = "\n".join(names)
    for token in FORBIDDEN:
        if token in ("/" + joined) or token.strip("/") in joined:
            # Match directory segments inside the archive.
            for name in names:
                norm = "/" + name.replace("\\", "/")
                if token in norm:
                    raise SystemExit(f"forbidden path in zip: {name}")
    expected = {dest for _, dest in zip_paths()}
    actual = set(names)
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if missing or extra:
        raise SystemExit(f"zip contents mismatch\nmissing={missing}\nextra={extra}")
    print(f"verified {path} ({len(names)} files)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    out = pathlib.Path(args.output) if args.output else ROOT / "dist" / f"{NAME}.zip"
    build(out)
    notes_path = out.with_suffix(".notes.md")
    notes_path.write_text(notes(), encoding="utf-8")
    verify(out)
    if args.check:
        print("package check ok")


if __name__ == "__main__":
    main()
