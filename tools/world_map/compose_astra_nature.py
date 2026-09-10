"""Art-directed districts, woodland shapes and shoreline compositions; source data is read-only."""
import numpy as np
from scipy import ndimage as nd
from PIL import Image
import json

SPACING=12.20703125
ORIGIN=np.array([-25000.,-14062.5])
DISTRICTS=[
    ('beech_downs',-3100,-2300,2100,1300,'woodland'),
    ('western_watermeadows',-5100,-1350,1600,2100,'wetland'),
    ('central_green_vales',1100,-3200,2700,1500,'woodland'),
    ('sunlit_downs',-2200,300,2000,1500,'meadow'),
    ('western_wind_heath',-9500,-3700,2100,1100,'heath'),
    ('parmetos_groves',-15800,2500,2400,1600,'olive'),
    ('southern_olive_country',-12100,4650,2400,1400,'olive'),
    ('chalk_coast',-18200,3600,1700,2000,'chalk'),
    ('central_stony_march',6400,300,2300,1900,'rocky'),
    ('northern_pine_vales',3200,-7800,2700,1800,'boreal'),
    ('northern_silver_heath',6700,-9650,2200,1200,'heath'),
    ('waring_pine_shores',12970,-4770,2300,2100,'boreal'),
    ('eastern_copper_foothills',11700,2100,2200,1600,'gravel'),
    ('amber_sands',10800,4700,2400,1700,'sand'),
    ('southeastern_wind_stones',12500,6100,1800,1900,'gravel'),
    ('southern_dry_vales',9900,8050,2600,1400,'scrub'),
]

