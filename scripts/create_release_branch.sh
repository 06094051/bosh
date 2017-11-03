#!/usr/bin/env bash

set -e

scripts_path=$(dirname $0)
start_point=${2:-'HEAD'}
patch_file=$scripts_path/create_release_branch.patch

git checkout -b $1 $start_point

sed -i '' -e "s/BRANCHNAME/$1/g" $patch_file

BRANCH_VERSION={$OVERRIDE_VERSION:$(echo $1 | cut -d '.' -f1)}
sed -i '' -e "s/BRANCHVER/$BRANCH_VERSION/g" $patch_file

git apply $patch_file
git checkout $patch_file

git add -A .
git ci -m "Create release branch $BRANCHNAME"

git set-upstream origin $BRANCHNAME
echo "Branch created successfully. Run 'git push' to push branch to Github."

echo "\n---------------------------\n"

echo "Run './ci/configure.sh' when ready to push pipeline to Concourse."
