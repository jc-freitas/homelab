"""
Ambilight script
- Top edge of screen -> light.lampada_intelbras_lampada_intelbras (room lamp)

PC RGB is handled separately by SignalRGB.

Requires: pip install -r requirements.txt
Toggle via HA: input_boolean.ambilight
"""

import json
import time

import mss
import requests
from PIL import Image, ImageEnhance

HA_URL = "http://10.0.20.2:8123"
with open(r"C:\Users\brokeboienige\AppData\Local\HASS.Agent\Client\config\appsettings.json") as _f:
    HA_TOKEN = json.load(_f)["HassToken"]

LAMP = "light.lampada_intelbras_lampada_intelbras"

# Edge slice height as fraction of screen height
EDGE_FRACTION  = 0.08  # 8% of height
FPS            = 5
POLL_INTERVAL  = 1.0   # seconds between HA toggle checks

# Color extraction tuning (screenBloom-style)
SAT_BOOST      = 4.0   # ImageEnhance.Color factor applied before averaging (try 2-6)
LOW_THRESHOLD  = 10    # pixels with all channels below this are excluded (near-black)
HIGH_THRESHOLD = 240   # pixels with all channels above this are excluded (near-white)

headers = {
    "Authorization": f"Bearer {HA_TOKEN}",
    "Content-Type": "application/json",
}


def get_ambilight_enabled() -> bool:
    try:
        r = requests.get(f"{HA_URL}/api/states/input_boolean.ambilight", headers=headers, timeout=2)
        return r.json().get("state") == "on"
    except Exception:
        return False


def region_color(img: Image.Image) -> tuple[int, int, int]:
    """
    screenBloom-style extraction:
    1. Resize to thumbnail for speed.
    2. Boost saturation with ImageEnhance.Color (validated PIL approach).
    3. Average pixels, excluding near-black and near-white outliers.
    Falls back to plain average if all pixels are filtered out.
    """
    img = img.resize((16, 9), Image.LANCZOS).convert("RGB")
    img = ImageEnhance.Color(img).enhance(SAT_BOOST)

    raw = img.tobytes()
    n = len(raw) // 3
    pixels = [(raw[i*3], raw[i*3+1], raw[i*3+2]) for i in range(n)]

    r_sum = g_sum = b_sum = count = 0
    for r, g, b in pixels:
        if r < LOW_THRESHOLD and g < LOW_THRESHOLD and b < LOW_THRESHOLD:
            continue
        if r > HIGH_THRESHOLD and g > HIGH_THRESHOLD and b > HIGH_THRESHOLD:
            continue
        r_sum += r; g_sum += g; b_sum += b; count += 1

    if count == 0:
        r_sum = sum(p[0] for p in pixels)
        g_sum = sum(p[1] for p in pixels)
        b_sum = sum(p[2] for p in pixels)
        count = n

    return r_sum // count, g_sum // count, b_sum // count


def normalize_brightness(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
    """Scale RGB so the brightest channel is always 255, preserving hue/saturation."""
    peak = max(rgb)
    if peak == 0:
        return (255, 255, 255)
    scale = 255 / peak
    return tuple(min(255, int(c * scale)) for c in rgb)


def set_light(entity_id: str, rgb: tuple[int, int, int]):
    rgb = normalize_brightness(rgb)
    requests.post(
        f"{HA_URL}/api/services/light/turn_on",
        headers=headers,
        json={"entity_id": entity_id, "rgb_color": list(rgb), "brightness": 255, "transition": 0},
        timeout=2,
    )


def restore_lights():
    """Return lamp to warm white when ambilight is turned off."""
    requests.post(
        f"{HA_URL}/api/services/light/turn_on",
        headers=headers,
        json={"entity_id": LAMP, "color_temp": 4000, "brightness": 200, "transition": 1},
        timeout=2,
    )


def main():
    sct = mss.MSS()
    monitor = sct.monitors[1]  # primary monitor
    w, h = monitor["width"], monitor["height"]
    left, top = monitor["left"], monitor["top"]

    edge_y = max(1, int(h * EDGE_FRACTION))
    top_region = {"left": left, "top": top, "width": w, "height": edge_y}

    frame_interval = 1.0 / FPS
    running = False
    last_poll = 0.0

    print("Ambilight started. Toggle via input_boolean.ambilight in HA.")

    while True:
        now = time.monotonic()

        if now - last_poll >= POLL_INTERVAL:
            enabled = get_ambilight_enabled()
            last_poll = now

            if enabled and not running:
                print("Ambilight ON")
                running = True
            elif not enabled and running:
                print("Ambilight OFF — restoring lights")
                restore_lights()
                running = False

        if running:
            top_img = Image.frombytes("RGB", (top_region["width"], top_region["height"]), sct.grab(top_region).rgb)
            set_light(LAMP, region_color(top_img))
            time.sleep(frame_interval)
        else:
            time.sleep(0.2)


if __name__ == "__main__":
    main()
