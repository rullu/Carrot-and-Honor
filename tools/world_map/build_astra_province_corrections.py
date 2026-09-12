"""Build the reviewed FCAH province correction manifest from immutable Azgaar cells.

This tool does not edit the Azgaar source.  It converts the approved correction
decisions into explicit, stable cell assignments consumed by the Godot importer.
"""

from __future__ import annotations

import argparse
import hashlib
import heapq
import json
import math
from collections import deque
from pathlib import Path
from typing import Any, Iterable


EXPECTED_SOURCE_SHA256 = "9c36b97b340c1fb5827b897db4f3798d16b017ce0e9906c26426ff295efaaa90"
HISTORICAL_MAX_PROVINCE_ID = 82
ACCEPTED_TOPOLOGY_PROPOSAL_SHA256 = "1dfd4cd8c3e4492eb8816b9143ec42bc9f8dfc8e1acd61d885788858d30dea03"

MERGES = (
    (28, (31,), "Absorb tiny Smyrchiala into adjacent Psia."),
    (62, (63,), "Absorb tiny Rheinen into adjacent Weitersia."),
    (67, (68,), "Absorb tiny Askronia into adjacent Tenekionia."),
    (65, (81,), "Attach tiny Trosovis island to the nearest coherent coastal province."),
    (56, (82,), "Attach tiny Cavempil island to the nearest coherent coastal province."),
)

NEW_PROVINCES = {
    83: ("Northern Wilds", "Northern Wilds", "neutral_mainland"),
    84: ("Eastern Highlands", "Eastern Highlands", "state_9"),
    85: ("Eastern Basin", "Eastern Basin", "state_19"),
    86: ("Northeast Coast", "Northeast Coast", "state_17"),
    87: ("Southeast Wastes", "Southeast Wastes", "state_3"),
    88: ("Eastern March", "Eastern March", "state_13"),
    89: ("Far Southeast", "Far Southeast", "state_11"),
}

STATE_ASSIGNMENTS = {
    3: 87,
    9: 84,
    11: 89,
    13: 88,
    17: 86,
    19: 85,
    21: 37,
}

