#!/bin/sh

# retrieve Maven auto release script
curl -s https://raw.githubusercontent.com/debovema/maven-auto-releaser/$MAVEN_AUTO_RELEASER_VERSION_TAG/maven-auto-release.sh -o /tmp/maven-auto-release.sh
chmod u+x /tmp/maven-auto-release.sh
. /tmp/maven-auto-release.sh
