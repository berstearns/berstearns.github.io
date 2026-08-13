/* Portfolio page: renders profile + live GitHub repos.
 *
 * Everything you would want to edit lives in PROFILE below.
 * Repos are fetched from the public GitHub API at page load — no build step,
 * no token. Unauthenticated calls are rate limited to 60/hour per IP, so the
 * response is cached in sessionStorage for the tab's lifetime.
 */

const PROFILE = {
  github: "berstearns",
  name: "Bernardo Stearns",
  tagline: "I do research on NLP for education",
  avatar: "https://avatars.githubusercontent.com/u/26882917?v=4",
  info: [
    { key: "Based in", value: "Galway, Ireland" },
    { key: "Role", value: "Research Associate & part-time PhD, Univ. of Galway" },
    { key: "GitHub", value: "berstearns", href: "https://github.com/berstearns" },
    { key: "Blog", value: "berstearns.github.io", href: "/" },
    { key: "Email", value: "[removed]", href: "mailto:[removed]" },
  ],
  stack: [
    "Python", "PyTorch", "Transformers", "spaCy", "NLTK",
    "Rust", "Haskell", "Kotlin", "C",
    "Docker", "Postgres", "SQLite", "Bash", "tmux", "Git",
    "NLP", "Grammatical Error Correction", "Language Learning",
  ],
  // The projects to show, in display order. Only these appear — add a repo
  // name here to publish it, delete the line to take it down. Names must match
  // the repo name on GitHub exactly (case-insensitive).
  show: [
    "public-metadata-aware-nwp-in-sla",
  ],
};

// GitHub's own language colors, for the dot on each card.
const LANG_COLORS = {
  Python: "#3572A5", Shell: "#89e051", CSS: "#663399", HTML: "#e34c26",
  JavaScript: "#f1e05a", TypeScript: "#3178c6", Rust: "#dea584",
  Haskell: "#5e5086", Kotlin: "#A97BFF", Java: "#b07219", C: "#555555",
  "C++": "#f34b7d", Go: "#00ADD8", Lua: "#000080", Vim9Script: "#019833",
  "Jupyter Notebook": "#DA5B0B", Makefile: "#427819", Dockerfile: "#384d54",
};

const esc = (s) =>
  String(s ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

function renderAside(root) {
  const info = PROFILE.info
    .map(({ key, value, href }) => {
      const val = href
        ? `<a href="${esc(href)}">${esc(value)}</a>`
        : esc(value);
      return `<div class="pf-info__row">
                <span class="pf-info__key">${esc(key)}</span>
                <span class="pf-info__val">${val}</span>
              </div>`;
    })
    .join("");

  const stack = PROFILE.stack
    .map((s) => `<span class="pf-stack__item">${esc(s)}</span>`)
    .join("");

  root.innerHTML = `
    <div class="pf-card pf-profile">
      <img class="pf-profile__avatar" src="${esc(PROFILE.avatar)}"
           alt="${esc(PROFILE.name)}" loading="lazy">
      <div class="pf-profile__name">${esc(PROFILE.name)}</div>
      <p class="pf-profile__tagline">${esc(PROFILE.tagline)}</p>
    </div>
    <div class="pf-card">
      <div class="pf-info">${info}</div>
    </div>
    <div class="pf-card">
      <div class="pf-card__title">Tech Stack</div>
      <div class="pf-stack">${stack}</div>
    </div>`;
}

function repoCard(repo) {
  const color = LANG_COLORS[repo.language] || "#6272a4";
  const stats = [];
  if (repo.stargazers_count) stats.push(`☆ ${repo.stargazers_count}`);
  if (repo.forks_count) stats.push(`⑂ ${repo.forks_count}`);
  if (!stats.length) {
    const when = new Date(repo.pushed_at).toLocaleDateString("en-GB", {
      month: "short",
      year: "numeric",
    });
    stats.push(`updated ${when}`);
  }

  const lang = repo.language
    ? `<span class="pf-repo__lang">
         <span class="pf-repo__dot" style="background:${color}"></span>${esc(repo.language)}
       </span>`
    : "";

  return `<a class="pf-repo" href="${esc(repo.html_url)}" target="_blank" rel="noopener">
            <span class="pf-repo__name">🔗 ${esc(repo.name)}</span>
            <p class="pf-repo__desc">${esc(repo.description || "No description yet.")}</p>
            <span class="pf-repo__meta">
              <span class="pf-repo__stats">${stats.map((s) => `<span>${s}</span>`).join("")}</span>
              ${lang}
            </span>
          </a>`;
}

function selectRepos(repos) {
  const byName = new Map(repos.map((r) => [r.name.toLowerCase(), r]));
  const picked = [];
  for (const name of PROFILE.show) {
    const repo = byName.get(name.toLowerCase());
    if (repo) picked.push(repo);
    else console.warn(`[portfolio] no such repo on GitHub: ${name}`);
  }
  return picked;
}

async function fetchRepos() {
  const cacheKey = `pf-repos:${PROFILE.github}`;
  const cached = sessionStorage.getItem(cacheKey);
  if (cached) return JSON.parse(cached);

  const url = `https://api.github.com/users/${PROFILE.github}/repos?per_page=100&sort=pushed`;
  const res = await fetch(url, { headers: { Accept: "application/vnd.github+json" } });
  if (!res.ok) throw new Error(`GitHub API returned ${res.status}`);

  const repos = await res.json();
  try {
    sessionStorage.setItem(cacheKey, JSON.stringify(repos));
  } catch (_) {
    /* quota — fine, we just refetch next time */
  }
  return repos;
}

async function renderProjects(root) {
  try {
    const repos = selectRepos(await fetchRepos());
    root.innerHTML = repos.length
      ? repos.map(repoCard).join("")
      : `<div class="pf-status">No projects listed yet.</div>`;
  } catch (err) {
    root.innerHTML = `<div class="pf-status">
        Could not load projects (${esc(err.message)}).
        See them on <a href="https://github.com/${esc(PROFILE.github)}">GitHub</a>.
      </div>`;
  }
}

function initPortfolio() {
  const aside = document.getElementById("pf-aside");
  const grid = document.getElementById("pf-grid");
  if (!aside || !grid) return; // not the portfolio page

  document.body.classList.add("portfolio-page");
  renderAside(aside);
  renderProjects(grid);
}

// mkdocs-material swaps pages without a reload, so hook its observable too.
if (window.document$) {
  window.document$.subscribe(initPortfolio);
} else {
  document.addEventListener("DOMContentLoaded", initPortfolio);
}
