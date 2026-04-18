# Release Automation Design

## Goal

Automatically publish downloadable Windows binaries for `cpp-iso-converter` whenever releasable changes are merged into `master`.

## Scope

This design adds release automation for the existing GitHub-hosted repository at `damoninc/cpp-iso-converter`.

The workflow should:

- run on pushes to `master`
- inspect commit messages since the latest tag
- derive the next semantic version from commit prefixes
- create a Git tag only when releasable changes are present
- build the Windows executable
- run verification before publishing
- attach a packaged binary to a GitHub Release

This design intentionally keeps versioning simple:

- `feat:` bumps the minor version
- `fix:` bumps the patch version
- `chore:` does not trigger a release

Major-version handling and breaking-change parsing are explicitly out of scope.

## Trigger Model

The release automation runs when new commits land on `master`.

The workflow looks at commits since the latest `vX.Y.Z` tag:

- if at least one `feat:` commit is present, bump minor and reset patch
- else if at least one `fix:` commit is present, bump patch
- else if only `chore:` commits are present, exit without creating a release

This makes `master` the release branch and keeps binary publication aligned with merged code rather than manual tagging.

## Version Rules

The workflow reads the latest existing tag that matches the `vX.Y.Z` pattern.

Version calculation rules:

- no tags yet: start from `v0.1.0` for the first `feat:` release
- no tags yet with only `fix:` commits: start from `v0.0.1`
- `feat:` after `v1.2.3` -> `v1.3.0`
- `fix:` after `v1.2.3` -> `v1.2.4`
- `chore:` only -> no release

If both `feat:` and `fix:` are present in the same unreleased range, the workflow chooses the higher bump level and creates a single release.

## Packaging

The release artifact should be a zip file named:

```text
ciso2iso-windows-x64-vX.Y.Z.zip
```

The package contents should be:

- `ciso2iso.exe`
- `README.md`

No sample images, generated `.iso` files, or test fixtures are packaged.

## Build And Verification

The workflow uses a Windows runner and the existing Visual Studio solution.

Build and verification steps:

1. check out the repository with tags
2. determine whether a release is needed
3. if needed, compute the next version
4. create the tag
5. build `Release|x64`
6. run the existing smoke test
7. package the executable and README
8. create a GitHub Release for the new tag
9. upload the zip asset

The smoke test is the required release gate. If it fails, the workflow must not publish a release.

## Repository Changes

The implementation is expected to add:

- `.github/workflows/release.yml`
- optionally a helper script under `scripts/` for version calculation or packaging
- a short release-process section in `README.md`

The repo should also document the commit convention clearly:

- `feat:` for user-visible features
- `fix:` for user-visible bug fixes
- `chore:` for non-release maintenance changes

## Error Handling

The workflow should fail clearly when:

- the latest tag cannot be parsed
- the computed next tag already exists
- the Windows build fails
- the smoke test fails
- release asset creation fails

If there are no releasable commits, the workflow should exit successfully without creating a tag or release.

## Testing Strategy

Validation for the release automation should cover:

- a `chore:`-only push does not create a release
- a `fix:` push creates a patch release
- a `feat:` push creates a minor release
- the packaged zip contains only the expected distribution files
- the workflow uses the existing smoke test as the publish gate

## Non-Goals

This design does not include:

- major-version bumping
- changelog generation
- release notes synthesis from issue metadata
- multi-platform binaries
- code signing
