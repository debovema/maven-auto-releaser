#!/bin/sh

# maven-auto-releaser.sh
# released by Mathieu Debove (https://github.com/debovema) under Apache License, Version 2.0

MAVEN_AUTO_RELEASER_VERSION=1.0.0-beta5 # this is the displayed version (in banner)
MAVEN_AUTO_RELEASER_VERSION_TAG=v$MAVEN_AUTO_RELEASER_VERSION #v$MAVEN_AUTO_RELEASER_VERSION # this is the Git tag used to retrieve template files

DEFAULT_RELEASE_TRIGGER_BRANCH=release-trigger
DEFAULT_SOURCE_BRANCH=master
DEFAULT_DOCKER_IMAGE=debovema/docker-mvn
DEFAULT_GIT_USER_NAME="Auto Releaser"
DEFAULT_GIT_USER_EMAIL="auto@release.io"
DEFAULT_INCREMENT_POLICY=revision
DEFAULT_MAVEN_RELEASER=unleash
DEFAULT_MODE_SCRIPT_CONTENT=remote

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

  [ -z "$GIT_USER_NAME" ] || git config user.name $GIT_USER_NAME
  [ -z "$GIT_USER_EMAIL" ] || git config user.email $GIT_USER_EMAIL

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
    FILE_TO_COPY=.gitlab-ci.yml
    copyFileFromToReleaseTriggerBranch  
  # README.md
    FILE_TO_COPY=README.md
    copyFileFromToReleaseTriggerBranch  
  # release.sh
    FILE_TO_COPY=release.sh
    copyFileFromToReleaseTriggerBranch  
  # release.properties
    FILE_TO_COPY=release.properties
    copyFileFromToReleaseTriggerBranch  
 
  git commit -qm "[ci skip] Adding auto release scripts to $RELEASE_TRIGGER_BRANCH branch"

  echo
  echo "== Finalization =="

  # 5. push the release trigger branch
  echo "5. Pushing the created release trigger branch"
  git push origin $RELEASE_TRIGGER_BRANCH -q > /dev/null 2>&1

  PUSH_BRANCH_RESULT=$?
  if [ $PUSH_BRANCH_RESULT -gt 0 ]; then
    cleanUp
    echo " Unable to create the release trigger branch"
    return 1
  fi

  echo " Successfully pushed the release trigger branch '$RELEASE_TRIGGER_BRANCH'"

  cleanUp
  return 0
}

copyFileFromToReleaseTriggerBranch  () {
  curl -s https://raw.githubusercontent.com/debovema/maven-auto-releaser/$MAVEN_AUTO_RELEASER_VERSION_TAG/release-trigger-branch/$FILE_TO_COPY -o ./$FILE_TO_COPY &&
  replaceProperties ./$FILE_TO_COPY &&
  git add ./$FILE_TO_COPY
}

createReleaseTriggerBranch_usage () {
  echo
  echo "Usage is $0 gitRepositoryURL"
}

createReleaseTriggerBranch_loadPropertiesFromFile () {
  unset GIT_REPOSITORY_URL RELEASE_TRIGGER_BRANCH SOURCE_BRANCH GIT_USER_NAME GIT_USER_EMAIL

  if [ "$#" -lt 1 ]; then
    echo
    echo " At least a Git repository URL is required" >&2
    return 1
  fi

  GIT_REPOSITORY_URL=$1

  defaultValues 

  [ -f ./branch.properties ] && source ./branch.properties

  [ ! -z "$RELEASE_TRIGGER_BRANCH_SEMVER" ] && RELEASE_TRIGGER_BRANCH=$RELEASE_TRIGGER_BRANCH_SEMVER
  [ ! -z "$INCREMENT_POLICY_SEMVER" ] && INCREMENT_POLICY=$INCREMENT_POLICY_SEMVER

  displayBanner
  simpleConsoleLogger "" $NO_BANNER
  simpleConsoleLogger "Arguments:" $NO_BANNER
  simpleConsoleLogger " using '$RELEASE_TRIGGER_BRANCH' as release trigger branch" $NO_BANNER
  simpleConsoleLogger " using '$SOURCE_BRANCH' as source branch" $NO_BANNER
}

