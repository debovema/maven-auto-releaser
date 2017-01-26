#/bin/sh

MAVEN_AUTO_RELEASER_VERSION=1.0-beta

### release trigger branch creation ###

# the createReleaseTriggerBranch function will:
#  1. clone a repository
#  2. 
#
# arguments are:
#  gitRepositoryURL
createReleaseTriggerBranch () {
  parseCommandLine $@

  createReleaseTriggerBranch_initCommandLineArguments $PARAMETERS

  echo
  echo "Creating release trigger branch on repository $GIT_REPOSITORY_URL, release trigger branch will be $RELEASE_TRIGGER_BRANCH"
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

  getProjectName

  # 2. create the release trigger branch (called release by default)
  git symbolic-ref HEAD refs/heads/$RELEASE_TRIGGER_BRANCH &&
  git reset &&
  rm -rf $TEMP_CLONE_DIRECTORY/* &&
  echo "# $RELEASE_TRIGGER_BRANCH" > README.md &&
  git add README.md &&
  git commit -m "Creating $RELEASE_TRIGGER_BRANCH branch"

  # 3. retrieve files and add them to the release trigger branch
  wget -q https://raw.githubusercontent.com/debovema/maven-auto-releaser/master/release-trigger-branch/.gitlab-ci.yml -O ./.gitlab-ci.yml &&
  replaceProperties ./.gitlab-ci.yml &&
  git add ./.gitlab-ci.yml
  wget -q https://raw.githubusercontent.com/debovema/maven-auto-releaser/master/release-trigger-branch/README.md -O ./README.md &&
  replaceProperties ./README.md &&
  git add ./README.md
  wget -q https://raw.githubusercontent.com/debovema/maven-auto-releaser/master/release-trigger-branch/fullAutoRelease.sh -O ./fullAutoRelease.sh &&
  replaceProperties ./fullAutoRelease.sh &&
  git add ./fullAutoRelease.sh
  wget -q https://raw.githubusercontent.com/debovema/maven-auto-releaser/master/release-trigger-branch/prepareRelease.sh -O ./prepareRelease.sh &&
  replaceProperties ./prepareRelease.sh &&
  git add ./prepareRelease.sh
  wget -q https://raw.githubusercontent.com/debovema/maven-auto-releaser/master/release-trigger-branch/release.properties -O ./release.properties &&
  replaceProperties ./release.properties &&
  git add ./release.properties

  git commit -m "Adding auto release scripts to $RELEASE_TRIGGER_BRANCH branch"

  # 4. push the release trigger branch
  git push origin $RELEASE_TRIGGER_BRANCH

  PUSH_BRANCH_RESULT=$?
  if [ $PUSH_BRANCH_RESULT -gt 0 ]; then
    cleanUp
    echo " Unable to create the release trigger branch"
    return 1
  fi

  cleanUp
  return 0
}

getProjectName () {
  PROJECT_NAME="Unknown project"

  # use the name of the repository
  PROJECT_BASE_NAME=$(basename $GIT_REPOSITORY_URL)
  PROJECT_NAME=${PROJECT_BASE_NAME%.*}

  # if POM exists and has a <name> element
  MAVEN_PROJECT_EVAL=$(mvn -N -Dexpression=project.name help:evaluate)
  [ $? -eq 0 ] && MAVEN_PROJECT_NAME=$(echo "$MAVEN_PROJECT_EVAL" | grep -Ev '(^\[|Download\w+:)')
  [ $? -eq 0 ] && PROJECT_NAME=$MAVEN_PROJECT_NAME

  echo $PROJECT_NAME
}

replaceProperties () {
  GIT_REPOSITORY_URL_ESCAPED=$(echo $GIT_REPOSITORY_URL | sed -e 's/[\/&]/\\&/g')
  sed -i "s/^\(.*\)\(\$GIT_REPOSITORY_URL\)\(.*\)$/\1$GIT_REPOSITORY_URL_ESCAPED\3/" $1
  sed -i "s/^\(.*\)\(\$PROJECT_NAME\)\(.*\)$/\1$PROJECT_NAME\3/" $1
  sed -i "s/^\(.*\)\(\$RELEASE_TRIGGER_BRANCH\)\(.*\)$/\1$RELEASE_TRIGGER_BRANCH\3/" $1
}

createReleaseTriggerBranch_initCommandLineArguments () {
  unset GIT_REPOSITORY_URL

  if [ "$#" -lt 1 ]; then
    echo " At least a Git repository URL is required" >&2
    return 1
  fi

  GIT_REPOSITORY_URL=$1

  # default values
  RELEASE_TRIGGER_BRANCH=release

  simpleConsoleLogger "Arguments:" $NO_BANNER
  # use arguments if they exist
  if [ "$#" -lt 2 ]; then
    simpleConsoleLogger " using '$RELEASE_TRIGGER_BRANCH' as default release trigger branch" $NO_BANNER
  else
    RELEASE_TRIGGER_BRANCH=$2
    simpleConsoleLogger " using '$RELEASE_TRIGGER_BRANCH' as release trigger branch" $NO_BANNER
  fi

}

### release triggering ###

# the updateReleaseVersionsAndTrigger function will:
#  1. clone a repository
#  2. checkout the source branch (master by default)
#  3. retrieve the next release and snapshot versions with the provided "increment policy" considering the current versions in the checked out branch
#  4. checkout the release triggerring branch (release by default)
#  5. update the release and snapshot versions properties in the release properties file (release.properties by default)
#  6. add, commit & push the changed release properties file (this will trigger the release for the project in the repository)
#
# arguments are:
#  gitRepositoryURL [incrementPolicy] [sourceBranch] [releaseBranch] [commandLineOverridesConfig]
#
# arguments can also be provided by an optional KEY=VALUE file named release.properties in the same directory of this script
updateReleaseVersionsAndTrigger () {
  parseCommandLine $@

  updateReleaseVersionsAndTrigger_initCommandLineArguments $PARAMETERS

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

  sourceReleaseProperties

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
    git push origin release -q
  fi

  # clean up and restore initial directory
  echo
  echo "== Clean up =="
  cd $OLDPWD
  echo " Removing temporary directory: $TEMP_CLONE_DIRECTORY"
  rm -rf $TEMP_CLONE_DIRECTORY

  return 0
}

updateReleaseVersionsAndTrigger_initCommandLineArguments () {
  unset RELEASE_VERSION DEV_VERSION GIT_USER_NAME GIT_USER_EMAIL GIT_REPOSITORY_URL INCREMENT_POLICY SOURCE_BRANCH RELEASE_TRIGGER_BRANCH

  if [ "$#" -lt 1 ]; then
    echo " At least a Git repository URL is required" >&2
    return 1
  fi

  GIT_REPOSITORY_URL=$1

  # default values
  INCREMENT_POLICY=revision
  SOURCE_BRANCH=master
  RELEASE_TRIGGER_BRANCH=release

  # use optional release.properties (to retrieve Git user config and to override arguments default values)
  [ ! -f release.properties ] || . ./release.properties

  simpleConsoleLogger "Arguments:" $NO_BANNER
  # use arguments if they exist
  if [ "$#" -lt 2 ]; then
    simpleConsoleLogger " using '$INCREMENT_POLICY' as default increment policy" $NO_BANNER
  else
    INCREMENT_POLICY=$2
    simpleConsoleLogger " using '$INCREMENT_POLICY' as increment policy" $NO_BANNER
  fi
  if [ "$#" -lt 3 ]; then
    simpleConsoleLogger " using '$SOURCE_BRANCH' as default source branch" $NO_BANNER
  else
    SOURCE_BRANCH=$3
    simpleConsoleLogger " using '$SOURCE_BRANCH' as source branch" $NO_BANNER
  fi
  if [ "$#" -lt 4 ]; then
    simpleConsoleLogger " using '$RELEASE_TRIGGER_BRANCH' as default release branch" $NO_BANNER
  else
    RELEASE_TRIGGER_BRANCH=$4
    simpleConsoleLogger " using '$RELEASE_TRIGGER_BRANCH' as release branch" $NO_BANNER
  fi
}

sourceReleaseProperties () {
  # use optional release.properties (to retrieve Git user config and to override increment policy)
  # this is not the same one as previous one but the one from the repository
  OLD_INCREMENT_POLICY=$INCREMENT_POLICY
  OLD_SOURCE_BRANCH=$SOURCE_BRANCH
  OLD_RELEASE_TRIGGER_BRANCH=$RELEASE_TRIGGER_BRANCH

  echo " Sourcing release.properties file"
  [ ! -f release.properties ] || . ./release.properties

  if [ $OLD_INCREMENT_POLICY != $INCREMENT_POLICY ]; then
    if [ "$NO_COMMAND_LINE_OVERRIDE" == "true" ]; then
      INCREMENT_POLICY=$OLD_INCREMENT_POLICY
    else
      echo " now using '$INCREMENT_POLICY' as increment policy"
    fi
  fi
  if [ $OLD_SOURCE_BRANCH != $SOURCE_BRANCH ]; then
    if [ "$NO_COMMAND_LINE_OVERRIDE" == "true" ]; then
      SOURCE_BRANCH=$OLD_SOURCE_BRANCH
    else
      echo " now using '$SOURCE_BRANCH' as increment policy"
    fi
  fi
  if [ $OLD_RELEASE_TRIGGER_BRANCH != $RELEASE_TRIGGER_BRANCH ]; then
    if [ "$NO_COMMAND_LINE_OVERRIDE" == "true" ]; then
      RELEASE_TRIGGER_BRANCH=$OLD_RELEASE_TRIGGER_BRANCH
    else
      echo " now using '$RELEASE_TRIGGER_BRANCH' as increment policy"
    fi
  fi
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
  unset OPTS NO_BANNER NO_COMMAND_LINE_OVERRIDE

  OPTS=`getopt -o '' -l no-banner,no-cmd-line-override -- "$@"`

  if [ $? != 0 ]
  then
    echo "Warning: getopt failed to parse command line arguments"
  fi

  eval set -- "$OPTS"

  while true ; do
    case "$1" in
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

  simpleConsoleLogger "Maven auto releaser v$MAVEN_AUTO_RELEASER_VERSION" $NO_BANNER
  simpleConsoleLogger " https://github.com/debovema/maven-auto-releaser" $NO_BANNER
}

cleanUp () {
  # clean up and restore initial directory
  if [ -d "$TEMP_CLONE_DIRECTORY" ]; then
    echo
    echo "== Clean up =="
    cd $OLDPWD
    echo " Removing temporary directory: $TEMP_CLONE_DIRECTORY"
    rm -rf $TEMP_CLONE_DIRECTORY
    echo
  fi
}

simpleConsoleLogger () {
    [ "$2" == "true" ] || echo "$1"
}