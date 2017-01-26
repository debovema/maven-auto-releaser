# $PROJECT_NAME

## Release trigger branch

This branch is a release trigger. It means that **whenever a commit is pushed on this branch**, a release job, defined in *.gitlab-ci.yml file*, will be launched, based on properties set in *release.properties* file.

## How to trigger a release ?

There is two different methods to trigger a release.
They will all commit & push a change on this branch which will trigger a build on Gitlab CI.

### automatically, with parent projects released before

Simply run:
```shell
./fullAutoRelease.sh
```

### setting manually the versions, without triggering releases for ancestors
To trigger a new release of $PROJECT_NAME, follow these steps:

* checkout this branch (after cloning this repository):
```shell
git checkout release
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
git add release.properties && git commit -m "Triggering release"
```

* trigger the release by pushing to the release branch:
```shell
git push origin release
```
