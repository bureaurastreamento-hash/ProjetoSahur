"""Converte OBJs CC0 já verificados em GLB; baixa três trilhas CC0 oficiais.
Só processa dados, sem executar código dos packs. Inventário inclui hashes e origem.
"""
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import subprocess
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "asset_library/para_importar"

def model(path):
    colors = {}
    material = "default"
    for line in path.with_suffix(".mtl").read_text().splitlines():
        if line.startswith("newmtl "): material = line.split()[1]
        if line.startswith("Kd "): colors[material] = list(map(float, line.split()[1:4])) + [1]
    vertices, groups, uvs = [], {}, []
    for line in path.read_text().splitlines():
        if line.startswith("v "): vertices.append(list(map(float, line.split()[1:4])))
        elif line.startswith("vt "): uvs.append(list(map(float, line.split()[1:3])))
        elif line.startswith("usemtl "): material = line.split()[1]
        elif line.startswith("f "):
            indices = [int(v.split("/")[0]) for v in line.split()[1:]]
            face = [vertices[v - 1 if v > 0 else len(vertices) + v] for v in indices]
            for i in range(1, len(face) - 1): groups.setdefault(material, []).append(([face[0], face[i], face[i+1]], [[uvs[int(indices_uv.split("/")[1])-1][0], 1-uvs[int(indices_uv.split("/")[1])-1][1]] for indices_uv in [line.split()[1], line.split()[i+1], line.split()[i+2]]] if uvs else None))
    gltf = {"asset": {"version": "2.0", "generator": "FX CC0 data converter"}, "scene": 0,
            "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0, "name": path.stem}], "meshes": [{"primitives": []}],
            "materials": [], "bufferViews": [], "accessors": []}
    data = bytearray()
    def accessor(values, kind):
        while len(data) % 4: data.append(0)
        offset = len(data)
        for row in values: data.extend(struct.pack("<" + "f"*len(row), *row))
        view = len(gltf["bufferViews"])
        gltf["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(data)-offset, "target": 34962})
        index = len(gltf["accessors"])
        item = {"bufferView": view, "componentType": 5126, "count": len(values), "type": "VEC2" if kind == "uv" else "VEC3"}
        if kind == "position":
            item["min"] = [min(v[i] for v in values) for i in range(3)]
            item["max"] = [max(v[i] for v in values) for i in range(3)]
        gltf["accessors"].append(item)
        return index
    for material, triangles in groups.items():
        positions, normals = [], []
        texcoords = []
        for triangle, triangle_uv in triangles:
            if triangle_uv: texcoords += triangle_uv
            a,b,c = triangle
            u,v = [b[i]-a[i] for i in range(3)], [c[i]-a[i] for i in range(3)]
            normal = [u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            length = math.sqrt(sum(n*n for n in normal)) or 1
            normal = [n/length for n in normal]
            positions += [[p*10 for p in row] for row in triangle]
            normals += [normal]*3
        index = len(gltf["materials"])
        gltf["materials"].append({"name": material, "pbrMetallicRoughness": {"baseColorFactor": colors.get(material,[.6,.6,.6,1]), "metallicFactor": 0, "roughnessFactor": .9}})
        primitive = {"attributes": {"POSITION": accessor(positions,"position"), "NORMAL": accessor(normals,"normal")}, "material": index, "mode": 4}
        if texcoords: primitive["attributes"]["TEXCOORD_0"] = accessor(texcoords, "uv")
        gltf["meshes"][0]["primitives"].append(primitive)
    gltf["buffers"] = [{"byteLength": len(data)}]
    encoded = json.dumps(gltf,separators=(",", ":")).encode()
    encoded += b" "*((-len(encoded))%4)
    data += b"\0"*((-len(data))%4)
    result = struct.pack("<III",0x46546c67,2,12+8+len(encoded)+8+len(data))+struct.pack("<II",len(encoded),0x4e4f534a)+encoded+struct.pack("<II",len(data),0x004e4942)+data
    output = path.with_suffix(".glb"); output.write_bytes(result)
    assert struct.unpack_from("<I",result,8)[0] == len(result)
    return output

def download(url):
    if not url.startswith("https://opengameart.org/sites/default/files/"): raise ValueError("Origem não permitida")
    with urllib.request.urlopen(urllib.request.Request(url,headers={"User-Agent":"BizarreAssets/1"}),timeout=60) as response:
        if not response.url.startswith("https://opengameart.org/"): raise ValueError("Redirect inesperado")
        data = response.read(40_000_001)
    if len(data)>40_000_000: raise ValueError("Arquivo grande demais")
    return data

def main():
    files = []
    for path in sorted((DEST/"modelos").rglob("*.obj")):
        output = model(path)
        files.append({"path": str(output.relative_to(ROOT)), "sourceFile": str(path.relative_to(ROOT)), "license": "CC0", "provider": "Kenney", "sha256": hashlib.sha256(output.read_bytes()).hexdigest()})
    music = DEST/"musicas";music.mkdir(exist_ok=True)
    town = download("https://opengameart.org/sites/default/files/JRPG%20Music%20Pack%20%232%20%5BTowns%5D%20by%20Juhani%20Junkala.zip")
    with zipfile.ZipFile(io.BytesIO(town)) as archive:
        for entry in archive.infolist():
            if entry.file_size>35_000_000 or entry.is_dir(): continue
            if "home town" in entry.filename.lower() and entry.filename.lower().endswith((".wav",".ogg",".mp3")):
                (music/"Village_source.ogg").write_bytes(archive.read(entry)); break
        else: raise ValueError("Hometown ausente: " + str(archive.namelist()))
    (music/"Boss_source.wav").write_bytes(download("https://opengameart.org/sites/default/files/Juhani%20Junkala%20-%20Epic%20Boss%20Battle%20%5BSeamlessly%20Looping%5D.wav"))
    (music/"Sea_source.mp3").write_bytes(download("https://opengameart.org/sites/default/files/deep_sea.mp3"))
    for name,author,source in [("Village","Juhani Junkala","https://opengameart.org/content/jrpg-pack-2-towns"),("Boss","Juhani Junkala","https://opengameart.org/content/boss-battle-music"),("Sea","Umplix","https://opengameart.org/content/deep-sea")]:
        original = next(music.glob(name+"_source.*")); output=music/(name+".ogg")
        subprocess.run(["ffmpeg","-v","error","-nostdin","-y","-i",str(original),"-af","loudnorm=I=-18:TP=-2:LRA=11","-c:a","libvorbis","-q:a","4",str(output)],check=True,timeout=60)
        subprocess.run(["ffmpeg","-v","error","-nostdin","-i",str(output),"-f","null","-"],check=True,timeout=30)
        files.append({"path":str(output.relative_to(ROOT)),"author":author,"source":source,"license":"CC0","sha256":hashlib.sha256(output.read_bytes()).hexdigest()})
    (ROOT/"ASSETS_CC0_EXTRAS.json").write_text(json.dumps({"files":files},indent=2)+"\n")
    print("Preparados",len(files),"assets adicionais (GLB e trilhas), sem scripts externos.")

if __name__ == "__main__": main()