# try to guess project name from repository name or POM if it exists (it should exist!)
getProjectName () {
  PROJECT_NAME="Unknown project"

  # use the name of the repository
  PROJECT_BASE_NAME=$(basename $GIT_REPOSITORY_URL)
  PROJECT_NAME=${PROJECT_BASE_NAME%.*}

  # if POM exists and has a <name> element
  MAVEN_PROJECT_EVAL=$(mvn -B -N -Dexpression=project.name help:evaluate)
  [ $? -eq 0 ] && MAVEN_PROJECT_NAME=$(echo "$MAVEN_PROJECT_EVAL" | grep -Ev '(^\[|Download\w+:)')
  [ $? -eq 0 ] && [ "$MAVEN_PROJECT_NAME" != "Maven Stub Project (No POM)" ] && PROJECT_NAME=$MAVEN_PROJECT_NAME

  echo " Project name will be: $PROJECT_NAME"
}

# the deleteReleaseTriggerBranch function will:
#  1. clone a repository
#  2. delete the release trigger branch (called DEFAULT_RELEASE_TRIGGER_BRANCH=release-trigger by default)
deleteReleaseTriggerBranch () {
  parseCommandLine $@

  deleteReleaseTriggerBranch_loadPropertiesFromFile $PARAMETERS

  if [ $? -gt 0 ]; then
    cleanUp
    deleteReleaseTriggerBranch_usage
    return 1
  fi

  echo
  echo "Deleting release trigger branch on repository $GIT_REPOSITORY_URL"
  echo "-> release trigger branch is $RELEASE_TRIGGER_BRANCH"
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

  [ -z "$GIT_USER_NAME" ] || git config user.name $GIT_USER_NAME
  [ -z "$GIT_USER_EMAIL" ] || git config user.email $GIT_USER_EMAIL

  # 2. delete the release trigger branch
  echo "2. Deleting remote release trigger branch '$RELEASE_TRIGGER_BRANCH'"
  git push -q --delete origin $RELEASE_TRIGGER_BRANCH # TODO: what if remote name is not origin ?
  if [ $? -gt 0 ]; then
    echo " Unable to delete $RELEASE_TRIGGER_BRANCH branch"
    cleanUp
    return 1
  fi

  cleanUp
  return 0
}

deleteReleaseTriggerBranch_usage () {
  echo
  echo "Usage is $0 gitRepositoryURL"
}

deleteReleaseTriggerBranch_loadPropertiesFromFile () {
  unset GIT_REPOSITORY_URL

  if [ "$#" -lt 1 ]; then
    echo
    echo " At least a Git repository URL is required" >&2
    return 1
  fi

  GIT_REPOSITORY_URL=$1

  defaultValues 

  [ -f ./branch.properties ] && source ./branch.properties

  [ ! -z "$RELEASE_TRIGGER_BRANCH_SEMVER" ] && RELEASE_TRIGGER_BRANCH=$RELEASE_TRIGGER_BRANCH_SEMVER

  displayBanner
  simpleConsoleLogger "" $NO_BANNER
  simpleConsoleLogger "Arguments:" $NO_BANNER
  simpleConsoleLogger " using '$RELEASE_TRIGGER_BRANCH' as release trigger branch" $NO_BANNER
}

