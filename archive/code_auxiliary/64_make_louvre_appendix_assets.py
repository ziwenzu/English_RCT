from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path("/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT")
FIGURES = ROOT / "writing" / "figures"

FONT_EN = "/System/Library/Fonts/HelveticaNeue.ttc"
FONT_EN_BOLD = "/System/Library/Fonts/Helvetica.ttc"
FONT_CN = "/System/Library/Fonts/Hiragino Sans GB.ttc"
FONT_CN_BOLD = "/System/Library/Fonts/Hiragino Sans GB.ttc"


def font(path: str, size: int):
    return ImageFont.truetype(path, size)


def rounded(draw, xy, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def wrap_text(draw, text, fnt, max_width):
    if " " in text:
        tokens = text.split()
        joiner = " "
    else:
        tokens = list(text)
        joiner = ""
    lines = []
    current = []
    for token in tokens:
        trial = joiner.join(current + [token])
        if draw.textbbox((0, 0), trial, font=fnt)[2] <= max_width:
            current.append(token)
        else:
            if current:
                lines.append(joiner.join(current))
            current = [token]
    if current:
        lines.append(joiner.join(current))
    return "\n".join(lines)


def draw_wrapped(draw, xy, text, fnt, fill, max_width, spacing=8):
    wrapped = wrap_text(draw, text, fnt, max_width)
    draw.multiline_text(xy, wrapped, font=fnt, fill=fill, spacing=spacing)
    return draw.multiline_textbbox(xy, wrapped, font=fnt, spacing=spacing)


def save(img: Image.Image, name: str):
    FIGURES.mkdir(parents=True, exist_ok=True)
    out = FIGURES / name
    img.save(out)


def load_video_frame() -> Image.Image:
    for candidate in [
        FIGURES / "louvre_video_source_frame.jpeg",
        FIGURES / "louvre_video_recap_frame.png",
    ]:
        if candidate.exists():
            return Image.open(candidate).convert("RGB")
    raise FileNotFoundError("No video frame source found for Louvre appendix assets.")


def make_source_screenshot():
    w, h = 1900, 2150
    img = Image.new("RGB", (w, h), "#FFFFFF")
    draw = ImageDraw.Draw(img)

    draw.rectangle((0, 0, w, 245), fill="#FFFFFF")
    draw.rectangle((78, 40, 355, 185), fill="#E3120B")
    draw.text((108, 68), "The", font=font(FONT_EN_BOLD, 50), fill="#FFFFFF")
    draw.text((108, 118), "Economist", font=font(FONT_EN_BOLD, 50), fill="#FFFFFF")
    draw.line((0, 246, w, 246), fill="#202020", width=2)

    nav = [
        "Weekly edition",
        "World in brief",
        "United States",
        "China",
        "Business",
        "Finance & economics",
        "Europe",
        "Asia",
    ]
    x = 80
    for item in nav:
        draw.text((x, 285), item, font=font(FONT_EN_BOLD, 28), fill="#111111")
        x += draw.textbbox((0, 0), item, font=font(FONT_EN_BOLD, 28))[2] + 52
    draw.line((0, 350, w, 350), fill="#E8E8E8", width=2)

    draw.text((560, 412), "Culture", font=font(FONT_EN_BOLD, 30), fill="#D61A10")
    draw.text((685, 412), "| Art of the steal", font=font(FONT_EN_BOLD, 30), fill="#222222")

    title = "The lessons from the brazen heist\nat the Louvre"
    draw.multiline_text((555, 500), title, font=font(FONT_EN_BOLD, 68), fill="#111111", spacing=12)
    draw.text((560, 760), "Museum thefts are surprisingly common", font=font(FONT_EN_BOLD, 34), fill="#222222")

    buttons = [("Save", 560), ("Share", 735), ("Summary", 930)]
    for label, x in buttons:
        rounded(draw, (x, 855, x + 150, 922), 12, "#FFFFFF", outline="#B8B8B8", width=2)
        draw.text((x + 38, 872), label, font=font(FONT_EN_BOLD, 22), fill="#202020")

    video = load_video_frame()
    photo = video.crop((330, 110, 1680, 1030)).resize((1200, 820))
    img.paste(photo, (560, 1020))
    return img


def make_quiz_cover():
    bg = Image.open(FIGURES / "louvre_app_reading_module.png").convert("RGB").filter(ImageFilter.GaussianBlur(radius=3))
    overlay = Image.new("RGBA", bg.size, (0, 0, 0, 90))
    img = Image.alpha_composite(bg.convert("RGBA"), overlay)

    popup = Image.open(FIGURES / "app_quiz_popup_reference.jpg").convert("RGBA").crop((0, 790, 1290, 2210))
    mask = Image.new("L", popup.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle((0, 45, 1289, 1310), radius=52, fill=255)
    img.paste(popup, (0, 850), mask)

    draw = ImageDraw.Draw(img)
    rounded(draw, (925, 985, 1165, 1038), 18, "#FFF5D8")
    draw.text((960, 996), "总分 100 分", font=font(FONT_CN_BOLD, 24), fill="#9A6A00")

    row_y = [1188, 1368, 1550, 1732, 1912]
    labels = ["20", "20", "20", "20", "20"]
    for y, lab in zip(row_y, labels):
        draw.text((1110, y), lab, font=font(FONT_EN_BOLD, 34), fill="#8A8A8A")

    draw.text((872, 2138), "Five quiz types x 20 points = 100", font=font(FONT_EN, 22), fill="#A0A0A0")
    return img.convert("RGB")


def main():
    video = load_video_frame()
    save(video, "louvre_video_recap_frame.png")


if __name__ == "__main__":
    main()
