extends RefCounted
## Preserve the curated silhouettes and UVs; give their fracture planes crisp normals.

static func faceted(source: ImporterMesh) -> ArrayMesh:
    var result: ArrayMesh = ArrayMesh.new()
    for surface_id: int in range(source.get_surface_count()):
        var arrays: Array = source.get_surface_arrays(surface_id)
        var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
        for level: int in range(source.get_surface_lod_count(surface_id)):
            var candidate: PackedInt32Array = source.get_surface_lod_indices(surface_id,level)
            if candidate.size() >= 540: indices = candidate
        var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
        var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
        var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
        var surface: SurfaceTool = SurfaceTool.new()
        surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        surface.set_material(source.get_surface_material(surface_id))
        for triangle: int in range(0,indices.size(),3):
            var a: int = indices[triangle]
            var b: int = indices[triangle+1]
            var c: int = indices[triangle+2]
            var normal: Vector3 = (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).normalized()
            if normal.dot(normals[a]+normals[b]+normals[c])<0.0: normal = -normal
            for index: int in [a,b,c]:
                surface.set_normal(normal)
                surface.set_uv(uvs[index])
                surface.set_color(colours[index] if not colours.is_empty() else Color.WHITE)
                surface.add_vertex(vertices[index])
        surface.index()
        surface.commit(result)
    return result
