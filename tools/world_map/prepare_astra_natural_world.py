"""Build presentation derivatives in the established Astra frame; never edit authorities."""
from pathlib import Path
import argparse, hashlib, json, struct
import numpy as np
from scipy import ndimage as nd
from PIL import Image
import OpenEXR, tifffile

SPACING = 12.20703125
ORIGIN = np.array([-25000., -14062.5])
SEED = 796959858

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def smooth(a,b,x):
    t=np.clip((x-a)/(b-a),0,1)
    return t*t*(3-2*t)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace',type=Path,required=True)
    parser.add_argument('--project',type=Path,required=True)
    args=parser.parse_args()
    data=args.workspace/'08_Final_Terrain/Data'
    out=args.project/'assets/world_map/astra/natural_world'
    out.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((args.workspace/'08_Final_Terrain/EXPORT_MANIFEST.json').read_text())
    for record in manifest['data_files']:
        path=args.workspace/'08_Final_Terrain'/Path(record['path'])
        assert sha(path)==record['sha256'],path
    with OpenEXR.File(str(data/'FCAH_Height_Playable_4096x2304_F32.exr')) as exr:
        height=exr.channels()['R'].pixels.astype(np.float32)*256-6.4
    features=np.array(Image.open(data/'FCAH_Features_RGBA.png'))[896:3200]
    environment=np.array(Image.open(data/'FCAH_Environment_RGBA.png'))[896:3200]/255.
    materials=np.array(Image.open(data/'FCAH_Materials_RGBA.png'))[896:3200]/255.
    land=features[:,:,0]>127
    shape=land.shape
    print('Verified all authority hashes; deriving coastline.',flush=True)
    # Reconstruct only the sub-texel silhouette. A narrow strait or tiny island
    # retains its original pixel-centre sign, including single-pixel features.
    raw=nd.distance_transform_edt(land)-nd.distance_transform_edt(~land)
    signed=nd.gaussian_filter(raw,.85)
    signed=np.where(land,np.maximum(signed,.08),np.minimum(signed,-.08))
    assert np.array_equal(signed>0,land)
    OpenEXR.File({'compression':OpenEXR.ZIP_COMPRESSION},{'R':np.clip(signed,-256,256).astype(np.float16)}).write(str(out/'shore_distance.exr'))
    rng=np.random.default_rng(SEED)
    def field(wavelength):
        dims=(max(3,int(shape[0]/wavelength)+2),max(3,int(shape[1]/wavelength)+2))
        small=rng.random(dims,dtype=np.float32)
        return np.clip(nd.zoom(small,(shape[0]/dims[0],shape[1]/dims[1]),order=3)[:shape[0],:shape[1]],0,1)
    broad=field(80)*.5+field(32)*.3+field(12)*.2
    fine=field(7)*.5+field(19)*.3+field(3)*.2
    forest=smooth(.47,.73,broad)*smooth(.12,.65,environment[:,:,1])
    forest*=1-smooth(.1,.7,materials[:,:,3])
    forest*=1-smooth(.28,.76,materials[:,:,2])
    # Deciduous glades, boreal woods and dry scrub keep the same climate signals.
    ecology=np.stack([environment[:,:,0],forest,environment[:,:,2],fine],axis=-1)
    Image.fromarray(np.rint(np.clip(ecology,0,1)*255).astype('uint8')).save(out/'ecology_rgba.png')
    old=np.array(Image.open(args.project/'assets/world_map/terrain_materials/art_preview/surface_context_rgba.png'))
    old[:,:,0]=np.rint(broad*255).astype('uint8')
    old[:,:,1]=np.rint(fine*255).astype('uint8')
    Image.fromarray(old).save(out/'surface_context_rgba.png')
    water=tifffile.imread(data/'FCAH_WaterSurface_4096_F32.tif')[896:3200]*256-6.4
    coverage=np.maximum(features[:,:,1],features[:,:,2])/255.
    wet=coverage>.025
    nearest=nd.distance_transform_edt(~wet,return_distances=False,return_indices=True)
    water=np.where(wet,water,water[tuple(nearest)])
    river_inside=features[:,:,1]>127
    lake_distance=nd.distance_transform_edt(land)
    # Antialiased river and lake masks meet at their original mouths. Taking
    # separate 50% contours leaves a false dry seam between the two water bodies.
    river_inside|=(features[:,:,1]>6)&(lake_distance<3)
    stream_sdf=nd.distance_transform_edt(river_inside)-nd.distance_transform_edt(~river_inside)
    stream_sdf=nd.gaussian_filter(stream_sdf,.75)
    # Perennial springs widen gradually inside their existing carved corridors.
    # Lake outlets retain their full connection width. No centreline is moved.
    rivers=json.loads((data/'FCAH_Rivers_AzgaarXY_SurfaceM.json').read_text())['features']
    half_width=nd.maximum_filter(np.maximum(stream_sdf,0),size=9)
    for river in rivers:
        if river['properties'].get('seasonal',False):continue
        head=river['geometry']['coordinates'][0]
        hx,hy=np.array(head[:2])*1.6-.5
        x0,x1=max(0,int(hx)-30),min(4096,int(hx)+31)
        y0,y1=max(0,int(hy)-30),min(2304,int(hy)+31)
        if features[max(0,int(hy)-4):min(2304,int(hy)+5),max(0,int(hx)-4):min(4096,int(hx)+5),2].max(initial=0)>0:continue
        gy,gx=np.mgrid[y0:y1,x0:x1]
        taper=smooth(0,25,np.hypot(gx-hx,gy-hy))
        stream_sdf[y0:y1,x0:x1]-=half_width[y0:y1,x0:x1]*(1-taper)*.98
    hydro=features.copy()
    # Keep the original route; naturalize width inside its carved corridor.
    # Contractions are bounded by local channel width, so tributaries stay open.
    width=nd.maximum_filter(np.maximum(stream_sdf,0),size=7)
    variation=smooth(.25,.72,fine*.8+broad*.2)
    stream_sdf-=np.minimum(width*.38,.95)*variation*smooth(2,6,lake_distance)
    joined=river_inside|(~land)
    joined_sdf=nd.gaussian_filter(nd.distance_transform_edt(joined)-nd.distance_transform_edt(~joined),.75)
    join_weight=(1-smooth(1,4,lake_distance))*smooth(0,8,features[:,:,1].astype('float32'))
    stream_sdf=stream_sdf*(1-join_weight)+joined_sdf*join_weight
    hydro[:,:,0]=np.rint(np.clip(.5+stream_sdf/16,0,1)*255).astype('uint8')
    # Shade connected sea/lake/river water as one body. Separate feature distances
    # create an artificial shallow strip across every lake mouth and confluence.
    connected=(~land)|(hydro[:,:,0]>=128)
    connected_sdf=nd.distance_transform_edt(connected)-nd.distance_transform_edt(~connected)
    connected_sdf=nd.gaussian_filter(connected_sdf,.75)
    hydro[:,:,3]=np.rint(np.clip(.5+connected_sdf/32,0,1)*255).astype('uint8')
    Image.fromarray(hydro).save(out/'water_features_rgba.png')
    # Source water/bed depth and the authored downstream direction give inland
    # water absorption and flow a geographic basis, not a global scrolling map.
    flow=np.zeros((*shape,2),dtype='float32')
    flow_seed=np.zeros(shape,dtype=bool)
    for river in rivers:
        if river['properties'].get('seasonal',False):continue
        points=np.array(river['geometry']['coordinates'])[:,:2]*1.6-.5
        for start,end in zip(points[:-1],points[1:]):
            tangent=end-start
            tangent/=max(np.linalg.norm(tangent),.001)
            samples=np.linspace(start,end,max(2,int(np.linalg.norm(end-start)*2))).round().astype(int)
            samples=samples[(samples[:,0]>=0)&(samples[:,0]<4096)&(samples[:,1]>=0)&(samples[:,1]<2304)]
            flow[samples[:,1],samples[:,0]]=tangent
            flow_seed[samples[:,1],samples[:,0]]=True
    flow_nearest=nd.distance_transform_edt(~flow_seed,return_distances=False,return_indices=True)
    flow=flow[tuple(flow_nearest)]
    optics=np.zeros((*shape,4),dtype='uint8')
    optics[:,:,0]=np.rint(np.clip((water-height)/1.5,0,1)*255).astype('uint8')
    optics[:,:,1:3]=np.rint((flow*.5+.5)*255).astype('uint8')
    optics[:,:,3]=features[:,:,2]
    Image.fromarray(optics).save(out/'water_optics_rgba.png')
    from astra_bank_geometry import build_banks
    build_banks(out,height,water,signed,stream_sdf,features)
    # Triangles retain the actual water elevations, including the high mountain lake.
    area=nd.binary_dilation(wet,iterations=2)
    yy,xx=np.where(area[:-1,:-1])
    xyz=np.empty((len(xx),6,3),dtype='<f4')
    for k,(ox,oy) in enumerate([(0,0),(1,0),(0,1),(1,0),(1,1),(0,1)]):
        xyz[:,k,0]=ORIGIN[0]+(xx+ox)*SPACING
        xyz[:,k,1]=water[yy+oy,xx+ox]+.035
        xyz[:,k,2]=ORIGIN[1]+(yy+oy)*SPACING
    # Godot uses clockwise winding from the visible side: these triangles face up.
    (out/'inland_water_vertices.bin').write_bytes(xyz.tobytes())
    print('Generating sparse, seeded ecological clusters.',flush=True)
    dz,dx=np.gradient(nd.gaussian_filter(height,.8),SPACING)
    slope=np.hypot(dx,dz)
    props=[]
    def at(a,x,y):
        return nd.map_coordinates(a,[[y],[x]],order=1,mode='nearest')[0]
    def add(kind,x,y,size):
        ix,iy=int(round(x)),int(round(y))
        if not (2<=ix<4094 and 2<=iy<2302): return
        if signed[iy,ix]<2.6 or coverage[iy,ix]>.01 or slope[iy,ix]>.19: return
        if kind<4 and materials[iy,ix,3]>.63: return
        h=at(height,x,y)
        props.append([kind,round(ORIGIN[0]+x*SPACING,4),round(float(h)-.18,4),round(ORIGIN[1]+y*SPACING,4),round(size,3),round(float(rng.uniform(0,np.pi*2)),5),round(float(rng.uniform(.85,1.14)),4),int(rng.integers(0,3))])
    for cy in np.arange(12,2290,18):
        for cx in np.arange(12,4080,18):
            x,y=np.array([cx,cy])+rng.uniform(-8,8,2)
            ix,iy=int(x),int(y)
            if not land[iy,ix] or signed[iy,ix]<4: continue
            cold=environment[iy,ix,0]; dry=materials[iy,ix,1]; arid=materials[iy,ix,2]; rock=materials[iy,ix,3]
            density=forest[iy,ix]
            if rock<.42 and arid<.28 and rng.random()<density*.72:
                kind=1 if cold>.28 or height[iy,ix]>70 else (2 if dry>.43 else 0)
                for _ in range(int(rng.integers(5,18))):
                    px,py=np.array([x,y])+rng.normal(0,[4.8,3.8],2)
                    add(kind,px,py,float(rng.uniform(20,36))*(.86 if kind==2 else 1))
            elif rock<.45 and dry+arid>.42 and rng.random()<.11:
                # Low maquis/juniper and isolated weathered outcrops, no palm spam.
                for _ in range(int(rng.integers(2,6))):
                    px,py=np.array([x,y])+rng.normal(0,3,2)
                    add(3,px,py,float(rng.uniform(5,10)))
            if (.12<rock<.82 or (arid>.48 and fine[iy,ix]>.58)) and rng.random()<.10:
                for _ in range(int(rng.integers(2,5))):
                    px,py=np.array([x,y])+rng.normal(0,2.8,2)
                    add(4 if arid+dry<.5 else 5,px,py,float(rng.uniform(8,24)))
    from compose_astra_nature import compose
    props=compose(out,height,features,environment,materials,signed,coverage,slope,broad,fine)
    (out/'natural_instances.json').write_text(json.dumps({'seed':SEED,'columns':['kind','x','y','z','height','yaw','value','variant'],'instances':props},separators=(',',':'))+'\n')
    counts={str(k):sum(p[0]==k for p in props) for k in range(20)}
    # Pixel-centre equality is stricter than a generous coastline area tolerance.
    validation={'pass':True,'seed':SEED,'shape':[4096,2304],'origin_xz':ORIGIN.tolist(),'spacing':SPACING,
        'land_pixel_centres':int(land.sum()),'shore_pixel_centre_mismatches':int(np.count_nonzero((signed>0)!=land)),
        'shore_reconstruction':'Gaussian 0.85 samples, sign constrained at every authority centre; original footprint and all channels remain unchanged.',
        'inland_water_triangles':len(xx)*2,'water_min_max_y':[float(water[wet].min()),float(water[wet].max())],
        'prop_counts':counts,'prop_total':len(props),'source_data_hashes_verified':len(manifest['data_files']),
        'source_files':{p.name:sha(p) for p in [data/'FCAH_Features_RGBA.png',data/'FCAH_Environment_RGBA.png',data/'FCAH_WaterSurface_4096_F32.tif',data/'FCAH_Height_Playable_4096x2304_F32.exr']}}
    validation['derived_files']={p.name:{'sha256':sha(p),'bytes':p.stat().st_size} for p in out.iterdir() if p.suffix not in ['.import'] and p.name!='natural_world_manifest.json'}
    (out/'natural_world_manifest.json').write_text(json.dumps(validation,indent=2)+'\n')
    print(json.dumps({k:validation[k] for k in ['prop_counts','prop_total','inland_water_triangles','shore_pixel_centre_mismatches']}),flush=True)

if __name__=='__main__':main()
