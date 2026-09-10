"""Original looping directional wave spectrum, evaluated offline for inexpensive playback."""
from pathlib import Path
import json, zlib
import numpy as np

root=Path(__file__).resolve().parents[2]/'assets/world_map/astra/natural_world/atmosphere'
root.mkdir(parents=True,exist_ok=True)
n=512; frames=64; width=900.; period=24.
rng=np.random.default_rng(820091)
k=np.fft.fftfreq(n,d=width/n)*2*np.pi
kz,kx=np.meshgrid(k,k,indexing='ij')
m=np.maximum(np.hypot(kx,kz),1e-5)
direction=(kx*.85-kz*.527)/m
power=np.exp(-(.065/m)**2)*np.exp(-(m/.46)**2)/m**3
power*=.10+np.abs(direction)**12
power[0,0]=0
spectrum=np.fft.fft2(rng.standard_normal((n,n)))*np.sqrt(power)
test_x=np.fft.ifft2(spectrum*1j*kx).real
test_z=np.fft.ifft2(spectrum*1j*kz).real
spectrum*=.20/np.sqrt(np.mean(test_x**2+test_z**2))
omega=np.round(np.sqrt(9.81*m)*.72/(2*np.pi/period))*(2*np.pi/period)*np.sign(direction)
all_frames=[]
for frame in range(frames):
    evolving=spectrum*np.exp(-1j*omega*frame/frames*period)
    gx=np.fft.ifft2(evolving*1j*kx).real
    gz=np.fft.ifft2(evolving*1j*kz).real
    height=np.fft.ifft2(evolving).real
    curvature=np.fft.ifft2(evolving*m*m).real
    rgba=np.stack([gx/.9+.5,gz/.9+.5,height/8+.5,curvature/1.2+.5],axis=-1)
    all_frames.append(np.uint8(np.clip(rgba,0,1)*255))
raw=np.stack(all_frames).tobytes()
(root/'ocean_spectrum.deflate').write_bytes(zlib.compress(raw,6))
(root/'ocean_spectrum.json').write_text(json.dumps({'size':[n,n,frames],'bytes':len(raw),'period':period,'world_width':width,'seed':820091,'licence':'Original procedural FCAH wave spectrum; no external assets.'},indent=2)+'\n')
print('Ocean spectrum:',len(raw),'bytes,',len(zlib.compress(raw,6)),'compressed.')
