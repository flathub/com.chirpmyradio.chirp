
set script-interpreter := ["bash", "-euo", "pipefail"]

appname := "com.chirpmyradio.chirp"
manifest := f"{{appname}}.yaml"

# == Helpers ==

@_help:
    just --list

@_log text:
    echo -e "\e[32m=== {{text}} ===\e[0m"

@_ask_if_ok:
    read -p "All good? [y/N] " response && [ "$response" = "y" ] || { echo "Aborting."; exit 1; }


#== Tasks ==

# Builds and installs the app
[group("Tasks")]
build: (_log "Building app")
    flatpak run org.flatpak.Builder build --install --user --force-clean {{manifest}}

# Lints manifest
[group("Tasks")]
lint: (_log "Running linter on manifest")
    -flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest {{manifest}}

# Runs the currently installed app
[group("Tasks")]
run: (_log "Running currently installed app")
    flatpak run {{appname}}


# == Scripts ==

patch_name := "version-number-injector"

# Pulls new changes on `master` and then branches off on branch `BRANCH` passed in, thus updating that branch
[group("Scripts")]
update-branch BRANCH: (_log "Pulling in new changes")
    git checkout master
    git pull
    -git branch -D {{BRANCH}}
    git checkout -b {{BRANCH}}

# Script to semi-automatically generate a new `patches/version-number-injector.patch`
[group("Scripts")]
[script]
bump-version _save-version-var="false": (_log "Starting patch generation script")
    xdg-open https://archive.chirpmyradio.com/download?stream=next >/dev/null 2>&1 &
    xdg-open https://github.com/kk7ds/chirp/commits/ >/dev/null 2>&1 &
    read -rp "New chommit hash: " new_hash
    sed -i -E "s/(commit: )[0-9a-f]{40}/\1${new_hash}/" {{manifest}} \

    project_dir="$PWD"

    rm -rf /tmp/chirp
    git clone --depth=1 git@github.com:kk7ds/chirp.git /tmp/chirp
    cd /tmp/chirp

    git apply "$project_dir/patches/{{patch_name}}.patch"

    read -rp "New app version number: " new_version
    sed -i -E "s/(CHIRP_VERSION = \")[^\"]+/\1${new_version}/" chirp/__init__.py


    date="${new_version#next-}"
    release_date="${date:0:4}-${date:4:2}-${date:6:2}"

    sed -i "/<releases>/a\\
        <release version=\"$new_version\" date=\"$release_date\"></release>" \
        flathub/com.chirpmyradio.chirp.metainfo.xml

    git diff > "$project_dir/patches/{{patch_name}}.patch"

    if [ "{{_save-version-var}}" = "true" ]; then
        mkdir -p $project_dir/build
        echo $release_date > $project_dir/build/var_buffer
    fi

    rm -rf /tmp/chirp


# == Workflows ==

# Semi-automatically creates new app version commit
[group("Workflows")]
update-app BRANCH: (update-branch BRANCH) (bump-version "true") lint _ask_if_ok build run _ask_if_ok
    git diff -- {{manifest}}
    git diff -- patches/{{patch_name}}.patch
    just _ask_if_ok
    git add {{manifest}} patches/{{patch_name}}.patch
    git commit -e -m "Bumped app version to $(cat build/var_buffer)"
    rm -f build/var_buffer
