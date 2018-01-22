#!/bin/sh

# maven-auto-releaser.sh
# released by Mathieu Debove (https://github.com/debovema) under Apache License, Version 2.0

MAVEN_AUTO_RELEASER_VERSION=1.0.0-beta3 # this is the displayed version (in banner)
MAVEN_AUTO_RELEASER_VERSION_TAG=v$MAVEN_AUTO_RELEASER_VERSION # this is the Git tag used to retrieve template files

DEFAULT_RELEASE_TRIGGER_BRANCH=release-trigger
DEFAULT_SOURCE_BRANCH=master

### release trigger branch creation ###

# the createReleaseTriggerBranch function will:
#  1. clone a repository (and try to guess a project name)
#  2. checkout the source branch (DEFAULT_SOURCE_BRANCH=master by default)
#  3. create the release trigger branch (called DEFAULT_RELEASE_TRIGGER_BRANCH=release-trigger by default)
#  4. retrieve template files from https://github.com/debovema/maven-auto-releaser, replace properties in these files and add them to the release trigger branch
#  5. push the newly created trigger branch
createReleaseTriggerBranch () {
  parseCommandLine $@

  createReleaseTriggerBranch_loadPropertiesFromFile $PARAMETERS

  if [ $? -gt 0 ]; then
    cleanUp
    createReleaseTriggerBranch_usage
    return 1
  fi

  echo
  echo "Creating release trigger branch on repository $GIT_REPOSITORY_URL"
  echo "-> source branch is $SOURCE_BRANCH"
  echo "-> release trigger branch will be $RELEASE_TRIGGER_BRANCH"
  echo

  echo "== Initialization =="
  # 1. clone the repository to a temporary directory
  TEMP_CLONE_DIRECTORY=$(mktemp -d)
  echo "1. Cloning the repository at $GIT_REPOSITORY_URL to $TEMP_CLONE_DIRECTORY"
  git clone -q $GIT_REPOSITORY_URL $TEMP_CLONE_DIRECTORY
  if [ $? -gt 0 ]; then
    cleanUp
    echo " Unable to clone $GIT_REPOSITORY_URL"
    return 1
  fi

  cd $TEMP_CLONE_DIRECTORY

  # 2. checkout the source branch
  echo "2. Checking out the source branch: $SOURCE_BRANCH"
  git checkout -q $SOURCE_BRANCH
  if [ $? -gt 0 ]; then
    echo " Unable to checkout to $SOURCE_BRANCH branch"
    cleanUp
    return 1
  fi

  getProjectName

  echo
  echo "== Release trigger branch creation =="

  # 3. create the release trigger branch
  echo "3. Create the release trigger"
  git symbolic-ref HEAD refs/heads/$RELEASE_TRIGGER_BRANCH &&
  git reset

  command -v setopt >/dev/null 2>&1 # fix for ZSH
  if [ $? -eq 0 ]; then
    setopt localoptions rmstarsilent
    rm -rf $TEMP_CLONE_DIRECTORY/*
  else
    rm -rf $TEMP_CLONE_DIRECTORY/*
  fi

  echo "# $RELEASE_TRIGGER_BRANCH" > README.md &&
  git add README.md &&
  git commit -qm "[ci skip] Creating $RELEASE_TRIGGER_BRANCH branch"

  # 4. retrieve files and add them to the release trigger branch
  echo "4. Adding content to the release trigger branch"
  # .gitlab-ci.yml
    wget -q https://raw.githubusercontent.com/debovema/maven-auto-releaser/$MAVEN_AUTO_RELEASER_VERSION_TAG/release-trigger-branch/.gitlab-ci.yml -O ./.gitlab-ci.yml &&
    replaceProperties ./.gitlab-ci.yml &&
    git add ./.gitlab-ci.yml
  # README.md
    wget -q https://raw.githubusercontent.com/debovema/maven-auto-releaser/$MAVEN_AUTO_RELEASER_VERSION_TAG/release-trigger-branch/README.md -O ./README.md &&
    replaceProperties ./README.md &&
    git add ./README.md
  # fullAutoRelease.sh
    wget -q https://raw.githubusercontent.com/debovema/maven-auto-releaser/$MAVEN_AUTO_RELEASER_VERSION_TAG/release-trigger-branch/fullAutoRelease.sh -O ./fullAutoRelease.sh &&
    replaceProperties ./fullAutoRelease.sh &&
    git add ./fullAutoRelease.sh
  # prepareRelease.sh
    wget -q https://raw.githubusercontent.com/debovema/maven-auto-releaser/$MAVEN_AUTO_RELEASER_VERSION_TAG/release-trigger-branch/prepareRelease.sh -O ./prepareRelease.sh &&
    replaceProperties ./prepareRelease.sh &&
    git add ./prepareRelease.sh
  # release.properties
    wget -q https://raw.githubusercontent.com/debovema/maven-auto-releaser/$MAVEN_AUTO_RELEASER_VERSION_TAG/release-trigger-branch/release.properties -O ./release.properties &&
    replaceProperties ./release.properties &&
    git add ./release.properties

  git commit -qm "[ci skip] Adding auto release scripts to $RELEASE_TRIGGER_BRANCH branch"

  echo
  echo "== Finalization =="

  # 5. push the release trigger branch
  echo "5. Pushing the created release trigger branch"
  git push origin $RELEASE_TRIGGER_BRANCH -q

  PUSH_BRANCH_RESULT=$?
  if [ $PUSH_BRANCH_RESULT -gt 0 ]; then
    cleanUp
    echo " Unable to create the release trigger branch"
    return 1
  fi

  cleanUp
  return 0
}

createReleaseTriggerBranch_usage () {
  echo
  echo "Usage is $0 gitRepositoryURL"
}

createReleaseTriggerBranch_loadPropertiesFromFile () {
  unset GIT_REPOSITORY_URL RELEASE_TRIGGER_BRANCH SOURCE_BRANCH GIT_PARENT_REPOSITORY_URL GIT_PARENT_PARENT_REPOSITORY_URL GIT_PARENT_PARENT_PARENT_REPOSITORY_URL

  if [ "$#" -lt 1 ]; then
    echo
    echo " At least a Git repository URL is required" >&2
    return 1
  fi

  GIT_REPOSITORY_URL=$1

  # default values
  SOURCE_BRANCH=$DEFAULT_SOURCE_BRANCH
  RELEASE_TRIGGER_BRANCH=$DEFAULT_RELEASE_TRIGGER_BRANCH

  [ -f ./branch.properties ] && source ./branch.properties

  simpleConsoleLogger "" $NO_BANNER
  simpleConsoleLogger "Arguments:" $NO_BANNER
  simpleConsoleLogger " using '$RELEASE_TRIGGER_BRANCH' as release trigger branch" $NO_BANNER
  simpleConsoleLogger " using '$SOURCE_BRANCH' as source branch" $NO_BANNER
#  simpleConsoleLogger " using '$GIT_PARENT_REPOSITORY_URL' as parent repository URL" $NO_BANNER
#  simpleConsoleLogger " using '$GIT_PARENT_PARENT_REPOSITORY_URL' as great parent repository URL" $NO_BANNER
#  simpleConsoleLogger " using '$GIT_PARENT_PARENT_PARENT_REPOSITORY_URL' as great great parent repository URL" $NO_BANNER
}

# try to guess project name from repository name or POM if it exists (it should exist!)
getProjectName () {
  PROJECT_NAME="Unknown project"

  # use the name of the repository
  PROJECT_BASE_NAME=$(basename $GIT_REPOSITORY_URL)
  PROJECT_NAME=${PROJECT_BASE_NAME%.*}

  # if POM exists and has a <name> element
  MAVEN_PROJECT_EVAL=$(mvn -N -Dexpression=project.name help:evaluate)
  [ $? -eq 0 ] && MAVEN_PROJECT_NAME=$(echo "$MAVEN_PROJECT_EVAL" | grep -Ev '(^\[|Download\w+:)')
  [ $? -eq 0 ] && [ "$MAVEN_PROJECT_NAME" != "Maven Stub Project (No POM)" ] && PROJECT_NAME=$MAVEN_PROJECT_NAME

  echo " Project name will be: $PROJECT_NAME"
}

replaceProperties () {
  GIT_REPOSITORY_URL_ESCAPED=$(echo $GIT_REPOSITORY_URL | sed 's/[\/&]/\\&/g')
  GIT_REPOSITORY_BASENAME=$(basename $GIT_REPOSITORY_URL_ESCAPED | cut -f 1 -d '.')

  sed -i "s/^\(.*\)\(\$GIT_REPOSITORY_URL\)\(.*\)$/\1$GIT_REPOSITORY_URL_ESCAPED\3/" $1
  sed -i "s/^\(.*\)\(\$GIT_REPOSITORY_BASENAME\)\(.*\)$/\1$GIT_REPOSITORY_BASENAME\3/" $1
  sed -i "s/^\(.*\)\(\$PROJECT_NAME\)\(.*\)$/\1$PROJECT_NAME\3/" $1
  sed -i "s/^\(.*\)\(\$RELEASE_TRIGGER_BRANCH\)\(.*\)$/\1$RELEASE_TRIGGER_BRANCH\3/" $1
  sed -i "s/^\(.*\)\(\$MAVEN_AUTO_RELEASER_VERSION_TAG\)\(.*\)$/\1$MAVEN_AUTO_RELEASER_VERSION_TAG\3/" $1
  sed -i "s/^\(.*\)\(\$MAVEN_AUTO_RELEASER_VERSION\)\(.*\)$/\1$MAVEN_AUTO_RELEASER_VERSION\3/" $1
}

### release triggering ###

# the updateReleaseVersionsAndTrigger function will:
#  1. clone a repository
#  2. checkout the source branch (DEFAULT_SOURCE_BRANCH=master by default)
#  3. retrieve the next release and snapshot versions with the provided "increment policy" considering the current versions in the checked out branch
#  4. checkout the release triggering branch (called DEFAULT_RELEASE_TRIGGER_BRANCH=release-trigger by default)
#  5. update the release and snapshot versions properties in the release properties file (release.properties by default)
#  6. add, commit & push the changed release properties file (this will trigger the release for the project in the repository)
#
# arguments are provided by a KEY=VALUE file named release.properties in the same directory of this script
executeRelease () {
  parseCommandLine $@

  executeRelease_loadPropertiesFromFile $PARAMETERS

  if [ $? -gt 0 ]; then
    cleanUp
    return 1
  fi

  echo
  echo "Releasing $GIT_REPOSITORY_URL, source branch is $SOURCE_BRANCH, release trigger branch is $RELEASE_TRIGGER_BRANCH"
  echo

  echo "== Initialization =="
  # 1. clone the repository to a temporary directory
  TEMP_CLONE_DIRECTORY=$(mktemp -d)
  echo "1. Cloning the repository at $GIT_REPOSITORY_URL to $TEMP_CLONE_DIRECTORY"
  git clone -q $GIT_REPOSITORY_URL $TEMP_CLONE_DIRECTORY
  if [ $? -gt 0 ]; then
    echo " Unable to clone $GIT_REPOSITORY_URL"
    return 1
  fi

  cd $TEMP_CLONE_DIRECTORY

  # checkout the release branch
  echo " Checking out the release branch: $RELEASE_TRIGGER_BRANCH"
  git checkout -q $RELEASE_TRIGGER_BRANCH
  if [ $? -gt 0 ]; then
    echo
    echo " Unable to checkout to $RELEASE_TRIGGER_BRANCH branch"
    cleanUp
    return 1
  fi

  echo
  echo "== Versions update =="
  # 2. checkout the source branch
  echo "2. Checking out the source branch: $SOURCE_BRANCH"
  git checkout -q $SOURCE_BRANCH
  if [ $? -gt 0 ]; then
    echo " Unable to checkout to $SOURCE_BRANCH branch"
    cleanUp
    return 1
  fi

  # 3. retrieve the next versions
  echo "3. Retrieving the next versions"
  updateReleaseVersions $INCREMENT_POLICY
  if [ $? -gt 0 ]; then
    echo " Unable to update versions!";
    cleanUp
    return 1
  fi
  echo " New versions are: RELEASE_VERSION=$RELEASE_VERSION and DEV_VERSION=$DEV_VERSION"

  echo
  echo "== Release triggering =="
  # 4. checkout the release branch
  echo "4. Checking out the release branch: $RELEASE_TRIGGER_BRANCH"
  git checkout -q $RELEASE_TRIGGER_BRANCH

  # 5. update the release properties file with new versions
  echo "5. Updating the versions in release.properties"
  sed -i "s/\(RELEASE_VERSION=\).*\$/\1${RELEASE_VERSION}/" release.properties
  sed -i "s/\(DEV_VERSION=\).*\$/\1${DEV_VERSION}/" release.properties

  [ -z "$GIT_USER_NAME" ] || git config user.name $GIT_USER_NAME
  [ -z "$GIT_USER_EMAIL" ] || git config user.email $GIT_USER_EMAIL

  # 6. trigger the release by pushing the new file
  echo "6. Triggering the release"
  git add release.properties && git commit -m "Triggering release" &> /dev/null
  COMMIT_RESULT=$?
  if [ $COMMIT_RESULT -gt 0 ]; then
    echo " A problem occurred while committing, not pushing anything"
    if [ "$COMMIT_RESULT" == "128" ]; then
      echo " You must set a Git user name and email"
    fi
  else
    echo " Pushing to the release trigger branch";
    git push origin $RELEASE_TRIGGER_BRANCH -q
  fi

  # clean up and restore initial directory
  echo
  echo "== Clean up =="
  cd $OLDPWD
  echo " Removing temporary directory: $TEMP_CLONE_DIRECTORY"
  rm -rf $TEMP_CLONE_DIRECTORY

  return 0
}

executeRelease_loadPropertiesFromFile () {
  unset RELEASE_VERSION DEV_VERSION GIT_USER_NAME GIT_USER_EMAIL GIT_REPOSITORY_URL INCREMENT_POLICY SOURCE_BRANCH RELEASE_TRIGGER_BRANCH

  if [ "$#" -lt 1 ]; then
    echo " At least a Git repository URL is required" >&2
    return 1
  fi

  GIT_REPOSITORY_URL=$1

  # default values
  INCREMENT_POLICY=revision
  SOURCE_BRANCH=$DEFAULT_SOURCE_BRANCH
  RELEASE_TRIGGER_BRANCH=$DEFAULT_RELEASE_TRIGGER_BRANCH

  # use release.properties (to retrieve Git user config and to override arguments default values)
  source ./release.properties

  simpleConsoleLogger "" $NO_BANNER
  simpleConsoleLogger "Arguments:" $NO_BANNER
  simpleConsoleLogger " using '$INCREMENT_POLICY' as increment policy" $NO_BANNER
  simpleConsoleLogger " using '$RELEASE_TRIGGER_BRANCH' as release branch" $NO_BANNER
  simpleConsoleLogger " using '$SOURCE_BRANCH' as source branch" $NO_BANNER
}

updateReleaseVersions () {
  INCREMENT_POLICY=$1

  case $INCREMENT_POLICY in
    revision)
      echo " using revision increment policy"
      RELEASE_VERSION=$(mvn -q -N build-helper:parse-version -Dexec.executable="echo" -Dexec.args='${parsedVersion.majorVersion}.${parsedVersion.minorVersion}.${parsedVersion.incrementalVersion}' exec:exec)
      DEV_VERSION=$(mvn -q -N build-helper:parse-version -Dexec.executable="echo" -Dexec.args='${parsedVersion.majorVersion}.${parsedVersion.minorVersion}.${parsedVersion.nextIncrementalVersion}-${parsedVersion.qualifier}' exec:exec)
      ;;
    minor)
      echo " using minor increment policy"
      RELEASE_VERSION=$(mvn -q -N build-helper:parse-version -Dexec.executable="echo" -Dexec.args='${parsedVersion.majorVersion}.${parsedVersion.nextMinorVersion}.0' exec:exec)
      DEV_VERSION=$(mvn -q -N build-helper:parse-version -Dexec.executable="echo" -Dexec.args='${parsedVersion.majorVersion}.${parsedVersion.nextMinorVersion}.1-${parsedVersion.qualifier}' exec:exec)
      ;;
    major)
      echo " using major increment policy"
      RELEASE_VERSION=$(mvn -q -N build-helper:parse-version -Dexec.executable="echo" -Dexec.args='${parsedVersion.nextMajorVersion}.0.0' exec:exec)
      DEV_VERSION=$(mvn -q -N build-helper:parse-version -Dexec.executable="echo" -Dexec.args='${parsedVersion.nextMajorVersion}.0.1-${parsedVersion.qualifier}' exec:exec)
      ;;
    *)
      echo " $INCREMENT_POLICY is not a valid increment policy"
      echo " A valid increment policy is a value in revision, minor or major"
      return 1
      ;;
  esac
}

### common

# common command line parser to convert command line switch to variables
# this will also set PARAMETERS variable with all command line arguments without switches
parseCommandLine () {
  unset OPTS NO_BANNER NO_COMMAND_LINE_OVERRIDE RELEASE_TRIGGER_BRANCH

  [ -z ${JAVA_HOME+x} ] && echo "JAVA_HOME is not set!" && exit 1

  OLDPWD1=`pwd`

  OPTS=`getopt -o '' -l no-banner,no-cmd-line-override,release-trigger-branch: -- "$@"`

  if [ $? != 0 ]
  then
    echo "Warning: getopt failed to parse command line arguments"
  fi

  eval set -- "$OPTS"
  NO_BANNER=false
  NO_COMMAND_LINE_OVERRIDE=false

  while true ; do
    case "$1" in
      --release-trigger-branch) RELEASE_TRIGGER_BRANCH=$2; shift 2;;
      --no-banner) NO_BANNER=true; shift;;
      --no-cmd-line-override) NO_COMMAND_LINE_OVERRIDE=true; shift;;
      --) shift; break;;
    esac
  done

  # remove switches
  PARAMETERS=""
  for arg
  do
    PARAMETERS="$PARAMETERS $arg"
  done

  PARAMETERS=$(echo $PARAMETERS | xargs)

  simpleConsoleLogger "Maven auto releaser v$MAVEN_AUTO_RELEASER_VERSION" $NO_BANNER
  simpleConsoleLogger " https://github.com/debovema/maven-auto-releaser/tree/$MAVEN_AUTO_RELEASER_VERSION_TAG" $NO_BANNER
}

cleanUp () {
  # clean up and restore initial directory
  if [ -d "$TEMP_CLONE_DIRECTORY" ]; then
    echo
    echo "== Clean up =="
    cd $OLDPWD1
    echo " Removing temporary directory: $TEMP_CLONE_DIRECTORY"
    rm -rf $TEMP_CLONE_DIRECTORY
    echo
  fi
}

# log first parameter $1 if second parameter $2 is not "true"
simpleConsoleLogger () {
  [ "$2" = "true" ] || echo "$1"
}
