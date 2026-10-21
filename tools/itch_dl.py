"""Downloads the free ("name your own price" / $0) files of an itch.io asset page.

Usage:  python tools/itch_dl.py <page url> <output dir> [name filter]
        e.g. python tools/itch_dl.py https://kaylousberg.itch.io/kaykit-skeletons /tmp/skeletons
Only for assets whose license allows it (the pages I use are CC0). It follows the same steps as the website's Download button.
"""
import http.cookiejar
import json
import os
import re
import sys
import urllib.parse
import urllib.request

UA = {"User-Agent": "Mozilla/5.0"}


def main(page, out, filt=""):
    jar = http.cookiejar.CookieJar()
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))

    def get(url, data=None, headers=None):
        h = dict(UA)
        h.update(headers or {})
        req = urllib.request.Request(url, data=data, headers=h)
        return op.open(req, timeout=120).read()

    page = page.rstrip("/")
    html = get(page).decode("utf-8", "ignore")
    csrf = re.search(r'csrf_token" value="([^"]+)"', html)
    if not csrf:
        csrf = re.search(r'name="csrf_token" content="([^"]+)"|content="([^"]+)" name="csrf_token"', html)
    token = (csrf.group(1) or csrf.group(2)) if csrf else ""
    post = urllib.parse.urlencode({"csrf_token": token}).encode()
    dl = json.loads(get(page + "/download_url", post, {"Referer": page}))
    dlpage = get(dl["url"]).decode("utf-8", "ignore")
    token2 = re.search(r'csrf_token" value="([^"]+)"', dlpage) or re.search(r'content="([^"]+)" name="csrf_token"', dlpage)
    token2 = token2.group(1) if token2 else token
    uploads = re.findall(r'data-upload_id="(\d+)"', dlpage)
    names = re.findall(r'class="upload_name"><strong[^>]*title="([^"]+)"', dlpage)
    os.makedirs(out, exist_ok=True)
    for uid, name in zip(uploads, names):
        if filt and filt.lower() not in name.lower():
            continue
        slug = page.rstrip("/").split("/")[-1]
        base = page
        resp = json.loads(get("%s/file/%s?source=game_download" % (base, uid), urllib.parse.urlencode({"csrf_token": token2}).encode(),
                              {"X-Requested-With": "XMLHttpRequest", "Referer": dl["url"]}))
        if "url" not in resp:
            print("  no url for", name, resp)
            continue
        data = get(resp["url"])
        path = os.path.join(out, name)
        with open(path, "wb") as f:
            f.write(data)
        print("  downloaded %s (%d KB)" % (name, len(data) // 1024))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
    else:
        main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
