"""Close the tiny vertical separation between rendered water and original terrain."""
import numpy as np
from scipy import ndimage as nd

def build_banks(out,height,water,signed,stream,features):
    field=np.maximum(-signed,stream)
    corners=[field[:-1,:-1],field[:-1,1:],field[1:,1:],field[1:,:-1]]
    cases=sum((v>0).astype('uint8')*(1<<i) for i,v in enumerate(corners))
    pairs={1:[(3,0)],2:[(0,1)],3:[(3,1)],4:[(1,2)],5:[(3,0),(1,2)],6:[(0,2)],7:[(3,2)],
           8:[(2,3)],9:[(0,2)],10:[(0,1),(2,3)],11:[(1,2)],12:[(1,3)],13:[(0,1)],14:[(3,0)]}
    offsets=np.array([[0,0],[1,0],[1,1],[0,1]],dtype='float32')
    edges=[(0,1),(1,2),(2,3),(3,0)]
    triangles=[]
    def sample(a,p):return nd.map_coordinates(a,[p[:,1],p[:,0]],order=1,mode='nearest')
    dy,dx=np.gradient(field)
    source_wet=(features[:,:,1]>127)|(features[:,:,0]<128)
    lake_near=nd.distance_transform_edt(features[:,:,0]>127)<4
    for case,connections in pairs.items():
        yy,xx=np.where(cases==case)
        if not len(xx):continue
        base=np.stack([xx,yy],axis=-1)
        values=[v[yy,xx] for v in corners]
        for e0,e1 in connections:
            ends=[]
            keep=[]
            for edge in [e0,e1]:
                a,b=edges[edge]
                t=values[a]/(values[a]-values[b])
                xy=base+offsets[a]+(offsets[b]-offsets[a])*t[:,None]
                direction=np.stack([sample(dx,xy),sample(dy,xy)],axis=-1)
                direction/=np.maximum(np.linalg.norm(direction,axis=1)[:,None],.001)
                # At lake mouths a residual contour can cross two connected wet
                # source cells. Such a face is water, never a strip of dry earth.
                wet_both=(sample(source_wet.astype('float32'),xy-direction*.9)>.65)&(sample(source_wet.astype('float32'),xy+direction*.9)>.65)
                keep.append(~(wet_both&(sample(lake_near.astype('float32'),xy)>.5)))
                dry=xy-direction*.07
                wet=xy+direction*.025
                ground=sample(height,dry)
                inland=(sample(features[:,:,2].astype('float32'),xy)>20)|(sample(stream,xy)>-.10)
                level=np.where(inland,sample(water,wet)+.035,-.05)
                low=np.stack([-25000+wet[:,0]*12.20703125,level,-14062.5+wet[:,1]*12.20703125],axis=-1)
                high=np.stack([-25000+dry[:,0]*12.20703125,ground,-14062.5+dry[:,1]*12.20703125],axis=-1)
                ends.append((low,high))
            a,b=ends[0];c,d=ends[1]
            triangles.append(np.stack([a,b,c,b,d,c],axis=1)[keep[0]|keep[1]].astype('<f4'))
    result=np.concatenate(triangles,axis=0)
    (out/'bank_vertices.bin').write_bytes(result.tobytes())
    print('Closed',len(result),'shore/bank segments.',flush=True)
