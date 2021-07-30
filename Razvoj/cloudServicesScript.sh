#!/bin/bash
VERSION="1.79"
COMMIT="SPLAT-1432: Add mqtt-log config"
get_branches() {
    echo "beta-$VERSION"
    echo "chi-$VERSION"
    echo "chi-staging-$VERSION"
    echo "delta-$VERSION"
    echo "dog1-$VERSION"
    echo "etna-$VERSION"
    echo "etna2"
    echo "func3"
    echo "func4-$VERSION"
    echo "gamma-$VERSION"
    echo "iota-$VERSION"
    echo "kappa-$VERSION"
    echo "opensync"
    echo "osacademy"
    echo "osync"
    echo "padev1"
    echo "padev2"
    echo "pml"
    echo "slodev1"
    echo "tau-$VERSION"
    echo "theta-$VERSION"
    echo "thetadev-$VERSION"
    echo "tomasz"
}
function create() {
    mkdir -p "$1"
    echo "$2" | jq . > "$1/val.json"
}
function transform() {
    for f in "$1/"*; do
        cat "$f" | jq "$2" > tmp
        mv tmp "$f"
    done
}
function apply() {
    create feature-flags/controller/mqtt-log '[{"id": "default","enabled": false,"reportInterval": 60}]'
}
git fetch
for branch in $(get_branches); do
    git checkout $branch
    git pull
    apply
    git add .
    git diff --cached -P
    read -p "Commit changes? [Yn] " result
    if ! [[ $result =~ ^[yY] ]] && ! [[ -z $result ]]; then
	    git reset --hard HEAD
        continue
    fi
    git commit -m "$COMMIT"
    git push
done