def compose(out,height,features,environment,materials,signed,coverage,slope,broad,fine):
    rng=np.random.default_rng(796959858+2026)
    shape=height.shape
    yy,xx=np.mgrid[:shape[0],:shape[1]].astype('float32')
    wx=ORIGIN[0]+xx*SPACING; wz=ORIGIN[1]+yy*SPACING
    family=np.zeros(shape,dtype='uint8'); district_strength=np.zeros(shape,dtype='float32')
    forest=np.clip((broad-.40)*2.5,0,1).astype('float32')
    wooded=np.zeros(shape,dtype='float32'); stones=np.zeros(shape,dtype='float32')
    for number,(_,cx,cz,rx,rz,motif) in enumerate(DISTRICTS):
        weight=np.exp(-(((wx-cx)/rx)**2+((wz-cz)/rz)**2)*1.3).astype('float32')
        take=weight>district_strength
        family[take]=number; district_strength=np.maximum(district_strength,weight)
        if motif in ('woodland','boreal','wetland'): wooded=np.maximum(wooded,weight)
        if motif in ('rocky','chalk','gravel','heath'): stones=np.maximum(stones,weight)
    river=features[:,:,1]>127
    river_dist=nd.distance_transform_edt(~river)
    lake_dist=nd.distance_transform_edt(features[:,:,2]<8)
    # Curving belts, broad groves and glades; not a field of equally spaced centres.
    forest=np.clip(forest*.62+wooded*.43+np.exp(-river_dist/8)*.30,0,1)
    forest*=np.clip(environment[:,:,1]*1.6+.22,0,1)*(1-materials[:,:,2]*.82)*(1-materials[:,:,3]*.85)
    forest*=np.clip(1-slope*5,0,1)
    coast_exposure=1-nd.gaussian_filter((features[:,:,0]>127).astype('float32'),30)
    coast_type=np.clip(broad*.64+coast_exposure*.5+stones*.48+environment[:,:,0]*.38+slope*4-.22,0,1)
    character=np.stack([forest,wooded,stones,coast_type],axis=-1)
    Image.fromarray(np.rint(character*255).astype('uint8')).save(out/'landscape_character_rgba.png')
    props=[]; used=set(); tree_density=np.zeros(shape,dtype='float32')
    def at(a,x,y): return float(nd.map_coordinates(a,[[y],[x]],order=1,mode='nearest')[0])
    def add(kind,x,y,size,variant=None,rotation=None):
        ix,iy=int(round(x)),int(round(y))
        if not (3<=ix<4092 and 3<=iy<2300): return False
        if signed[iy,ix]<.50 or coverage[iy,ix]>.015 or slope[iy,ix]>.24:return False
        if kind in (0,1,2,6,7,8,9,10,14) and materials[iy,ix,3]>.74:return False
        cell=(int(x*1.4),int(y*1.4))
        if cell in used:return False
        used.add(cell)
        h=at(height,x,y)
        props.append([kind,round(ORIGIN[0]+x*SPACING,4),round(h-.18,4),round(ORIGIN[1]+y*SPACING,4),round(size,3),
          round(float(rng.uniform(0,np.pi*2) if rotation is None else rotation),5),round(float(rng.uniform(.88,1.13)),4),
          int(rng.integers(0,3) if variant is None else variant)])
        if kind in (0,1,2,6,7,8,9,10,14): tree_density[iy,ix]+=size/55
        return True
    for cy in np.arange(8,2297,9):
      for cx in np.arange(8,4089,9):
        x,y=np.array([cx,cy])+rng.uniform(-4.4,4.4,2)
        ix,iy=int(x),int(y)
        if signed[iy,ix]<1 or coverage[iy,ix]>.01:continue
        cold=environment[iy,ix,0]; dry=materials[iy,ix,1]; arid=materials[iy,ix,2]; rock=materials[iy,ix,3]
        motif=DISTRICTS[family[iy,ix]][5]
        density=forest[iy,ix]
        if rock<.48 and arid<.50 and rng.random()<max(0,density-.16)*.66:
            # Groves follow the local contour, with a little variation on flats.
            sy,sx=np.gradient(height[max(0,iy-1):iy+2,max(0,ix-1):ix+2])
            angle=float(np.arctan2(sx[1,1],-sy[1,1])+rng.uniform(-.5,.5)) if slope[iy,ix]>.006 else float(rng.uniform(0,np.pi))
            c,s=np.cos(angle),np.sin(angle)
            for _ in range(int(rng.integers(9,27))):
                a,b=rng.normal(0,[5.3,2.3],2); px=x+a*c-b*s; py=y+a*s+b*c
                if cold>.27 or motif=='boreal':kind=int(rng.choice([1,1,1,6,7]))
                elif dry>.35:kind=int(rng.choice([2,2,7,8,10]))
                else:kind=int(rng.choice([0,0,0,6,2]))
                add(kind,px,py,float(rng.uniform(40,71)))
                if rng.random()<.20:add(3,px+rng.uniform(-2,2),py+rng.uniform(-2,2),float(rng.uniform(9,17)))
        elif dry+arid>.32 and rng.random()<.075:
            for _ in range(int(rng.integers(3,8))):
                px,py=np.array([x,y])+rng.normal(0,2.7,2)
                add(int(rng.choice([3,10,12,11],p=[.47,.20,.28,.05])),px,py,float(rng.uniform(7,17)))
        elif motif in ('heath','meadow') and rng.random()<.055:
            for _ in range(5):
                px,py=np.array([x,y])+rng.normal(0,2.7,2)
                add(12 if cold>.18 else 19,px,py,float(rng.uniform(7,13)))
        # Outcrops occur in seams and groups, not uniformly over every surface.
        if rock>.12 and rng.random()<.07+stones[iy,ix]*.10:
            for _ in range(int(rng.integers(3,7))):
                px,py=np.array([x,y])+rng.normal(0,2.4,2)
                add(5 if dry+arid>.5 else 4,px,py,float(rng.uniform(10,30)))
        # Coastal and riparian compositions at source-valid land anchors.
        if signed[iy,ix]<5 and rng.random()<.58:
            rocky=coast_type[iy,ix]>.46
            for _ in range(int(rng.integers(3,8))):
                px,py=np.array([x,y])+rng.normal(0,2.0,2)
                add((5 if dry+arid>.5 else 4) if rocky else 13,px,py,float(rng.uniform(13,40) if rocky else rng.uniform(7,14)))
        if 1<river_dist[iy,ix]<5 and rng.random()<.62:
            for _ in range(int(rng.integers(3,7))):
                px,py=np.array([x,y])+rng.normal(0,1.6,2)
                add(13 if rng.random()<.7 else (9 if arid>.44 else 6),px,py,float(rng.uniform(7,14) if rng.random()<.65 else rng.uniform(27,46)))
        if 1<lake_dist[iy,ix]<7 and 1<signed[iy,ix]<8 and arid<.5 and rng.random()<.22:
            # A few sheltered woodland pockets and reed beds, with open shores between.
            for _ in range(7):
                px,py=np.array([x,y])+rng.normal(0,[3.6,1.9],2)
                add((1 if cold>.27 else (2 if dry>.35 else 6)),px,py,float(rng.uniform(32,55)))
            for _ in range(5):
                px,py=np.array([x,y])+rng.normal(0,2.8,2)
                add(13,px,py,float(rng.uniform(8,15)))
    # Stone pavements and low outcrops punctuate dry gravel districts, including
    # flat ground. Their own random stream leaves the woodland composition stable.
    gravel_rng=np.random.default_rng(796959858+731)
    for cy in range(8,2297,12):
        for cx in range(8,4089,12):
            if materials[cy,cx,2]<.5 or stones[cy,cx]<.60 or fine[cy,cx]<.54:continue
            if gravel_rng.random()>.09:continue
            for _ in range(int(gravel_rng.integers(3,6))):
                px,py=np.array([cx,cy])+gravel_rng.normal(0,[3.5,1.6],2)
                add(5,px,py,float(gravel_rng.uniform(8,24)))
    # A handful of deliberately composed discoveries, anchored in appropriate geography.
    landmarks=[]
    def find_anchor(tx,tz,condition,radius=1300):
        score=(wx-tx)**2+(wz-tz)**2
        valid=condition&(signed>3)&(coverage<.01)&(slope<.12)&(score<radius**2)
        if not valid.any():return None
        score=np.where(valid,score,np.inf); iy,ix=np.unravel_index(score.argmin(),shape)
        return float(ix),float(iy)
    specs=[('elder_beech',-2800,-2250,'elder',materials[:,:,0]>.50),
      ('seven_sisters',-5500,-1350,'stacks',(signed<8)&(materials[:,:,0]>.35)),
      ('parmetos_silent_arch',-16100,2650,'arch',(signed<12)&(materials[:,:,2]<.4)),
      ('heather_stones',4400,-8100,'stones',environment[:,:,0]>.2),
      ('amber_spring',12000,6700,'oasis',(materials[:,:,2]>.48)&(river_dist<8)),
      ('waring_silver_grove',12800,-4800,'silver',(signed<14)&(materials[:,:,3]<.50)),
      ('copper_wind_arch',14000,5400,'wind_arch',materials[:,:,2]>.5)]
    for name,tx,tz,motif,condition in specs:
        point=find_anchor(tx,tz,condition,2100)
        if point is None:continue
        x,y=point
        if motif=='elder':
            # Give this old tree a clearing; it should be discovered while panning.
            props[:]=[p for p in props if p[0] not in (0,1,2,6,7,8,10) or np.hypot(p[1]-(ORIGIN[0]+x*SPACING),p[3]-(ORIGIN[1]+y*SPACING))>90]
            add(14,x,y,110,2)
            for a in np.linspace(0,2*np.pi,14,endpoint=False): add(19,x+np.cos(a)*5,y+np.sin(a)*4,12)
        elif motif in ('stacks','stones'):
            for i in range(7):
                px,py=(x+(i-3)*3.8,y+np.sin(i)*2) if motif=='stacks' else (x+np.cos(i*5.7/7)*6.2,y+np.sin(i*5.7/7)*4.5)
                add(17 if motif=='stacks' else 15,px,py,float(35+22*np.sin(i*.6)**2),i%3)
        elif motif in ('arch','wind_arch'):
            add(16,x,y,68,1 if motif=='arch' else 2,rotation=.15)
            for _ in range(12):add(4 if motif=='arch' else 5,x+rng.normal(0,5),y+rng.normal(0,3),float(rng.uniform(8,21)))
            if motif=='arch':
                for _ in range(6):add(3,x+rng.normal(0,3),y+rng.normal(0,2),float(rng.uniform(6,11)))
        elif motif=='oasis':
            for _ in range(34):add(9 if rng.random()<.75 else 10,x+rng.normal(0,7),y+rng.normal(0,4),float(rng.uniform(30,63)))
        elif motif=='silver':
            for _ in range(35):add(6 if rng.random()<.8 else 1,x+rng.normal(0,7),y+rng.normal(0,4),float(rng.uniform(43,72)))
        landmarks.append({'name':name,'motif':motif,'target':[ORIGIN[0]+x*SPACING,at(height,x,y),ORIGIN[1]+y*SPACING]})
    # Ground beneath actual groves receives a low, soft litter/undergrowth footprint.
    tree_density=np.clip(nd.gaussian_filter(tree_density,2.2)*20,0,1)
    ecology=np.stack([environment[:,:,0],tree_density,environment[:,:,2],fine],axis=-1)
    Image.fromarray(np.rint(np.clip(ecology,0,1)*255).astype('uint8')).save(out/'ecology_rgba.png')
    (out/'natural_districts.json').write_text(json.dumps({'districts':DISTRICTS,'landmarks':landmarks},indent=2)+'\n',newline='\n')
    print('Composed',len(props),'natural instances and',len(landmarks),'discoveries.',flush=True)
    return props
