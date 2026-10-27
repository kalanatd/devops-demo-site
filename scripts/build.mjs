// Copies site/ to dist/ and stamps the commit into the page and version.json.
// The deploy health check reads version.json to prove the right commit is live.
import { cpSync, rmSync, readFileSync, writeFileSync } from "node:fs";

const commit = (process.env.GITHUB_SHA || "local").slice(0, 7);

rmSync("dist", { recursive: true, force: true });
cpSync("site", "dist", { recursive: true });

const indexPath = "dist/index.html";
writeFileSync(indexPath, readFileSync(indexPath, "utf8").replaceAll("{{VERSION}}", commit));

writeFileSync(
  "dist/version.json",
  JSON.stringify({ commit, builtAt: new Date().toISOString() }, null, 2) + "\n",
);

console.log(`Built dist/ for commit ${commit}`);
