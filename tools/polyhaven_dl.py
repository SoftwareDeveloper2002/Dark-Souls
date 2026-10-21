"""Download free CC0 models from Poly Haven into assets/models/polyhaven/<id>/<id>_1k.gltf (+ .bin and textures).

Usage:   python tools/polyhaven_dl.py rock_07 stone_01 fir_tree_01
         python tools/polyhaven_dl.py --search tree        (list matching model ids)
Then open the project in Godot once so it imports the new files. Everything on Poly Haven is CC0 (free, no credit needed).
"""
import json
import os
import sys
import urllib.request

API = "https://api.polyhaven.com"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "models", "polyhaven")
HEADERS = {"User-Agent": "dark-souls-mobile-game-asset-fetch"}


def get(url: str) -> bytes:
	req = urllib.request.Request(url, headers=HEADERS)
	with urllib.request.urlopen(req, timeout=60) as r:
		return r.read()


def search(term: str) -> None:
	models = json.loads(get(API + "/assets?t=models"))
	for k, v in sorted(models.items()):
		hay = " ".join([k, v.get("name", "")] + v.get("tags", []) + v.get("categories", [])).lower()
		if term.lower() in hay:
			print(k, "-", v.get("name"))


def download(asset: str, res: str = "1k") -> bool:
	files = json.loads(get("%s/files/%s" % (API, asset)))
	try:
		entry = files["gltf"][res]["gltf"]
	except KeyError:
		print("  no %s glTF for %s" % (res, asset))
		return False
	out = os.path.normpath(os.path.join(ROOT, asset))
	os.makedirs(out, exist_ok=True)
	with open(os.path.join(out, "%s_%s.gltf" % (asset, res)), "wb") as f:
		f.write(get(entry["url"]))
	for rel, info in entry.get("include", {}).items():
		dest = os.path.join(out, rel)
		os.makedirs(os.path.dirname(dest), exist_ok=True)
		with open(dest, "wb") as f:
			f.write(get(info["url"]))
	with open(os.path.join(out, "LICENSE.txt"), "w") as f:
		f.write("%s - Poly Haven, CC0 (public domain)\nhttps://polyhaven.com/a/%s\n" % (asset, asset))
	print("  ok  %s" % asset)
	return True


if __name__ == "__main__":
	args = sys.argv[1:]
	if not args:
		print(__doc__)
	elif args[0] == "--search":
		search(args[1])
	else:
		for a in args:
			download(a)
