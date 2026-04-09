import fs from "node:fs";
import { parseHTML } from "linkedom";
import Defuddle from "defuddle";
import DefuddleFull from "defuddle/full";
import TurndownService from "turndown";

function readInput(path) {
  const raw = fs.readFileSync(path, "utf8");
  return JSON.parse(raw);
}

function canonicalURLFromDocument(doc, fallbackURL) {
  const canonical =
    doc.querySelector('link[rel="canonical"]')?.getAttribute("href")?.trim() ||
    doc.querySelector('meta[property="og:url"]')?.getAttribute("content")?.trim() ||
    "";
  return canonical || fallbackURL || "";
}

function excerptFromDocument(doc, fallbackDescription) {
  const excerpt =
    doc.querySelector('meta[name="description"]')?.getAttribute("content")?.trim() ||
    doc.querySelector('meta[property="og:description"]')?.getAttribute("content")?.trim() ||
    fallbackDescription ||
    "";
  return excerpt;
}

async function resolvedHTML(input) {
  const rawHTML = (input.html || "").trim();
  if (rawHTML.length > 32) {
    return rawHTML;
  }

  const url = (input.url || "").trim();
  if (!url) {
    return "";
  }

  const response = await fetch(url, {
    redirect: "follow",
    headers: {
      "user-agent": "QuickSnap Obsidian Clipper Helper"
    }
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch source HTML (${response.status})`);
  }

  return await response.text();
}

function convertToMarkdown(html, url) {
  const markdownFactory = DefuddleFull?.createMarkdownContent;
  const fallbackTurndown = new TurndownService({
    codeBlockStyle: "fenced",
    headingStyle: "atx"
  });

  if (typeof markdownFactory !== "function") {
    return fallbackTurndown.turndown(html || "").trim();
  }

  const originalError = console.error;
  const originalStderrWrite = process.stderr.write.bind(process.stderr);
  try {
    console.error = () => {};
    process.stderr.write = () => true;
    const markdown = String(markdownFactory(html || "", url || "") || "").trim();
    if (markdown && !markdown.startsWith("Partial conversion completed with errors.")) {
      return markdown;
    }
  } catch {
    // fall through to Turndown fallback
  } finally {
    console.error = originalError;
    process.stderr.write = originalStderrWrite;
  }

  return fallbackTurndown.turndown(html || "").trim();
}

async function main() {
  const inputPath = process.argv[2];
  if (!inputPath) {
    throw new Error("Missing input file path");
  }

  const input = readInput(inputPath);
  const html = await resolvedHTML(input);
  if (!html.trim()) {
    throw new Error("No page HTML was available for extraction");
  }

  const { document } = parseHTML(html);
  const defuddle = new Defuddle(document, { url: input.url || "" });
  const result = defuddle.parse();
  const markdown = convertToMarkdown(result.content || "", input.url || "");

  const output = {
    engine: "obsidian_clipper_helper",
    title: (result.title || input.pageTitle || "").trim(),
    author: (result.author || "").trim(),
    published: (result.published || "").trim(),
    excerpt: excerptFromDocument(document, result.description || ""),
    canonicalURL: canonicalURLFromDocument(document, input.url || ""),
    site: (result.site || "").trim(),
    wordCount: Number(result.wordCount || 0),
    markdown,
    success: markdown.length > 0
  };

  process.stdout.write(JSON.stringify(output));
}

try {
  await main();
} catch (error) {
  process.stdout.write(
    JSON.stringify({
      success: false,
      engine: "obsidian_clipper_helper",
      error: error instanceof Error ? error.message : String(error),
      title: "",
      author: "",
      published: "",
      excerpt: "",
      canonicalURL: "",
      site: "",
      wordCount: 0,
      markdown: ""
    })
  );
  process.exit(1);
}