createSemVerReleaseTriggerBranches () {
  unset GIT_REPOSITORY_URL

  if [ "$#" -lt 1 ]; then
    echo
    echo " At least a Git repository URL is required" >&2
    return 1
  fi

  GIT_REPOSITORY_URL=$1

  defaultValues

  [ -f ./branch.properties ] && source ./branch.properties

  ORIGINAL_RELEASE_TRIGGER_BRANCH=$RELEASE_TRIGGER_BRANCH

  RELEASE_TRIGGER_BRANCH_SEMVER=$ORIGINAL_RELEASE_TRIGGER_BRANCH-revision
  INCREMENT_POLICY_SEMVER=revision
  createReleaseTriggerBranch $@

  RELEASE_TRIGGER_BRANCH_SEMVER=$ORIGINAL_RELEASE_TRIGGER_BRANCH-minor
  INCREMENT_POLICY_SEMVER=minor
  createReleaseTriggerBranch $@

  RELEASE_TRIGGER_BRANCH_SEMVER=$ORIGINAL_RELEASE_TRIGGER_BRANCH-major
  INCREMENT_POLICY_SEMVER=major
  createReleaseTriggerBranch $@
}

deleteSemVerReleaseTriggerBranches () {
  unset GIT_REPOSITORY_URL

  if [ "$#" -lt 1 ]; then
    echo
    echo " At least a Git repository URL is required" >&2
    return 1
  fi

  GIT_REPOSITORY_URL=$1

  defaultValues

  [ -f ./branch.properties ] && source ./branch.properties

  ORIGINAL_RELEASE_TRIGGER_BRANCH=$RELEASE_TRIGGER_BRANCH

  RELEASE_TRIGGER_BRANCH_SEMVER=$ORIGINAL_RELEASE_TRIGGER_BRANCH-revision
  deleteReleaseTriggerBranch $@

  RELEASE_TRIGGER_BRANCH_SEMVER=$ORIGINAL_RELEASE_TRIGGER_BRANCH-minor
  deleteReleaseTriggerBranch $@

  RELEASE_TRIGGER_BRANCH_SEMVER=$ORIGINAL_RELEASE_TRIGGER_BRANCH-major
  deleteReleaseTriggerBranch $@
}

### release triggering runtime ###

# the initCI function will:
#  1. check that Git is installed
#  2. check that SSH Agent is installed
#  3. launch an SSH Agent
#  4. add the provided private key to the SSH Agent
#  5. disable StrictHostKeyChecking for SSH
initCI () {
  # check git exists
  echo "Checking Git..."
  which git > /dev/null 2>&1 || ( echo "git executable is not found in docker-registry.square-it.grp:5000/soft/maven:3.5.2-4\nUse a Docker image with prerequisites installed" )
  echo "Checked  Git"
  # check ssh-agent exists
  echo "Checking SSH Agent"
  which ssh-agent > /dev/null 2>&1 || ( echo "ssh-agent executable is not found in docker-registry.square-it.grp:5000/soft/maven:3.5.2-4\nUse a Docker image with prerequisites installed" )
  echo "Checked  SSH Agent"
  # run ssh-agent
  echo "Launching an SSH agent"
  eval $(ssh-agent -s) > /dev/null
  # add ssh key stored in SSH_PRIVATE_KEY variable to the agent store
  echo "Adding SSH private key..."
  ssh-add <(echo "$SSH_PRIVATE_KEY") > /dev/null
  echo "Added  SSH private key"
  # disable host key checking (on Docker runners only)
  [[ -f /.dockerenv ]] && mkdir -p ~/.ssh && touch ~/.ssh/config && echo -e "Host *\n\tStrictHostKeyChecking no\n\n" > ~/.ssh/config
}

