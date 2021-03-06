# $PROJECT_NAME

This branch (*$RELEASE_TRIGGER_BRANCH*) is a [**release trigger branch**](#release-trigger-branch) for the **$PROJECT_NAME** project.

## Release trigger branch

This branch is a release trigger. It means that **whenever a commit is pushed on this branch**, a release job, defined in [*.gitlab-ci.yml*](./.gitlab-ci.yml) file, will be launched, based on properties set in [*release.properties*](./release.properties) file.

## How to trigger a release ?

There are several methods to trigger a release.
They will all commit & push a change on this *release trigger branch* which will trigger a build on Gitlab CI.

### automatically from Gitlab

To trigger a new release with *$INCREMENT_POLICY* increment policy, simply [run a new pipeline]($GIT_REPOSITORY_URL_NO_EXT/pipelines/new) after selecting *$RELEASE_TRIGGER_BRANCH* in the list.
That's it !

### automatically from this repository

* clone this repository:
```shell
git clone $GIT_REPOSITORY_URL
cd $GIT_REPOSITORY_BASENAME
```

* checkout this branch:
```shell
git checkout $RELEASE_TRIGGER_BRANCH
```

* simply run:
```shell
chmod u+x ./release.sh
. ./release.sh && triggerRelease
```

This script will update the [*release.properties*](./release.properties) file with next versions (based on ```INCREMENT_POLICY``` set in [*release.properties*](./release.properties) and current version set in POM of branch $SOURCE_BRANCH) then commit and push this file on this *release trigger branch*, hence triggering a release.

### manually

* clone this repository:
```shell
git clone $GIT_REPOSITORY_URL
cd $GIT_REPOSITORY_BASENAME
```

* checkout this branch:
```shell
git checkout $RELEASE_TRIGGER_BRANCH
```

* edit Release Version (*0.0.1* is an example):
```shell
RELEASE_VERSION=0.0.1 && sed -i "s/\(RELEASE_VERSION=\).*\$/\1${RELEASE_VERSION}/" release.properties
```

* edit Development Version (*0.0.2-SNAPSHOT* is an example):
```shell
DEV_VERSION=0.0.2-SNAPSHOT && sed -i "s/\(DEV_VERSION=\).*\$/\1${DEV_VERSION}/" release.properties
```

* commit the release information:
```shell
git add release.properties && git commit -m "Triggering release $RELEASE_VERSION, next development version will be $DEV_VERSION"
```

* trigger the release by pushing to the *release trigger branch*:
```shell
git push origin $RELEASE_TRIGGER_BRANCH
```

These versions numbers can also be [edited directly in Gitlab]($GIT_REPOSITORY_URL_NO_EXT/edit/$RELEASE_TRIGGER_BRANCH/release.properties).

## Full documentation

The full documentation for the Maven auto releaser v$MAVEN_AUTO_RELEASER_VERSION can be found at https://github.com/debovema/maven-auto-releaser/blob/$MAVEN_AUTO_RELEASER_VERSION_TAG/README.md.
