---
name: kicad-gerber-export
description: Use when generating Gerber and drill files from KiCad PCB projects, especially via the KiCad Docker container. Triggers on keywords like "gerber", "kicad docker", "pcb manufacturing files", "export gerber", or when a KiCad project needs fabrication outputs.
---

# KiCad Gerber Export via Docker

Generate manufacturing files from `.kicad_pcb` files using the official `kicad/kicad` Docker image. No local KiCad install needed.

## Quick Reference

```bash
# Pull image (only once — no :latest tag exists)
docker pull kicad/kicad:9.0

# Export Gerbers
docker run --rm -v $(pwd):/project kicad/kicad:9.0 \
  kicad-cli pcb export gerbers \
  --output /project/output-dir \
  --layers F.Cu,B.Cu,F.Paste,B.Paste,F.Silkscreen,B.Silkscreen,F.Mask,B.Mask,Edge.Cuts \
  --no-protel-ext \
  /project/path/to/board.kicad_pcb

# Export drill file
docker run --rm -v $(pwd):/project kicad/kicad:9.0 \
  kicad-cli pcb export drill \
  --output /project/output-dir \
  /project/path/to/board.kicad_pcb
```

## Layers

Standard 2-layer board layer set:

| Layer | Description |
|-------|-------------|
| F.Cu  | Front copper |
| B.Cu  | Back copper |
| F.Paste | Front solder paste |
| B.Paste | Back solder paste |
| F.Silkscreen | Front silkscreen |
| B.Silkscreen | Back silkscreen |
| F.Mask | Front soldermask |
| B.Mask | Back soldermask |
| Edge.Cuts | Board outline |

## Common Pitfalls

- **No `latest` tag** — `kicad/kicad:latest` doesn't exist. Use a version tag like `:9.0`.
- **UID mismatch** — Docker runs as root. Files written to the volume mount will be owned by root (uid 0). Use `chown` after if needed.
- **Project dependencies** — The `.kicad_pcb` file references footprints and libraries relative to the project. Mount the entire project root (not just the PCB directory) to ensure libraries resolve.
- **Mulitple boards** — For projects with left/right boards, run the same commands per board, changing only the input and output paths.
- **`.gbrjob` file** — A job file is auto-generated alongside the gerbers; keep it in the zip for manufacturers that support it.

## Complete Example: Two-Board Project

```bash
PROJECT_ROOT="/home/user/my-keyboard"
IMAGE="kicad/kicad:9.0"
LAYERS="F.Cu,B.Cu,F.Paste,B.Paste,F.Silkscreen,B.Silkscreen,F.Mask,B.Mask,Edge.Cuts"

for side in left right; do
  mkdir -p "$PROJECT_ROOT/pcb/$side/gerber"

  docker run --rm -v "$PROJECT_ROOT:/project" "$IMAGE" \
    kicad-cli pcb export gerbers \
    --output "/project/pcb/$side/gerber" \
    --layers "$LAYERS" \
    --no-protel-ext \
    "/project/pcb/$side/board.kicad_pcb"

  docker run --rm -v "$PROJECT_ROOT:/project" "$IMAGE" \
    kicad-cli pcb export drill \
    --output "/project/pcb/$side/gerber" \
    "/project/pcb/$side/board.kicad_pcb"

  zip -j "$PROJECT_ROOT/pcb/$side/gerber-$side.zip" \
    "$PROJECT_ROOT/pcb/$side/gerber"/*
done
```
