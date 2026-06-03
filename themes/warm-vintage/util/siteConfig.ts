import * as fs from "fs"
import * as path from "path"

export interface SiteConfig {
  tagline?:     string
  description?: string
  SEO?:         string
  copyright?:   string
  instagram?:   string
  ebay?:        string
  etsy?:        string
  [key: string]: string | undefined
}

function parseFrontmatterStrings(raw: string): Record<string, string> {
  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---/)
  if (!match) return {}
  const result: Record<string, string> = {}
  for (const line of match[1].split(/\r?\n/)) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith("#") || trimmed.startsWith("-")) continue
    const colonIdx = trimmed.indexOf(":")
    if (colonIdx < 1) continue
    const key = trimmed.slice(0, colonIdx).trim()
    const rawVal = trimmed.slice(colonIdx + 1).trim()
    // Skip YAML booleans, arrays, objects, and empty values
    if (!rawVal || rawVal === "true" || rawVal === "false"
        || rawVal.startsWith("[") || rawVal.startsWith("{")) continue
    const val = rawVal.replace(/^["']|["']$/g, "").trim()
    if (key && val) result[key] = val
  }
  return result
}

function load(): SiteConfig {
  try {
    const p = path.join(process.cwd(), "content", "_meta.md")
    return parseFrontmatterStrings(fs.readFileSync(p, "utf-8")) as SiteConfig
  } catch {
    return {}
  }
}

// Read once at module load time; Node caches the module so this runs once per build.
export const siteConfig: SiteConfig = load()
