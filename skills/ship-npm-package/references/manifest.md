# Manifest checklist

A release script cannot rescue a broken `package.json`. Fix this first.

## Verify with the one command that tells the truth

```bash
npm pack --dry-run
```

This lists exactly what would be published. Everything below is a way of making that output correct.

## Required fields

| Field         | Why                                                                            |
| ------------- | ------------------------------------------------------------------------------ |
| `name`        | Must be available, or owned by you. Check `npm view <name>`                     |
| `version`     | Valid semver. The starting version is the one number nobody can change later    |
| `description` | Shown in npm search results — this is the package's one-line pitch             |
| `license`     | Without it, consumers legally cannot use the package. Ship a LICENSE file too   |
| `repository`  | Enables the GitHub link on npm and is required for provenance                  |
| `keywords`    | The only discovery mechanism npm search has                                     |

## `files` — what actually ships

Allowlist, not denylist. `.npmignore` is a denylist and is the usual reason a secret gets published.

```json
"files": ["dist", "README.md", "LICENSE", "CHANGELOG.md"]
```

`package.json`, `README`, and `LICENSE` are always included regardless. If both `files` and `.npmignore` exist, `files` wins — delete the `.npmignore` rather than leaving two sources of truth.

## `exports` — the map that breaks silently

```json
{
	"type": "module",
	"main": "./dist/index.cjs",
	"module": "./dist/index.js",
	"types": "./dist/index.d.ts",
	"exports": {
		".": {
			"types": "./dist/index.d.ts",
			"import": "./dist/index.js",
			"require": "./dist/index.cjs"
		},
		"./sub": {
			"types": "./dist/sub/index.d.ts",
			"import": "./dist/sub/index.js",
			"require": "./dist/sub/index.cjs"
		},
		"./package.json": "./package.json"
	}
}
```

Rules that are easy to get wrong:

- **`types` must come first** in each condition block. Resolution is order-sensitive, and a `types` key after `import` is silently ignored.
- **`exports` blocks deep imports.** Once present, `pkg/dist/internal.js` stops working. That is usually intended — but it is a breaking change if consumers relied on it.
- **Export `./package.json`.** Tools read it, and `exports` would otherwise block them.
- **Every subpath needs its own `types`.** Missing ones fail only in editors, which no runtime test catches.
- **`main` and `module` are for old bundlers.** Keep them as a fallback; `exports` is what modern resolvers use.

## Other fields worth setting

```json
{
	"sideEffects": false,
	"engines": { "node": ">=18.0.0" },
	"publishConfig": { "access": "public", "provenance": true }
}
```

- **`sideEffects: false`** enables tree-shaking. Only correct if importing a module genuinely does nothing — a package with a polyfill or global registration must not claim this.
- **`engines`** should match the lowest Node in your CI matrix. Setting it lower than you test is a promise you have not verified.
- **`publishConfig.access: "public"`** is required for scoped packages, which default to private and fail the first publish otherwise.

## Peer dependencies

```json
{
	"peerDependencies": { "react": ">=17" },
	"peerDependenciesMeta": { "react": { "optional": true } }
}
```

Mark a peer optional when only one entry point needs it. Without `optional: true`, every consumer gets an install warning for something most of them do not use.

## `prepublishOnly`, not `prepare`

```json
"scripts": { "prepublishOnly": "npm run check && npm run build" }
```

`prepare` runs on `npm install` in consumer projects too, which fails for anyone who installs from a git URL without your devDependencies. `prepublishOnly` runs only on publish.

Note this is a safety net, not the gate. The real gate is the release script, which runs the smoke test as well.

## Versioning

For an unpublished package the version is a free choice; after that it is a contract.

| Change                                                    | Bump  |
| --------------------------------------------------------- | ----- |
| Removing or renaming an export                            | major |
| Changing a function signature or a required option         | major |
| Adding `exports` where deep imports previously worked      | major |
| Raising the `engines` floor                                | major |
| Making an optional option required                         | major |
| Adding an export or an optional option                     | minor |
| Adding a new subpath                                       | minor |
| Bug fix with no API change                                 | patch |
| Type-only fix that changes what compiles                   | minor, occasionally major |

Type changes deserve care: tightening a type is a compile-time breaking change even though runtime behaviour is identical. Consumers experience it as a broken build.

## If the package was already published badly

`npm unpublish` is only allowed within 72 hours and only if nothing depends on it. Assume you cannot use it.

```bash
# The tool that actually reaches existing installs
npm deprecate 'pkg@<2.0.0' 'Versions before 2.0.0 leaked credentials to the browser. Upgrade: https://…/MIGRATION.md'
```

Deprecation prints a warning on every install of a matching version. For a security issue it is an obligation, not housekeeping — it is the only channel that reaches people already pinned to the bad version. **Any secret in a published tarball is public permanently. Rotate it.**
