#!/usr/bin/env python3
"""
Converts PvZ compiled reanim files (Debug/compiled/reanim/*.reanim.compiled)
into JSON that the GameMaker reanim player (scr_reanim) loads at runtime.

File layout (from Sexy.TodLib/Definition.cpp, DefinitionReadCompiledFile):
  u32 cookie 0xDEADFED4, u32 uncompressedSize, zlib stream.
  Inside: u32 schemaHash, ReanimatorDefinition struct (16 bytes: tracksPtr,
  trackCount, fps, atlasPtr), then DefMapReadFromCache for each field:
    array "track": i32 defSize(12), trackCount*12 raw bytes, then per track:
        string name (i32 len + bytes)
        array "t": i32 defSize(44), count*44 raw bytes, then per transform:
            image name, font name, text (each i32 len + bytes)
  Transform raw struct (44 bytes): x y kx ky sx sy f a (floats), imgPtr, fontPtr, textPtr
  A float equal to -10000 means "not set, inherit previous value"
  (ReanimationLoadDefinition in Reanimator.cpp fills these in).
"""
import sys, os, json, struct, zlib, re
import xml.etree.ElementTree as ET

PLACEHOLDER = -10000.0

def build_image_map(resources_xml):
    """IMAGE id -> relative file path (no extension) using SetDefaults semantics."""
    m = {}
    path = ""; prefix = ""
    root = ET.parse(resources_xml).getroot()
    for res in root.iter():
        if res.tag == "SetDefaults":
            path = res.get("path", path); prefix = res.get("idprefix", prefix)
        elif res.tag == "Image":
            rid = prefix + res.get("id")
            m[rid] = (path + "/" + res.get("path")).replace("\\", "/")
        elif res.tag == "Resources":
            path = ""; prefix = ""
    return m

class R:
    def __init__(s, b): s.b = b; s.p = 0
    def u32(s): v = struct.unpack_from('<I', s.b, s.p)[0]; s.p += 4; return v
    def i32(s): v = struct.unpack_from('<i', s.b, s.p)[0]; s.p += 4; return v
    def raw(s, n): v = s.b[s.p:s.p+n]; s.p += n; return v
    def string(s):
        n = s.i32(); assert 0 <= n <= 100000
        return s.raw(n).decode('latin-1')

def parse(path):
    d = open(path, 'rb').read()
    cookie, usize = struct.unpack_from('<II', d, 0)
    assert cookie == 0xDEADFED4, "bad cookie"
    u = zlib.decompress(d[8:])
    assert len(u) == usize
    r = R(u)
    r.u32()  # schema hash
    _tp, track_count, fps, _atlas = struct.unpack('<IifI', r.raw(16))
    assert r.i32() == 12
    track_raw = [struct.unpack('<IiI', r.raw(12)) for _ in range(track_count)]
    tracks = []
    for (_n, _t, tcount) in track_raw:
        pass
    # NOTE: track struct = {char* name, Transform* t, int count}; count is at +8.
    for (_np, _tp2, tcount) in track_raw:
        name = r.string()
        assert r.i32() == 44
        raws = [struct.unpack('<8fIII', r.raw(44)) for _ in range(tcount)] if tcount else []
        # arrays with count 0 return before reading data (DefReadFromCacheArray)
        trans = []
        for t in raws:
            img = r.string(); font = r.string(); text = r.string()
            trans.append((t[:8], img, font, text))
        tracks.append((name, trans))
    assert r.p == len(u), f"trailing bytes {len(u)-r.p}"
    return fps, tracks

def build_file_index(debug):
    """case-insensitive index: (subdir, lowername-without-ext) -> real relative path.
    Mirrors gDefLoadResPaths in Definition.cpp: prefixes IMAGE_ / IMAGE_REANIM_ with
    search dirs "", particles/, reanim/, images/."""
    idx = {}
    for sub in ("reanim", "images", "particles"):
        d = os.path.join(debug, sub)
        for fn in os.listdir(d):
            stem, ext = os.path.splitext(fn)
            if ext.lower() in (".png", ".jpg", ".gif"):
                idx.setdefault((sub, stem.lower()), sub + "/" + fn)
    return idx

