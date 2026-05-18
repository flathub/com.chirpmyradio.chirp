builder := "flatpak run org.flatpak.Builder"

_help:
    just --list

# Builds and install flatpak
build:
    {{builder}} build --install --user --force-clean com.chirpmyradio.chirp.yaml

# Run flatpak
run:
    flatpak run com.chirpmyradio.chirp

# Run flatpak linter
linter:
    flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest com.chirpmyradio.chirp.yaml

# Script to easily generate new version-number-injector.patch
bump-version:
    #!/usr/bin/env bash
    set -euo pipefail

    xdg-open https://github.com/kk7ds/chirp/commits/build-queue
    $EDITOR ./com.chirpmyradio.chirp.yaml

    project_dir="$PWD"
    patch_name="version-number-injector"

    rm -rf /tmp/chirp
    git clone git@github.com:kk7ds/chirp.git -b build-queue /tmp/chirp
    cd /tmp/chirp

    git apply "$project_dir/patches/$patch_name.patch"
    xdg-open https://archive.chirpmyradio.com/download?stream=next
    $EDITOR chirp/__init__.py
    $EDITOR flathub/com.chirpmyradio.chirp.metainfo.xml

    git add . && git commit -m "$patch_name"
    git format-patch -1 --stdout > "$project_dir/patches/$patch_name.patch"

    rm -rf /tmp/chirp

    cd "$project_dir"
    git add com.chirpmyradio.chirp.yaml patches/$patch_name.patch
    git commit -e -m "Bumped app version to "
