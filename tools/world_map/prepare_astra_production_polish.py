"""Final, additive shoreline dressing. Reads accepted geography; never rebuilds it."""
from pathlib import Path
import argparse, hashlib, json
import numpy as np
from PIL import Image
from scipy import ndimage as nd
from scipy.spatial import cKDTree
import OpenEXR, tifffile

SPACING = 12.20703125
ORIGIN = np.array([-25000., -14062.5])
SEED = 796959858 + 909

def smooth(a, b, x):
    t = np.clip((x-a)/(b-a), 0, 1)
    return t*t*(3-2*t)

def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace', type=Path, required=True)
    parser.add_argument('--project', type=Path, required=True)
    args = parser.parse_args()
    data = args.workspace/'08_Final_Terrain/Data'
    out = args.project/'assets/world_map/astra/natural_world'
    source_manifest = json.loads((args.workspace/'08_Final_Terrain/EXPORT_MANIFEST.json').read_text())
    for entry in source_manifest['data_files']:
        assert sha(args.workspace/'08_Final_Terrain'/entry['path']) == entry['sha256'], entry['path']
    with OpenEXR.File(str(data/'FCAH_Height_Playable_4096x2304_F32.exr')) as f:
        height = f.channels()['R'].pixels.astype('float32')*256-6.4
    with OpenEXR.File(str(out/'shore_distance.exr')) as f:
        shore = f.channels()['R'].pixels.astype('float32')
    features = np.array(Image.open(data/'FCAH_Features_RGBA.png'))[896:3200]
    climate = np.array(Image.open(data/'FCAH_Materials_RGBA.png'))[896:3200].astype('float32')/255
    habitat = np.array(Image.open(out/'ecology_rgba.png')).astype('float32')/255
    character = np.array(Image.open(out/'landscape_character_rgba.png')).astype('float32')/255
    context = np.array(Image.open(out/'surface_context_rgba.png')).astype('float32')/255
    hydro = np.array(Image.open(out/'water_features_rgba.png'))
    optics = np.array(Image.open(out/'water_optics_rgba.png'))
    water = tifffile.imread(data/'FCAH_WaterSurface_4096_F32.tif')[896:3200]*256-6.4
    wet_source = features[:,:,1:3].max(axis=2)>6
    nearest = nd.distance_transform_edt(~wet_source, return_distances=False, return_indices=True)
    water = np.where(wet_source, water, water[tuple(nearest)])
    # Open ocean is the existing reference plane, never an invented water level.
    ocean = (shore<0)&(features[:,:,2]<1)
    water[ocean] = -.05
    river_distance = (hydro[:,:,0].astype('float32')/255-.5)*16
    wet = (shore<0)|((river_distance>=0)&(hydro[:,:,1]>2))
    signed = nd.distance_transform_edt(~wet)-nd.distance_transform_edt(wet)
    dz, dx = np.gradient(nd.gaussian_filter(height, .65), SPACING)
    slope = np.hypot(dx, dz)
    rng = np.random.default_rng(SEED)
    # The existing shelter, climate and woodland fields set a varied vocabulary.
    # These channels only affect a narrow shoreline in the shader.
    finish = np.zeros((*height.shape,4), dtype='float32')
    finish[:,:,0] = smooth(.40,.67,context[:,:,0])*(.48+habitat[:,:,1]*.44)*(1-climate[:,:,2]*.85)*(1-climate[:,:,3]*.6)
    finish[:,:,1] = smooth(.38,.69,context[:,:,1])*(.22+character[:,:,2]*.50)*(1-habitat[:,:,1]*.45)
    finish[:,:,3] = smooth(.45,.72,context[:,:,0]) * smooth(.24,.73,character[:,:,3]) * .62
    # Existing vegetation and all original instances are read-only inputs.
    accepted = json.loads((out/'natural_instances.json').read_text())['instances']
    solids = np.array([p for p in accepted if p[0] in (4,5,17)])
    rock_tree = cKDTree(solids[:,[1,3]])
    occupied = {(round(p[1]/9),round(p[3]/9)) for p in accepted}
    props, anchors, wakes, sites = [], [], [], []
    banks = (~wet)&(signed<=3.2)&(slope<.24)&(height>-1)
    river_banks = banks&(shore>6)&(river_distance> -3.4)
    coast_banks = banks&(shore<3.3)&(features[:,:,1]<4)

    def sample(a, x, y):
        return float(nd.map_coordinates(a, [[y],[x]], order=1, mode='nearest')[0])

    def stamp(channel, x, y, rx, ry, amount):
        x0,x1=max(0,int(x-rx*2)),min(4096,int(x+rx*2)+1)
        y0,y1=max(0,int(y-ry*2)),min(2304,int(y+ry*2)+1)
        yy,xx=np.mgrid[y0:y1,x0:x1]
        patch=np.exp(-(((xx-x)/rx)**2+((yy-y)/ry)**2)*1.6)*amount
        finish[y0:y1,x0:x1,channel]=np.maximum(finish[y0:y1,x0:x1,channel],patch)

    def add(kind, x, y, size, mode, site_id, yaw=None):
        ix,iy=round(x),round(y)
        if not (3<ix<4092 and 3<iy<2300) or slope[iy,ix]>.26:
            return False
        if abs(signed[iy,ix])>9:
            return False
        is_wet = bool(wet[iy,ix])
        if mode=='land' and is_wet:
            return False
        if mode=='shallow' and not is_wet:
            return False
        pos=ORIGIN+np.array([x,y])*SPACING
        if kind in (3,9,20):
            near=rock_tree.query_ball_point(pos,135)
            if any(np.linalg.norm(pos-solids[k,[1,3]]) < solids[k,4]*.64+size*.16 for k in near):
                return False
        cell=tuple(np.rint(pos/9).astype(int))
        if cell in occupied:
            return False
        h=sample(height,x,y)
        level=sample(water,x,y)
        if is_wet and level-h>size*(.16 if kind==20 else .55):
            return False
        if kind==20 and (abs(signed[iy,ix])>2.4 or climate[iy,ix,3]>.55):
            return False
        occupied.add(cell)
        direction=float(rng.uniform(0,np.pi*2) if yaw is None else yaw)
        burial=size*.12 if kind in (4,5,17) else 0.0
        props.append([kind,round(float(pos[0]),4),round(h-.18-burial,4),round(float(pos[1]),4),round(size,3),round(direction,5),round(float(rng.uniform(.91,1.08)),4),int(rng.integers(0,3))])
        anchors.append(dict(instance=len(props)-1,site=site_id,wet=is_wet,bed_height=h,water_level=level,burial=burial))
        if is_wet and kind in (4,5) and size>11 and len(wakes)<90:
            flow=optics[iy,ix,1:3].astype(float)/255*2-1
            flow/=max(np.linalg.norm(flow),.001)
            river=bool(hydro[iy,ix,1]>6 and shore[iy,ix]>3)
            if river or (ocean[iy,ix] and character[iy,ix,3]>.38):
                if not river:
                    gy,gx=np.gradient(shore[max(0,iy-1):iy+2,max(0,ix-1):ix+2])
                    flow=np.array([-gx[1,1],-gy[1,1]])
                    flow/=max(np.linalg.norm(flow),.001)
                gradient=[(sample(water,x+1,y)-sample(water,x-1,y))/(2*SPACING),
                          (sample(water,x,y+1)-sample(water,x,y-1))/(2*SPACING)]
                wakes.append(dict(x=float(pos[0]),z=float(pos[1]),y=level+.18,flow=flow.tolist(),slope=gradient,width=size*3.6,length=size*(7.4 if river else 5.5),strength=.50 if river else .28,river=river))
        return True

    def choose(name, wx, wz, motif, river=False, radius=550):
        x,y=(np.array([wx,wz])-ORIGIN)/SPACING
        r=radius/SPACING
        x0,x1=max(3,int(x-r)),min(4092,int(x+r)+1)
        y0,y1=max(3,int(y-r)),min(2300,int(y+r)+1)
        valid=(river_banks if river else coast_banks)[y0:y1,x0:x1]
        if not valid.any():
            return False
        yy,xx=np.mgrid[y0:y1,x0:x1]
        score=(xx-x)**2+(yy-y)**2+abs(signed[y0:y1,x0:x1]-1.5)*1.5
        if motif in ('gravel','rock'):
            score+=habitat[y0:y1,x0:x1,1]*75
        k=np.argmin(np.where(valid,score,np.inf)); py,px=np.unravel_index(k,valid.shape)
        x,y=float(px+x0),float(py+y0)
        if any(np.hypot(x-s['sample'][0],y-s['sample'][1])<22 for s in sites):
            return False
        site_id=len(sites)
        start=len(props)
        warm=climate[int(y),int(x),1:3].sum()>.6
        rock_kind=5 if warm else 4
        if motif=='auto':
            motif='rock' if character[int(y),int(x),3]>.58 else ('reeds' if not warm else 'gravel')
        gy,gx=np.gradient(signed[int(y)-1:int(y)+2,int(x)-1:int(x)+2])
        normal=np.array([gx[1,1],gy[1,1]])
        normal/=max(np.linalg.norm(normal),.001)
        tangent=np.array([-normal[1],normal[0]])
        if motif in ('reeds','oasis'):
            stamp(0,x,y,10,9,.86)
            stamp(2,x,y,8,7,.85 if motif=='oasis' else .36)
            # Two asymmetric pockets; leave most of the reach open.
            for pocket,offset in enumerate([-3.8,3.0]):
                centre=np.array([x,y])+tangent*offset
                for _ in range(15 if motif=='oasis' else 10):
                    point=centre+tangent*rng.normal(0,1.35)+normal*rng.normal(.0,.8)
                    add(20,*point,float(rng.uniform(12,21)), 'either', site_id)
                for _ in range(4 if motif=='oasis' else 2):
                    point=centre+tangent*rng.normal(0,2)+normal*rng.uniform(1.1,3.4)
                    add(3,*point,float(rng.uniform(9,16)), 'land', site_id)
            if motif=='oasis':
                for offset in [-3,0,2.5,4.4]:
                    point=np.array([x,y])+tangent*offset+normal*rng.uniform(3.0,5.0)
                    add(9,*point,float(rng.uniform(34,51)),'land',site_id)
        if motif in ('gravel','rock','oasis'):
            stamp(1,x,y,9 if motif=='gravel' else 6,7,.94)
            if motif=='rock':stamp(3,x,y,7,6,.90)
            for _ in range(14 if motif=='gravel' else 8):
                point=np.array([x,y])+tangent*rng.normal(0,3.4)+normal*rng.normal(.1,1.2)
                add(rock_kind,*point,float(rng.uniform(2.6,6.5)),'either',site_id)
            for offset in [-2.0,1.0]:
                point=np.array([x,y])+tangent*offset-normal*rng.uniform(1.4,2.6)
                add(rock_kind,*point,float(rng.uniform(14,27) if motif=='rock' else rng.uniform(11,17)),'shallow',site_id)
            if motif=='rock':
                for _ in range(3):
                    point=np.array([x,y])+tangent*rng.normal(0,3)+normal*rng.uniform(.6,2.5)
                    add(rock_kind,*point,float(rng.uniform(17,31)),'land',site_id)
        if len(props)==start:
            return False
        world=ORIGIN+np.array([x,y])*SPACING
        sites.append(dict(id=site_id,name=name,motif=motif,river=river,sample=[x,y],target=[float(world[0]),0,float(world[1])],instances=len(props)-start))
        return True

    authored=[
        ('western_gravel_reach',-2825,-740,'gravel',True),
        ('western_overgrown_reach',-4540,-1050,'reeds',True),
        ('watermeadow_margin',-5900,-1900,'reeds',False),
        ('western_headland_stones',-6030,-1420,'rock',False),
        ('central_reed_reach',1100,-3200,'reeds',True),
        ('parmetos_sheltered_reeds',-16520,2260,'reeds',False),
        ('parmetos_gravel_margin',-15710,2440,'gravel',False),
        ('waring_stone_margin',12540,-5030,'rock',False),
        ('waring_sheltered_reeds',13260,-4740,'reeds',False),
        ('mountain_lake_scree',10554,-3177,'rock',False),
        ('northern_quiet_lake',7385,-8586,'gravel',False),
        ('amber_oasis_crescent',11620,6050,'oasis',False),
        ('southern_small_spring',9587,8487,'reeds',False),
        ('exposed_rocky_headland',427,-6836,'rock',False),
        ('chalk_coast_outcrop',-18200,3600,'rock',False),
        ('southwestern_lake_reeds',-6753,2347,'reeds',False),
    ]
    for item in authored:choose(*item)
    for label,valid,limit in [('river',river_banks,24),('shore',coast_banks,22)]:
        yy,xx=np.where(valid)
        count=0
        for k in rng.permutation(len(xx)):
            x,y=xx[k],yy[k]
            if any(np.hypot(x-s['sample'][0],y-s['sample'][1])<85 for s in sites):
                continue
            world=ORIGIN+np.array([x,y])*SPACING
            if choose(f'{label}_pocket_{count+1:02}',*world,'auto',label=='river',radius=45):
                count+=1
            if count>=limit:break

    # Green wet ground cannot spill into uplands; its support is nearby water.
    finish[:,:,2]*=np.exp(-np.maximum(signed,0)/5.5)*(1-smooth(.06,.22,slope))
    Image.fromarray(np.rint(np.clip(finish,0,1)*255).astype('uint8')).save(out/'shore_finish_rgba.png')
    # Cyclic distance along unchanged source polylines. Encoding sine/cosine
    # avoids phase-wrap seams and keeps the motion aligned through river bends.
    shape=height.shape
    seeds=np.zeros(shape,dtype=bool)
    progress=np.zeros(shape,dtype='float32')
    flow_x=np.zeros(shape,dtype='float32')
    flow_y=np.zeros(shape,dtype='float32')
    rivers=json.loads((data/'FCAH_Rivers_AzgaarXY_SurfaceM.json').read_text())['features']
    for river in rivers:
        if river['properties'].get('seasonal',False):continue
        points=np.array(river['geometry']['coordinates'])[:,:2]*1.6-.5
        travelled=0.0
        for start,end in zip(points[:-1],points[1:]):
            length=np.linalg.norm(end-start)
            if length<.001:continue
            direction=(end-start)/length
            t=np.linspace(0,1,max(2,int(length*3)))
            coords=np.rint(start[None,:]+(end-start)[None,:]*t[:,None]).astype(int)
            valid=(coords[:,0]>=0)&(coords[:,0]<4096)&(coords[:,1]>=0)&(coords[:,1]<2304)
            coords=coords[valid];t=t[valid]
            sx,sy=coords[:,0],coords[:,1]
            seeds[sy,sx]=True
            progress[sy,sx]=travelled+t*length
            flow_x[sy,sx]=direction[0];flow_y[sy,sx]=direction[1]
            travelled+=length
    near=nd.distance_transform_edt(~seeds,return_distances=False,return_indices=True)
    yy,xx=np.indices(shape,dtype='float32')
    fx=flow_x[tuple(near)];fy=flow_y[tuple(near)]
    offset_x=xx-near[1];offset_y=yy-near[0]
    phase=(progress[tuple(near)]+offset_x*fx+offset_y*fy)*SPACING*.08
    cross=offset_x*(-fy)+offset_y*fx
    motion=np.stack([np.sin(phase)*.5+.5,np.cos(phase)*.5+.5,np.clip(.5+cross/12,0,1),np.ones(shape)],axis=-1)
    Image.fromarray(np.rint(motion*255).astype('uint8')).save(out/'river_motion_rgba.png')
    payload=dict(seed=SEED,columns=['kind','x','y','z','height','yaw','value','variant'],instances=props,anchors=anchors,sites=sites,wakes=wakes)
    (out/'shore_details.json').write_text(json.dumps(payload,separators=(',',':'))+'\n')
    files=['shore_finish_rgba.png','shore_details.json','river_motion_rgba.png']
    manifest=dict(version=1,source_authorities_verified=len(source_manifest['data_files']),
        accepted_instances_sha256=sha(out/'natural_instances.json'),
        preserved_water_vertices_sha256=sha(out/'inland_water_vertices.bin'),
        channels=['damp bank','gravel pocket','water-influenced vegetation','rock interruption'],
        sites=len(sites),added_instances=len(props),wakes=len(wakes),
        provenance='Original deterministic project geometry and composition; no additional third-party assets.',
        files={name:dict(sha256=sha(out/name),bytes=(out/name).stat().st_size) for name in files})
    (out/'production_polish_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({k:manifest[k] for k in ['sites','added_instances','wakes']}))
    print(json.dumps(sites[:16]))

if __name__=='__main__':main()
