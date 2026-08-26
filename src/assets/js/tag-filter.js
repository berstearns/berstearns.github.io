/* In-place tag filter for the blog index.
 * Clicking a tag rectangle (in the filter bar or on a post card) hides
 * every post card that doesn't carry that tag. Clicking the active tag
 * again — or "all" — shows everything. No navigation involved. */
(function () {
  function apply(tag) {
    document.querySelectorAll("article.md-post").forEach(function (card) {
      var tags = (card.dataset.tags || "").split(",").filter(Boolean);
      var show = !tag || tags.indexOf(tag) !== -1;
      card.classList.toggle("post-hidden", !show);
    });
    document.querySelectorAll(".tag-filter a.md-tag").forEach(function (el) {
      el.classList.toggle(
        "md-tag--active",
        tag ? el.dataset.tag === tag : el.dataset.tag === ""
      );
    });
    var empty = document.querySelector(".tag-filter__empty");
    if (empty) {
      var any = document.querySelector("article.md-post:not(.post-hidden)");
      empty.style.display = any ? "none" : "block";
    }
  }

  document.addEventListener("click", function (ev) {
    var el = ev.target.closest("a.md-tag[data-tag]");
    if (!el) return;
    // only filter in place when there are post cards on this page
    if (!document.querySelector("article.md-post")) return;
    ev.preventDefault();
    var active = document.querySelector(
      '.tag-filter a.md-tag--active:not([data-tag=""])'
    );
    var tag = el.dataset.tag;
    apply(!tag || (active && active.dataset.tag === tag) ? "" : tag);
  });
})();
