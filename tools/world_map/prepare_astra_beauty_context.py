"""Bounded shore materials and rock composition; source terrain stays read-only."""
from pathlib import Path
import argparse, hashlib, json
import numpy as np
from PIL import Image
from scipy import ndimage as nd
import OpenEXR

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[2])
parser.add_argument('--workspace',type=Path,default=Path('C:/Projects/FCAH_ASTRA_WORKSPACE'))
args=parser.parse_args()
P=args.project.resolve()
W=args.workspace.resolve()
R=P/'assets/world_map/astra/natural_world'
B=W/'06_Astra_Checkpoints/Natural_Beauty_2026-09-09/files/assets/world_map/astra/natural_world'
S=12.20703125; origin=np.array([-25000.,-14062.5]); rng=np.random.default_rng(290991)

def sha(path):
    with path.open('rb') as handle:return hashlib.file_digest(handle,'sha256').hexdigest()

for entry in json.loads((W/'08_Final_Terrain/EXPORT_MANIFEST.json').read_text())['data_files']:
    source=W/'08_Final_Terrain'/entry['path']
    if sha(source)!=entry['sha256']:raise RuntimeError('Authoritative export changed: '+entry['path'])
for name in ('shore_distance.exr','water_features_rgba.png','surface_context_rgba.png',
             'ecology_rgba.png','landscape_character_rgba.png','natural_instances.json','shore_details.json'):
    if sha(R/name)!=sha(B/name):raise RuntimeError('Accepted input changed: '+name)

def image(name):return np.array(Image.open(R/name)).astype(np.float32)/255
with OpenEXR.File(str(W/'08_Final_Terrain/Data/FCAH_Height_Playable_4096x2304_F32.exr')) as f:
    h=f.channels()['R'].pixels.astype(np.float32)*256-6.4
with OpenEXR.File(str(R/'shore_distance.exr')) as f:shore=f.channels()['R'].pixels.astype(np.float32)
hydro=image('water_features_rgba.png'); context=image('surface_context_rgba.png'); eco=image('ecology_rgba.png')
character=image('landscape_character_rgba.png')
finish=np.array(Image.open(B/'shore_finish_rgba.png')).astype(np.float32)/255
wet=(shore<0)|((hydro[:,:,0]>=.5)&(hydro[:,:,1]>.01))
signed=nd.distance_transform_edt(~wet)-nd.distance_transform_edt(wet)
appearance=np.clip(nd.gaussian_filter(signed.astype(np.float32),.95),-64,64).astype(np.float16)
OpenEXR.File({'compression':OpenEXR.ZIP_COMPRESSION},{'R':appearance}).write(str(R/'water_edge_style.exr'))
reach=nd.gaussian_filter(context[:,:,0],3)
finish[:,:,0]=np.maximum(finish[:,:,0],np.clip((reach-.38)*3,0,.8)*(1-eco[:,:,0]*.5))
finish[:,:,1]=np.maximum(finish[:,:,1],np.clip((context[:,:,1]-.36)*3,0,.85)*(1-eco[:,:,1]*.6))
finish[:,:,3]=np.maximum(finish[:,:,3],character[:,:,3]*np.clip((reach-.30)*3,0,1)*.75)
finish[:,:,2]=np.maximum(finish[:,:,2],np.exp(-np.maximum(signed,0)/7)*np.clip((reach-.51)*5,0,1)*(1-eco[:,:,0])*.55)

def stamp(channel,wx,wz,rx,rz,amount):
    px,pz=(np.array([wx,wz])-origin)/S
    x0,x1=max(0,int(px-rx*2.5)),min(4096,int(px+rx*2.5)+1)
    z0,z1=max(0,int(pz-rz*2.5)),min(2304,int(pz+rz*2.5)+1)
    zz,xx=np.mgrid[z0:z1,x0:x1]
    patch=np.exp(-(((xx-px)/rx)**2+((zz-pz)/rz)**2)*1.2)*amount
    finish[z0:z1,x0:x1,channel]=np.maximum(finish[z0:z1,x0:x1,channel],patch)

for x,z in [(11690,6020),(11890,6450),(9587,8487)]:
    stamp(2,x,z,14,11,.96)
    stamp(0,x,z,11,9,.92)
    stamp(1,x+70,z+25,7,5,.85)

def sample(a,x,z):
    q=(np.array([x,z])-origin)/S
    return float(nd.map_coordinates(a,[[q[1]],[q[0]]],order=1,mode='nearest')[0])

