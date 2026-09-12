"""Build the review-only targeted FCAH province-topology proposal.

The generated manifest composes the accepted correction manifest with the
requested targeted merges, transfers, and splits.  It never writes the live
correction manifest or authoritative runtime province data.
"""

from __future__ import annotations

import argparse
import copy
import heapq
import json
import math
from collections import Counter, defaultdict, deque
from pathlib import Path
from typing import Any, Iterable

from build_astra_province_corrections import (
    EXPECTED_SOURCE_SHA256,
    choose_anchor,
    components,
    sha256,
)


NEW_ID_LAYOUT: dict[int, tuple[int, ...]] = {
    6: (90,),
    84: (91, 92, 93, 94, 95),
    86: (96, 97),
    85: (98, 99),
    10: (100,),
    88: (101,),
    22: (102,),
    21: (103, 104, 105),
    37: (106, 107),
}

# Deliberately irregular seed placement.  Seeds identify geographic subregions;
# terrain-aware graph distance determines the actual boundaries.
SPLIT_SEED_POINTS: dict[int, dict[int, tuple[float, float] | None]] = {
    6: {6: None, 90: (1990.0, 970.0)},
    84: {
        84: None,
        91: (1585.0, 430.0),
        92: (1810.0, 410.0),
        93: (1980.0, 560.0),
        94: (1800.0, 700.0),
        95: (1900.0, 805.0),
    },
    86: {86: None, 96: (1930.0, 390.0), 97: (2020.0, 665.0)},
    85: {85: None, 98: (1555.0, 835.0), 99: (1700.0, 980.0)},
    10: {10: None, 100: (1735.0, 1115.0)},
    88: {88: None, 101: (1545.0, 805.0)},
    22: {22: None, 102: (1435.0, 505.0)},
    21: {
        21: None,
        103: (790.0, 470.0),
        104: (1010.0, 365.0),
        105: (1015.0, 590.0),
    },
    37: {37: None, 106: (225.0, 815.0), 107: (300.0, 960.0)},
}


def load_json(path: Path, *, surrogatepass: bool = False) -> dict[str, Any]:
    return json.loads(
        path.read_text(
            encoding="utf-8", errors="surrogatepass" if surrogatepass else "strict"
        )
    )


def apply_manifest_assignments(
    cells: list[dict[str, Any]], manifest: dict[str, Any]
) -> list[int]:
    assignments = [int(cell.get("province", 0)) for cell in cells]
    for merge in manifest["merges"]:
        retained = int(merge["retained_id"])
        retired = {int(value) for value in merge["retired_ids"]}
        assignments = [retained if value in retired else value for value in assignments]
    for group in manifest["cell_assignments"]:
        target = int(group["province_id"])
        for cell_id in group["cell_ids"]:
            assignments[int(cell_id)] = target
    return assignments


def province_land_cells(
    province_id: int, assignments: list[int], cells: list[dict[str, Any]]
) -> set[int]:
    return {
        cell_id
        for cell_id, owner in enumerate(assignments)
        if owner == province_id and int(cells[cell_id].get("h", 0)) >= 20
    }


def area(cell_ids: Iterable[int], cells: list[dict[str, Any]]) -> float:
    return sum(float(cells[cell_id].get("area", 0.0)) for cell_id in cell_ids)


def nearest_cell(
    region: set[int], point: tuple[float, float], cells: list[dict[str, Any]]
) -> int:
    return min(
        region,
        key=lambda cell_id: (
            math.dist(
                (float(cells[cell_id]["p"][0]), float(cells[cell_id]["p"][1])),
                point,
            ),
            cell_id,
        ),
    )


def edge_cost(left: int, right: int, cells: list[dict[str, Any]]) -> float:
    left_cell = cells[left]
    right_cell = cells[right]
    distance = math.dist(
        (float(left_cell["p"][0]), float(left_cell["p"][1])),
        (float(right_cell["p"][0]), float(right_cell["p"][1])),
    )
    left_height = float(left_cell.get("h", 20.0))
    right_height = float(right_cell.get("h", 20.0))
    slope_factor = 1.0 + abs(left_height - right_height) * 0.045
    highland_factor = 1.0 + max(0.0, min(left_height, right_height) - 38.0) * 0.012
    biome_factor = 1.10 if left_cell.get("biome") != right_cell.get("biome") else 1.0
    left_river = int(left_cell.get("r", 0))
    right_river = int(right_cell.get("r", 0))
    corridor_factor = 0.84 if left_river > 0 and left_river == right_river else 1.0
    return max(distance, 0.01) * slope_factor * highland_factor * biome_factor * corridor_factor


