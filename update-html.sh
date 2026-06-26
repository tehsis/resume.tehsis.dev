#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INPUT="$SCRIPT_DIR/Pablo Terradillos - Resume.md"
OUTPUT="$SCRIPT_DIR/index.html"

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js is required to regenerate index.html" >&2
  exit 1
fi

node - "$INPUT" "$OUTPUT" <<'NODE'
const fs = require("fs");

const [, , input, output] = process.argv;
const markdown = fs.readFileSync(input, "utf8");
const lines = markdown.replace(/\r\n/g, "\n").split("\n");

function stripEscapes(value) {
  return value.replace(/\\([\\`*_{}\[\]()#+\-.!_])/g, "$1");
}

function escapeHtml(value) {
  return stripEscapes(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function inline(value) {
  let html = escapeHtml(value.trim());
  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_match, text, href) => {
    return `<a href="${href.replace(/&/g, "&amp;")}">${text}</a>`;
  });
  html = html.replace(/(^|[\s(])(https?:\/\/[^\s<)]+)/g, (_match, prefix, url) => {
    return `${prefix}<a href="${url}">${url}</a>`;
  });
  html = html.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  html = html.replace(/\*([^*]+)\*/g, "<em>$1</em>");
  return html;
}

function textOnly(value) {
  return stripEscapes(value)
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/\*\*/g, "")
    .replace(/\*/g, "")
    .trim();
}

function slug(value) {
  return textOnly(value)
    .toLowerCase()
    .replace(/&/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

function blocksBetween(startMatcher, endMatcher) {
  const start = lines.findIndex(startMatcher);
  const end = lines.findIndex((line, index) => index > start && endMatcher(line));
  return tokenize(lines.slice(start + 1, end === -1 ? undefined : end));
}

function tokenize(sourceLines) {
  const blocks = [];
  for (let index = 0; index < sourceLines.length; index++) {
    const line = sourceLines[index];
    const heading = line.match(/^(#{1,6})\s+(.*)$/);
    if (heading) {
      const text = heading[2].trim();
      if (text) blocks.push({ type: "heading", level: heading[1].length, text });
      continue;
    }

    if (!line.trim()) continue;

    if (/^\*\s+/.test(line)) {
      const items = [];
      while (index < sourceLines.length && /^\*\s+/.test(sourceLines[index])) {
        items.push(sourceLines[index].replace(/^\*\s+/, "").trim());
        index++;
      }
      index--;
      blocks.push({ type: "list", items });
      continue;
    }

    const paragraph = [line.trim()];
    while (
      index + 1 < sourceLines.length &&
      sourceLines[index + 1].trim() &&
      !/^(#{1,6})\s+/.test(sourceLines[index + 1]) &&
      !/^\*\s+/.test(sourceLines[index + 1]) &&
      !/\s{2,}$/.test(sourceLines[index])
    ) {
      paragraph.push(sourceLines[++index].trim());
    }
    blocks.push({ type: "paragraph", text: paragraph.join(" ").replace(/\s{2,}/g, " ") });
  }
  return blocks;
}

function renderBlock(block, headingOffset = 0) {
  if (block.type === "list") {
    return ["            <ul>", ...block.items.map((item) => `              <li>${inline(item)}</li>`), "            </ul>"].join("\n");
  }
  if (block.type === "heading") {
    const level = Math.min(6, block.level + headingOffset);
    return `            <h${level}>${inline(block.text)}</h${level}>`;
  }
  const cleanText = textOnly(block.text).replace(/\.$/, "");
  if (/^highlights$/i.test(cleanText)) return "            <h4>Highlights</h4>";
  return `            <p>${inline(block.text)}</p>`;
}

const title = textOnly(lines.find((line) => /^#\s+/.test(line))?.replace(/^#\s+/, "") || "Resume");
const subtitle = textOnly(lines.find((line) => /^##\s+/.test(line))?.replace(/^##\s+/, "") || "Software Engineer");

const overview = blocksBetween((line) => /^#\s+Overview\s*$/.test(line), (line) => /^#\s+Contact Information\s*$/.test(line));
const expertise = blocksBetween((line) => /^##\s+Expertise\s*$/.test(line), (line) => /^#\s+Experience\s*$/.test(line));
const experience = blocksBetween((line) => /^#\s+Experience\s*$/.test(line), (line) => /^##\s+Miscellaneous\s*$/.test(line));
const miscellaneous = blocksBetween((line) => /^##\s+Miscellaneous\s*$/.test(line), () => false);

const contactLines = lines.slice(
  lines.findIndex((line) => /^#\s+Contact Information\s*$/.test(line)) + 1,
  lines.findIndex((line) => /^##\s+Expertise\s*$/.test(line)),
);
const contacts = contactLines
  .map((line) => line.trim())
  .filter((line) => /^\*\*.+?\*\*/.test(line))
  .map((line) => {
    const [, label, value] = line.match(/^\*\*(.+?)\*\*:?\s*(.+?)\s*$/) || [];
    return { label: textOnly(label).replace(/:$/, ""), value: inline(value) };
  })
  .filter((entry) => entry.label && entry.value);

function renderExperience() {
  const output = [];
  let openArticle = false;
  let awaitingDate = false;

  for (const block of experience) {
    if (block.type === "heading" && block.level === 2 && !/^\w+\s+\d{4}/.test(textOnly(block.text))) {
      if (openArticle) output.push("          </article>", "");
      output.push("          <article class=\"role\">");
      output.push(`            <h3>${inline(block.text)}</h3>`);
      openArticle = true;
      awaitingDate = true;
      continue;
    }

    if (openArticle && awaitingDate && block.type === "heading" && block.level === 2) {
      output.push(`            <p class="date">${inline(block.text)}</p>`);
      awaitingDate = false;
      continue;
    }

    if (!openArticle) continue;
    awaitingDate = false;
    output.push(renderBlock(block, block.type === "heading" ? 1 : 0));
  }

  if (openArticle) output.push("          </article>");
  return output.join("\n");
}

function renderMisc() {
  const sections = [];
  let current = { title: "Miscellaneous", blocks: [] };
  for (const block of miscellaneous) {
    if (block.type === "heading" && block.level === 3 && ["Talks & Workshops", "Highlighted Articles"].includes(textOnly(block.text))) {
      sections.push(current);
      current = { title: textOnly(block.text), blocks: [] };
      continue;
    }
    current.blocks.push(block);
  }
  sections.push(current);

  return sections.map((section) => {
    const id = slug(section.title);
    return [
      `        <section id="${id}" class="section" aria-labelledby="${id}-title">`,
      `          <h2 id="${id}-title">${inline(section.title)}</h2>`,
      ...section.blocks.map((block) => renderBlock(block, block.type === "heading" ? 0 : 0).replace(/^            /gm, "          ")),
      "        </section>",
    ].join("\n");
  }).join("\n\n");
}

const nav = ["Overview", "Contact", "Expertise", "Experience", "Miscellaneous", "Talks & Workshops", "Highlighted Articles"];

const html = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta
      name="description"
      content="Resume for Pablo Emiliano Terradillos, Software Engineer and Engineering Manager."
    />
    <title>${escapeHtml(title)} — Resume</title>
    <link rel="stylesheet" href="styles.css" />
  </head>
  <body>
    <div class="page">
      <nav class="index" aria-label="Resume sections">
        <img class="profile-picture" src="profile.webp" alt="Profile picture of ${escapeHtml(title)}" />
${nav.map((item) => `        <a href="#${slug(item)}">${escapeHtml(item)}</a>`).join("\n")}
        <a href="Pablo%20Terradillos%20-%20Resume.pdf" download>Download PDF</a>
      </nav>

      <main class="resume">
        <header class="hero">
          <p class="eyebrow">${escapeHtml(subtitle)}</p>
          <h1>${escapeHtml(title)}</h1>
        </header>

        <section id="overview" class="section" aria-labelledby="overview-title">
          <h2 id="overview-title">Overview</h2>
${overview.map((block) => renderBlock(block).replace(/^            /gm, "          ")).join("\n")}
        </section>

        <section id="contact" class="section" aria-labelledby="contact-title">
          <h2 id="contact-title">Contact</h2>
          <dl class="contact-list">
${contacts.map((entry) => `            <div>\n              <dt>${escapeHtml(entry.label)}</dt>\n              <dd>${entry.value}</dd>\n            </div>`).join("\n")}
          </dl>
        </section>

        <section id="expertise" class="section" aria-labelledby="expertise-title">
          <h2 id="expertise-title">Expertise</h2>
${expertise.map((block) => renderBlock(block, block.type === "heading" ? 1 : 0).replace(/^            /gm, "          ")).join("\n")}
        </section>

        <section id="experience" class="section" aria-labelledby="experience-title">
          <h2 id="experience-title">Experience</h2>

${renderExperience()}
        </section>

${renderMisc()}
      </main>
    </div>
  </body>
</html>
`;

fs.writeFileSync(output, html);
NODE

echo "Updated $OUTPUT"
