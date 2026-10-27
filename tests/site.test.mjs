// Fast checks that run on every pull request and before every deploy.
// Run locally with: npm test
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync, readdirSync } from "node:fs";
import { join } from "node:path";

const SITE = "site";
const html = readFileSync(join(SITE, "index.html"), "utf8");

test("homepage has a page title", () => {
  assert.match(html, /<title>[^<]+<\/title>/);
});

test("homepage has a non-empty main heading", () => {
  const h1 = html.match(/<h1[^>]*>([^<]*)<\/h1>/);
  assert.ok(h1, "expected an <h1> element");
  assert.ok(h1[1].trim().length > 0, "the <h1> must not be empty");
});

test("homepage shows the club name", () => {
  const name = html.match(/<p id="club-name">([^<]*)<\/p>/);
  assert.ok(name, "expected the club name in the footer");
  assert.equal(name[1].trim(), "AWS Student Builder Group");
});

test("homepage has a version placeholder for the build step", () => {
  assert.ok(html.includes("{{VERSION}}"), "build.mjs replaces {{VERSION}} with the commit");
});

test("every local link and asset exists", () => {
  for (const file of readdirSync(SITE).filter((f) => f.endsWith(".html"))) {
    const page = readFileSync(join(SITE, file), "utf8");
    const refs = [...page.matchAll(/(?:href|src)="([^"]+)"/g)].map((m) => m[1]);
    for (const ref of refs) {
      if (/^(https?:|mailto:|#)/.test(ref)) continue;
      assert.ok(existsSync(join(SITE, ref)), `${file} links to missing file: ${ref}`);
    }
  }
});

test("a 404 page exists for the S3 error document", () => {
  assert.ok(existsSync(join(SITE, "404.html")));
});
