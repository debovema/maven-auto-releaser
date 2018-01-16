#!/bin/sh

# retrieve Maven auto release script
wget -q https://raw.githubusercontent.com/debovema/maven-auto-releaser/$MAVEN_AUTO_RELEASER_VERSION_TAG/mavenAutoRelease.sh -O /tmp/mavenAutoRelease.sh
chmod u+x /tmp/mavenAutoRelease.sh
. /tmp/mavenAutoRelease.sh

# call updateReleaseVersionsAndTrigger from Maven auto release script
updateReleaseVersionsAndTrigger $GIT_REPOSITORY_URL
