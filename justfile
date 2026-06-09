
# == Helpers ==

_help:
    @just --list

_colorprint text:
    @echo -e "\e[32m== {{text}} ==\e[0m"

_ask_if_ok:
    @read -p "All good? [y/N] " response && [ "$response" = "y" ] || { echo "Aborting."; exit 1; }

#== Tasks ==

# Builds and installs the app
[group("Tasks")]
build: (_colorprint "Building app")
    flatpak run org.flatpak.Builder build --install --user --force-clean com.chirpmyradio.chirp.yaml

# Lints manifest
[group("Tasks")]
lint: (_colorprint "Running linter on manifest")
    @echo -e "\e[33mINFO: \e[34mError \e[36m\`finish-args-home-filesystem-access\`\e[34m is expected and should be ignored\e[0m\n"
    flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest com.chirpmyradio.chirp.yaml || true

# Runs the currently installed app
[group("Tasks")]
run: (_colorprint "Running currently installed app")
    flatpak run com.chirpmyradio.chirp


# == Scripts ==

patch_name := "version-number-injector"

# Pulls new changes on `master` and then branches off on branch `bump-version`
[group("Scripts")]
pull-changes: (_colorprint "Pulling in new changes")
    git checkout master
    git pull
    git branch -D bump-version
    git checkout -b bump-version

# Script to semi-automatically generate a new `patches/version-number-injector.patch`
[group("Scripts")]
bump-version: (_colorprint "Starting patch generation script")
    #!/usr/bin/env bash
    set -euo pipefail

    xdg-open https://github.com/kk7ds/chirp/commits/build-queue
    $EDITOR ./com.chirpmyradio.chirp.yaml

    project_dir="$PWD"

    rm -rf /tmp/chirp
    git clone git@github.com:kk7ds/chirp.git -b build-queue /tmp/chirp
    cd /tmp/chirp

    git apply "$project_dir/patches/{{patch_name}}.patch"
    xdg-open https://archive.chirpmyradio.com/download?stream=next
    $EDITOR chirp/__init__.py
    $EDITOR flathub/com.chirpmyradio.chirp.metainfo.xml

    git add . && git commit -m "{{patch_name}}"
    git format-patch -1 --stdout > "$project_dir/patches/{{patch_name}}.patch"

    rm -rf /tmp/chirp


# Prepares a commit containing only the files needed to bump the version of the app
[group("Scripts")]
make-bump-commit: 
    git add com.chirpmyradio.chirp.yaml patches/{{patch_name}}.patch
    git commit -e -m "Bumped app version to "


# == Tootstrappers ==

# Runs `build`,`lint`, `run` tasks in that order
[group("Bootstrappers")]
testapp: build lint run


# Runs `pull-changes`, `lint`,`testapp`, `make-bump-commit` tasks in that order with user confirmation prompts between major steps
[group("Bootstrappers")]
all: pull-changes lint _ask_if_ok testapp _ask_if_ok make-bump-commit
