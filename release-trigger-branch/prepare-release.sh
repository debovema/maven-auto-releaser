#!/bin/sh

chmod $PREPARE_RELEASE_SH_CHMOD ./prepare-release.sh

. release.properties

# configure repository and checkout $SOURCE_BRANCH instead of current release branch
git config --global user.name $GIT_USER_NAME
git config --global user.email $GIT_USER_EMAIL
git config --global push.default upstream

# delete the branch and check it out again from remote
git branch -d $SOURCE_BRANCH
git checkout -b $SOURCE_BRANCH remotes/origin/$SOURCE_BRANCH
git branch --set-upstream-to=origin/$SOURCE_BRANCH $SOURCE_BRANCH
