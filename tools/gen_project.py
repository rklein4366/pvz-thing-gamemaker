#!/usr/bin/env python3
"""Writes the GameMaker project files (PvZ.yyp + resource .yy + .gml) around datafiles/.
Usage: gen_project.py <project_dir>      (project_dir already contains datafiles/ and gml_source/)"""
import os, sys, json, shutil

P = sys.argv[1]
SRC = os.path.join(P, "gml_source")
IDE = "2023.11.1.129"

def w(path, text):
    full = os.path.join(P, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", newline="\n") as f:
        f.write(text)

def j(o):  # GameMaker accepts standard JSON (trailing commas optional)
    return json.dumps(o, indent=2)

# ---------- scripts ----------
scripts = ["scr_core", "scr_reanim"]
for s in scripts:
    shutil.copyfile(os.path.join(SRC, s + ".gml"), os.path.join(P, f"scripts/{s}/{s}.gml")) if os.path.isdir(os.path.join(P, f"scripts/{s}")) else (os.makedirs(os.path.join(P, f"scripts/{s}")), shutil.copyfile(os.path.join(SRC, s + ".gml"), os.path.join(P, f"scripts/{s}/{s}.gml")))
    w(f"scripts/{s}/{s}.yy", j({
        "$GMScript": "v1", "%Name": s, "isCompatibility": False, "isDnD": False,
        "name": s, "parent": {"name": "Scripts", "path": "folders/Scripts.yy"},
        "resourceType": "GMScript", "resourceVersion": "2.0"}))

# ---------- object ----------
OBJ = "obj_reanim_viewer"
events = [("Create_0", 0, 0), ("Step_0", 3, 0), ("Draw_0", 8, 0)]
for name, et, en in events:
    os.makedirs(os.path.join(P, f"objects/{OBJ}"), exist_ok=True)
    shutil.copyfile(os.path.join(SRC, f"{OBJ}_{name}.gml"), os.path.join(P, f"objects/{OBJ}/{name}.gml"))
w(f"objects/{OBJ}/{OBJ}.yy", j({
    "$GMObject": "", "%Name": OBJ,
    "eventList": [{"$GMEvent": "v1", "%Name": "", "collisionObjectId": None, "eventNum": en, "eventType": et,
                   "isDnD": False, "name": "", "resourceType": "GMEvent", "resourceVersion": "2.0"} for _, et, en in events],
    "managed": True, "name": OBJ, "overriddenProperties": [],
    "parent": {"name": "Objects", "path": "folders/Objects.yy"},
    "parentObjectId": None, "persistent": False,
    "physicsAngularDamping": 0.1, "physicsDensity": 0.5, "physicsFriction": 0.2, "physicsGroup": 1,
    "physicsKinematic": False, "physicsLinearDamping": 0.1, "physicsObject": False, "physicsRestitution": 0.1,
    "physicsSensor": False, "physicsShape": 1, "physicsShapePoints": [], "physicsStartAwake": True,
    "properties": [], "resourceType": "GMObject", "resourceVersion": "2.0",
    "solid": False, "spriteId": None, "spriteMaskId": None, "visible": True}))

# ---------- room ----------
RM = "rm_reanim_viewer"
view = {"hborder": 32, "hport": 768, "hspeed": -1, "hview": 768, "inherit": False, "objectId": None,
        "vborder": 32, "visible": False, "vspeed": -1, "wport": 1366, "wview": 1366, "xport": 0, "xview": 0,
        "yport": 0, "yview": 0}
w(f"rooms/{RM}/{RM}.yy", j({
    "$GMRoom": "v1", "%Name": RM, "creationCodeFile": "", "inheritCode": False, "inheritCreationOrder": False,
    "inheritLayers": False,
    "instanceCreationOrder": [{"name": "inst_viewer", "path": f"rooms/{RM}/{RM}.yy"}],
    "isDnd": False,
    "layers": [{
        "$GMRInstanceLayer": "", "%Name": "Instances", "depth": 0, "effectEnabled": True, "effectType": None,
        "gridX": 32, "gridY": 32, "hierarchyFrozen": False, "inheritLayerDepth": False,
        "inheritLayerSettings": False, "inheritSubLayers": True, "inheritVisibility": True,
        "instances": [{
            "$GMRInstance": "v1", "%Name": "inst_viewer", "colour": 4294967295, "frozen": False,
            "hasCreationCode": False, "ignore": False, "imageIndex": 0, "imageSpeed": 1.0,
            "inheritCode": False, "inheritedItemId": None, "inheritItemSettings": False, "isDnd": False,
            "name": "inst_viewer",
            "objectId": {"name": OBJ, "path": f"objects/{OBJ}/{OBJ}.yy"},
            "properties": [], "resourceType": "GMRInstance", "resourceVersion": "2.0",
            "rotation": 0.0, "scaleX": 1.0, "scaleY": 1.0, "x": 0.0, "y": 0.0}],
        "layers": [], "name": "Instances", "properties": [], "resourceType": "GMRInstanceLayer",
        "resourceVersion": "2.0", "userdefinedDepth": False, "visible": True}],
    "name": RM, "parent": {"name": "Rooms", "path": "folders/Rooms.yy"}, "parentRoom": None,
    "physicsSettings": {"inheritPhysicsSettings": False, "PhysicsWorld": False, "PhysicsWorldGravityX": 0.0,
                        "PhysicsWorldGravityY": 10.0, "PhysicsWorldPixToMetres": 0.1},
    "resourceType": "GMRoom", "resourceVersion": "2.0",
    "roomSettings": {"Height": 600, "inheritRoomSettings": False, "persistent": False, "Width": 800},
    "sequenceId": None, "views": [dict(view) for _ in range(8)],
    "viewSettings": {"clearDisplayBuffer": True, "clearViewBackground": False, "enableViews": False,
                     "inheritViewSettings": False},
    "volume": 1.0}))

# ---------- included files ----------
inc = []
root = os.path.join(P, "datafiles")
for d, _, files in os.walk(root):
    rel = os.path.relpath(d, P).replace("\\", "/")
    for f in sorted(files):
        inc.append({"$GMIncludedFile": "", "%Name": f, "CopyToMask": -1, "filePath": rel, "name": f,
                    "resourceType": "GMIncludedFile", "resourceVersion": "2.0"})

# ---------- project ----------
res = [{"id": {"name": s, "path": f"scripts/{s}/{s}.yy"}} for s in scripts]
res.append({"id": {"name": OBJ, "path": f"objects/{OBJ}/{OBJ}.yy"}})
res.append({"id": {"name": RM, "path": f"rooms/{RM}/{RM}.yy"}})
w("PvZ.yyp", j({
    "$GMProject": "v1", "%Name": "PvZ",
    "AudioGroups": [{"$GMAudioGroup": "v1", "%Name": "audiogroup_default", "exportDir": "",
                     "name": "audiogroup_default", "resourceType": "GMAudioGroup", "resourceVersion": "2.0", "targets": -1}],
    "configs": {"children": [], "name": "Default"},
    "defaultScriptType": 1,
    "Folders": [{"$GMFolder": "", "%Name": n, "folderPath": f"folders/{n}.yy", "name": n,
                 "resourceType": "GMFolder", "resourceVersion": "2.0"} for n in ("Scripts", "Objects", "Rooms")],
    "ForcedPrefabProjectReferences": [],
    "IncludedFiles": inc,
    "isEcma": False, "LibraryEmitters": [],
    "MetaData": {"IDEVersion": IDE},
    "name": "PvZ",
    "resources": res,
    "resourceType": "GMProject", "resourceVersion": "2.0",
    "RoomOrderNodes": [{"roomId": {"name": RM, "path": f"rooms/{RM}/{RM}.yy"}}],
    "templateType": None,
    "TextureGroups": [{"$GMTextureGroup": "", "%Name": "Default", "autocrop": True, "border": 2,
                       "compressFormat": "bz2", "customOptions": "", "directory": "", "groupParent": None,
                       "isScaled": True, "loadType": "default", "mipsToGenerate": 0, "name": "Default",
                       "resourceType": "GMTextureGroup", "resourceVersion": "2.0", "targets": -1}]}))
print("project written:", len(inc), "included files,", len(scripts), "scripts, 1 object, 1 room")