def principal_component(region: set[int], cells: list[dict[str, Any]]) -> tuple[set[int], list[set[int]]]:
    groups = [set(group) for group in components(region, cells)]
    groups.sort(key=lambda group: (-area(group, cells), min(group)))
    return groups[0], groups[1:]


def graph_partition(
    source_id: int,
    region: set[int],
    seed_points: dict[int, tuple[float, float] | None],
    retained_anchor_cell: int,
    cells: list[dict[str, Any]],
) -> dict[int, set[int]]:
    principal, detached = principal_component(region, cells)
    seeds: dict[int, int] = {}
    used: set[int] = set()
    for target_id, point in seed_points.items():
        if point is None and retained_anchor_cell in principal:
            seed = retained_anchor_cell
        elif point is None:
            seed = nearest_cell(principal, tuple(cells[retained_anchor_cell]["p"]), cells)
        else:
            candidates = principal - used
            seed = nearest_cell(candidates, point, cells)
        seeds[target_id] = seed
        used.add(seed)

    best: dict[int, tuple[float, int]] = {}
    heap: list[tuple[float, int, int]] = []
    for target_id, seed in sorted(seeds.items()):
        best[seed] = (0.0, target_id)
        heapq.heappush(heap, (0.0, target_id, seed))
    while heap:
        distance, target_id, cell_id = heapq.heappop(heap)
        if best.get(cell_id) != (distance, target_id):
            continue
        for neighbor_value in cells[cell_id]["c"]:
            neighbor = int(neighbor_value)
            if neighbor not in principal:
                continue
            proposal = (distance + edge_cost(cell_id, neighbor, cells), target_id)
            if neighbor not in best or proposal < best[neighbor]:
                best[neighbor] = proposal
                heapq.heappush(heap, (proposal[0], proposal[1], neighbor))
    if set(best) != principal:
        raise ValueError(f"Province {source_id} partition left unreachable principal cells.")

    result = {target_id: set() for target_id in seed_points}
    for cell_id, (_, target_id) in best.items():
        result[target_id].add(cell_id)

    # Preserve natural islands as whole components and attach each to the nearest
    # mainland piece rather than cutting it or inventing a sliver.
    for island in detached:
        centroid_area = area(island, cells)
        centroid = (
            sum(float(cells[c]["p"][0]) * float(cells[c].get("area", 1.0)) for c in island)
            / centroid_area,
            sum(float(cells[c]["p"][1]) * float(cells[c].get("area", 1.0)) for c in island)
            / centroid_area,
        )
        target_id = min(
            seeds,
            key=lambda value: (
                math.dist(tuple(cells[seeds[value]]["p"]), centroid), value
            ),
        )
        result[target_id].update(island)

    if set().union(*result.values()) != region:
        raise ValueError(f"Province {source_id} partition did not preserve its full land region.")
    if any(not cell_ids for cell_ids in result.values()):
        raise ValueError(f"Province {source_id} partition produced an empty piece.")
    return result


def transfer_southern_strip(
    assignments: list[int], cells: list[dict[str, Any]]
) -> tuple[list[int], float, float]:
    source_cells = province_land_cells(12, assignments, cells)
    merged_cells = province_land_cells(8, assignments, cells) | province_land_cells(9, assignments, cells)
    candidates = [
        cell_id
        for cell_id in source_cells
        if any(int(neighbor) in merged_cells for neighbor in cells[cell_id]["c"])
    ]
    if not candidates:
        raise ValueError("Province 12 has no source-cell edge adjoining provinces 8/9.")
    # Source cells are coarser than the requested 1–2 percent strip.  Select the
    # narrowest available southern-edge cell and record the exact consequence.
    selected = min(
        candidates,
        key=lambda cell_id: (
            float(cells[cell_id].get("area", 0.0)),
            -float(cells[cell_id]["p"][1]),
            cell_id,
        ),
    )
    assignments[selected] = 9
    moved = float(cells[selected].get("area", 0.0))
    return [selected], moved, moved * 100.0 / area(source_cells, cells)


