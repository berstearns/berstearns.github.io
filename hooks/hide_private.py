"""
Hide posts with `private: true` from blog views, RSS, and sitemap.
Private post pages stay reachable at their normal URLs; they're just
unlisted everywhere except the manual index at /zenitsu/.

Pages with `noindex: true` (the /zenitsu/ index itself) also get
robots-noindex and are removed from sitemap.
"""
import gzip
import os
import re

_hidden_urls: set[str] = set()
_private_posts: list[dict] = []


def on_page_context(context, page, config, nav, **kwargs):
    if hasattr(page, "posts") and page.posts is not None:
        page.posts = [p for p in page.posts if not p.meta.get("private", False)]
    return context


def on_page_markdown(markdown, page, config, files, **kwargs):
    if page.meta.get("private") or page.meta.get("noindex"):
        _hidden_urls.add("/" + page.url.lstrip("/"))
    if page.meta.get("private"):
        _private_posts.append({
            "url": "/" + page.url.lstrip("/"),
            "title": page.title or page.meta.get("title", "(untitled)"),
            "date": str(page.meta.get("date", ""))[:10],
        })
    return markdown


def on_post_page(output, page, config, **kwargs):
    if page.meta.get("private") or page.meta.get("noindex"):
        return output.replace(
            "<head>",
            '<head>\n  <meta name="robots" content="noindex,nofollow">',
            1,
        )
    return output


def _strip_blocks(xml: str, tag: str, urls: set[str]) -> str:
    for url in urls:
        xml = re.sub(
            rf"<{tag}>(?:(?!</{tag}>).)*?" + re.escape(url) + rf"(?:(?!</{tag}>).)*?</{tag}>\s*",
            "",
            xml,
            flags=re.DOTALL,
        )
    return xml


def on_post_build(config, **kwargs):
    site_dir = config["site_dir"]

    zenitsu = os.path.join(site_dir, "zenitsu", "index.html")
    if os.path.exists(zenitsu):
        posts = sorted(_private_posts, key=lambda p: p["date"], reverse=True)
        items = "\n".join(
            f'<li><a href="{p["url"]}">{p["title"]}</a> &mdash; {p["date"]}</li>'
            for p in posts
        ) or "<li><em>no private posts yet</em></li>"
        with open(zenitsu, "r", encoding="utf-8") as f:
            html = f.read()
        html = re.sub(
            r'<ul id="private-posts-list">.*?</ul>',
            f'<ul id="private-posts-list">\n{items}\n</ul>',
            html,
            count=1,
            flags=re.DOTALL,
        )
        with open(zenitsu, "w", encoding="utf-8") as f:
            f.write(html)

    if not _hidden_urls:
        return

    for feed in ("feed_rss_created.xml", "feed_rss_updated.xml"):
        path = os.path.join(site_dir, feed)
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                xml = f.read()
            xml = _strip_blocks(xml, "item", _hidden_urls)
            with open(path, "w", encoding="utf-8") as f:
                f.write(xml)

    sitemap = os.path.join(site_dir, "sitemap.xml")
    if os.path.exists(sitemap):
        with open(sitemap, "r", encoding="utf-8") as f:
            xml = f.read()
        xml = _strip_blocks(xml, "url", _hidden_urls)
        with open(sitemap, "w", encoding="utf-8") as f:
            f.write(xml)
        gz_path = sitemap + ".gz"
        if os.path.exists(gz_path):
            with open(sitemap, "rb") as fin, gzip.open(gz_path, "wb") as fout:
                fout.write(fin.read())
