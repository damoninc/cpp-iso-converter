#!/usr/bin/env bash
set -euo pipefail

command_name="${1:-}"
shift || true

version=""
exe_path=""
readme_path="README.md"
output_dir="dist"
binary_name="ciso2iso.exe"
target="windows-x64"

write_github_output() {
  local line="$1"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    mkdir -p "$(dirname "$GITHUB_OUTPUT")"
    printf '%s\n' "$line" >> "$GITHUB_OUTPUT"
  else
    printf '%s\n' "$line"
  fi
}

latest_version_tag() {
  git tag --list 'v*' --sort=-version:refname | head -n 1
}

commit_subjects_since_tag() {
  local tag="$1"
  if [[ -z "$tag" ]]; then
    git log --format=%s
  else
    git log "${tag}..HEAD" --format=%s
  fi
}

next_version() {
  local current_tag="$1"
  shift
  local has_feat=false
  local has_fix=false

  for subject in "$@"; do
    if [[ "$subject" =~ ^[[:space:]]*feat: ]]; then
      has_feat=true
      continue
    fi
    if [[ "$subject" =~ ^[[:space:]]*fix: ]]; then
      has_fix=true
    fi
  done

  if [[ "$has_feat" == false && "$has_fix" == false ]]; then
    return 1
  fi

  if [[ -z "$current_tag" ]]; then
    if [[ "$has_feat" == true ]]; then
      printf 'v0.1.0\n'
    else
      printf 'v0.0.1\n'
    fi
    return 0
  fi

  if [[ ! "$current_tag" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    printf "Latest tag '%s' is not in vX.Y.Z format.\n" "$current_tag" >&2
    return 2
  fi

  local major="${BASH_REMATCH[1]}"
  local minor="${BASH_REMATCH[2]}"
  local patch="${BASH_REMATCH[3]}"

  if [[ "$has_feat" == true ]]; then
    printf 'v%s.%s.0\n' "$major" "$((minor + 1))"
  else
    printf 'v%s.%s.%s\n' "$major" "$minor" "$((patch + 1))"
  fi
}

release_plan() {
  local tag
  tag="$(latest_version_tag)"

  mapfile -t subjects < <(commit_subjects_since_tag "$tag")

  local planned
  if ! planned="$(next_version "$tag" "${subjects[@]:-}")"; then
    write_github_output 'release=false'
    return 0
  fi

  write_github_output 'release=true'
  write_github_output "version=${planned}"
}

create_zip() {
  local source_dir="$1"
  local destination_zip="$2"

  if command -v zip >/dev/null 2>&1; then
    (
      cd "$source_dir"
      zip -r "$destination_zip" .
    ) >/dev/null
    return
  fi

  python - "$source_dir" "$destination_zip" <<'PYTHON'
import pathlib
import sys
import zipfile

source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])

with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for path in source.rglob("*"):
        if path.is_file():
            zf.write(path, path.relative_to(source))
PYTHON
}

release_package() {
  [[ -n "$version" ]] || { echo 'Version is required for package mode.' >&2; exit 1; }
  [[ -n "$exe_path" ]] || { echo 'ExePath is required for package mode.' >&2; exit 1; }
  [[ -n "$binary_name" ]] || { echo 'BinaryName is required for package mode.' >&2; exit 1; }
  [[ -n "$target" ]] || { echo 'Target is required for package mode.' >&2; exit 1; }
  [[ -f "$exe_path" ]] || { echo "Executable not found at $exe_path" >&2; exit 1; }
  [[ -f "$readme_path" ]] || { echo "README not found at $readme_path" >&2; exit 1; }

  mkdir -p "$output_dir"

  local stage_dir="$output_dir/package"
  rm -rf "$stage_dir"
  mkdir -p "$stage_dir"

  cp "$exe_path" "$stage_dir/$binary_name"
  cp "$readme_path" "$stage_dir/README.md"

  local zip_path="$output_dir/ciso2iso-$target-$version.zip"
  rm -f "$zip_path"

  create_zip "$stage_dir" "$zip_path"

  write_github_output "asset_path=$zip_path"
}

while (($#)); do
  case "$1" in
    --version)
      version="$2"
      shift 2
      ;;
    --exe-path)
      exe_path="$2"
      shift 2
      ;;
    --readme-path)
      readme_path="$2"
      shift 2
      ;;
    --output-dir)
      output_dir="$2"
      shift 2
      ;;
    --binary-name)
      binary_name="$2"
      shift 2
      ;;
    --target)
      target="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

case "$command_name" in
  plan)
    release_plan
    ;;
  package)
    release_package
    ;;
  *)
    echo "Usage: ./scripts/release.sh <plan|package> [options]" >&2
    exit 1
    ;;
esac
