import socket
import sys
from pathlib import Path

import clii
import fscm


cli = clii.App()
this_dir: Path = fscm.this_dir_path()
home: Path = Path.home()
local_bin = home / ".local/bin"
hostname = socket.gethostname()

def ln(*args, **kwargs):
    kwargs.setdefault('sudo', False)
    return fscm.s.link(*args, **kwargs)

mkdir = fscm.mkdir

def err(*args, **kwargs):
    kwargs.setdefault('file', sys.stderr)
    print(*args, **kwargs)


@cli.main
def main():
    mkdir(home / "src")
    for f in [".vim", ".nvim"]:
        mkdir(home / f / "backup")
        mkdir(home / f / "swp")
        mkdir(home / f / "undo")

    local_bin.mkdir(exist_ok=True, parents=True)

    dot_srcs = [
        this_dir / "dots",
        this_dir / "hosts" / hostname,
    ]

    for src in dot_srcs:
        if not src.is_dir():
            err(f"skipping non-existent dot source {src}")
            continue

        for dir in [d for d in src.rglob("*") if d.is_dir()]:
            relpath = dir.relative_to(src)
            new_dir = Path(home / f".{relpath}")
            if not new_dir.is_dir():
                print(f"creating dir {new_dir}")
                mkdir(new_dir)

        for path in [d for d in src.rglob("*") if not d.is_dir()]:
            relpath = path.relative_to(src)
            ln(path.absolute(), home / f".{relpath}")

    dots_bin = this_dir / "bin"
    mkdir(local_bin)
    for f in [f for f in dots_bin.glob("*")]:
        dest = local_bin / f.relative_to(dots_bin)
        ln(f, dest)
        fscm.make_executable(dest)


if __name__ == "__main__":
    cli.run()
