#!/bin/sh

# retrieve Maven auto release script
wget -q https://raw.githubusercontent.com/debovema/maven-auto-releaser/master/mavenAutoRelease.sh -O /tmp/mavenAutoRelease.sh
chmod u+x /tmp/mavenAutoRelease.sh
. /tmp/mavenAutoRelease.sh

# call updateReleaseVersionsAndTrigger from Maven auto release script
updateReleaseVersionsAndTrigger $MAVEN_AUTO_RELEASE_REPOSITORY_URL
