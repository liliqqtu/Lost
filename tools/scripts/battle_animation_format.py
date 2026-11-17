"""Small, lossless reader/writer for the project's SpriteFrames animation dictionaries."""
import copy
import json
import re
from pathlib import Path

ANIMATION = re.compile(
    r'\{\s*"frames": \[(.*?)\],\s*"loop": (\w+),\s*'
    r'"name": &"([^"]+)",\s*"speed": ([\d.]+)\s*\}', re.S)
FRAME = re.compile(r'\{\s*"duration": ([\d.]+),\s*"texture": (.*?)\s*\}', re.S)


def read_resource(path):
    text = Path(path).read_text(encoding="utf-8")
    animations = {}
    for match in ANIMATION.finditer(text):
        body, loop, name, speed = match.groups()
        animations[name] = {
            "frames": [(float(d), t.strip()) for d, t in FRAME.findall(body)],
            "loop": loop in ("true", "1"), "speed": float(speed)}
    if not animations:
        raise ValueError(f"No animations parsed: {path}")
    textures = dict(re.findall(
        r'\[ext_resource type="Texture2D"[^\n]*path="([^"]+)" id="([^"]+)"\]', text))
    textures = {f'ExtResource("{v}")': k for k, v in textures.items()}
    return text, animations, textures


def signature(animation, textures):
    return tuple((duration, textures[texture].rsplit("/", 1)[-1])
                 for duration, texture in animation["frames"])


def clone(animation, frames=None, loop=None):
    result = copy.deepcopy(animation)
    if frames is not None:
        result["frames"] = list(frames)
    if loop is not None:
        result["loop"] = loop
    return result


def write_resource(path, original, animations, metadata):
    blocks = []
    for name, animation in animations.items():
        frames = ", ".join('{\n"duration": %s,\n"texture": %s\n}' % (d, t)
                           for d, t in animation["frames"])
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
                      % (frames, str(animation["loop"]).lower(), name, animation["speed"]))
    # Preserve all texture definitions, resource UIDs and any unrelated properties.
    start = original.index("animations = [")
    end = list(ANIMATION.finditer(original))[-1].end()
    end = original.index("]", end) + 1
    suffix = original[end:]
    suffix = re.sub(r'\nmetadata/battle_animation_\w+ = [^\n]*', '', suffix)
    output = original[:start] + "animations = [\n" + ",\n".join(blocks) + "\n]" + suffix.rstrip() + "\n"
    for key, value in metadata.items():
        output += f"metadata/battle_animation_{key} = " + json.dumps(value, ensure_ascii=False) + "\n"
    if output != original:
        Path(path).write_text(output, encoding="utf-8", newline="\n")
        return True
    return False
