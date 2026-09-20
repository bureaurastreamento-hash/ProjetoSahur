#!/usr/bin/env python3
"""comparar_extras.py <dump.txt> — compara as BaseParts de Workspace.Sahur.ArenaExtras no Studio (dump do mesmo
trecho de tools/sincronizar_arena.luau, trocando Arena por ArenaExtras) com src/workspace/ArenaExtras.model.json.
Lista o que sobra de cada lado (= o que o dono moveu/redimensionou/apagou/criou no Studio). Só lista: o
ArenaExtras é GERADO por gerar_arena.py, então mudanças de verdade entram lá (ou no rbxm) à mão."""
import json, re, sys, collections
dump = open(sys.argv[1]).read().replace('[OUTPUT]', '')
import math
def r(v): return f"{round(float(v)*10)/10+0:.1f}"
def rotkey(o):
    # Orientation (graus, ordem YXZ do Roblox) -> matriz; chave pelos vetores Look/Up arredondados (ângulos
    # equivalentes como -88 / 272 ou (x,y,z) / (x±180, 180-y, z±180) viram a mesma chave)
    x, y, z = [math.radians(float(a)) for a in o]
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    # R = Ry * Rx * Rz
    m = [[cy*cz + sy*sx*sz, cz*sy*sx - cy*sz, cx*sy], [cx*sz, cx*cz, -sx], [cy*sx*sz - cz*sy, cy*cz*sx + sy*sz, cy*cx]]
    look = (-m[0][2], -m[1][2], -m[2][2]); up = (m[0][1], m[1][1], m[2][1])
    return ','.join(f"{round(v*100)/100+0:.2f}" for v in look + up)
def key(name, p, s, o): return '|'.join([name] + [r(x) for x in p + s] + [rotkey(o)])
studio = collections.Counter()
for line in re.split(r'[;\n]', dump):
    c = line.strip().split(',')
    if len(c) == 10 and re.match(r'-?\d', c[1]):
        studio[key(c[0], c[1:4], c[4:7], c[7:10])] += 1
d = json.load(open('src/workspace/ArenaExtras.model.json'))
file = collections.Counter()
def walk(n, path):
    if n.get('className') in ('Part', 'WedgePart', 'SpawnLocation'):
        p = n.get('properties', {})
        file[key(p.get('Name', n.get('name')), p.get('Position', [0,0,0]), p.get('Size', [4,1.2,2]), p.get('Orientation', [0,0,0]))] += 1
    for c in n.get('children', []): walk(c, path + '/' + c.get('name', ''))
walk(d, 'ArenaExtras')
print(f"Studio: {sum(studio.values())} | arquivo: {sum(file.values())}")
so = studio - file; fo = file - studio
print(f"Sobras: {sum(so.values())} no Studio | {sum(fo.values())} no arquivo")
for k, n in list(so.items()): print("  STUDIO ", k, f"x{n}" if n > 1 else "")
for k, n in list(fo.items()): print("  ARQUIVO", k, f"x{n}" if n > 1 else "")
