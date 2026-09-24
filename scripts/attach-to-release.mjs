import { readFileSync, statSync } from "node:fs";
import { basename } from "node:path";

/**
 * Attaches a built file to the draft release of a tag, drafting one if the tag has none.
 *
 * A draft is not visible through `releases/tags`, which only answers for published ones,
 * so the release is found by listing them instead.
 *
 *   node scripts/attach-to-release.mjs <tag> <file>
 */
const [tag, file] = process.argv.slice(2);
const repo = process.env.GITHUB_REPOSITORY;
const token = process.env.GH_TOKEN;

if (!tag || !file) throw new Error("usage: attach-to-release.mjs <tag> <file>");
if (!repo || !token) throw new Error("GITHUB_REPOSITORY and GH_TOKEN are required");

const headers = { Authorization: `Bearer ${token}`, Accept: "application/vnd.github+json" };
const api = `https://api.github.com/repos/${repo}/releases`;

const releases = await fetch(`${api}?per_page=30`, { headers }).then(asJson);
const release =
  releases.find((each) => each.tag_name === tag) ??
  (await fetch(api, {
    method: "POST",
    headers,
    body: JSON.stringify({
      tag_name: tag,
      name: tag,
      draft: true,
      body: process.env.RELEASE_NOTES ?? "",
    }),
  }).then(asJson));

const name = basename(file);
const already = release.assets?.find((asset) => asset.name === name);
if (already) {
  await fetch(`${api}/assets/${already.id}`, { method: "DELETE", headers });
}

const uploaded = await fetch(
  `https://uploads.github.com/repos/${repo}/releases/${release.id}/assets?name=${encodeURIComponent(name)}`,
  {
    method: "POST",
    headers: {
      ...headers,
      "Content-Type": "application/octet-stream",
      "Content-Length": String(statSync(file).size),
    },
    body: readFileSync(file),
  },
).then(asJson);

console.log(`${uploaded.name} (${uploaded.size} bytes) is on ${tag}`);

async function asJson(response) {
  const json = await response.json();
  if (!response.ok) throw new Error(`${response.status}: ${JSON.stringify(json)}`);
  return json;
}
