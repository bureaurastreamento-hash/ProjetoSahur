#!/usr/bin/env python3
"""Lista SoundIds únicos de um .rbxl/.rbxm (nome, caminho, id) em JSON. Uso: listar_sons.py arquivo saida.json"""
import json, struct, sys, collections
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from rbx_tree import read_chunks, rstr, ints

def main(path, out):
    data = open(path, 'rb').read()
    classes = {}; names = {}; parent = {}; soundids = {}
    for name, raw in read_chunks(data):
        if name == b'INST':
            cid = struct.unpack_from('<I', raw, 0)[0]; cname, p = rstr(raw, 4); p += 1
            cnt = struct.unpack_from('<I', raw, p)[0]; p += 4
            refs, p = ints(raw, p, cnt); classes[cid] = (cname, refs)
        elif name == b'PROP':
            cid = struct.unpack_from('<I', raw, 0)[0]; pname, p = rstr(raw, 4); t = raw[p]; p += 1
            if t == 1 and pname in ('Name', 'SoundId') and cid in classes:
                for r in classes[cid][1]:
                    s, p = rstr(raw, p)
                    if pname == 'Name': names[r] = s
                    elif classes[cid][0] == 'Sound': soundids[r] = s
        elif name == b'PRNT':
            cnt = struct.unpack_from('<I', raw, 1)[0]; p = 5
            ch, p = ints(raw, p, cnt); pa, p = ints(raw, p, cnt)
            for c, q in zip(ch, pa): parent[c] = q
    def full(r):
        parts = []
        while r in parent and r != -1:
            parts.append(names.get(r, '?')); r = parent[r]
        return '/'.join(reversed(parts))
    seen = {}; rows = []
    for r, sid in soundids.items():
        digits = ''.join(ch for ch in sid if ch.isdigit())
        if digits and digits not in seen:
            seen[digits] = True
            rows.append({'id': digits, 'name': names.get(r, '?'), 'path': full(r)})
    rows.sort(key=lambda x: x['path'])
    json.dump(rows, open(out, 'w'), indent=1, ensure_ascii=False)
    print(f'{len(rows)} sons únicos -> {out}')

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
