#/bin/sh

# the updateVersions function will:
#  1. clone a repository
#  2. checkout the source branch (master by default)
#  3. retrieve the next release and snapshot versions with the provided "increment policy" considering the current versions in the checked out branch
#  4. checkout the release triggerring branch (release by default)
#  5. update the release and snapshot versions properties in the release properties file (release.properties by default)
#  6. add, commit & push the changed release properties file (this will trigger the release for the project in the repository)
#
# arguments are:
#  gitRepositoryURL [incrementPolicy] [sourceBranch] [releaseBranch]
updateVersions () {
  if [ "$#" -lt 1 ]; then
    echo "${FUNCNAME}(): at least a Git repository URL is required" >&2
    exit 1
  fi
  GIT_REPOSITORY_URL=$1
  # default values
  INCREMENT_POLICY=revision
  SOURCE_BRANCH=master
  RELEASE_BRANCH=release
  if [ "$#" -lt 2 ]; then
    echo "${FUNCNAME}(): using '$INCREMENT_POLICY' as default increment policy"
  else
    INCREMENT_POLICY=$2
    echo "${FUNCNAME}(): using '$INCREMENT_POLICY' as increment policy"
  fi
  if [ "$#" -lt 3 ]; then
    echo "${FUNCNAME}(): using '$SOURCE_BRANCH' as default source branch"
  else
    SOURCE_BRANCH=$3
    echo "${FUNCNAME}(): using '$SOURCE_BRANCH' as source branch"
  fi
  if [ "$#" -lt 4 ]; then
    echo "${FUNCNAME}(): using '$RELEASE_BRANCH' as default release branch"
  else
    SOURCE_BRANCH=$4
    echo "${FUNCNAME}(): using '$RELEASE_BRANCH' as release branch"
  fi

  echo "Updating $GIT_REPOSITORY_URL, source branch is $SOURCE_BRANCH, release branch is $RELEASE_BRANCH"

  # 1. clone the repository to a temporary directory
  TEMP_CLONE_DIRECTORY=$(mktemp -d)
  git clone $GIT_REPOSITORY_URL $TEMP_CLONE_DIRECTORY
  cd $TEMP_CLONE_DIRECTORY

  # 2. checkout the source branch
  git checkout $SOURCE_BRANCH

  # 3. retrieve the next versions
  RELEASE_VERSION=$(mvn -q -N build-helper:parse-version -Dexec.executable="echo" -Dexec.args='${parsedVersion.majorVersion}.${parsedVersion.minorVersion}.${parsedVersion.incrementalVersion}' exec:exec)
  DEV_VERSION=$(mvn -q -N build-helper:parse-version -Dexec.executable="echo" -Dexec.args='${parsedVersion.majorVersion}.${parsedVersion.minorVersion}.${parsedVersion.nextIncrementalVersion}-${parsedVersion.qualifier}' exec:exec)

  # 4. checkout the release branch
  git checkout $RELEASE_BRANCH

  # 5. update the release properties file with new versions
  sed -i "s/\(RELEASE_VERSION=\).*\$/\1${RELEASE_VERSION}/" release.properties
  sed -i "s/\(DEV_VERSION=\).*\$/\1${DEV_VERSION}/" release.properties

  # 6. trigger the release by pushing the new file
  git add release.properties && git commit -m "Triggering release"
  #git push origin release

  cd $OLDPWD

  return 0
} 