def expand_province_11(
    assignments: list[int], cells: list[dict[str, Any]], protected_cell: int
) -> tuple[list[int], float, float]:
    source = province_land_cells(6, assignments, cells)
    province_11 = province_land_cells(11, assignments, cells)
    required = area(source, cells) * 0.10
    frontier = sorted(
        cell_id
        for cell_id in source
        if any(int(neighbor) in province_11 for neighbor in cells[cell_id]["c"])
    )
    if not frontier:
        raise ValueError("Province 6 has no source-cell edge adjoining province 11.")

    selected: set[int] = set()
    best: dict[int, float] = {}
    heap: list[tuple[float, int]] = []
    for cell_id in frontier:
        best[cell_id] = 0.0
        heapq.heappush(heap, (0.0, cell_id))
    moved = 0.0
    while heap and moved < required:
        distance, cell_id = heapq.heappop(heap)
        if best.get(cell_id) != distance or cell_id in selected:
            continue
        if cell_id != protected_cell:
            selected.add(cell_id)
            moved += float(cells[cell_id].get("area", 0.0))
        for neighbor_value in cells[cell_id]["c"]:
            neighbor = int(neighbor_value)
            if neighbor not in source or neighbor in selected:
                continue
            proposal = distance + edge_cost(cell_id, neighbor, cells)
            # Prefer the southeastern/coastal end adjoining the existing peninsula.
            proposal += max(0.0, 1900.0 - float(cells[neighbor]["p"][0])) * 0.08
            proposal += max(0.0, 1140.0 - float(cells[neighbor]["p"][1])) * 0.06
            if neighbor not in best or proposal < best[neighbor]:
                best[neighbor] = proposal
                heapq.heappush(heap, (proposal, neighbor))
    if moved < required:
        raise ValueError("Province 11 expansion could not reach ten percent of province 6.")
    for cell_id in selected:
        assignments[cell_id] = 11
    return sorted(selected), moved, moved * 100.0 / area(source, cells)


