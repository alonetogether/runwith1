"""Blender 4.0 script: merge Mixamo clips onto the skinned character and export one .glb.

Usage:
  Blender -b --python mixamo_to_glb.py -- <character_with_skin.fbx> <out.glb> <textures_dir> <clip_name>=<clip.fbx> ...

Each clip FBX is a Mixamo "without skin" download for the same character, so the
armatures match bone for bone; its action is moved onto the character's armature
as an NLA track named after the clip, and the glTF exporter writes one animation
per track.
"""
import sys, os, bpy

argv = sys.argv[sys.argv.index("--") + 1:]
char_fbx, out_glb, tex_dir, *clip_args = argv
clips = [a.split("=", 1) for a in clip_args]

bpy.ops.wm.read_factory_settings(use_empty=True)

def import_fbx(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False,
                             ignore_leaf_bones=False, use_image_search=True)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    return arm, new

def add_track(name, action):
    track = char_arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, int(action.frame_range[0]), action)
    strip.name = name

def ping_pong_tail(action, name, tail_frames, gain=3.0):
    """Copies the last `tail_frames` of `action`, exaggerates their motion
    about the final pose by `gain`, and appends them reversed: a short shiver
    that lands exactly where the one-shot clip ended."""
    new = action.copy()
    new.name = name
    new.use_fake_user = True
    end = action.frame_range[1]
    for fc in new.fcurves:
        pts = sorted((k.co.x, k.co.y) for k in fc.keyframe_points if k.co.x >= end - tail_frames - 1e-3)
        if len(pts) < 2:
            continue
        final = pts[-1][1]
        pts = [(f, final + (v - final) * gain) for f, v in pts]
        seq = pts + [(end + (end - f), v) for f, v in reversed(pts[:-1])]
        base = seq[0][0]
        fc.keyframe_points.clear()
        fc.keyframe_points.add(len(seq))
        for kp, (f, v) in zip(fc.keyframe_points, seq):
            kp.co = (f - base + 1, v)
            kp.interpolation = "LINEAR"
        fc.update()
    print(f"CLIP {name}: derived from {action.name} tail, frames {new.frame_range[0]:.0f}-{new.frame_range[1]:.0f}")
    return new

char_arm, char_objs = import_fbx(char_fbx)
char_arm.name = "Armature"
print("CHAR bones:", len(char_arm.data.bones), "objects:", [o.name for o in char_objs])

# Drop the T-pose/default action that comes with the character import.
if char_arm.animation_data and char_arm.animation_data.action:
    a = char_arm.animation_data.action
    char_arm.animation_data.action = None
    bpy.data.actions.remove(a)
if char_arm.animation_data is None:
    char_arm.animation_data_create()

for name, path in clips:
    arm, objs = import_fbx(path)
    action = arm.animation_data.action
    action.name = name
    action.use_fake_user = True
    missing = {fc.data_path.split('"')[1] for fc in action.fcurves if '"' in fc.data_path} - set(char_arm.data.bones.keys())
    print(f"CLIP {name}: frames {action.frame_range[0]:.0f}-{action.frame_range[1]:.0f}, unmatched bones: {sorted(missing)[:5]}")
    add_track(name, action)
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)

# "cower": a quivering hold derived from the tail of the one-shot "hide" clip,
# ping-ponged so she keeps breathing instead of freezing on the last frame.
if "hide" in bpy.data.actions:
    add_track("cower", ping_pong_tail(bpy.data.actions["hide"], "cower", tail_frames=6))

# Re-link textures that did not come through embedded.
tex_map = {
    "mtl_bdy1052_00": "tex_bdy1052_00_diff.png",
    "mtl_chr1052_00_face": "tex_chr1052_00_face_diff.png",
    "mtl_chr1052_00_mayu": "tex_chr1052_00_face_diff.png",
    "mtl_chr1052_00_eye": "tex_chr1052_00_eye0.png",
    "mtl_chr1052_00_hair": "tex_chr1052_00_hair_diff.png",
    "mtl_tail0001_00": "tex_tail0001_00_1052_diff.png",
}
for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        continue
    linked = bsdf.inputs["Base Color"].links
    has_tex = bool(linked) and linked[0].from_node.type == "TEX_IMAGE" and linked[0].from_node.image and linked[0].from_node.image.has_data
    key = next((k for k in tex_map if mat.name.startswith(k)), None)
    if not has_tex and key:
        img = bpy.data.images.load(os.path.join(tex_dir, tex_map[key]), check_existing=True)
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = img
        for l in list(linked):
            mat.node_tree.links.remove(l)
        mat.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
        print("TEX relinked", mat.name, "->", tex_map[key])
    # Matte, unlit-ish look: the app lights her flatly anyway.
    bsdf.inputs["Roughness"].default_value = 1.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
    print("MAT", mat.name, "textured:", has_tex or bool(key))

bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=out_glb, export_format="GLB", use_selection=True,
    export_animations=True, export_animation_mode="NLA_TRACKS",
    export_nla_strips_merged_animation_name="", export_force_sampling=True,
    export_optimize_animation_size=True, export_anim_single_armature=True,
    export_skins=True, export_all_influences=False, export_def_bones=False,
    export_apply=False, export_yup=True, export_materials="EXPORT",
    # The source carries ~1400 facial shape keys (30 MB). Off until expressions are used.
    export_morph=False,
    export_image_format="AUTO", export_texcoords=True, export_normals=True,
)
print("WROTE", out_glb, os.path.getsize(out_glb))
