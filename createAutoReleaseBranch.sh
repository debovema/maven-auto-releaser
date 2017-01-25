#!/bin/sh

GIT_REPOSITORY_URL=$1

echo "== Initialization =="
# 1. clone the repository to a temporary directory
TEMP_CLONE_DIRECTORY=$(mktemp -d)
echo "1. Cloning the repository at $GIT_REPOSITORY_URL to $TEMP_CLONE_DIRECTORY"
git clone -q $GIT_REPOSITORY_URL $TEMP_CLONE_DIRECTORY
if [ $? -gt 0 ]; then
  echo " Unable to clone $GIT_REPOSITORY_URL"
  exit 1
fi

cd $TEMP_CLONE_DIRECTORY

# 2. create the release trigger branch (called release by default)
RELEASE_BRANCH=release &&
git symbolic-ref HEAD refs/heads/$RELEASE_BRANCH &&
git reset &&
rm -rf $TEMP_CLONE_DIRECTORY/* &&
echo "# $RELEASE_BRANCH" > README.md &&
git add README.md &&
git commit -m "Creating $RELEASE_BRANCH branch" &&
git push origin $RELEASE_BRANCH

# clean up and restore initial directory
echo
echo "== Clean up =="
cd $OLDPWD
echo " Removing temporary directory: $TEMP_CLONE_DIRECTORY"
rm -rf $TEMP_CLONE_DIRECTORY
return 0
