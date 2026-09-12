#!/usr/bin/env bash
#
# apply-docker-deps.sh
#
# Adds the two header-only dependencies that the Docker build was missing:
#
#   nlohmann/json  -> apt package  nlohmann-json3-dev   (build stage)
#   cxxopts        -> git clone into /usr/local/include (deps stage)
#
# nlohmann is an apt package on this host (/usr/include/nlohmann/), so it goes
# in the build stage's apt block. cxxopts was installed by hand into
# /usr/local/include, so it needs a source step in the deps stage — the exact
# version is read off this machine so the image matches what you build against.
#
# Safe to run more than once: every edit checks whether it is already applied.
#
# Usage:  ./apply-docker-deps.sh          (run from the repo root, ~/tru)
#
set -euo pipefail

DOCKERFILES=(Dockerfile Dockerfile.miner Dockerfile.gpu)

# --- sanity -----------------------------------------------------------------
for f in "${DOCKERFILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: $f not found. Run this from the repo root (~/tru)." >&2
        exit 1
    fi
done

# --- work out which cxxopts version this host has ---------------------------
CXXOPTS_HEADER=""
for candidate in /usr/local/include/cxxopts.hpp /usr/include/cxxopts.hpp; do
    [ -f "$candidate" ] && CXXOPTS_HEADER="$candidate" && break
done

if [ -n "$CXXOPTS_HEADER" ]; then
    MAJOR=$(grep -m1 'CXXOPTS__VERSION_MAJOR' "$CXXOPTS_HEADER" | awk '{print $3}')
    MINOR=$(grep -m1 'CXXOPTS__VERSION_MINOR' "$CXXOPTS_HEADER" | awk '{print $3}')
    PATCHV=$(grep -m1 'CXXOPTS__VERSION_PATCH' "$CXXOPTS_HEADER" | awk '{print $3}')
    CXXOPTS_TAG="v${MAJOR:-3}.${MINOR:-2}.${PATCHV:-0}"
    echo "Detected cxxopts ${CXXOPTS_TAG} at ${CXXOPTS_HEADER}"
else
    CXXOPTS_TAG="v3.2.0"
    echo "WARNING: cxxopts.hpp not found locally; defaulting to ${CXXOPTS_TAG}"
fi

# --- backups ----------------------------------------------------------------
STAMP=$(date +%F-%H%M%S)
for f in "${DOCKERFILES[@]}"; do
    cp "$f" "${f}.bak-${STAMP}"
done
echo "Backups written with suffix .bak-${STAMP}"
echo

# --- edit 1: nlohmann-json3-dev in the build stage apt block ----------------
for f in "${DOCKERFILES[@]}"; do
    if grep -q 'nlohmann-json3-dev' "$f"; then
        echo "[$f] nlohmann-json3-dev already present — skipping"
    else
        # libqrencode-dev appears exactly once, in the build stage apt list.
        # Append to whichever line it sits on — the three Dockerfiles use two
        # different layouts (one package per line vs several per line).
        sed -i '/libqrencode-dev/ s/ \\$/ nlohmann-json3-dev \\/' "$f"
        if grep -q 'nlohmann-json3-dev' "$f"; then
            echo "[$f] added nlohmann-json3-dev"
        else
            echo "[$f] WARNING: could not add nlohmann-json3-dev — add it by hand" >&2
        fi
    fi
done
echo

# --- edit 2: cxxopts source step in the deps stage --------------------------
# Inserted immediately before the keccak COPY, which marks the end of the
# from-source dependency block in every one of the three files.
CXXOPTS_BLOCK="# --- cxxopts (header-only) ------------------------------------------------\n\
# Installed by hand on the build host under \/usr\/local\/include, so it is not\n\
# available as a package here. Pinned to the version this project builds\n\
# against — the API changed between major releases.\n\
RUN git clone --depth 1 --branch ${CXXOPTS_TAG} \\\\\n\
        https:\/\/github.com\/jarro2783\/cxxopts.git \\\\\n\
    \&\& cp cxxopts\/include\/cxxopts.hpp \/usr\/local\/include\/ \\\\\n\
    \&\& rm -rf cxxopts\n"

for f in "${DOCKERFILES[@]}"; do
    if grep -q 'cxxopts.git' "$f"; then
        echo "[$f] cxxopts block already present — skipping"
    else
        sed -i "0,|^COPY docker/vendor/libkeccak.a|s||${CXXOPTS_BLOCK}\nCOPY docker/vendor/libkeccak.a|" "$f" 2>/dev/null \
            || sed -i "s|^COPY docker/vendor/libkeccak.a|${CXXOPTS_BLOCK}\nCOPY docker/vendor/libkeccak.a|" "$f"
        if grep -q 'cxxopts.git' "$f"; then
            echo "[$f] added cxxopts ${CXXOPTS_TAG} build step"
        else
            echo "[$f] WARNING: could not add cxxopts block — add it by hand" >&2
        fi
    fi
done

echo
echo "=== Verification ==="
for f in "${DOCKERFILES[@]}"; do
    printf '%-20s nlohmann:%s  cxxopts:%s\n' "$f" \
        "$(grep -c 'nlohmann-json3-dev' "$f")" \
        "$(grep -c 'cxxopts.git' "$f")"
done

echo
echo "Each file should show nlohmann:1 and cxxopts:1."
echo "Review with:  git diff Dockerfile   (or: diff Dockerfile.bak-${STAMP} Dockerfile)"
echo "Then build:   docker build -t tru-node:latest ."