# the createTriggerTag function will:
#  1. clone a repository
#  2. checkout its release trigger branch (called DEFAULT_RELEASE_TRIGGER_BRANCH=release-trigger by default)
#  3. checkout a new temporary branch from release trigger branch
#  4. save SHA of latest commit of the source branch (called DEFAULT_SOURCE_BRANCH=master by default) in the release.properties file
#  5. create a commit on the temporary branch (it will not trigger any Gitlab CI build)
#  6. optionally, if versions have not been set manually (manual edition is detected automatically),
#     retrieve the next release and snapshot versions with the provided "increment policy" considering the current versions in the checked out branch
#  7. create a tag from the latest commit of temporary branch (it will trigger a Gitlab CI build to actually launch the release job)
#  8. push the commit and tag
#
# arguments are provided by a KEY=VALUE file named release.properties in the same directory of this script
createTriggerTag () {
  GIT_REPOSITORY_URL="ssh://$(git config --get remote.origin.url | sed 's|https\?://gitlab-ci-token:.*@\(.*\)|git@\1|')"

  defaultValues

  [ -f ./release.properties ] && source ./release.properties

  # get SHA of the latest commit of the source branch
  RELEASE_COMMIT_SHA=$(git rev-parse $SOURCE_BRANCH)
  # generate the tag trigger name composed of the release trigger branch, the version to be released, the SHA of the latest commit of the source branch
  TAG_TRIGGER="$RELEASE_TRIGGER_BRANCH-$RELEASE_VERSION-$(git rev-parse $SOURCE_BRANCH)"
 
  echo
  echo "Creating a trigger tag in $GIT_REPOSITORY_URL, source branch is $SOURCE_BRANCH, release trigger branch is $RELEASE_TRIGGER_BRANCH"
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

  # 2. checkout the release trigger branch
  echo "2. Checking out the release branch: $RELEASE_TRIGGER_BRANCH"
  git checkout -q $RELEASE_TRIGGER_BRANCH
  if [ $? -gt 0 ]; then
    echo
    echo " Unable to checkout to $RELEASE_TRIGGER_BRANCH branch"
    cleanUp
    return 1
  fi

  TMP_RELEASE_TRIGGER_BRANCH=$RELEASE_TRIGGER_BRANCH-tmp
  # 3. create a new temporary branch
  echo "3. Creating temporary branch: $TMP_RELEASE_TRIGGER_BRANCH"

  # create a new temporary branch from the release trigger branch
  git checkout -qb $TMP_RELEASE_TRIGGER_BRANCH
  if [ $? -gt 0 ]; then
    echo
    echo " Unable to checkout to $TMP_RELEASE_TRIGGER_BRANCH branch"
    cleanUp
    return 1
  fi

  [ -z "$GIT_USER_NAME" ] || git config user.name $GIT_USER_NAME
  [ -z "$GIT_USER_EMAIL" ] || git config user.email $GIT_USER_EMAIL
 
  echo
  echo "== Release updates =="

  # 4.
  # check whether release.properties was changed in last commit (greater than zero if true)
  VERSIONS_SET_MANUALLY=0
  [[ "$(git rev-parse @:release.properties)" != "$(git rev-parse @~:release.properties)" ]] && VERSIONS_SET_MANUALLY=1

  if [ "$RELEASE_VERSION" == "0.0.0" ] || [ $VERSIONS_SET_MANUALLY -eq 0 ]; then
    echo "4. Updating versions"
    versionsUpdate

    # switch back to the temporary branch
    git checkout -q $TMP_RELEASE_TRIGGER_BRANCH
    if [ $? -gt 0 ]; then
      echo
      echo " Unable to checkout to $TMP_RELEASE_TRIGGER_BRANCH branch"
      cleanUp
      return 1
    fi

    echo " c. Updating the versions in release.properties"
    sed -i "s/\(RELEASE_VERSION=\).*\$/\1${RELEASE_VERSION}/" release.properties
    sed -i "s/\(DEV_VERSION=\).*\$/\1${DEV_VERSION}/" release.properties
  else
    echo "4. Not updating versions"
  fi

  # get SHA of the latest commit of the source branch
  RELEASE_COMMIT_SHA=$(git rev-parse $SOURCE_BRANCH)
  # generate the tag trigger name composed of the release trigger branch, the version to be released, the SHA of the latest commit of the source branch
  TAG_TRIGGER="$RELEASE_TRIGGER_BRANCH-$RELEASE_VERSION-$(git rev-parse $SOURCE_BRANCH)"
 
  # 5. update the release commit SHA
  echo "5. Updating release commit SHA"
  # replace the release commit SHA in release.properties file 
  sed -i "s|RELEASE_COMMIT_SHA=.*|RELEASE_COMMIT_SHA=$RELEASE_COMMIT_SHA|" release.properties

  # check whether the repository is clean (nothing to add)
  if [ -z "$(git status -s)" ]; then
    echo " No change since last release. Aborting."
    cleanUp
    return 1
  fi


  # 6. create a commit with modified release.properties file
  echo "6. Commiting the new release commit SHA"
  git add release.properties && git commit -qm "Releasing version $RELEASE_VERSION based on SHA '$RELEASE_COMMIT_SHA'" > /dev/null 2>&1
  COMMIT_RESULT=$?

  if [ $COMMIT_RESULT -gt 0 ]; then
    echo " A problem occurred while committing, not pushing anything"
    if [ $COMMIT_RESULT -eq 128 ]; then
      echo " You must set a Git user name and email"
    fi
	return 1
  fi

  echo
  echo "== Finalization =="
  # 7. create the tag trigger
  echo "7. Creating the tag trigger: $TAG_TRIGGER"
  git tag -a $TAG_TRIGGER -m "Creating tag trigger '$TAG_TRIGGER' from '$RELEASE_COMMIT_SHA' commit"
  if [ $COMMIT_RESULT -gt 0 ]; then
    echo " A problem occurred while tagging, not pushing"
    return 1
  fi

  echo
  # 8. push the commit and the tag
  echo "8. Pushing the trigger tag: $TAG_TRIGGER"

  git push origin $TMP_RELEASE_TRIGGER_BRANCH --follow-tags -q > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo " Successfully pushed the new release commit SHA '$RELEASE_COMMIT_SHA' in tag '$TAG_TRIGGER'"
  fi

  # 9. cleaning the versions
  echo "9. Cleaning the release.properties file"

  # switch back to the temporary branch
  git checkout $RELEASE_TRIGGER_BRANCH
  if [ $? -gt 0 ]; then
    echo
    echo " Unable to checkout to $RELEASE_TRIGGER_BRANCH branch"
    cleanUp
    return 1
  fi

  # put value 0.0.0 in RELEASE_VERSION property
  sed -i "s/\(RELEASE_VERSION=\).*\$/\10.0.0/" release.properties

  if [ ! -z "$(git status -s)" ]; then # only if there is a change
    git add release.properties && git commit -qm "[ci skip] Cleaning up release.properties" > /dev/null 2>&1
    COMMIT_RESULT=$?

    if [ $COMMIT_RESULT -gt 0 ]; then
      echo " A problem occurred while committing, not pushing anything"
      if [ $COMMIT_RESULT -eq 128 ]; then
        echo " You must set a Git user name and email"
      fi
    else
      echo " Pushing to the release trigger branch";
      git push origin $RELEASE_TRIGGER_BRANCH -q > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        echo " Successfully pushed on the release trigger branch '$RELEASE_TRIGGER_BRANCH'"
      fi
    fi
  fi

  # delete temporary branch
  git push -q --delete origin $TMP_RELEASE_TRIGGER_BRANCH # TODO: what if remote name is not origin ?
  if [ $? -gt 0 ]; then
    echo " Unable to delete $TMP_RELEASE_TRIGGER_BRANCH branch"
    cleanUp
    return 1
  fi

  # clean up and restore initial directory
  cleanUp
  return 0
}

