from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import textwrap


ROOT = Path("/Users/ziwenzu/Library/CloudStorage/Dropbox/research/2_Info_opinion/English_RCT")
FIGURES = ROOT / "writing" / "figures"


def load_font(path: str, size: int):
    return ImageFont.truetype(path, size)


FONT_EN = "/System/Library/Fonts/HelveticaNeue.ttc"
FONT_EN_BOLD = "/System/Library/Fonts/Helvetica.ttc"
FONT_CN = "/System/Library/Fonts/Hiragino Sans GB.ttc"
FONT_CN_BOLD = "/System/Library/Fonts/Hiragino Sans GB.ttc"


def rounded(draw, xy, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def arrow_left(draw, x, y, size, color, width=6):
    draw.line((x + size, y, x, y + size, x + size, y + 2 * size), fill=color, width=width, joint="curve")


def phone_status(draw, width, time_text):
    draw.text((70, 45), time_text, font=load_font(FONT_EN_BOLD, 44), fill="#F5F5F5")
    draw.rectangle((width - 170, 56, width - 100, 72), outline="#F5F5F5", width=4)
    draw.rectangle((width - 98, 60, width - 94, 68), fill="#F5F5F5")
    draw.rectangle((width - 165, 60, width - 112, 68), fill="#F5F5F5")
    draw.arc((width - 260, 46, width - 220, 86), start=200, end=340, fill="#F5F5F5", width=4)
    draw.arc((width - 300, 38, width - 228, 94), start=220, end=320, fill="#F5F5F5", width=4)


def wrap_text(draw, text, font, max_width):
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
        if draw.textbbox((0, 0), trial, font=font)[2] <= max_width:
            current.append(token)
        else:
            if current:
                lines.append(joiner.join(current))
            current = [token]
    if current:
        lines.append(joiner.join(current))
    return "\n".join(lines)


def draw_wrapped(draw, xy, text, font, fill, max_width, spacing=10):
    wrapped = wrap_text(draw, text, font, max_width)
    draw.multiline_text(xy, wrapped, font=font, fill=fill, spacing=spacing)
    bbox = draw.multiline_textbbox(xy, wrapped, font=font, spacing=spacing)
    return bbox


def draw_player(draw, width, height):
    accent = "#F1C84D"
    grey = "#B7B7B7"
    y_base = height - 330
    draw.text((60, y_base + 10), "巴中", font=load_font(FONT_CN, 28), fill=accent)
    draw.text((240, y_base + 10), "1.0x", font=load_font(FONT_EN_BOLD, 30), fill="#F3F3F3")
    draw.text((430, y_base + 10), "跟读", font=load_font(FONT_CN, 28), fill="#D7D7D7")
    draw.text((640, y_base + 10), "听写", font=load_font(FONT_CN, 28), fill="#D7D7D7")
    draw.text((850, y_base + 10), "听句", font=load_font(FONT_CN, 28), fill="#D7D7D7")
    draw.text((1060, y_base + 10), "AB 阅读", font=load_font(FONT_CN, 28), fill="#D7D7D7")

    draw.line((110, y_base + 95, width - 110, y_base + 95), fill=grey, width=6)
    draw.line((110, y_base + 95, 635, y_base + 95), fill=accent, width=6)
    draw.ellipse((610, y_base + 72, 660, y_base + 122), fill=accent)
    draw.text((60, y_base + 125), "02:34", font=load_font(FONT_EN, 28), fill=grey)
    draw.text((width - 160, y_base + 125), "05:02", font=load_font(FONT_EN, 28), fill=grey)

    draw.ellipse((84, height - 165, 144, height - 105), outline=grey, width=4)
    draw.text((102, height - 154), "↺", font=load_font(FONT_EN, 28), fill=grey)
    draw.polygon([(345, height - 135), (415, height - 175), (415, height - 95)], fill="#F3F3F3")
    draw.polygon([(615, height - 180), (615, height - 90), (710, height - 135)], fill="#F3F3F3")
    draw.rectangle((790, height - 180, 800, height - 90), fill="#F3F3F3")
    draw.rectangle((825, height - 180, 835, height - 90), fill="#F3F3F3")
    draw.line((1110, height - 180, 1180, height - 180), fill="#F3F3F3", width=8)
    draw.line((1110, height - 135, 1180, height - 135), fill="#F3F3F3", width=8)
    draw.line((1110, height - 90, 1180, height - 90), fill="#F3F3F3", width=8)
    rounded(draw, (430, height - 33, 860, height - 21), 6, "#F1F1F1")


def make_reading_screen():
    img = Image.open(FIGURES / "app_reading_layout_reference.png").convert("RGB")
    width, height = img.size
    draw = ImageDraw.Draw(img)
    draw.rectangle((845, 300, 1268, 394), fill="#2B2B2B")
    draw.rectangle((0, 430, width, 2290), fill="#2B2B2B")

    x = 60
    max_w = 1100
    title_cn = load_font(FONT_CN_BOLD, 72)
    common_en = load_font(FONT_EN_BOLD, 56)
    common_cn = load_font(FONT_CN, 36)
    body_en = load_font(FONT_EN_BOLD, 46)
    body_cn = load_font(FONT_CN, 34)

    draw.text((x, 500), "卢浮宫劫案的教训", font=title_cn, fill="#F1F1F1")

    y = 690
    draw.text((x, y), "Culture", font=common_en, fill="#DADADA")
    draw.text((x, y + 70), "文化", font=common_cn, fill="#8F8F8F")

    y = 900
    draw.text((x, y), "Museum theft", font=common_en, fill="#ECECEC")
    draw.text((x, y + 72), "博物馆盗窃", font=common_cn, fill="#9A9A9A")

    y = 1110
    draw.text((x, y), "Lessons from the Louvre heist", font=common_en, fill="#F0F0F0")
    draw.text((x, y + 72), "卢浮宫劫案留下的教训", font=common_cn, fill="#9A9A9A")

    blocks = [
        (
            "A rapid robbery exposed daring thieves and a security system that failed to slow them down.",
            "这起迅速发生的盗窃案暴露出的，不只是盗贼的大胆，还有安保系统未能有效拖慢他们。",
        ),
        (
            "Two masked thieves reached a high window, cut through display cases, and escaped within minutes.",
            "两名蒙面盗贼从高处窗户进入馆内，切开陈列柜后在数分钟内逃离。",
        ),
        (
            "The Louvre is a symbolic museum, so the robbery looked like more than an ordinary theft.",
            "卢浮宫具有强烈的国家与文化象征意义，因此这起案件看起来远不只是一次普通盗窃。",
        ),
        (
            "Security experts say a museum must detect danger and also buy time for guards to respond.",
            "安全专家强调，博物馆不仅要发现危险，更要为安保人员争取反应时间。",
        ),
    ]

    y = 1360
    for en_text, zh_text in blocks:
        en_bbox = draw_wrapped(draw, (x, y), en_text, body_en, "#EFEFEF", max_w, spacing=18)
        zh_bbox = draw_wrapped(draw, (x, en_bbox[3] + 20), zh_text, body_cn, "#9A9A9A", max_w, spacing=14)
        y = zh_bbox[3] + 54
    return img


def make_sentence_screen():
    width, height = 3718, 1942
    img = Image.new("RGB", (width, height), "#F5E6D0")
    draw = ImageDraw.Draw(img)

    draw.text((52, 25), "P7", font=load_font(FONT_EN_BOLD, 110), fill="#111111")
    rounded(draw, (18, 118, 2130, 1680), 52, "#FFFFFF")

    title = (
        "That a truck could park outside the museum without drawing notice\n"
        "raised serious questions about the Louvre's security design.\n"
        "The goal was not only to detect danger but also to buy time\n"
        "for guards to respond."
    )
    draw.multiline_text((110, 250), title, font=load_font(FONT_EN, 54), fill="#2E2E2E", spacing=20)

    highlights = [
        (960, 336, 1580, 400),
        (765, 505, 1065, 570),
        (1490, 505, 1770, 570),
    ]
    for box in highlights:
        rounded(draw, box, 20, "#F8DB77")

    draw.multiline_text((110, 250), title, font=load_font(FONT_EN, 54), fill="#2E2E2E", spacing=20)
    draw.multiline_text(
        (110, 670),
        "一辆卡车竟然能在不引人注意的情况下停到博物馆外，\n"
        "这立刻让人对卢浮宫的安保设计提出严重质疑。\n"
        "安保目标不仅是发现危险，更重要的是为安保人员争取反应时间。",
        font=load_font(FONT_CN, 42),
        fill="#404040",
        spacing=16,
    )

    red = "#BF2E2E"
    draw.line((980, 412, 1565, 422), fill=red, width=8)
    draw.line((782, 580, 1040, 590), fill=red, width=8)
    draw.line((1508, 580, 1752, 590), fill=red, width=8)

    x0 = 2260
    draw.text((x0, 140), "raise serious questions about", font=load_font(FONT_EN_BOLD, 56), fill="#111111")
    draw.line((x0 + 415, 224, x0 + 940, 236), fill=red, width=8)
    draw.text((x0 + 990, 112), "关键搭配", font=load_font(FONT_CN, 46), fill=red)
    draw_wrapped(draw, (x0 + 50, 290), "• to make people doubt or examine sth closely", load_font(FONT_EN, 42), "#2E2E2E", 1280, spacing=10)
    draw_wrapped(draw, (x0 + 90, 360), "• 对某事提出严重质疑；引发认真审视", load_font(FONT_CN, 38), "#555555", 1180, spacing=8)

    draw.text((x0, 620), "not only ... but also ...", font=load_font(FONT_EN_BOLD, 56), fill="#111111")
    draw.line((x0 + 245, 704, x0 + 690, 716), fill=red, width=8)
    draw_wrapped(draw, (x0 + 50, 770), "• links two related points and sharpens contrast", load_font(FONT_EN, 42), "#2E2E2E", 1260, spacing=10)
    draw_wrapped(draw, (x0 + 90, 840), "• 不仅……而且……；用于强化并列关系", load_font(FONT_CN, 38), "#555555", 1180, spacing=8)

    draw.text((x0, 1070), "buy time", font=load_font(FONT_EN_BOLD, 56), fill="#111111")
    draw.line((x0 + 5, 1150, x0 + 250, 1160), fill=red, width=8)
    draw_wrapped(draw, (x0 + 50, 1215), "• to delay a threat long enough for a response", load_font(FONT_EN, 42), "#2E2E2E", 1260, spacing=10)
    draw_wrapped(draw, (x0 + 90, 1285), "• 为应对争取时间；延缓威胁扩散", load_font(FONT_CN, 38), "#555555", 1180, spacing=8)
    draw_wrapped(draw, (x0 + 50, 1360), "• Security systems buy time when they slow thieves down.", load_font(FONT_EN, 42), "#2E2E2E", 1260, spacing=10)
    return img


def make_quiz_screen():
    width, height = 1290, 2796
    bg = make_reading_screen().filter(ImageFilter.GaussianBlur(radius=3))
    overlay = Image.new("RGBA", (width, height), (0, 0, 0, 90))
    img = Image.alpha_composite(bg.convert("RGBA"), overlay)
    img_draw = ImageDraw.Draw(img)
    img_draw.rectangle((0, 0, 86, 92), fill=(24, 24, 24, 255))
    img_draw.rectangle((0, 82, 86, 156), fill=(24, 24, 24, 255))
    popup_y = 855
    popup_w = 1240
    popup_h = 1340
    popup_x = (width - popup_w) // 2
    img_draw.rectangle((0, popup_y - 8, width, popup_y + 70), fill=(24, 24, 24, 255))
    popup = Image.new("RGBA", (popup_w, popup_h), (0, 0, 0, 0))
    popup_draw = ImageDraw.Draw(popup)
    popup_draw.rounded_rectangle((0, 0, popup_w - 1, 1310), radius=52, fill="#FFFFFF")
    popup_draw.rectangle((0, 116, popup_w - 1, 210), fill="#F5F5F5")

    title_font = load_font(FONT_CN, 68)
    label_font = load_font(FONT_CN_BOLD, 64)
    item_font = load_font(FONT_CN_BOLD, 72)

    title = "测试答题"
    title_bbox = popup_draw.textbbox((0, 0), title, font=title_font)
    title_x = (popup_w - (title_bbox[2] - title_bbox[0])) // 2
    popup_draw.text((title_x, 34), title, font=title_font, fill="#404040")
    popup_draw.text((52, 126), "请选择测试类型", font=label_font, fill="#7A7A7A")

    items = ["阅读理解", "语法句法", "单词测试", "听力测试", "句子积累"]
    row_start = 304
    row_gap = 205
    line_color = "#EDEDED"
    for idx, item in enumerate(items):
        y = row_start + idx * row_gap
        popup_draw.text((52, y), item, font=item_font, fill="#404040")
        popup_draw.line((52, y + 132, popup_w - 52, y + 132), fill=line_color, width=2)

    circle = (popup_w - 90, 1140, popup_w, 1230)
    popup_draw.ellipse(circle, fill="#FFD12A")
    cx = (circle[0] + circle[2]) // 2
    cy = (circle[1] + circle[3]) // 2
    popup_draw.line((cx - 18, cy + 1, cx - 4, cy + 15), fill="#111111", width=7)
    popup_draw.line((cx - 4, cy + 15, cx + 21, cy - 18), fill="#111111", width=7)

    img.alpha_composite(popup, (popup_x, popup_y))
    return img.convert("RGB")


def save_image(img: Image.Image, filename: str):
    out = FIGURES / filename
    FIGURES.mkdir(parents=True, exist_ok=True)
    img.save(out, quality=95)


def main():
    save_image(make_reading_screen(), "louvre_app_reading_module.png")
    save_image(make_sentence_screen(), "louvre_sentence_annotation_screen.png")
    save_image(make_quiz_screen(), "louvre_quiz_type_selection.png")


if __name__ == "__main__":
    main()
