"""Imports every model and sound under Content/ImportSource into /Game, keeping the folder layout.

Run it inside the Unreal Editor (Tools > Execute Python Script... or the Python console):
    py "<project>/../tools/import_assets.py"
or from a shell:
    UnrealEditor-Cmd.exe DarkSouls.uproject -run=pythonscript -script="<path>/import_assets.py"

Models (.glb/.gltf) go to /Game/Models/<Characters|Props|Forest>/..., music and voices to /Game/Audio/<Music|Vox|Sfx>/...
The project needs the "glTF Importer" (Interchange) plugin enabled; Unreal 5.3 or newer.
"""
import os

import unreal

SRC = os.path.normpath(os.path.join(unreal.Paths.project_dir(), "Content", "ImportSource"))
EXT = {".glb", ".gltf", ".wav", ".mp3", ".ogg"}


def collect():
    tasks = []
    for folder, _, files in os.walk(SRC):
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext not in EXT:
                continue
            # the .bin / texture files that belong to a .gltf are picked up by the importer itself
            src = os.path.join(folder, f)
            rel = os.path.relpath(folder, SRC).replace("\\", "/")
            dest = "/Game/" + ("" if rel == "." else rel)
            t = unreal.AssetImportTask()
            t.filename = src
            t.destination_path = dest
            t.automated = True
            t.replace_existing = True
            t.save = True
            tasks.append(t)
    return tasks


def main():
    tasks = collect()
    unreal.log("Importing %d files from %s" % (len(tasks), SRC))
    tools = unreal.AssetToolsHelpers.get_asset_tools()
    for i in range(0, len(tasks), 25):
        tools.import_asset_tasks(tasks[i:i + 25])
        unreal.log("  %d / %d" % (min(i + 25, len(tasks)), len(tasks)))
    unreal.log("Done. Characters are in /Game/Models/Characters, props in /Game/Models/Props, trees in /Game/Models/Forest.")


main()