prepareRelease () {
  defaultValues

  # source release.properties
  [ -f ./release.properties ] && source ./release.properties

  SSH_GIT_URL=$(git config --get remote.origin.url | sed 's|https\?://gitlab-ci-token:.*@\(.*\)|git@\1|')
  git remote set-url origin ssh://$SSH_GIT_URL

  # configure repository and checkout $SOURCE_BRANCH instead of current release branch
  git config user.name $GIT_USER_NAME
  git config user.email $GIT_USER_EMAIL
  git config push.default upstream

  # delete the branch and check it out again from release commit SHA
  git branch -d $SOURCE_BRANCH
  git checkout -b $SOURCE_BRANCH $RELEASE_COMMIT_SHA
  git branch --set-upstream-to=origin/$SOURCE_BRANCH $SOURCE_BRANCH

  return 0
}

executeRelease () {
  defaultValues

  # source release.properties
  [ -f ./release.properties ] && source ./release.properties

  case "$MAVEN_RELEASER" in
    "unleash")
      echo " Executing release build using unleash-maven-plugin releaser."
      mvn unleash:perform -Dunleash.developmentVersion=$DEV_VERSION -Dunleash.releaseVersion=$RELEASE_VERSION
    ;;
    "maven")
      echo " Executing release build using unleash-maven-plugin releaser."
      mvn release:prepare release:perform -DdevelopmentVersion=$DEV_VERSION -DreleaseVersion=$RELEASE_VERSION
    ;;
    *)
      echo "The releaser '$MAVEN_RELEASER' is not 'unleash' or 'maven'."
      return 1
    ;;
  esac

  return 0
}