# Replace a fraction of repetitive isolated stones with broad, buried silhouettes.
original=json.loads((B/'natural_instances.json').read_text())['instances']
supplement=json.loads((B/'shore_details.json').read_text())
overrides={}; omitted=[]
for index,entry in enumerate(original+supplement['instances']):
    kind,x,y,z,size,yaw,value,variant=entry
    if kind not in (4,5,17):continue
    d=sample(signed,x,z)
    if d>13 and size<15 and index%4==0:
        omitted.append(index)
        continue
    # Strata rest within the surface rather than sitting as equal upright nuggets.
    ratio=[float(rng.uniform(1.06,1.34)),float(rng.uniform(.65,.91)),float(rng.uniform(.90,1.18))]
    if kind==17:ratio=[1.0,.90,1.0]
    burial=min(size*.12,2.8) if d<4 else min(size*.08,2.0)
    overrides[str(index)]={'scale':ratio,'burial':burial}

# Short exposed shelves extend into existing sea. Each stone is bed-anchored.
# These are selected compositions, not a coastline-wide scatter rule.
sites=[('northern_cove',380,-7060),('northern_headland',-80,-6840),
       ('western_reef',-6030,-1420),('western_stacks',-3980,-6370),
       ('sheltered_outer_rocks',-3300,2150),('eastern_rock_coast',14005,-1490)]
new=[]; anchors=[]; wakes=[]
for name,wx,wz in sites:
    px,pz=(np.array([wx,wz])-origin)/S
    x0,x1=max(3,int(px-25)),min(4093,int(px+25))
    z0,z1=max(3,int(pz-25)),min(2301,int(pz+25))
    zz,xx=np.mgrid[z0:z1,x0:x1]
    valid=(shore[z0:z1,x0:x1]<-.7)&(shore[z0:z1,x0:x1]>-3.0)&(h[z0:z1,x0:x1]>-5.7)&(hydro[z0:z1,x0:x1,2]<.1)
    if not valid.any():continue
    score=(xx-px)**2+(zz-pz)**2
    k=np.argmin(np.where(valid,score,np.inf)); az,ax=np.unravel_index(k,valid.shape); ax+=x0;az+=z0
    gz,gx=np.gradient(shore[az-1:az+2,ax-1:ax+2]); normal=np.array([gx[1,1],gz[1,1]])
    normal/=max(np.linalg.norm(normal),.001); tangent=np.array([-normal[1],normal[0]])
    base=origin+np.array([ax,az])*S
    for i,offset in enumerate([-54,-32,-14,11,24,64]):
        pos=base+tangent*offset+normal*[-10,-4,-15,14,1,-6][i]
        d=sample(shore,*pos)
        if not -4.5<d<.4:continue
        bed=sample(h,*pos); size=float([14,33,25,39,18,9][i])*rng.uniform(.92,1.10)
        if bed>1.0 or bed<-size*.40:continue
        new.append([4,float(pos[0]),bed-size*.10,float(pos[1]),size,float(np.arctan2(tangent[0],tangent[1])+rng.uniform(-.5,.5)),float(rng.uniform(.90,1.06)),i%3])
        anchors.append({'index':len(new)-1,'site':name,'bed_height':bed,'burial':size*.10,'water_level':-.05})
        index=len(original)+len(supplement['instances'])+len(new)-1
        overrides[str(index)]={'scale':[1.22,.92 if i==3 else .73,1.05],'burial':0.0}
        if i in (1,3,5):
            wakes.append({'x':float(pos[0]),'z':float(pos[1]),'y':.14,'flow':(-normal).tolist(),'slope':[0,0], 'width':size*4.2,'length':size*6,'strength':.78,'river':False})
    stamp(3,*base,14,10,1.0)
    stamp(1,*base,10,8,.9)

Image.fromarray(np.uint8(np.clip(finish,0,1)*255)).save(R/'shore_finish_rgba.png')
record={'seed':290991,'instances':new,'anchors':anchors,'wakes':wakes,'rock_overrides':overrides,'omitted':omitted,'sites':[s[0] for s in sites],
        'authority':'Presentation-only rock transforms, additions and shore materials. Original heights, river routes and source masks are unchanged.'}
(R/'beauty_composition.json').write_text(json.dumps(record,separators=(',',':'))+'\n')
print('Bounded shore fields;',len(new),'shelf rocks;',len(omitted),'isolated stones removed;',len(overrides),'rock silhouette adjustments.')