def resolve_image(name, imgmap, fidx):
    """IMAGE_REANIM_PEASHOOTER_HEAD -> 'reanim/PeaShooter_Head.png' (relative to Debug/)."""
    if name in imgmap:
        base = imgmap[name]
        sub, stem = base.split("/", 1)
        hit = fidx.get((sub, stem.lower()))
        if hit: return hit
    for prefix, subs in (("IMAGE_REANIM_", ("reanim", "images")), ("IMAGE_", ("particles", "images", "reanim"))):
        if name.startswith(prefix):
            rest = name[len(prefix):].lower()
            for sub in subs:
                hit = fidx.get((sub, rest))
                if hit: return hit
    return ""

def safe_path(p):
    return p.replace(" ", "_")

def convert(path, imgmap, fidx=None):
    """Compact JSON: {"fps", "imgs":[paths], "texts":[...], "tracks":[{"name","t":[[x,y,kx,ky,sx,sy,f,a,img,txt],...]}]}
    img/txt are indices into imgs/texts (-1 = none). Missing values are already filled in from
    the previous frame, exactly like ReanimationLoadDefinition does."""
    fps, tracks = parse(path)
    imgs, texts = [], []
    out = {"fps": fps, "imgs": imgs, "texts": texts, "tracks": []}
    for name, trans in tracks:
        px, py, kx, ky, sx, sy, f, a = 0, 0, 0, 0, 1, 1, 0, 1
        img = ""; text = ""
        frames = []
        for vals, im, font, tx in trans:
            v = list(vals)
            def pick(i, prev):
                return prev if v[i] == PLACEHOLDER else v[i]
            px = pick(0, px); py = pick(1, py); kx = pick(2, kx); ky = pick(3, ky)
            sx = pick(4, sx); sy = pick(5, sy); f = pick(6, f); a = pick(7, a)
            if im: img = im
            if tx: text = tx
            ii = -1
            if img:
                rp = resolve_image(img, imgmap, fidx)
                if rp:
                    rp = safe_path(rp)
                    if rp not in imgs: imgs.append(rp)
                    ii = imgs.index(rp)
            ti = -1
            if text:
                if text not in texts: texts.append(text)
                ti = texts.index(text)
            frames.append([round(px, 3), round(py, 3), round(kx, 3), round(ky, 3),
                           round(sx, 4), round(sy, 4), int(f), round(a, 3), ii, ti])
        out["tracks"].append({"name": name, "t": frames})
    return out

if __name__ == "__main__":
    import shutil
    repo, project = sys.argv[1], sys.argv[2]
    debug = os.path.join(repo, "Debug")
    imgmap = build_image_map(os.path.join(debug, "properties/resources.xml"))
    fidx = build_file_index(debug)
    src = os.path.join(debug, "compiled/reanim")
    out_json = os.path.join(project, "datafiles/reanim")
    out_parts = os.path.join(project, "datafiles/parts")
    os.makedirs(out_json, exist_ok=True)
    ok = bad = 0; used = set(); names = []
    for fn in sorted(os.listdir(src)):
        if not fn.endswith(".reanim.compiled"): continue
        try:
            j = convert(os.path.join(src, fn), imgmap, fidx)
        except Exception as e:
            bad += 1; print("FAIL", fn, e); continue
        name = fn[:-len(".reanim.compiled")]
        json.dump(j, open(os.path.join(out_json, name + ".json"), "w"), separators=(",", ":"))
        used.update(j["imgs"]); names.append(name); ok += 1
    json.dump(names, open(os.path.join(out_json, "_index.json"), "w"))
    n = 0
    for p in sorted(used):
        real = None
        # p is the sanitized path; find the original (with spaces)
        cand = os.path.join(debug, p)
        if not os.path.exists(cand): cand = os.path.join(debug, p.replace("_", " "))
        if not os.path.exists(cand):
            d, b = os.path.split(os.path.join(debug, p))
            lo = {x.lower().replace(" ", "_"): x for x in os.listdir(d)}
            cand = os.path.join(d, lo[b.lower()])
        dst = os.path.join(out_parts, p)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(cand, dst); n += 1
    print(f"reanims converted: {ok}, failed: {bad}, part images copied: {n}")
