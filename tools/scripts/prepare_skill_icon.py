"""Convert artwork to an opaque 16x16 skill icon with the shared frame (Pillow)."""

import argparse
from pathlib import Path

from PIL import Image, ImageColor


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--colors", type=int, default=12)
    parser.add_argument("--palette", choices=("median", "maximum"), default="median",
                        help="maximum preserves small contrasting highlights")
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--sample", choices=("nearest", "box"), default="nearest")
    parser.add_argument("--padding", type=int, default=0, help="background margin in final pixels")
    parser.add_argument("--background", default="#290b16", help="opaque fallback color")
    parser.add_argument("--frame", type=Path, default=Path(__file__).resolve().parents[2]
                        / "assets/graphics/skill/技能框.png")
    parser.add_argument("--force", action="store_true", help="replace existing outputs explicitly")
    args = parser.parse_args()
    if not 2 <= args.colors <= 16:
        parser.error("--colors must be between 2 and 16")
    if not 0 <= args.padding <= 3:
        parser.error("--padding must be between 0 and 3")
    targets = [args.output] + ([args.preview] if args.preview else [])
    if args.source.resolve() in [path.resolve() for path in targets]:
        parser.error("source must not be overwritten")
    if not args.force and any(path.exists() for path in targets):
        parser.error("output already exists; choose a new filename")
    source = Image.open(args.source).convert("RGBA")
    if source.width != source.height:
        parser.error("source must be square; compose/crop it explicitly first")
    frame = Image.open(args.frame).convert("RGBA")
    if frame.size != (16, 16):
        parser.error("frame must be exactly 16x16")
    try:
        background = ImageColor.getrgb(args.background)
        if len(background) != 3:
            raise ValueError("background must be RGB")
    except ValueError as error:
        parser.error(str(error))
    method = Image.Resampling.NEAREST if args.sample == "nearest" else Image.Resampling.BOX
    edge = 16 - 2 * args.padding
    icon = Image.new("RGBA", (16, 16), (*background, 255))
    icon.alpha_composite(source.resize((edge, edge), method), (args.padding, args.padding))
    palette_method = (Image.Quantize.MAXCOVERAGE if args.palette == "maximum"
                      else Image.Quantize.MEDIANCUT)
    icon = icon.convert("RGB").quantize(colors=args.colors, method=palette_method,
                                       dither=Image.Dither.NONE).convert("RGBA")
    # Overlay last: never quantize or rescale the shared frame's original colors.
    icon = Image.alpha_composite(icon, frame)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    icon.save(args.output)
    if args.preview:
        args.preview.parent.mkdir(parents=True, exist_ok=True)
        icon.resize((256, 256), Image.Resampling.NEAREST).save(args.preview)
    print(f"Saved {args.output}: {icon.size}, {icon.mode}, "
          f"{len(set(icon.getdata()))} colors, alpha={icon.getchannel('A').getextrema()}")


if __name__ == "__main__":
    main()
