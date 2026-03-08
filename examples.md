# Retroactive Commit History – Examples

## Example 1: New Package (50 commits, 5 days)

**Day 1 – Bootstrap (10 commits)**
- chore: init package.json
- chore: add tsconfig
- chore: add build config
- chore: add eslint and prettier
- chore: add .gitignore
- chore: add .nvmrc
- chore: add LICENSE
- chore: add package-lock.json
- feat: add README

**Day 2 – Types (10 commits)**
- feat: add primitive types
- feat: add element constants
- feat: add WordStyle and animation types
- feat: add BaseElementJSON
- feat: add element JSON types (Text, Image, Path)
- feat: add SvgJSON, GroupContainerJSON
- feat: add union and overrides
- feat: add capsule types
- feat: add types barrel export
- feat: add constants

**Day 3 – Utils (10 commits)**
- feat: add type guards
- feat: add sizeMatching (normalize, euclidean)
- feat: add computeSizeMatchScores
- feat: add findClosestSizeWithMatches
- feat: add findBestReferenceSize
- feat: add scaling helpers (area, skew)
- feat: add scaleCornerRadius, scalePadding
- feat: add adaptWordStyleFontSizes
- feat: add getValuesWithoutSkewingJSON
- feat: add per-type adapt helpers

**Day 4 – Adapter (10 commits)**
- feat: add getAdaptedObjectsJSON skeleton
- feat: add skew detection and non-skew path
- feat: add resolveObjectsForSize
- feat: add applyAdaptedAsOverrides
- feat: add buildNewCapsule
- feat: add generateBaseLayoutForSize
- feat: add public API exports

**Day 5 – Polish (10 commits)**
- refact: add section comments
- feat: expand README
- chore: add dist to gitignore
- fix: ensure type exports
- chore: add package exports
- chore: finalize package metadata

## Example 2: Feature Branch (15 commits, 3 days)

- feat: add API endpoint skeleton
- feat: add request validation
- feat: add service layer
- feat: add repository layer
- feat: add database migration
- fix: handle edge case in validation
- feat: add unit tests
- refact: extract shared logic
- feat: add integration tests
- docs: add API docs
- chore: update dependencies
- fix: correct error response format
- feat: add rate limiting
- refact: simplify error handling
- chore: bump version

## Example 3: Bugfix (5 commits, 1 day)

- fix: add null check for optional param
- fix: correct off-by-one in loop
- test: add regression test
- chore: update changelog
- fix: handle empty array edge case
