"""Original sparse cumulus volumes and the sunlight projection of those exact shapes."""
from pathlib import Path
import json
import numpy as np
from scipy.ndimage import map_coordinates, gaussian_filter
from PIL import Image

OUT=Path(__file__).resolve().parents[2]/'assets/world_map/astra/natural_world/atmosphere'
OUT.mkdir(parents=True,exist_ok=True)
NZ,NY,NX=64,64,96
z,y,x=np.meshgrid(np.linspace(-1,1,NZ),np.linspace(-1,1,NY),np.linspace(-1,1,NX),indexing='ij')
sun=np.array([-.353,.788,-.505])

def sample(density,points):
    return map_coordinates(density,[(points[2]+1)*(NZ-1)*.5,(points[1]+1)*(NY-1)*.5,(points[0]+1)*(NX-1)*.5],order=1,mode='constant',cval=0)

def make_volume(variant):
    rng=np.random.default_rng(240909+variant*47)
    volume=np.full_like(x,-1.0)
    if variant==0:
        lobes=[(-.47,-.17,-.13,.38,.52,.45),(-.08,.06,.05,.43,.72,.59),(.39,-.08,-.05,.35,.54,.49)]
    elif variant==1:
        lobes=[(-.52,-.28,.05,.31,.35,.34),(-.20,-.06,-.14,.34,.62,.54),(.19,.04,.1,.39,.75,.56),(.52,-.22,-.07,.29,.42,.39)]
    else:
        lobes=[(-.40,-.08,.18,.36,.64,.47),(-.1,-.19,-.23,.48,.44,.47),(.36,-.15,-.02,.40,.49,.59)]
    for cx,cy,cz,rx,ry,rz in lobes:
        for i in range(5):
            j=rng.normal(0,.105,3) if i else np.zeros(3)
            scale=rng.uniform(.56,.76) if i else 1.0
            ball=np.sqrt(((x-cx-j[0])/(rx*scale))**2+((y-cy-j[1])/(ry*scale))**2+((z-cz-j[2])/(rz*scale))**2)
            volume=np.maximum(volume,1-ball)
    noise=np.zeros_like(x)
    for n,strength in [(6,.35),(13,.18),(29,.09)]:
        grid=rng.random((n,n,n))-.5
        noise+=map_coordinates(grid,[(z+1)*(n-1)*.5,(y+1)*(n-1)*.5,(x+1)*(n-1)*.5],order=3,mode='reflect')*strength
    density=np.clip((volume+noise-.02)*3.6,0,1)*np.clip((y+.68)*12,0,1)
    density=gaussian_filter(density,.30).astype(np.float32)
    light=np.zeros_like(density)
    for t in np.linspace(.03,.9,20):
        light+=sample(density,[x+sun[0]*t*.38,y+sun[1]*t,z+sun[2]*t*.63])*.18
    rgba=np.stack([density,np.exp(-light),np.clip((y+1)*.5,0,1),np.ones_like(y)],axis=-1)
    (OUT/f'cumulus_volume_{variant}.rgba8').write_bytes(np.uint8(np.clip(rgba,0,1)*255).tobytes())
    return density

volumes=[make_volume(i) for i in range(3)]
rng=np.random.default_rng(240909)
period=np.array([7500.,6000.]); clouds=[]
cells=[(0,0),(2,0),(1,1),(4,1),(0,2),(3,2),(2,3),(4,3)]
for index,(i,j) in enumerate(cells):
    pos=np.array([(i+.5)*1500,(j+.5)*1500])+rng.uniform(-260,260,2)
    if index==6:pos=np.array([3300.,4800.])
    dims=np.array([rng.uniform(520,740),rng.uniform(220,275),rng.uniform(340,460)])
    clouds.append({'xz':pos.tolist(),'size':dims.tolist(),'angle':float(rng.uniform(-2.9,2.9)),'variant':index%3})

H,W=1024,1280
zz,xx=np.meshgrid(np.arange(H)/H*period[1],np.arange(W)/W*period[0],indexing='ij')
field=np.zeros((H,W),np.float32)
for c in clouds:
    dx=(xx-c['xz'][0]+period[0]/2)%period[0]-period[0]/2
    dz=(zz-c['xz'][1]+period[1]/2)%period[1]-period[1]/2
    size=np.array(c['size']);ca,sa=np.cos(c['angle']),np.sin(c['angle'])
    region=(abs(dx)<size[0])&(abs(dz)<size[0]);u,v=dx[region],dz[region]
    optical=np.zeros_like(u)
    for fy in np.linspace(-.5,.5,40):
        sx=u+sun[0]/sun[1]*fy*size[1];sz=v+sun[2]/sun[1]*fy*size[1]
        optical+=sample(volumes[c['variant']],[(ca*sx-sa*sz)/size[0]*2,np.full_like(u,fy*2),(sa*sx+ca*sz)/size[2]*2])*.15
    field[region]=np.maximum(field[region],1-np.exp(-optical))
Image.fromarray(np.uint8(np.clip(gaussian_filter(field,1.4,mode='wrap'),0,1)*255)).save(OUT/'cloud_shadow.png')
record={'volume_size':[NX,NY,NZ],'variants':3,'period':period.tolist(),'altitude':325.,'drift':[3.,1.2],'clouds':clouds,
        'licence':'Original procedural work for FCAH; no third-party assets.','seed':240909}
(OUT/'clouds.json').write_text(json.dumps(record,indent=2)+'\n')
print('Generated 3 cloud volumes and 8 sparse compositions with corresponding shadows.')
