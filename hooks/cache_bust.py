"""
Append a content-hash query string to our own CSS/JS asset references.

GitHub Pages serves everything with Cache-Control: max-age=600 and our
asset URLs never change between deploys, so browsers keep serving a
stale dracula.css / tag-filter.js for up to 10 minutes after a push —
"the new feature doesn't work" until a hard refresh. A ?v=<hash> that
changes with the file's content makes every deploy fetch fresh assets
while untouched files stay cached.
"""
import hashlib
import os

ASSETS = (
    "assets/css/dracula.css",
    "assets/css/portfolio.css",
    "assets/js/portfolio.js",
    "assets/js/tag-filter.js",
    "assets/js/private-gate.js",
)


def on_post_build(config, **kwargs):
    site = config["site_dir"]

    hashes = {}
    for asset in ASSETS:
        path = os.path.join(site, asset)
        if os.path.exists(path):
            with open(path, "rb") as f:
                hashes[asset] = hashlib.md5(f.read()).hexdigest()[:8]

    for root, _, files in os.walk(site):
        for name in files:
            if not name.endswith(".html"):
                continue
            path = os.path.join(root, name)
            with open(path, "r", encoding="utf-8") as f:
                html = f.read()
            out = html
            for asset, digest in hashes.items():
                # asset refs are root-relative or ../-relative; matching on
                # the path suffix right before the closing quote covers both
                out = out.replace(f'{asset}"', f'{asset}?v={digest}"')
            if out != html:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(out)
