#!/usr/bin/env bash

set -euo pipefail

PUBSPEC_PATH="app/pubspec.yaml"
VERSION_FILE_PATH="app/lib/core/version/spec_version.dart"

if [[ ! -f "${PUBSPEC_PATH}" ]]; then
  echo "Missing ${PUBSPEC_PATH}"
  exit 1
fi

current_version_line="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)$/\1/p' "${PUBSPEC_PATH}" | head -n1)"

if [[ -z "${current_version_line}" ]]; then
  echo "Could not read version from ${PUBSPEC_PATH}. Expected format: version: X.Y.Z+N"
  exit 1
fi

if [[ ! "${current_version_line}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
  echo "Unsupported version format: ${current_version_line}"
  exit 1
fi

major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"
build="${BASH_REMATCH[4]}"

next_patch="$((patch + 1))"
next_build="$((build + 1))"

next_semver="${major}.${minor}.${next_patch}"
next_pubspec_version="${next_semver}+${next_build}"

awk -v new_version="${next_pubspec_version}" '
BEGIN { replaced = 0 }
{
  if (!replaced && $0 ~ /^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$/) {
    print "version: " new_version
    replaced = 1
  } else {
    print $0
  }
}
END {
  if (!replaced) {
    exit 1
  }
}
' "${PUBSPEC_PATH}" > "${PUBSPEC_PATH}.tmp"

mv "${PUBSPEC_PATH}.tmp" "${PUBSPEC_PATH}"

cat > "${VERSION_FILE_PATH}" <<EOF
const String thriveAppVersion = '${next_semver}';
const String thriveVersionLabel = 'v\$thriveAppVersion';
EOF

echo "Bumped app version to ${next_pubspec_version} (label: v${next_semver})"