# the triggerRelease function will:
#  1. clone a repository
#  2. checkout the source branch (DEFAULT_SOURCE_BRANCH=master by default)
#  3. retrieve the next release and snapshot versions with the provided "increment policy" considering the current versions in the checked out branch
#  4. checkout the release triggering branch (called DEFAULT_RELEASE_TRIGGER_BRANCH=release-trigger by default)
#  5. update the release and snapshot versions properties in the release properties file (release.properties by default)
#  6. add, commit & push the changed release properties file (this will trigger the release for the project in the repository)
#
# arguments are provided by a KEY=VALUE file named release.properties in the same directory of this script
triggerRelease () {
  parseCommandLine $@

  triggerRelease_loadPropertiesFromFile $PARAMETERS

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

  echo "2. Updating versions"
  versionsUpdate

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

  # check whether the repository is clean (nothing to add)
  if [ -z "$(git status -s)" ]; then
    echo " No change since last release. Aborting."
    cleanUp
    return 1
  fi

  # 6. trigger the release by pushing the new file
  echo "6. Triggering the release"
  git add release.properties && git commit -qm "Triggering release version $RELEASE_VERSION, next development version will be $DEV_VERSION" > /dev/null 2>&1
  COMMIT_RESULT=$?

  if [ $COMMIT_RESULT -gt 0 ]; then
    echo " A problem occurred while committing, not pushing anything"
    if [ $COMMIT_RESULT -eq 128 ]; then
      echo " You must set a Git user name and email"
    fi
  else
    echo " Pushing to the release trigger branch";
    git push origin $RELEASE_TRIGGER_BRANCH -q > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo " Successfully pushed on the release trigger branch '$RELEASE_TRIGGER_BRANCH'"
    fi
  fi

  # clean up and restore initial directory
  cleanUp
  return 0
}

triggerRelease_loadPropertiesFromFile () {
  unset RELEASE_VERSION DEV_VERSION GIT_USER_NAME GIT_USER_EMAIL GIT_REPOSITORY_URL INCREMENT_POLICY SOURCE_BRANCH RELEASE_TRIGGER_BRANCH

  if [ "$#" -lt 1 ]; then
    GIT_REPOSITORY_URL=$(git config --get remote.origin.url) # use remote URL of current repository (assuming remote is called origin)
    if [ $? -ne 0 ]; then
      echo " At least a Git repository URL is required" >&2
      return 1
    fi
  else
    GIT_REPOSITORY_URL=$1
  fi

  defaultValues

  # use release.properties (to retrieve Git user config and to override arguments default values)
  RELEASE_PROPERTIES_FILE="$(dirname -- "$0")/release.properties"
  [ -f $RELEASE_PROPERTIES_FILE ] && . $RELEASE_PROPERTIES_FILE

  displayBanner
  simpleConsoleLogger "" $NO_BANNER
  simpleConsoleLogger "Arguments:" $NO_BANNER
  simpleConsoleLogger " using '$INCREMENT_POLICY' as increment policy" $NO_BANNER
  simpleConsoleLogger " using '$RELEASE_TRIGGER_BRANCH' as release branch" $NO_BANNER
  simpleConsoleLogger " using '$SOURCE_BRANCH' as source branch" $NO_BANNER
}

