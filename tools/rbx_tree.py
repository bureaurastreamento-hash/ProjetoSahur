#!/usr/bin/env python3
# Lista a árvore de instâncias de um .rbxm/.rbxl (binário) sem o Studio.
# Uso: python3 tools/rbx_tree.py arquivo.rbxm [profundidade] [max_filhos]
import struct, sys, collections
def lz4_block(src, out_len):
    out = bytearray(); i = 0; n = len(src)
    while i < n:
        token = src[i]; i += 1
        lit = token >> 4
        if lit == 15:
            while True:
                b = src[i]; i += 1; lit += b
                if b != 255: break
        out += src[i:i+lit]; i += lit
        if i >= n: break
        off = src[i] | (src[i+1] << 8); i += 2
        ml = token & 15
        if ml == 15:
            while True:
                b = src[i]; i += 1; ml += b
                if b != 255: break
        ml += 4
        start = len(out) - off
        for k in range(ml): out.append(out[start + k])
    return bytes(out)
def zstd_dec(b):
    from compression import zstd
    return zstd.decompress(b)
def read_chunks(data):
    pos = 32  # header
    while pos < len(data):
        name = data[pos:pos+4]; clen, ulen = struct.unpack_from('<II', data, pos+4); pos += 16
        raw = data[pos:pos+(clen or ulen)]; pos += (clen or ulen)
        if clen:
            raw = zstd_dec(raw) if raw[:4] == b'\x28\xb5\x2f\xfd' else lz4_block(raw, ulen)
        yield name, raw
        if name == b'END\x00': break
def rstr(b, p):
    n = struct.unpack_from('<I', b, p)[0]; return b[p+4:p+4+n].decode('utf8','replace'), p+4+n
def ints(b, p, count):
    raw = b[p:p+4*count]; p += 4*count
    vals = []
    for i in range(count):
        v = (raw[i] << 24) | (raw[count+i] << 16) | (raw[2*count+i] << 8) | raw[3*count+i]
        v = (v >> 1) ^ -(v & 1)
        vals.append(v)
    acc = 0; out = []
    for v in vals: acc += v; out.append(acc)
    return out, p
def parse(path):
    data = open(path,'rb').read()
    classes = {}; inst_class = {}; names = {}; parent = {}
    for name, raw in read_chunks(data):
        if name == b'INST':
            cid = struct.unpack_from('<I', raw, 0)[0]; cname, p = rstr(raw, 4); p += 1
            cnt = struct.unpack_from('<I', raw, p)[0]; p += 4
            refs, p = ints(raw, p, cnt); classes[cid] = (cname, refs)
            for r in refs: inst_class[r] = cname
        elif name == b'PROP':
            cid = struct.unpack_from('<I', raw, 0)[0]; pname, p = rstr(raw, 4); t = raw[p]; p += 1
            if pname == 'Name' and t == 1:
                for r in classes[cid][1]:
                    s, p = rstr(raw, p); names[r] = s
        elif name == b'PRNT':
            cnt = struct.unpack_from('<I', raw, 1)[0]; p = 5
            ch, p = ints(raw, p, cnt); pa, p = ints(raw, p, cnt)
            for c, q in zip(ch, pa): parent[c] = q
    children = collections.defaultdict(list)
    for c, q in parent.items(): children[q].append(c)
    return inst_class, names, children
def dump(path, maxdepth=3, maxkids=25):
    ic, names, ch = parse(path)
    total = len(ic); print(f"== {path} ({total} instâncias)")
    def walk(r, d):
        kids = ch.get(r, [])
        for k in kids[:maxkids]:
            print('  '*d + f"{names.get(k,'?')} [{ic.get(k,'?')}]" + (f" ({len(ch.get(k,[]))} filhos)" if ch.get(k) else ''))
            if d+1 < maxdepth: walk(k, d+1)
        if len(kids) > maxkids: print('  '*d + f"... +{len(kids)-maxkids}")
    walk(-1, 0)
if __name__ == '__main__':
    dump(sys.argv[1], int(sys.argv[2]) if len(sys.argv)>2 else 3, int(sys.argv[3]) if len(sys.argv)>3 else 25)
