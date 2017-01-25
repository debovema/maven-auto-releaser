#/bin/sh

MAVEN_AUTO_RELEASER_VERSION=1.0-beta

# the updateReleaseVersionsAndTrigger function will:
#  1. clone a repository
#  2. checkout the source branch (master by default)
#  3. retrieve the next release and snapshot versions with the provided "increment policy" considering the current versions in the checked out branch
#  4. checkout the release triggerring branch (release by default)
#  5. update the release and snapshot versions properties in the release properties file (release.properties by default)
#  6. add, commit & push the changed release properties file (this will trigger the release for the project in the repository)
#
# arguments are:
#  gitRepositoryURL [incrementPolicy] [sourceBranch] [releaseBranch]
#
# arguments can only provided by an optional KEY=VALUE file named release.properties in the same directory of this script
updateReleaseVersionsAndTrigger () {
  echo "Maven auto releaser v$MAVEN_AUTO_RELEASER_VERSION"
  echo " https://github.com/debovema/maven-auto-releaser"
  echo

  if [ "$#" -lt 1 ]; then
    echo "${FUNCNAME}(): at least a Git repository URL is required" >&2
    return 1
  fi

  GIT_REPOSITORY_URL=$1

  # default values
  INCREMENT_POLICY=revision
  SOURCE_BRANCH=master
  RELEASE_TRIGGER_BRANCH=release

  # use optional release.properties (to retrieve Git user config and to override arguments default values)
  [ ! -f release.properties ] || . ./release.properties

  echo "Arguments:"
  # use arguments if they exist
  if [ "$#" -lt 2 ]; then
    echo " using '$INCREMENT_POLICY' as default increment policy"
  else
    INCREMENT_POLICY=$2
    echo " using '$INCREMENT_POLICY' as increment policy"
  fi
  if [ "$#" -lt 3 ]; then
    echo " using '$SOURCE_BRANCH' as default source branch"
  else
    SOURCE_BRANCH=$3
    echo " using '$SOURCE_BRANCH' as source branch"
  fi
  if [ "$#" -lt 4 ]; then
    echo " using '$RELEASE_TRIGGER_BRANCH' as default release branch"
  else
    SOURCE_BRANCH=$4
    echo " using '$RELEASE_TRIGGER_BRANCH' as release branch"
  fi

  echo
  echo "Releasing $GIT_REPOSITORY_URL, source branch is $SOURCE_BRANCH, release trigger branch is $RELEASE_TRIGGER_BRANCH"
  echo

  echo "== Initialization =="
  # 1. clone the repository to a temporary directory
  TEMP_CLONE_DIRECTORY=$(mktemp -d)
  echo "1. Cloning the repository at $GIT_REPOSITORY_URL to $TEMP_CLONE_DIRECTORY"
  git clone -q $GIT_REPOSITORY_URL $TEMP_CLONE_DIRECTORY
  cd $TEMP_CLONE_DIRECTORY

  # checkout the release branch
  echo " Checking out the release branch: $RELEASE_TRIGGER_BRANCH"
  git checkout -q $RELEASE_TRIGGER_BRANCH

  # use optional release.properties (to retrieve Git user config and to override arguments default values)
  # this is not the same one as previous one but the one from the repository
  echo " Sourcing release.properties file"
  [ ! -f release.properties ] || . ./release.properties

  echo
  echo "== Versions update =="
  # 2. checkout the source branch
  echo "2. Checking out the source branch: $SOURCE_BRANCH"
  git checkout -q $SOURCE_BRANCH

  # 3. retrieve the next versions
  echo "3. Retrieving the next versions"
  RELEASE_VERSION=$(mvn -q -N build-helper:parse-version -Dexec.executable="echo" -Dexec.args='${parsedVersion.majorVersion}.${parsedVersion.minorVersion}.${parsedVersion.incrementalVersion}' exec:exec)
  DEV_VERSION=$(mvn -q -N build-helper:parse-version -Dexec.executable="echo" -Dexec.args='${parsedVersion.majorVersion}.${parsedVersion.minorVersion}.${parsedVersion.nextIncrementalVersion}-${parsedVersion.qualifier}' exec:exec)
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
  git add release.properties && git commit -q -m "Triggering release" &> /dev/null
  COMMIT_RESULT=$?
  if [ $COMMIT_RESULT -gt 0 ]; then
    echo "problem with commit"
  else
    echo " Push to the release trigger branch";
    #git push origin release
  fi

  # clean up and restore initial directory
  echo
  echo "== Clean up =="
  cd $OLDPWD
  echo " Removing temporary directory: $TEMP_CLONE_DIRECTORY"
  rm -rf $TEMP_CLONE_DIRECTORY

  return 0
}