versionsUpdate () {
  echo
  echo "== Versions update =="
  # a. checkout the source branch
  echo " a. Checking out the source branch: $SOURCE_BRANCH"
  git checkout -q $SOURCE_BRANCH
  if [ $? -gt 0 ]; then
    echo " Unable to checkout to $SOURCE_BRANCH branch"
    cleanUp
    return 1
  fi

  # b. retrieve the next versions
  echo " b. Retrieving the next versions"
  updateReleaseVersions $INCREMENT_POLICY
  if [ $? -gt 0 ]; then
    echo " Unable to update versions!";
    cleanUp
    return 1
  fi
  echo " New versions are: RELEASE_VERSION=$RELEASE_VERSION and DEV_VERSION=$DEV_VERSION"
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

replaceProperties () {
  GIT_REPOSITORY_BASENAME=$(basename $GIT_REPOSITORY_URL | cut -f 1 -d '.')
  GIT_REPOSITORY_URL_NO_EXT=$(echo $GIT_REPOSITORY_URL | cut -f 1 -d '.')

  replaceProperty $1 GIT_REPOSITORY_URL_NO_EXT
  replaceProperty $1 GIT_REPOSITORY_URL
  replaceProperty $1 GIT_REPOSITORY_BASENAME
  replaceProperty $1 PROJECT_NAME
  replaceProperty $1 SOURCE_BRANCH
  replaceProperty $1 RELEASE_TRIGGER_BRANCH
  replaceProperty $1 INCREMENT_POLICY
  replaceProperty $1 GIT_USER_NAME
  replaceProperty $1 GIT_USER_EMAIL
  replaceProperty $1 DOCKER_IMAGE
  replaceProperty $1 MAVEN_AUTO_RELEASER_VERSION_TAG
  replaceProperty $1 MAVEN_AUTO_RELEASER_VERSION
}

replaceProperty () {
  unset PROPERTY_VALUE
  PROPERTY_VALUE=${!2}
  PROPERTY_VALUE=$(echo $PROPERTY_VALUE | sed 's/[\/&]/\\&/g') # escape slashes
  sed -i "s/^\(.*\)\(\$$2\)\(.*\)$/\1$PROPERTY_VALUE\3/" $1
}

# common command line parser to convert command line switch to variables
# this will also set PARAMETERS variable with all command line arguments without switches
parseCommandLine () {
  unset OPTS NO_BANNER NO_COMMAND_LINE_OVERRIDE RELEASE_TRIGGER_BRANCH

  [ -z ${JAVA_HOME+x} ] && JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
  [ ! -d "$JAVA_HOME" ] && echo "JAVA_HOME does not exist!" && exit 1

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
}

defaultValues () {
  # default values
  SOURCE_BRANCH=$DEFAULT_SOURCE_BRANCH
  RELEASE_TRIGGER_BRANCH=$DEFAULT_RELEASE_TRIGGER_BRANCH
  GIT_USER_NAME=$DEFAULT_GIT_USER_NAME
  GIT_USER_EMAIL=$DEFAULT_GIT_USER_EMAIL
  DOCKER_IMAGE=$DEFAULT_DOCKER_IMAGE 
  INCREMENT_POLICY=$DEFAULT_INCREMENT_POLICY
  MAVEN_RELEASER=$DEFAULT_MAVEN_RELEASER
  MODE_SCRIPT_CONTENT=$DEFAULT_MODE_SCRIPT_CONTENT
}

displayBanner () {
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
