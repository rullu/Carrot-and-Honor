"""Independent preservation, geometry placement and presentation data checks."""
from pathlib import Path
import argparse,json,hashlib
import numpy as np
from PIL import Image
from scipy import ndimage as nd
import OpenEXR,tifffile

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',type=Path,required=True)
    parser.add_argument('--workspace',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    asset=args.project/'assets/world_map/astra/natural_world'
    data=args.workspace/'08_Final_Terrain/Data'
    record=json.loads((asset/'natural_world_manifest.json').read_text())
    failures=[]
    for name,entry in record['derived_files'].items():
        if sha(asset/name)!=entry['sha256']:failures.append('Derived file hash: '+name)
    baseline=(args.project/'src/presentation/world_map/astra_terrain_art.gdshader').read_text()
    final=(args.project/'src/presentation/world_map/astra_natural_terrain.gdshader').read_text()
    def vertex(code):return code[code.index('void vertex()'):code.index('vec2 rotate_uv(')]
    if vertex(baseline)!=vertex(final):failures.append('Terrain vertex kernel changed')
    with OpenEXR.File(str(asset/'shore_distance.exr')) as f:shore=f.channels()['R'].pixels.astype('float32')
    features=np.array(Image.open(data/'FCAH_Features_RGBA.png'))[896:3200]
    centre_changes=int(np.count_nonzero((shore>0)!=(features[:,:,0]>127)))
    if centre_changes:failures.append('Shore classification changed')
    with OpenEXR.File(str(data/'FCAH_Height_Playable_4096x2304_F32.exr')) as f:height=f.channels()['R'].pixels*256-6.4
    props=np.array(json.loads((asset/'natural_instances.json').read_text())['instances'])
    xy=(props[:,[1,3]]-[-25000,-14062.5])/12.20703125
    heights=nd.map_coordinates(height,[xy[:,1],xy[:,0]],order=1,mode='nearest')
    placement_error=float(np.max(np.abs(heights-.18-props[:,2])))
    idx=np.rint(xy).astype(int)
    invalid_water=int(np.count_nonzero((features[idx[:,1],idx[:,0],0]<128)|(features[idx[:,1],idx[:,0],1]>3)))
    if placement_error>.001:failures.append('Props lost terrain anchoring')
    if invalid_water:failures.append('Prop in water')
    vertices=np.fromfile(asset/'inland_water_vertices.bin',dtype='<f4').reshape(-1,3)
    cells=np.rint((vertices[:,[0,2]]-[-25000,-14062.5])/12.20703125).astype(int)
    source_water=tifffile.imread(data/'FCAH_WaterSurface_4096_F32.tif')[896:3200]*256-6.4
    selected=features[cells[:,1],cells[:,0],1:3].max(axis=1)>7
    water_error=float(np.max(np.abs(vertices[selected,1]-.035-source_water[cells[selected,1],cells[selected,0]])))
    if water_error>.0001:failures.append('Water elevations changed')
    province_data=json.loads((args.project/'data/world_map/astra_provinces.json').read_text())
    areas=np.array([x['area_godot_units_squared'] for x in province_data['provinces']])
    view_area=1600*1600*16/9/np.sin(np.deg2rad(40))
    banks=np.fromfile(asset/'bank_vertices.bin',dtype='<f4').reshape(-1,3)
    if not np.isfinite(banks).all():failures.append('Invalid bank geometry')
    if not ((banks[:,0]>=-25000)&(banks[:,0]<=25000)&(banks[:,2]>=-14062.5)&(banks[:,2]<=14062.5)).all():
        failures.append('Bank geometry outside established footprint')
    library=args.project/'assets/world_map/nature_library/quaternius'
    provenance=json.loads((library/'provenance.json').read_text())
    for name,entry in provenance['files'].items():
        expected=entry['sha256'] if isinstance(entry,dict) else entry
        if sha(library/name)!=expected:failures.append('Botanical source hash: '+name)
    yy,xx=np.where(features[:,:,1]>200)
    wx=-25000+xx*12.20703125;wz=-14062.5+yy*12.20703125
    closest=int(np.argmin((wx+2300)**2+(wz+650)**2))
    result={'pass':not failures,'failures':failures,'vertex_kernel_identical':vertex(baseline)==vertex(final),
        'land_classification_changes':centre_changes,'terrain_anchored_props':len(props),
        'maximum_prop_anchor_error_units':placement_error,'props_in_water':invalid_water,
        'maximum_inland_water_height_error_units':water_error,'inland_water_triangles':len(vertices)//3,
        'bank_triangles':len(banks)//3,'botanical_source_files_verified':len(provenance['files']),
        'gameplay_camera':{'pitch_degrees':40,'closest':800,'default':1600,'furthest':3600,'projection':'orthographic'},
        'province_count':len(areas),'median_province_area_units_squared':float(np.median(areas)),
        'mean_province_area_units_squared':float(areas.mean()),'gameplay_view_ground_area_units_squared':float(view_area),
        'mean_province_area_equivalents_per_gameplay_view':float(view_area/areas.mean()),
        'river_review_anchor':[float(wx[closest]),float(wz[closest])]}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    if failures:raise SystemExit(1)

if __name__=='__main__':main()
