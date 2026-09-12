"""Validate corrected province topology against the accepted playable-land mask.

The report and QA images are deterministic review artifacts.  This tool reads
terrain authority but never writes to the terrain workspace.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage
from shapely.geometry import MultiPolygon, Point, Polygon
from shapely.ops import unary_union


RASTER_WIDTH = 4096
RASTER_HEIGHT = 2304
SOURCE_TO_PLAYABLE_SCALE = 1.6
SOURCE_TO_PLAYABLE_OFFSET = -0.5


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def geometry_for(record: dict[str, Any]):
    shells = [Polygon(ring["source_points_xy"]) for ring in record["rings"] if not ring["is_hole"]]
    holes = [ring["source_points_xy"] for ring in record["rings"] if ring["is_hole"]]
    polygons = []
    for shell in shells:
        contained = [hole for hole in holes if shell.covers(Point(hole[0]))]
        polygons.append(Polygon(shell.exterior.coords, contained))
    return unary_union(polygons)


def raster_points(points: list[list[float]]) -> list[tuple[float, float]]:
    return [
        (
            float(point[0]) * SOURCE_TO_PLAYABLE_SCALE + SOURCE_TO_PLAYABLE_OFFSET,
            float(point[1]) * SOURCE_TO_PLAYABLE_SCALE + SOURCE_TO_PLAYABLE_OFFSET,
        )
        for point in points
    ]


def draw_province(draw: ImageDraw.ImageDraw, record: dict[str, Any], fill: int) -> None:
    for ring in record["rings"]:
        draw.polygon(raster_points(ring["source_points_xy"]), fill=0 if ring["is_hole"] else fill)


def load_land_mask(path: Path) -> np.ndarray:
    image = np.asarray(Image.open(path))
    if image.shape[:2] == (4096, 4096):
        image = image[896:3200]
    if image.shape[:2] != (RASTER_HEIGHT, RASTER_WIDTH):
        raise ValueError(f"Expected a 4096x2304 playable mask, got {image.shape[:2]}")
    channel = image[..., 0] if image.ndim == 3 else image
    return channel > 127


def connected_component_summary(mask: np.ndarray) -> list[dict[str, Any]]:
    labels, count = ndimage.label(mask, structure=np.ones((3, 3), dtype=np.uint8))
    if count == 0:
        return []
    slices = ndimage.find_objects(labels)
    sizes = np.bincount(labels.ravel())[1:]
    result = []
    for index, (size, bounds) in enumerate(zip(sizes, slices, strict=True), start=1):
        if bounds is None:
            continue
        rows, columns = bounds
        ys, xs = np.nonzero(labels[bounds] == index)
        result.append(
            {
                "pixel_count": int(size),
                "centroid_pixel_xy": [
                    round(float(xs.mean() + columns.start), 3),
                    round(float(ys.mean() + rows.start), 3),
                ],
                "bounds_pixel_xyxy": [columns.start, rows.start, columns.stop - 1, rows.stop - 1],
            }
        )
    result.sort(key=lambda item: -item["pixel_count"])
    return result


def load_font(path: Path, size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    try:
        return ImageFont.truetype(str(path), size=size)
    except OSError:
        return ImageFont.load_default()


def base_overview(height_path: Path | None, land: np.ndarray) -> Image.Image:
    if height_path and height_path.exists():
        height = np.asarray(Image.open(height_path))
        if height.shape[:2] == (4096, 4096):
            height = height[896:3200]
        if height.ndim == 3:
            height = height[..., 0]
        height = height.astype(np.float32)
        values = height[land]
        low, high = np.percentile(values, (2, 98)) if values.size else (0.0, 1.0)
        normalized = np.clip((height - low) / max(high - low, 1.0), 0.0, 1.0)
    else:
        normalized = np.zeros_like(land, dtype=np.float32)
    rgb = np.zeros((RASTER_HEIGHT, RASTER_WIDTH, 3), dtype=np.uint8)
    rgb[:] = (39, 55, 65)
    land_shade = (155 + normalized * 55).astype(np.uint8)
    rgb[..., 0][land] = land_shade[land]
    rgb[..., 1][land] = np.clip(land_shade[land] + 5, 0, 255)
    rgb[..., 2][land] = np.clip(land_shade[land] - 8, 0, 255)
    return Image.fromarray(rgb, mode="RGB")


def render_overview(
    province_data: dict[str, Any],
    land: np.ndarray,
    height_path: Path | None,
    output_path: Path,
    font_path: Path,
) -> None:
    image = base_overview(height_path, land)
    draw = ImageDraw.Draw(image)
    for record in province_data["provinces"]:
        for ring in record["rings"]:
            if not ring["is_hole"]:
                draw.line(raster_points(ring["source_points_xy"]), fill=(31, 24, 20), width=3, joint="curve")
    font = load_font(font_path, 24)
    for record in province_data["provinces"]:
        source = record["label_point_source_xy"]
        point = (
            float(source[0]) * SOURCE_TO_PLAYABLE_SCALE + SOURCE_TO_PLAYABLE_OFFSET,
            float(source[1]) * SOURCE_TO_PLAYABLE_SCALE + SOURCE_TO_PLAYABLE_OFFSET,
        )
        text = str(record["id"])
        box = draw.textbbox(point, text, font=font, anchor="mm", stroke_width=2)
        draw.rounded_rectangle((box[0] - 4, box[1] - 2, box[2] + 4, box[3] + 2), radius=5, fill=(245, 239, 218))
        draw.text(point, text, font=font, anchor="mm", fill=(20, 18, 16), stroke_width=1, stroke_fill=(245, 239, 218))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path, optimize=True)


def render_coverage(
    province_data: dict[str, Any],
    land: np.ndarray,
    owned: np.ndarray,
    output_path: Path,
) -> None:
    rgb = np.zeros((RASTER_HEIGHT, RASTER_WIDTH, 3), dtype=np.uint8)
    rgb[:] = (24, 39, 52)
    rgb[land & owned] = (103, 166, 103)
    rgb[land & ~owned] = (255, 0, 180)
    rgb[~land & owned] = (56, 105, 124)
    image = Image.fromarray(rgb, mode="RGB")
    draw = ImageDraw.Draw(image)
    for record in province_data["provinces"]:
        for ring in record["rings"]:
            if not ring["is_hole"]:
                draw.line(raster_points(ring["source_points_xy"]), fill=(230, 235, 220), width=2)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path, optimize=True)


def validate(args: argparse.Namespace) -> dict[str, Any]:
    province_data = json.loads(args.province_data.read_text(encoding="utf-8"))
    corrections = json.loads(args.corrections.read_text(encoding="utf-8"))
    source = json.loads(args.source.read_text(encoding="utf-8", errors="surrogatepass"))
    cells = source["pack"]["cells"]
    land = load_land_mask(args.land_mask)
    owner_image = Image.new("I", (RASTER_WIDTH, RASTER_HEIGHT), 0)
    owner_draw = ImageDraw.Draw(owner_image)
    records = province_data["provinces"]
    geometries = {}
    problems: list[str] = []
    for record in records:
        province_id = int(record["id"])
        draw_province(owner_draw, record, province_id)
        geometry = geometry_for(record)
        geometries[province_id] = geometry
        if not geometry.is_valid:
            problems.append(f"Province {province_id} geometry is invalid.")
        for field in ("selection_point_source_xy", "label_point_source_xy"):
            if not geometry.covers(Point(record[field])):
                problems.append(f"Province {province_id} {field} is outside its geometry.")
        if any(ring["is_hole"] for ring in record["rings"]):
            problems.append(f"Province {province_id} retains a political hole.")

    active_ids = [int(value) for value in corrections["id_policy"]["active_ids"]]
    retired_ids = [int(value) for value in corrections["id_policy"]["retired_ids"]]
    record_ids = [int(record["id"]) for record in records]
    if record_ids != active_ids:
        problems.append("Runtime active IDs do not exactly match the correction manifest.")
    if set(retired_ids) & set(record_ids):
        problems.append("A retired ID remains active.")

    cell_assignments = [int(cell.get("province", 0)) for cell in cells]
    for merge in corrections["merges"]:
        for retired_id in merge["retired_ids"]:
            cell_assignments = [
                int(merge["retained_id"]) if value == int(retired_id) else value
                for value in cell_assignments
            ]
    explicit_cells: set[int] = set()
    for assignment in corrections["cell_assignments"]:
        for cell_id in assignment["cell_ids"]:
            if int(cell_id) in explicit_cells:
                problems.append(f"Cell {cell_id} has conflicting explicit assignments.")
            explicit_cells.add(int(cell_id))
            cell_assignments[int(cell_id)] = int(assignment["province_id"])
    inland_feature_ids: set[int] = set()
    for assignment in corrections["inland_water_assignments"]:
        for feature_id in assignment["feature_ids"]:
            inland_feature_ids.add(int(feature_id))
            for cell_id, cell in enumerate(cells):
                if int(cell.get("f", 0)) == int(feature_id):
                    cell_assignments[cell_id] = int(assignment["province_id"])
    unassigned_source_land_cells = [
        int(cell["i"])
        for cell, province_id in zip(cells, cell_assignments, strict=True)
        if int(cell.get("h", 0)) >= 20 and province_id == 0
    ]
    active_without_land = [
        province_id
        for province_id in active_ids
        if not any(
            assigned_id == province_id and int(cell.get("h", 0)) >= 20
            for cell, assigned_id in zip(cells, cell_assignments, strict=True)
        )
    ]
    assigned_external_water = [
        int(cell["i"])
        for cell, province_id in zip(cells, cell_assignments, strict=True)
        if province_id > 0
        and int(cell.get("h", 0)) < 20
        and int(cell.get("f", 0)) not in inland_feature_ids
    ]
    remaining_retired_cells = [
        index for index, province_id in enumerate(cell_assignments) if province_id in retired_ids
    ]
    if unassigned_source_land_cells:
        problems.append("Source topology retains unassigned land cells.")
    if active_without_land:
        problems.append("An active province has no land cells.")
    if assigned_external_water:
        problems.append("External ocean/sea cells were assigned politically.")
    if remaining_retired_cells:
        problems.append("Retired IDs remain in corrected source-cell assignments.")
    for record in records:
        if set(int(value) for value in record["neighbor_ids"]) & set(retired_ids):
            problems.append(f"Province {record['id']} references a retired neighbor.")
        for neighbor_id in record["neighbor_ids"]:
            neighbor = next((item for item in records if int(item["id"]) == int(neighbor_id)), None)
            if neighbor is None or int(record["id"]) not in [int(value) for value in neighbor["neighbor_ids"]]:
                problems.append(f"Province {record['id']} has asymmetric neighbor {neighbor_id}.")

    overlap_pairs = []
    for index, left_id in enumerate(active_ids):
        for right_id in active_ids[index + 1 :]:
            intersection_area = geometries[left_id].intersection(geometries[right_id]).area
            if intersection_area > 1e-6:
                overlap_pairs.append(
                    {"province_ids": [left_id, right_id], "source_area": intersection_area}
                )
    if overlap_pairs:
        problems.append("Province polygons have positive-area overlaps.")

    owner = np.asarray(owner_image) > 0
    unassigned = land & ~owner
    components = connected_component_summary(unassigned)
    threshold = int(corrections["coverage_policy"]["meaningful_component_min_pixels"])
    meaningful = [component for component in components if component["pixel_count"] >= threshold]
    if meaningful:
        problems.append("Meaningful playable land remains unassigned.")

    playable_pixels = int(land.sum())
    unassigned_pixels = int(unassigned.sum())
    pixel_area_godot = 12.20703125**2
    report = {
        "schema_version": 1,
        "authorities": {
            "province_data": {"path": str(args.province_data), "sha256": sha256(args.province_data)},
            "corrections": {"path": str(args.corrections), "sha256": sha256(args.corrections)},
            "land_mask": {"path": str(args.land_mask), "sha256": sha256(args.land_mask)},
            "immutable_source": {"path": str(args.source), "sha256": sha256(args.source)},
        },
        "active_province_count": len(active_ids),
        "active_province_ids": active_ids,
        "retired_province_ids": retired_ids,
        "raster_coverage": {
            "playable_land_pixels": playable_pixels,
            "unassigned_playable_land_pixels": unassigned_pixels,
            "unassigned_playable_land_percent": unassigned_pixels * 100.0 / playable_pixels,
            "meaningful_component_min_pixels": threshold,
            "meaningful_unassigned_pixels": sum(item["pixel_count"] for item in meaningful),
            "meaningful_unassigned_percent": sum(item["pixel_count"] for item in meaningful) * 100.0 / playable_pixels,
            "meaningful_unassigned_components": meaningful,
            "minor_unassigned_component_count": len(components) - len(meaningful),
            "minor_unassigned_pixels": unassigned_pixels - sum(item["pixel_count"] for item in meaningful),
            "minor_unassigned_area_godot_units_squared": (unassigned_pixels - sum(item["pixel_count"] for item in meaningful)) * pixel_area_godot,
        },
        "vector_overlap": {
            "positive_area_pair_count": len(overlap_pairs),
            "pairs": overlap_pairs,
        },
        "source_cell_topology": {
            "unassigned_land_cell_count": len(unassigned_source_land_cells),
            "active_provinces_without_land_cells": active_without_land,
            "assigned_external_water_cell_count": len(assigned_external_water),
            "remaining_retired_cell_count": len(remaining_retired_cells),
            "politically_assigned_inland_feature_ids": sorted(inland_feature_ids),
        },
        "political_hole_count": sum(
            1 for record in records for ring in record["rings"] if ring["is_hole"]
        ),
        "validation_errors": problems,
        "passed": not problems,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8", newline="\n")
    render_overview(province_data, land, args.height_map, args.overview, args.font)
    render_coverage(province_data, land, owner, args.coverage)
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--province-data", required=True, type=Path)
    parser.add_argument("--corrections", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--land-mask", required=True, type=Path)
    parser.add_argument("--height-map", type=Path)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--overview", required=True, type=Path)
    parser.add_argument("--coverage", required=True, type=Path)
    parser.add_argument("--font", type=Path, default=Path(r"C:\Windows\Fonts\arialbd.ttf"))
    args = parser.parse_args()
    report = validate(args)
    coverage = report["raster_coverage"]
    print(
        "Province geography validation "
        + ("PASS" if report["passed"] else "FAIL")
        + f": {report['active_province_count']} active provinces, "
        + f"{coverage['meaningful_unassigned_percent']:.8f}% meaningful land unassigned, "
        + f"{report['vector_overlap']['positive_area_pair_count']} overlap pairs."
    )
    if report["validation_errors"]:
        for error in report["validation_errors"]:
            print(f"ERROR: {error}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
