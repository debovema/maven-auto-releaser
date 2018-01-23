#!/bin/sh

# retrieve Maven auto release script
wget -q https://raw.githubusercontent.com/debovema/maven-auto-releaser/$MAVEN_AUTO_RELEASER_VERSION_TAG/maven-auto-release.sh -O /tmp/maven-auto-release.sh
chmod u+x /tmp/maven-auto-release.sh
. /tmp/maven-auto-release.sh

# call executeRelease from Maven auto release script
executeRelease $GIT_REPOSITORY_URL