"""Reproducible presentation-only texture packing and terrain context. Never writes authorities."""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, zoom
import OpenEXR

PROJECT = Path('C:/Projects/For-Carrot-and-Honour')
WORKSPACE = Path('C:/Projects/FCAH_ASTRA_WORKSPACE')
SETS = ['Grass001','sparse_grass','withered_grass','dirt_aerial_03','sand_03','aerial_rocks_02','rock_05','aerial_grass_rock']

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def mip_chain(pixels, kind):
    """Colour averages in linear light; normals average as signed vectors."""
    data = pixels.astype(np.float32) / 255
    if kind == 'colour':
        data = np.where(data <= .04045, data/12.92, ((data+.055)/1.055)**2.4)
    else:
        data[:, :, :3] = data[:, :, :3] * 2 - 1
    chunks = []
    while True:
        if kind == 'colour':
            encoded = np.where(data <= .0031308, data*12.92, 1.055*np.maximum(data,0)**(1/2.4)-.055)
        else:
            encoded = data.copy()
            vec = encoded[:, :, :3]
            vec /= np.maximum(np.linalg.norm(vec, axis=2, keepdims=True), 1e-6)
            encoded[:, :, :3] = vec * .5 + .5
        chunks.append(np.rint(np.clip(encoded,0,1)*255).astype(np.uint8).tobytes())
        if data.shape[0] == 1:
            break
        data = (data[::2,::2]+data[1::2,::2]+data[::2,1::2]+data[1::2,1::2])*.25
    return b''.join(chunks)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    dest = args.output.resolve()
    if dest == PROJECT or 'source' in dest.parts or 'terrain_data' in dest.parts:
        raise ValueError('Only a separate art-derived output directory is allowed')
    dest.mkdir(parents=True, exist_ok=True)
    records = []
    for index, name in enumerate(SETS):
        folder = PROJECT / 'assets/world_map/terrain_materials' / name
        files = sorted(folder.glob('*.png'))
        albedo = next(p for p in files if '_Color' in p.name or '_diff_' in p.name)
        normal = next(p for p in files if 'NormalGL' in p.name or '_nor_gl_' in p.name)
        rough = next(p for p in files if 'Roughness' in p.name or '_rough_' in p.name)
        n = np.asarray(Image.open(normal).convert('RGB'))
        r_img = Image.open(rough)
        r = np.asarray(r_img)
        if r.ndim == 3:
            r = r[:, :, 0]
        if r.dtype.itemsize > 1:
            r = np.rint(r.astype(np.float32) / 257).astype(np.uint8)
        assert n.shape == (2048, 2048, 3) and r.shape == (2048, 2048)
        packed = np.dstack((n, r))
        packed_path = dest / f'{name}_normal_roughness.png'
        Image.fromarray(packed).save(packed_path)
        assert np.array_equal(np.asarray(Image.open(packed_path)), packed)
        diffuse_pixels = np.asarray(Image.open(albedo).convert('RGB'))
        (dest / f'{name}_albedo_mips.bin').write_bytes(mip_chain(diffuse_pixels, 'colour'))
        (dest / f'{name}_normal_roughness_mips.bin').write_bytes(mip_chain(packed, 'normal'))
        records.append(dict(name=name, layer=index, albedo='res://' + albedo.relative_to(PROJECT).as_posix(),
            intermediate_normal_roughness=f'{name}_normal_roughness.png',
            production_albedo=f'res://assets/world_map/terrain_materials/art_preview/layers/albedo_srgb_{index}.res',
            production_normal_roughness=f'res://assets/world_map/terrain_materials/art_preview/layers/normal_roughness_{index}.res',
            sources={p.name: sha(p) for p in [albedo,normal,rough]},
            packed_sha256=sha(packed_path)))

    height_path = WORKSPACE / '08_Final_Terrain/Data/FCAH_Height_Playable_4096x2304_F32.exr'
    assert sha(height_path) == '5a1a895081e2cf24fe1466b2a0cf036b04908afad57dfff01f50b366f63a3dbc'
    with OpenEXR.File(str(height_path)) as exr:
        h = exr.channels()['R'].pixels.astype(np.float32) * 256 - 6.4
    # Only colour support is derived: no height, mask, region or coordinate is written.
    rng = np.random.default_rng(796959858)
    def field(cells):
        small = rng.random((cells, round(cells * 16/9)), dtype=np.float32)
        expanded = zoom(small, (2304/small.shape[0], 4096/small.shape[1]), order=3)
        return np.clip(expanded[:2304,:4096], 0, 1)
    macro = .67 * field(9) + .33 * field(24)
    meso = .55 * field(52) + .3 * field(110) + .15 * field(230)
    valley = h - gaussian_filter(h, 13)
    broad_relief = h - gaussian_filter(h, 48)
    relief = np.clip(.5 + .18 * np.tanh(valley / 2.5) + .16 * np.tanh(broad_relief / 8), 0, 1)
    # Horizon-like local shelter from actual elevations, deliberately restrained.
    shelter = np.clip(np.maximum(-valley, 0) / 30 + np.maximum(-broad_relief, 0) / 80, 0, 1)
    context = np.rint(np.stack([macro,meso,relief,shelter],axis=2)*255).astype(np.uint8)
    context_path = dest / 'surface_context_rgba.png'
    Image.fromarray(context).save(context_path)
    manifest = dict(version=2, description='Presentation context only; linear RGBA, exact playable frame.',
        texture_arrays=dict(albedo='albedo_srgb.tres', normal_roughness='normal_roughness.tres',
            formats=['BC1 sRGB colour','BC3 linear NormalGL RGB / roughness A'], resolution=[2048,2048], mip_levels=12),
        context_channels=['macro variety','meso variety','signed terrain relief','local shelter'],
        height_source_sha256=sha(height_path), context_sha256=sha(context_path),
        size=[4096,2304], seed=796959858, materials=records)
    (dest / 'texture_manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(f'Prepared {len(records)} normal/roughness packs and aligned surface context in {dest}')

if __name__ == '__main__':
    main()