def build_manifest_from_base(
    source_path: Path,
    base: dict[str, Any],
    base_label: str,
    base_hash: str,
) -> dict[str, Any]:
    if sha256(source_path) != EXPECTED_SOURCE_SHA256:
        raise ValueError("Immutable Azgaar source fingerprint changed.")
    source = load_json(source_path, surrogatepass=True)
    cells: list[dict[str, Any]] = source["pack"]["cells"]
    if base["id_policy"]["next_new_id"] != 90:
        raise ValueError("Current correction state no longer has next province ID 90.")
    if len(base["id_policy"]["active_ids"]) != 84:
        raise ValueError("Current correction state no longer has exactly 84 active provinces.")

    current = apply_manifest_assignments(cells, base)
    proposed = current.copy()
    before_areas = {
        province_id: area(province_land_cells(province_id, current, cells), cells)
        for province_id in sorted({6, 8, 9, 10, 11, 12, 21, 22, 37, 56, 57, 84, 85, 86, 88})
    }

    # Proposal merges retain 9 and 56.
    proposed = [9 if value == 8 else 56 if value == 57 else value for value in proposed]
    strip_cells, strip_area, strip_percent = transfer_southern_strip(proposed, cells)

    historical_definitions = source["pack"]["provinces"]
    protected_6 = int(historical_definitions[6]["center"])
    expansion_cells, expansion_area, expansion_percent = expand_province_11(
        proposed, cells, protected_6
    )

    split_summaries: list[dict[str, Any]] = []
    for source_id in (6, 84, 86, 85, 10, 88, 22, 21, 37):
        region = province_land_cells(source_id, proposed, cells)
        if source_id <= 82:
            retained_anchor = int(historical_definitions[source_id]["center"])
        else:
            base_definition = next(
                record for record in base["new_provinces"] if int(record["id"]) == source_id
            )
            retained_anchor = int(base_definition["selection_cell_id"])
        pieces = graph_partition(
            source_id,
            region,
            SPLIT_SEED_POINTS[source_id],
            retained_anchor,
            cells,
        )
        for target_id, cell_ids in pieces.items():
            for cell_id in cell_ids:
                proposed[cell_id] = target_id
        split_summaries.append(
            {
                "source_id": source_id,
                "piece_ids": sorted(pieces),
                "land_area_before": area(region, cells),
                "land_area_after": {
                    str(target): area(piece, cells) for target, piece in sorted(pieces.items())
                },
            }
        )

    retired = sorted(set(int(value) for value in base["id_policy"]["retired_ids"]) | {8, 57})
    new_ids = sorted(value for values in NEW_ID_LAYOUT.values() for value in values)
    active = sorted((set(int(value) for value in base["id_policy"]["active_ids"]) - {8, 57}) | set(new_ids))
    if len(active) != 100 or new_ids != list(range(90, 108)):
        raise ValueError("Proposal ID arithmetic does not produce exactly 100 active IDs and 90–107.")
    if set(retired) & set(active):
        raise ValueError("Proposal active and retired IDs overlap.")

    merges = copy.deepcopy(base["merges"])
    merges.extend(
        [
            {
                "retained_id": 9,
                "retired_ids": [8],
                "reason": "Proposal: merge undersized provinces 8 and 9; retain 9 as requested.",
            },
            {
                "retained_id": 56,
                "retired_ids": [57],
                "reason": "Proposal: retain larger province 56 and merge adjacent undersized province 57.",
            },
        ]
    )

    raw_after_merges = [int(cell.get("province", 0)) for cell in cells]
    for merge in merges:
        retained = int(merge["retained_id"])
        retired_set = {int(value) for value in merge["retired_ids"]}
        raw_after_merges = [retained if value in retired_set else value for value in raw_after_merges]
    explicit_by_target: dict[int, list[int]] = defaultdict(list)
    for cell_id, (raw_owner, proposal_owner) in enumerate(zip(raw_after_merges, proposed, strict=True)):
        if raw_owner != proposal_owner:
            explicit_by_target[proposal_owner].append(cell_id)

    new_records = copy.deepcopy(base["new_provinces"])
    for source_id, allocated_ids in NEW_ID_LAYOUT.items():
        for new_id in allocated_ids:
            ids = province_land_cells(new_id, proposed, cells)
            anchor_cell = choose_anchor(sorted(ids), cells)
            new_records.append(
                {
                    "id": new_id,
                    "name": f"Proposal Province {new_id}",
                    "full_name": f"Proposal Province {new_id}",
                    "provisional_name": True,
                    "source_group": f"review_split_from_{source_id}",
                    "selection_cell_id": anchor_cell,
                    "label_point_source_xy": [float(value) for value in cells[anchor_cell]["p"]],
                }
            )
    new_records.sort(key=lambda record: int(record["id"]))

    anchor_overrides = copy.deepcopy(base["anchor_overrides"])
    changed_retained = {6, 9, 10, 11, 12, 21, 22, 37, 56, 84, 85, 86, 88}
    for province_id in sorted(changed_retained):
        ids = province_land_cells(province_id, proposed, cells)
        anchor_cell = choose_anchor(sorted(ids), cells)
        anchor_overrides.append(
            {
                "province_id": province_id,
                "selection_cell_id": anchor_cell,
                "label_point_source_xy": [float(value) for value in cells[anchor_cell]["p"]],
                "reason": "Proposal: keep selection and label anchors inside the changed province geometry.",
            }
        )

    inland_assignments = copy.deepcopy(base["inland_water_assignments"])
    for assignment in inland_assignments:
        if int(assignment["province_id"]) == 8:
            assignment["province_id"] = 9
            assignment["reason"] = "Proposal: lake ownership follows the retained ID 9 after merge."
        elif int(assignment["province_id"]) == 57:
            assignment["province_id"] = 56
            assignment["reason"] = "Proposal: lake ownership follows the retained ID 56 after merge."
        elif int(assignment["province_id"]) in NEW_ID_LAYOUT:
            neighbors: Counter[int] = Counter()
            for feature_id in assignment["feature_ids"]:
                feature_cells = {
                    cell_id
                    for cell_id, cell in enumerate(cells)
                    if int(cell.get("f", 0)) == int(feature_id)
                }
                for cell_id in feature_cells:
                    for neighbor_value in cells[cell_id]["c"]:
                        neighbor = int(neighbor_value)
                        if neighbor not in feature_cells and int(cells[neighbor].get("h", 0)) >= 20:
                            neighbors[proposed[neighbor]] += 1
            if not neighbors:
                raise ValueError(
                    f"Could not determine surrounding proposal owner for inland features {assignment['feature_ids']}."
                )
            surrounding_owner = min(
                neighbors,
                key=lambda province_id: (-neighbors[province_id], province_id),
            )
            assignment["province_id"] = surrounding_owner
            assignment["reason"] = (
                "Proposal: enclosed water follows the split piece with the strongest surrounding land adjacency."
            )

    after_areas = {
        province_id: area(province_land_cells(province_id, proposed, cells), cells)
        for province_id in sorted(set(before_areas) | set(new_ids))
        if province_id in active
    }
    cell_components = {
        str(province_id): [len(group) for group in components(province_land_cells(province_id, proposed, cells), cells)]
        for province_id in sorted(after_areas)
    }
    empty = [province_id for province_id in active if not province_land_cells(province_id, proposed, cells)]
    if empty:
        raise ValueError(f"Proposal leaves active provinces without land: {empty}")

    result = copy.deepcopy(base)
    result["id_policy"] = {
        "ids_are_stable_opaque_identifiers": True,
        "never_reuse_retired_ids": True,
        "retired_ids": retired,
        "active_ids": active,
        "next_new_id": 108,
    }
    result["merges"] = merges
    result["new_provinces"] = new_records
    result["cell_assignments"] = [
        {
            "province_id": target,
            "cell_ids": ids,
            "reason": "Review proposal: deterministic composed assignment after accepted corrections and targeted topology edits.",
        }
        for target, ids in sorted(explicit_by_target.items())
    ]
    result["inland_water_assignments"] = inland_assignments
    result["anchor_overrides"] = anchor_overrides
    result["proposal_metadata"] = {
        "status": "review_only_not_authoritative",
        "base_corrections_file": base_label,
        "base_corrections_sha256": base_hash,
        "expected_active_province_count": 100,
        "new_ids": new_ids,
        "new_retired_ids": [8, 57],
        "merge_decisions": [
            {"retained_id": 9, "retired_id": 8},
            {"retained_id": 56, "retired_id": 57},
        ],
        "province_12_strip_transfer": {
            "cell_ids": strip_cells,
            "land_area": strip_area,
            "percent_of_previous_province_12_land_area": strip_percent,
            "note": "The narrowest available source cell is coarser than the requested 1–2 percent intent.",
        },
        "province_11_expansion": {
            "cell_ids": expansion_cells,
            "land_area": expansion_area,
            "percent_of_previous_province_6_land_area": expansion_percent,
        },
        "splits": split_summaries,
        "affected_land_area_before": {str(key): value for key, value in before_areas.items()},
        "affected_land_area_after": {str(key): value for key, value in after_areas.items()},
        "land_component_cell_counts_after": cell_components,
        "partition_method": (
            "Manual geographic seeds with deterministic terrain-, biome-, slope-, and river-aware "
            "shortest-path allocation on the immutable Azgaar cell adjacency graph."
        ),
    }
    result["notes"] = copy.deepcopy(base.get("notes", [])) + [
        "This file is a review-only topology proposal and is not the authoritative correction source.",
        "Proposal province names are temporary QA labels; only stable numeric IDs are under review.",
    ]
    return result


def build_manifest(source_path: Path, base_path: Path) -> dict[str, Any]:
    return build_manifest_from_base(
        source_path,
        load_json(base_path),
        base_path.name,
        sha256(base_path),
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--base-corrections", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    manifest = build_manifest(args.source, args.base_corrections)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    metadata = manifest["proposal_metadata"]
    print(
        "Province topology proposal PASS: "
        f"{len(manifest['id_policy']['active_ids'])} active IDs, "
        f"new IDs {metadata['new_ids'][0]}–{metadata['new_ids'][-1]}, "
        f"retired IDs {metadata['new_retired_ids']}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
