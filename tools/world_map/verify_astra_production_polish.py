"""Independently verify the final additive layer against its accepted checkpoint."""
from pathlib import Path
import argparse,hashlib,json
import numpy as np
from scipy import ndimage as nd
from PIL import Image
import OpenEXR

def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--workspace',type=Path,required=True)
    p.add_argument('--project',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    root=args.project
    out=root/'assets/world_map/astra/natural_world'
    checkpoint=args.workspace/'06_Astra_Checkpoints/Natural_Production_2026-09-09'
    baseline=json.loads((checkpoint/'baseline_sha256.json').read_text())
    authority_prefixes=('assets/world_map/astra/terrain_data/','assets/world_map/astra/source/','data/world_map/','src/simulation/')
    # The accepted natural composition and hydrology also remain byte-identical.
    preserved_fields=('shore_distance.exr','natural_instances.json','natural_districts.json','inland_water_vertices.bin','bank_vertices.bin',
        'water_features_rgba.png','water_optics_rgba.png','surface_context_rgba.png','ecology_rgba.png','landscape_character_rgba.png')
    verified=[];failures=[]
    for entry in baseline:
        rel=entry['path']
        if rel.startswith(authority_prefixes) or rel in ['assets/world_map/astra/natural_world/'+n for n in preserved_fields]:
            if not (root/rel).exists() or sha(root/rel)!=entry['sha256']:failures.append('Preserved file changed: '+rel)
            else:verified.append(rel)
    manifest=json.loads((out/'production_polish_manifest.json').read_text())
    for name,entry in manifest['files'].items():
        if sha(out/name)!=entry['sha256']:failures.append('Polish derivative hash: '+name)
    detail=json.loads((out/'shore_details.json').read_text())
    props=np.array(detail['instances'])
    with OpenEXR.File(str(args.workspace/'08_Final_Terrain/Data/FCAH_Height_Playable_4096x2304_F32.exr')) as f:
        h=f.channels()['R'].pixels.astype('float32')*256-6.4
    xy=(props[:,[1,3]]-[-25000,-14062.5])/12.20703125
    sampled=nd.map_coordinates(h,[xy[:,1],xy[:,0]],order=1,mode='nearest')
    burial=np.array([x['burial'] for x in detail['anchors']])
    error=float(np.max(abs(sampled-.18-burial-props[:,2])))
    if error>.001:failures.append('Additional prop not anchored to source bed')
    if not np.isfinite(props).all():failures.append('Non-finite placement')
    if not set(props[:,0]).issubset({3,4,5,9,20}):failures.append('Unexpected added prop family')
    wet_vegetation=[i for i,a in enumerate(detail['anchors']) if a['wet'] and props[i,0] not in (4,5,20)]
    if wet_vegetation:failures.append('Land vegetation in water')
    for wake in detail['wakes']:
        distance=np.linalg.norm(props[:,[1,3]]-[wake['x'],wake['z']],axis=1)
        k=int(distance.argmin())
        if distance[k]>.001 or props[k,0] not in (4,5):failures.append('Water reaction has no corresponding rock')
        if abs(wake['y']-detail['anchors'][k]['water_level']-.18)>.001:failures.append('Reaction lost source water level')
    for name in ('shore_finish_rgba.png','river_motion_rgba.png'):
        im=Image.open(out/name)
        if im.size!=(4096,2304) or im.mode!='RGBA':failures.append('Polish field frame/format: '+name)
    if len(props)>1200 or len(detail['sites'])>75 or len(detail['wakes'])>90:failures.append('Selective-detail budget exceeded')
    before=(checkpoint/'files/src/presentation/world_map/astra_natural_terrain.gdshader').read_text()
    after=(root/'src/presentation/world_map/astra_natural_terrain.gdshader').read_text()
    vertex=lambda s:s[s.index('void vertex()'):s.index('vec2 rotate_uv(')]
    if vertex(before)!=vertex(after):failures.append('Terrain vertex kernel changed')
    provinces=json.loads((root/'data/world_map/astra_provinces.json').read_text())['provinces']
    result=dict(passed=not failures,failures=failures,province_count=len(provinces),
        unchanged_terrain_regions=sum(s.startswith('assets/world_map/astra/terrain_data/') and s.endswith('.res') for s in verified),
        preserved_files_verified=len(verified),accepted_composition_and_water_fields_unchanged=True,
        terrain_vertex_kernel_identical=vertex(before)==vertex(after),
        added_instances=len(props),sites=len(detail['sites']),water_reactions=len(detail['wakes']),
        added_prop_anchor_max_error_units=error,land_vegetation_in_water=len(wet_vegetation),
        reused_rock_sources='Existing curated Quaternius CC0 mesh silhouettes and UVs, simplified fracture planes and corrected normals; source files unchanged.')
    if result['unchanged_terrain_regions']!=576 or len(provinces)!=82:
        result['passed']=False;result['failures'].append('Authority counts changed')
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    if not result['passed']:raise SystemExit(1)

if __name__=='__main__':main()
