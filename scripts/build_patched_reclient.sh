#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <android-tree-root> [reclient-src-dir]" >&2
  exit 1
fi

AOSP_ROOT="$(cd "$1" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="${SCRIPT_DIR}/../patches/reclient-buildbuddy-root-working-dir.patch"

if [[ $# -eq 2 ]]; then
  RECLIENT_DIR="$(cd "$2" && pwd)"
else
  RECLIENT_DIR="${AOSP_ROOT}/.tmp/reclient-buildbuddyfix-src"
fi

GO_BIN="${AOSP_ROOT}/prebuilts/go/linux-x86/bin/go"
LIVE_DIR="${AOSP_ROOT}/prebuilts/remoteexecution-client/live"
OUT_DIR="${AOSP_ROOT}/prebuilts/remoteexecution-client/buildbuddyfix"

if [[ ! -x "${GO_BIN}" ]]; then
  echo "missing Go toolchain: ${GO_BIN}" >&2
  exit 1
fi

if [[ ! -d "${LIVE_DIR}" ]]; then
  echo "missing bundled reclient dir: ${LIVE_DIR}" >&2
  exit 1
fi

mkdir -p "$(dirname "${RECLIENT_DIR}")"

if [[ ! -d "${RECLIENT_DIR}/.git" ]]; then
  git clone --depth=1 https://github.com/bazelbuild/reclient "${RECLIENT_DIR}"
fi

if ! grep -q 'if cOpts.WorkDir == "."' "${RECLIENT_DIR}/cmd/rewrapper/main.go"; then
  (
    cd "${RECLIENT_DIR}"
    git apply "${PATCH_FILE}"
  )
fi

mkdir -p "${RECLIENT_DIR}/internal/pkg/version"
cp "${RECLIENT_DIR}/go.mod" "${RECLIENT_DIR}/internal/pkg/version/go.mod.txt"

BASE_VERSION="$(cat "${LIVE_DIR}/version.txt")"
printf '%s' "${BASE_VERSION}-buildbuddyfix" > "${RECLIENT_DIR}/internal/pkg/version/version.txt"

CLANG_JSON="$(find "${RECLIENT_DIR}/llvm" -maxdepth 1 -name 'clang-options-*.json' | head -n 1)"
if [[ -z "${CLANG_JSON}" ]]; then
  echo "could not find clang-options-*.json under ${RECLIENT_DIR}/llvm" >&2
  exit 1
fi

(
  cd "${RECLIENT_DIR}"
  "${GO_BIN}" run ./internal/pkg/inputprocessor/clangparser/gen_clang_flags \
    --input "${CLANG_JSON}" \
    -o ./internal/pkg/inputprocessor/clangparser/clang_flags.go
)

mkdir -p "${RECLIENT_DIR}/out"

(
  cd "${RECLIENT_DIR}"
  "${GO_BIN}" build -o ./out/rewrapper ./cmd/rewrapper
  "${GO_BIN}" build -o ./out/reproxy ./cmd/reproxy
)

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"
cp -a "${LIVE_DIR}/." "${OUT_DIR}/"
cp "${RECLIENT_DIR}/out/rewrapper" "${OUT_DIR}/rewrapper"
cp "${RECLIENT_DIR}/out/reproxy" "${OUT_DIR}/reproxy"
printf '%s\n' "${BASE_VERSION}-buildbuddyfix" > "${OUT_DIR}/version.txt"

cat <<EOF
patched client created at:
  ${OUT_DIR}
EOF
