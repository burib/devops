#!/bin/bash

# If you don't want to deploy the latest version, you can just specify the SHA
# of an older revision as the only argument to this script.

set -e

# Choose an explicit "remote" alias for the `git push`.
# The default behavior is "upstream". This entirely depends
# on your personal git remote config.
# See .git/config and `git remote -v` for more info.
REMOTE_BRANCH=${2}
REMOTE_BRANCH_EXISTS=0
CURRENT_BRANCH=$(git branch --show-current) # from git 2.2
#CURRENT_BRANCH=${`git symbolic-ref HEAD | cut -d"/" -f3`}
git pull
git fetch

cecho(){
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[1;33m"
    # ... ADD MORE COLORS
    NC="\033[0m" # No Color

    printf "${!1}${2} ${NC}\n"
}

getSHA1() {
  echo $(git rev-parse --short HEAD);
}

getLastGitTag() {
  git fetch
  git fetch $REMOTE_BRANCH
  echo $(git ls-remote --tags --sort="v:committerdate" | tail -n1 | sed 's/.*\///; s/\^{}//');
}

getFormattedLogsSinceLastTag() {
  echo $(git log --pretty=format:"%cn %ci %s%n" HEAD...$(getLastGitTag));
}

getVersion() {
  PACKAGE_JSON="package.json";
  if test -f "$PACKAGE_JSON"; then
      # if package.json exists, we read the version of it and add it to the commit message
      VERSION="v$(cat $PACKAGE_JSON \
                            | grep version \
                            | head -1 \
                            | awk -F: '{ print $2 }' \
                            | sed 's/[",]//g' \
                            | tr -d '[[:space:]]')"
  else
      VERSION="v$(getSHA1)"
  fi

  echo $VERSION;
}

if [ -z $1 ]; then
    # If no SHA1 specified, we have to make sure that we'll deploy from the
    # master branch.
    if [[ "${CURRENT_BRANCH}" != "master" ]]; then
        cecho "RED" "Production deploys only allowed from the master branch."
        exit 1
    fi
fi

if [ $REMOTE_BRANCH ]; then
    # If remote branch is given, check if exists
    REMOTE_BRANCH_EXISTS=$(git ls-remote --heads 2>/dev/null|awk -F 'refs/heads/' '{print $2}'|grep -x "${REMOTE_BRANCH}"|wc -l)

    if ! $REMOTE_BRANCH_EXISTS ; then
        cecho "RED" "given remote branch ('${REMOTE_BRANCH}') doesn't exists."
        exit 1
    fi
fi

VERSION=$(getVersion)
COMMIT_MESSAGE="release $VERSION at $(date -u +%Y-%m-%d_%H:%M:%S) UTC && [skip ci]"

# TODO: check if there were commits since last tag.

git commit --amend -m "$COMMIT_MESSAGE"

if ($(git tag -l $(getVersion) != $(getVersion))); then
    cecho "GREEN" "$(getVersion) doesn't exists";
    # git tag -a "$(getVersion)" -m "$(getFormattedLogsSinceLastTag)"  # create tag with current version
    git tag -a "v$(date -u +%Y-%m-%d_%H-%M-%S)" -m "release version $(getVersion)"  # create tag with current version
    git push --tags # push tags to remote
    if ! $REMOTE_BRANCH ; then
        git push $REMOTE_BRANCH --tags # push tags to remote
    fi
else
    cecho "RED" "YES. $(getVersion) does exists";
fi

git pull
git fetch
git push # push changes to local


if ! $REMOTE_BRANCH ; then
    cecho "GREEN" "\t pushing changes to '$REMOTE_BRANCH' remote branch as well."
    git push $REMOTE_BRANCH # push changes to remote
fi
