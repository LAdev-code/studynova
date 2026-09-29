from pathlib import Path
from PIL import Image, ImageOps

INPUT_DIR = Path("input")
OUTPUT_DIR = Path("output")
TARGET_SIZE = (1200, 800)


def make_gradient_background(width, height, start=(245, 247, 250), end=(226, 233, 240)):
    bg = Image.new("RGBA", (width, height))
    pixels = bg.load()

    for y in range(height):
        t = y / max(height - 1, 1)
        r = int(start[0] + (end[0] - start[0]) * t)
        g = int(start[1] + (end[1] - start[1]) * t)
        b = int(start[2] + (end[2] - start[2]) * t)
        for x in range(width):
            pixels[x, y] = (r, g, b, 255)

    return bg


def fit_center(image, container_size, padding=30):
    iw, ih = image.size
    cw, ch = container_size

    scale = min((cw - padding * 2) / iw, (ch - padding * 2) / ih)
    new_w = max(1, int(iw * scale))
    new_h = max(1, int(ih * scale))

    resized = image.resize((new_w, new_h), Image.Resampling.LANCZOS)
    x = (cw - new_w) // 2
    y = (ch - new_h) // 2
    return resized, (x, y)


def process_image(input_path: Path, output_path: Path):
    with Image.open(input_path) as img:
        img = ImageOps.exif_transpose(img).convert("RGBA")

        canvas = make_gradient_background(*TARGET_SIZE)
        resized, pos = fit_center(img, TARGET_SIZE, padding=30)
        canvas.alpha_composite(resized, pos)

        canvas.save(output_path, format="PNG", optimize=True, compress_level=9)


def main():
    INPUT_DIR.mkdir(exist_ok=True)
    OUTPUT_DIR.mkdir(exist_ok=True)

    files = sorted(
        p for p in INPUT_DIR.iterdir()
        if p.is_file() and p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
    )

    if not files:
        print(f"No images found in '{INPUT_DIR}'.")
        return

    for src in files:
        dst = OUTPUT_DIR / f"{src.stem}_processed.png"
        process_image(src, dst)
        print(f"Processed: {src.name} -> {dst.name}")

    print(f"\nDone. Output saved in: {OUTPUT_DIR.resolve()}")


if __name__ == "__main__":
    main()
