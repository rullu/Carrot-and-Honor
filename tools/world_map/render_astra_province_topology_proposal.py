"""Render comparison maps for the review-only FCAH topology proposal."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

from validate_astra_province_geography import (
    SOURCE_TO_PLAYABLE_OFFSET,
    SOURCE_TO_PLAYABLE_SCALE,
    base_overview,
    load_font,
    load_land_mask,
    raster_points,
)


GROUPS: dict[str, set[int]] = {
    "south": {6, 9, 10, 11, 12, 56, 90, 100},
    "east": {84, 85, 86, 88, 91, 92, 93, 94, 95, 96, 97, 98, 99, 101},
    "northwest": {21, 22, 37, 102, 103, 104, 105, 106, 107},
}
GROUP_COLORS = {
    "south": (218, 137, 79, 54),
    "east": (128, 113, 184, 50),
    "northwest": (76, 148, 174, 52),
}


def label_point(record: dict[str, Any]) -> tuple[float, float]:
    source = record["label_point_source_xy"]
    return (
        float(source[0]) * SOURCE_TO_PLAYABLE_SCALE + SOURCE_TO_PLAYABLE_OFFSET,
        float(source[1]) * SOURCE_TO_PLAYABLE_SCALE + SOURCE_TO_PLAYABLE_OFFSET,
    )


def draw_fills(image: Image.Image, proposed: dict[str, Any]) -> None:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for record in proposed["provinces"]:
        province_id = int(record["id"])
        group_name = next((name for name, ids in GROUPS.items() if province_id in ids), None)
        if group_name is None:
            continue
        for ring in record["rings"]:
            if not ring["is_hole"]:
                draw.polygon(
                    raster_points(ring["source_points_xy"]),
                    fill=GROUP_COLORS[group_name],
                )
    image.alpha_composite(overlay)


def draw_boundaries(
    image: Image.Image,
    data: dict[str, Any],
    color: tuple[int, int, int, int],
    width: int,
) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    for record in data["provinces"]:
        for ring in record["rings"]:
            draw.line(
                raster_points(ring["source_points_xy"]),
                fill=color,
                width=width,
                joint="curve",
            )


def draw_labels(
    image: Image.Image,
    proposed: dict[str, Any],
    bounds: tuple[int, int, int, int] | None = None,
    include_ids: set[int] | None = None,
) -> None:
    font_size = 24 if bounds is None else 30
    font = load_font(Path(r"C:\Windows\Fonts\arialbd.ttf"), font_size)
    draw = ImageDraw.Draw(image, "RGBA")
    for record in proposed["provinces"]:
        province_id = int(record["id"])
        if include_ids is not None and province_id not in include_ids:
            continue
        x, y = label_point(record)
        if bounds is not None:
            left, top, right, bottom = bounds
            if not (left <= x < right and top <= y < bottom):
                continue
            x -= left
            y -= top
        text = str(province_id)
        box = draw.textbbox((x, y), text, font=font, anchor="mm", stroke_width=2)
        draw.rounded_rectangle(
            (box[0] - 4, box[1] - 2, box[2] + 4, box[3] + 2),
            radius=5,
            fill=(238, 235, 221, 226),
        )
        draw.text(
            (x, y),
            text,
            font=font,
            anchor="mm",
            fill=(24, 26, 31, 255),
            stroke_width=1,
            stroke_fill=(238, 235, 221, 255),
        )


def draw_retired_labels(
    image: Image.Image,
    current: dict[str, Any],
    bounds: tuple[int, int, int, int],
    retired_ids: set[int],
) -> None:
    font = load_font(Path(r"C:\Windows\Fonts\arialbd.ttf"), 20)
    draw = ImageDraw.Draw(image, "RGBA")
    left, top, right, bottom = bounds
    for record in current["provinces"]:
        province_id = int(record["id"])
        if province_id not in retired_ids:
            continue
        x, y = label_point(record)
        if left <= x < right and top <= y < bottom:
            draw.text(
                (x - left, y - top),
                f"OLD {province_id}",
                font=font,
                anchor="mm",
                fill=(91, 108, 123, 230),
                stroke_width=2,
                stroke_fill=(232, 236, 237, 220),
            )


def add_caption(image: Image.Image, title: str, *, at_bottom: bool = False) -> None:
    title_font = load_font(Path(r"C:\Windows\Fonts\arialbd.ttf"), 28)
    body_font = load_font(Path(r"C:\Windows\Fonts\arial.ttf"), 20)
    draw = ImageDraw.Draw(image, "RGBA")
    top = image.height - 112 if at_bottom else 18
    draw.rounded_rectangle((18, top, 755, top + 76), radius=10, fill=(19, 27, 37, 220))
    draw.text((34, top + 11), title, font=title_font, fill=(241, 243, 245, 255))
    draw.text(
        (34, top + 47),
        "Dark line: proposal   |   faint blue-grey: current border",
        font=body_font,
        fill=(200, 211, 222, 255),
    )


def render(args: argparse.Namespace) -> None:
    current = json.loads(args.current.read_text(encoding="utf-8"))
    proposed = json.loads(args.proposed.read_text(encoding="utf-8"))
    land = load_land_mask(args.land_mask)
    master = base_overview(args.height_map, land).convert("RGBA")
    draw_fills(master, proposed)
    draw_boundaries(master, current, (94, 112, 131, 104), 2)
    draw_boundaries(master, proposed, (26, 31, 40, 235), 4)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    full = master.copy()
    draw_labels(full, proposed)
    add_caption(full, "REVIEW-ONLY PROVINCE TOPOLOGY PROPOSAL")
    full.convert("RGB").save(
        args.output_dir / "astra_province_topology_proposal_overview.png",
        optimize=True,
    )

    closeups = {
        "astra_province_topology_proposal_south.png": (
            (1760, 1560, 3392, 2288),
            "SOUTHERN CHANGES — REVIEW PROPOSAL",
            "south",
        ),
        "astra_province_topology_proposal_east_northeast.png": (
            (2240, 380, 3424, 1830),
            "EAST / NORTH-EAST CHANGES — REVIEW PROPOSAL",
            "east",
        ),
        "astra_province_topology_proposal_northwest_central.png": (
            (230, 250, 2550, 1760),
            "NORTH-WEST / CENTRAL CHANGES — REVIEW PROPOSAL",
            "northwest",
        ),
    }
    for file_name, (bounds, title, group_name) in closeups.items():
        crop = master.crop(bounds)
        draw_labels(crop, proposed, bounds, include_ids=GROUPS[group_name])
        draw_retired_labels(crop, current, bounds, {8, 57})
        add_caption(crop, title, at_bottom=group_name == "south")
        crop.convert("RGB").save(args.output_dir / file_name, optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--current", required=True, type=Path)
    parser.add_argument("--proposed", required=True, type=Path)
    parser.add_argument("--land-mask", required=True, type=Path)
    parser.add_argument("--height-map", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    render(args)
    print(f"Proposal QA maps written to {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
