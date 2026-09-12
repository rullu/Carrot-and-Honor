"""Verify presentation changes against the recoverable pre-beauty checkpoint."""
from pathlib import Path
import argparse, hashlib, json
import numpy as np
from scipy import ndimage as nd
import OpenEXR

def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace',type=Path,required=True)
    parser.add_argument('--project',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    checkpoint=args.workspace/'06_Astra_Checkpoints/Natural_Beauty_2026-09-09'
    baseline=json.loads((checkpoint/'baseline_sha256.json').read_text())
    root=args.project; natural=root/'assets/world_map/astra/natural_world'
    prefixes=('assets/world_map/astra/terrain_data/','assets/world_map/astra/source/','src/simulation/')
    fields=('shore_distance.exr','natural_instances.json','natural_districts.json','inland_water_vertices.bin','bank_vertices.bin',
            'water_features_rgba.png','water_optics_rgba.png','river_motion_rgba.png','surface_context_rgba.png','ecology_rgba.png','landscape_character_rgba.png')
    field_paths={'assets/world_map/astra/natural_world/'+x for x in fields}
    failures=[];verified=[]
    for entry in baseline:
        rel=entry['path']
        if rel.startswith(prefixes) or rel in field_paths:
            if not (root/rel).is_file() or sha(root/rel)!=entry['sha256']:failures.append('Authority changed: '+rel)
            else:verified.append(rel)
    source_manifest=json.loads((args.workspace/'08_Final_Terrain/EXPORT_MANIFEST.json').read_text())
    for entry in source_manifest['data_files']:
        source=args.workspace/'08_Final_Terrain'/entry['path']
        if sha(source)!=entry['sha256']:failures.append('Source export changed: '+entry['path'])
    shader_path='src/presentation/world_map/astra_natural_terrain.gdshader'
    before=(checkpoint/'files'/shader_path).read_text(encoding='utf-8')
    after=(root/shader_path).read_text(encoding='utf-8')
    kernel=lambda s:s[s.index('void vertex()'):s.index('vec2 rotate_uv(')]
    if kernel(before)!=kernel(after):failures.append('Terrain3D vertex kernel changed')
    count_regions=sum(p.startswith(prefixes[0]) and p.endswith('.res') for p in verified)
    province_data=json.loads((root/'data/world_map/astra_provinces.json').read_text())
    count_provinces=len(province_data['provinces'])
    coverage=json.loads((root/'data/world_map/astra_province_coverage_report.json').read_text())
    if count_regions!=576:failures.append('Terrain region count changed')
    if count_provinces!=province_data['province_count'] or not coverage['passed']:
        failures.append('Corrected province geography validation failed')
    composition=json.loads((natural/'beauty_composition.json').read_text())
    props=np.array(composition['instances'])
    with OpenEXR.File(str(args.workspace/'08_Final_Terrain/Data/FCAH_Height_Playable_4096x2304_F32.exr')) as f:
        height=f.channels()['R'].pixels.astype(np.float32)*256-6.4
    xy=(props[:,[1,3]]-[-25000,-14062.5])/12.20703125
    sampled=nd.map_coordinates(height,[xy[:,1],xy[:,0]],order=1,mode='nearest')
    burial=np.array([x['burial'] for x in composition['anchors']])
    anchor_error=float(np.max(abs(sampled-burial-props[:,2])))
    if anchor_error>.001:failures.append('Coastal composition lost source bed anchoring')
    original=json.loads((natural/'natural_instances.json').read_text())['instances']
    previous=json.loads((natural/'shore_details.json').read_text())['instances']
    combined=original+previous+composition['instances']
    if any(combined[i][0] not in (4,5,17) for i in composition['omitted']):failures.append('Non-rock composition omitted')
    if any(combined[int(i)][0] not in (4,5,17) for i in composition['rock_overrides']):failures.append('Non-rock shape changed')
    for wake in composition['wakes']:
        distances=np.linalg.norm(props[:,[1,3]]-[wake['x'],wake['z']],axis=1)
        if distances.min()>.001:failures.append('Reaction has no corresponding obstacle')
        if abs(wake['y']-.14)>.001:failures.append('Coastal reaction left the accepted sea surface')
    if not np.isfinite(props).all():failures.append('Non-finite composition')
    result={'passed':not failures,'failures':failures,'checkpoint':str(checkpoint),
            'provinces':count_provinces,'unchanged_terrain_regions':count_regions,'preserved_project_files':len(verified),
            'verified_authoritative_exports':len(source_manifest['data_files']),'terrain_vertex_kernel_identical':kernel(before)==kernel(after),
            'authoritative_height_and_masks_unchanged':not any('Authority' in x or 'Source' in x for x in failures),
            'river_routes_and_water_meshes_unchanged':all('assets/world_map/astra/natural_world/'+x in verified for x in fields if 'water' in x or 'river' in x),
            'existing_vegetation_compositions_unchanged':not any('Non-rock' in x for x in failures),
            'added_coastal_rocks':len(props),'omitted_isolated_stones':len(composition['omitted']),
            'composed_instance_count':len(combined)-len(composition['omitted']), 'new_coastal_anchor_max_error_units':anchor_error,
            'scope':'Presentation shaders, lighting, cloud/wave resources, shore appearance derivatives and bounded environmental composition.'}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    if failures:raise SystemExit(1)

if __name__=='__main__':main()
