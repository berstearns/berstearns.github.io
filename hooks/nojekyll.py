"""
Drop a .nojekyll marker into the site dir on every build.

GitHub Pages (legacy build) pipes the published folder through Jekyll,
which can choke on generated files and strips anything it dislikes.
MkDocs output needs no processing — .nojekyll makes Pages publish it
as-is. Generated here because `mkdocs build` wipes site_dir each run
and ignores dotfiles placed in docs_dir.
"""
import os


def on_post_build(config, **kwargs):
    open(os.path.join(config["site_dir"], ".nojekyll"), "w").close()