LAKE_FEATURE_ASSIGNMENTS = {
    1: (36, 37),
    3: (30, 33, 34, 41),
    21: (8,),
    24: (35,),
    54: (40,),
    64: (14,),
    66: (32,),
    83: (3,),
    84: (16,),
    87: (52,),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def components(cell_ids: Iterable[int], cells: list[dict[str, Any]]) -> list[list[int]]:
    remaining = set(cell_ids)
    result: list[list[int]] = []
    while remaining:
        start = min(remaining)
        remaining.remove(start)
        queue = deque([start])
        component: list[int] = []
        while queue:
            cell_id = queue.popleft()
            component.append(cell_id)
            for neighbor in cells[cell_id]["c"]:
                neighbor_id = int(neighbor)
                if neighbor_id in remaining:
                    remaining.remove(neighbor_id)
                    queue.append(neighbor_id)
        result.append(sorted(component))
    result.sort(key=lambda group: (-len(group), group[0]))
    return result


def component_centroid(component: list[int], cells: list[dict[str, Any]]) -> tuple[float, float]:
    area_sum = sum(float(cells[cell_id].get("area", 1.0)) for cell_id in component)
    return (
        sum(float(cells[cell_id]["p"][0]) * float(cells[cell_id].get("area", 1.0)) for cell_id in component)
        / area_sum,
        sum(float(cells[cell_id]["p"][1]) * float(cells[cell_id].get("area", 1.0)) for cell_id in component)
        / area_sum,
    )


def add_assignment(
    groups: list[dict[str, Any]],
    province_id: int,
    cell_ids: Iterable[int],
    reason: str,
) -> None:
    ids = sorted(set(int(value) for value in cell_ids))
    if not ids:
        raise ValueError(f"Correction group for province {province_id} is empty: {reason}")
    groups.append({"province_id": province_id, "cell_ids": ids, "reason": reason})


def partition_state_18(
    region: set[int],
    cells: list[dict[str, Any]],
    assignments: list[int],
) -> dict[int, list[int]]:
    candidates = {37, 54, 70, 73}
    best: dict[int, tuple[float, int]] = {}
    heap: list[tuple[float, int, int]] = []
    for cell_id in sorted(region):
        bordering = sorted(
            {
                assignments[int(neighbor)]
                for neighbor in cells[cell_id]["c"]
                if int(neighbor) not in region and assignments[int(neighbor)] in candidates
            }
        )
        for province_id in bordering:
            proposal = (0.0, province_id)
            if cell_id not in best or proposal < best[cell_id]:
                best[cell_id] = proposal
                heapq.heappush(heap, (0.0, province_id, cell_id))
    if {province_id for _, province_id in best.values()} != candidates:
        raise ValueError("Western gap does not border all expected candidate provinces.")

    while heap:
        distance, province_id, cell_id = heapq.heappop(heap)
        if best.get(cell_id) != (distance, province_id):
            continue
        x1, y1 = (float(value) for value in cells[cell_id]["p"])
        for neighbor in cells[cell_id]["c"]:
            neighbor_id = int(neighbor)
            if neighbor_id not in region:
                continue
            x2, y2 = (float(value) for value in cells[neighbor_id]["p"])
            proposal = (distance + math.hypot(x2 - x1, y2 - y1), province_id)
            current = best.get(neighbor_id)
            if current is None or proposal < current:
                best[neighbor_id] = proposal
                heapq.heappush(heap, (proposal[0], proposal[1], neighbor_id))
    if set(best) != region:
        raise ValueError("Western gap partition left unreachable cells.")

    result = {province_id: [] for province_id in sorted(candidates)}
    for cell_id in sorted(region):
        result[best[cell_id][1]].append(cell_id)
    return result


def choose_anchor(cell_ids: list[int], cells: list[dict[str, Any]]) -> int:
    groups = components(cell_ids, cells)
    principal = set(groups[0])
    distance: dict[int, int] = {}
    queue: deque[int] = deque()
    for cell_id in sorted(principal):
        if any(int(neighbor) not in principal for neighbor in cells[cell_id]["c"]):
            distance[cell_id] = 0
            queue.append(cell_id)
    while queue:
        cell_id = queue.popleft()
        for neighbor in cells[cell_id]["c"]:
            neighbor_id = int(neighbor)
            if neighbor_id in principal and neighbor_id not in distance:
                distance[neighbor_id] = distance[cell_id] + 1
                queue.append(neighbor_id)
    max_depth = max(distance.values(), default=0)
    deep_cells = [cell_id for cell_id in principal if distance.get(cell_id, 0) == max_depth]
    centroid = component_centroid(list(principal), cells)
    return min(
        deep_cells,
        key=lambda cell_id: (
            math.dist((float(cells[cell_id]["p"][0]), float(cells[cell_id]["p"][1])), centroid),
            cell_id,
        ),
    )


def build_pre_topology_manifest(source_path: Path) -> dict[str, Any]:
    source_hash = sha256(source_path)
    if source_hash != EXPECTED_SOURCE_SHA256:
        raise ValueError(f"Unexpected Azgaar source SHA-256: {source_hash}")
    source = json.loads(source_path.read_text(encoding="utf-8", errors="surrogatepass"))
    cells: list[dict[str, Any]] = source["pack"]["cells"]
    assignments = [int(cell.get("province", 0)) for cell in cells]
    if len(source["pack"]["provinces"]) != HISTORICAL_MAX_PROVINCE_ID + 1:
        raise ValueError("Historical province definition count changed.")

    retired_ids: set[int] = set()
    for retained_id, absorbed_ids, _ in MERGES:
        for absorbed_id in absorbed_ids:
            retired_ids.add(absorbed_id)
            for cell_id, province_id in enumerate(assignments):
                if province_id == absorbed_id:
                    assignments[cell_id] = retained_id

    groups: list[dict[str, Any]] = []
    neutral_land = [
        int(cell["i"])
        for cell in cells
        if int(cell.get("province", 0)) == 0
        and int(cell.get("state", 0)) == 0
        and int(cell.get("h", 0)) >= 20
    ]
    neutral_components = components(neutral_land, cells)
    expected_sizes = [1116, 36, 25, 23, 14, 13, 8, 7, 3, 1]
    actual_sizes = [len(group) for group in neutral_components]
    if actual_sizes != expected_sizes:
        raise ValueError(f"Neutral component fingerprint changed: {actual_sizes}")
    neutral_targets = [83, 18, 18, 86, 18, 18, 80, 22, 80, 80]
    neutral_reasons = [
        "Create a coherent northern wilderness province from the principal neutral mainland.",
        "Attach northern island to nearby province 18.",
        "Attach northern island to nearby province 18.",
        "Join the detached northeast coastal land to the new Northeast Coast province.",
        "Attach northern island to nearby province 18.",
        "Attach northern island to nearby province 18.",
        "Attach northeast coastal/island land to nearby province 80.",
        "Fill the enclosed land defect inside province 22.",
        "Attach northeast coastal/island land to nearby province 80.",
        "Attach northeast coastal/island land to nearby province 80.",
    ]
    for component, target, reason in zip(neutral_components, neutral_targets, neutral_reasons, strict=True):
        add_assignment(groups, target, component, reason)
        for cell_id in component:
            assignments[cell_id] = target

    for state_id, target_id in sorted(STATE_ASSIGNMENTS.items()):
        state_cells = [
            int(cell["i"])
            for cell in cells
            if int(cell.get("province", 0)) == 0
            and int(cell.get("state", 0)) == state_id
            and int(cell.get("h", 0)) >= 20
        ]
        add_assignment(
            groups,
            target_id,
            state_cells,
            f"Assign previously unowned playable land from source state {state_id} coherently.",
        )
        for cell_id in state_cells:
            assignments[cell_id] = target_id

    western_region = {
        int(cell["i"])
        for cell in cells
        if int(cell.get("province", 0)) == 0
        and int(cell.get("state", 0)) == 18
        and int(cell.get("h", 0)) >= 20
    }
    for target_id, cell_ids in partition_state_18(western_region, cells, assignments).items():
        add_assignment(
            groups,
            target_id,
            cell_ids,
            "Divide the western gap by shortest connected cell distance to bordering provinces.",
        )
        for cell_id in cell_ids:
            assignments[cell_id] = target_id

    fragmentation_rules = {
        38: {1: 41},
        39: {1: 32, 2: 21},
        49: {1: 76, 2: 76, 3: 76},
        32: {1: 64},
    }
    for source_province, rules in fragmentation_rules.items():
        original_cells = [
            int(cell["i"]) for cell in cells if int(cell.get("province", 0)) == source_province
        ]
        source_components = components(original_cells, cells)
        expected_component_counts = {38: 3, 39: 3, 49: 4, 32: 2}
        if len(source_components) != expected_component_counts[source_province]:
            raise ValueError(f"Province {source_province} component fingerprint changed.")
        for component_index, target_id in rules.items():
            component = source_components[component_index]
            add_assignment(
                groups,
                target_id,
                component,
                f"Reassign disconnected component {component_index + 1} of province {source_province}.",
            )
            for cell_id in component:
                assignments[cell_id] = target_id

    assigned_once: set[int] = set()
    for group in groups:
        for cell_id in group["cell_ids"]:
            if cell_id in assigned_once:
                raise ValueError(f"Cell {cell_id} appears in multiple explicit correction groups.")
            assigned_once.add(cell_id)

    new_records: list[dict[str, Any]] = []
    for province_id, (name, full_name, source_group) in sorted(NEW_PROVINCES.items()):
        province_cells = [index for index, value in enumerate(assignments) if value == province_id]
        if not province_cells:
            raise ValueError(f"New province {province_id} has no assigned land cells.")
        anchor_cell = choose_anchor(province_cells, cells)
        anchor = [float(value) for value in cells[anchor_cell]["p"]]
        new_records.append(
            {
                "id": province_id,
                "name": name,
                "full_name": full_name,
                "provisional_name": True,
                "source_group": source_group,
                "selection_cell_id": anchor_cell,
                "label_point_source_xy": anchor,
            }
        )

    active_ids = sorted(
        (set(range(1, HISTORICAL_MAX_PROVINCE_ID + 1)) - retired_ids) | set(NEW_PROVINCES)
    )
    for province_id in active_ids:
        if province_id not in assignments:
            raise ValueError(f"Active province {province_id} has no source land cell.")
    if retired_ids & set(assignments):
        raise ValueError("A retired province ID remains in the corrected land assignments.")

    province_49_cells = [index for index, value in enumerate(assignments) if value == 49]
    province_49_anchor_cell = choose_anchor(province_49_cells, cells)
    province_49_anchor = [float(value) for value in cells[province_49_anchor_cell]["p"]]

    return {
        "schema_version": 1,
        "source": {
            "kind": "immutable Azgaar Full JSON",
            "file_name": source_path.name,
            "sha256": source_hash,
            "historical_max_province_id": HISTORICAL_MAX_PROVINCE_ID,
        },
        "id_policy": {
            "ids_are_stable_opaque_identifiers": True,
            "never_reuse_retired_ids": True,
            "retired_ids": sorted(retired_ids),
            "active_ids": active_ids,
            "next_new_id": max(active_ids) + 1,
        },
        "merges": [
            {"retained_id": retained, "retired_ids": list(retired), "reason": reason}
            for retained, retired, reason in MERGES
        ],
        "new_provinces": new_records,
        "cell_assignments": groups,
        "inland_water_assignments": [
            {
                "province_id": province_id,
                "feature_ids": list(feature_ids),
                "reason": "Assign enclosed inland water politically without changing terrain or water.",
            }
            for province_id, feature_ids in sorted(LAKE_FEATURE_ASSIGNMENTS.items())
        ],
        "anchor_overrides": [
            {
                "province_id": 49,
                "label_point_source_xy": province_49_anchor,
                "reason": "Move Agos label into its retained principal component after fragment repair.",
            }
        ],
        "supported_operations": [
            "assign_unowned_source_cells",
            "assign_enclosed_water_features",
            "merge_with_stable_retained_id",
            "reassign_disconnected_components",
            "create_new_id_above_historical_maximum",
            "override_selection_or_label_anchor",
            "targeted_split_or_reshape_by_source_cell_assignment",
        ],
        "coverage_policy": {
            "playable_land_mask_red_threshold": 127,
            "meaningful_component_min_pixels": 500,
            "maximum_meaningful_unassigned_pixels": 0,
        },
        "notes": [
            "Source state IDs are authoring partitions only and are not runtime realms.",
            "New province names are provisional QA names pending the later naming pass.",
            "The manifest is explicit so regeneration never mutates the Azgaar master source.",
            "Future splits and reshapes use the same explicit source-cell assignments plus a new province definition when needed.",
        ],
    }


def build_manifest(source_path: Path) -> dict[str, Any]:
    """Build the accepted 100-province correction authority from source."""
    base = build_pre_topology_manifest(source_path)
    base_bytes = json.dumps(
        base,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    from build_astra_province_topology_proposal import build_manifest_from_base

    manifest = build_manifest_from_base(
        source_path,
        base,
        "generated_pre_topology_manifest",
        hashlib.sha256(base_bytes).hexdigest(),
    )
    metadata = manifest.pop("proposal_metadata")
    metadata["status"] = "accepted_authoritative"
    metadata["accepted_proposal_sha256"] = ACCEPTED_TOPOLOGY_PROPOSAL_SHA256
    metadata.pop("base_corrections_file", None)
    metadata.pop("base_corrections_sha256", None)
    manifest["accepted_topology"] = metadata

    for collection_name in (
        "merges",
        "cell_assignments",
        "inland_water_assignments",
        "anchor_overrides",
    ):
        for record in manifest[collection_name]:
            reason = str(record.get("reason", ""))
            reason = reason.replace("Review proposal:", "Accepted topology:")
            reason = reason.replace("Proposal:", "Accepted topology:")
            record["reason"] = reason
    manifest["notes"] = [
        note
        for note in manifest.get("notes", [])
        if "review-only" not in note and "only stable numeric IDs" not in note
    ] + [
        "The targeted 100-province topology is accepted as authoritative gameplay geography.",
        "The accepted review proposal remains preserved separately as historical QA evidence.",
    ]
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    manifest = build_manifest(args.source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False, sort_keys=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )
    assignment_count = sum(len(group["cell_ids"]) for group in manifest["cell_assignments"])
    print(
        f"Province correction manifest PASS: {len(manifest['id_policy']['active_ids'])} active IDs, "
        f"{assignment_count} explicit cell assignments."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
