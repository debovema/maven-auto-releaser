# Maven auto releaser

## What it does

The **Maven auto releaser** is a tool to automate the release process of large and complex Maven projects — especially those with a multi-level hierarchy — using Git as their Source Code Management tool.

## How it works?

This tool is composed of **two parts**:

1. **a creation step**: a script to create *release trigger branches* on the repositories of the projects to release. This step is a one-shot action for a given repository.
2. **an execution runtime**: a set of configuration, scripts and Continuous Integration files which will trigger the actual Maven release the classical way (i.e. with the [maven-release-plugin](http://maven.apache.org/maven-release/maven-release-plugin) or the [unleash-maven-plugin](https://github.com/shillner/unleash-maven-plugin)). This execution runtime is used whenever a release is to be created on a given repository.

### The *release trigger branch* concept

The main idea behind the *release trigger branch* concept is to create a Git branch on all repositories of the projects to release called the *release trigger branch*.

This branch will be composed of:
* a Continuous Integration configuration file (for Gitlab CI, it's the *.gitlab-cy.yml*). In this file, a trigger is set to be executed **whenever a commit is pushed on the _release trigger branch_**.
* a *release.properties* file with information for the next version to be released.
* a preparation script, *prepareRelease.sh*, called by the Continuous Integration trigger. It will clone the repository and checkout the source branch and configure Git with username and email.
* an execution script, *release.sh*, called by the Continuous Integration trigger. It will execute the actual release Maven build.

### Remote vs Standalone mode

The preparation and execution scripts above (*prepareRelease.sh* and *release.sh*) always exist in the *release trigger branch*.

The difference between the two modes are:
* in **remote mode** the [**creation step**](#how-it-works) will only write links to the actual scripts which will be downloaded from this repository (https://github.com/debovema/maven-auto-releaser) based on the version used during the **creation step**.
Main advantage is that it is easy to update to the latest version of the **Maven auto releaser** tool by changing the version in the existing *release trigger branches* of your repositories.
* **local mode** will copy the content of scripts from this repository (https://github.com/debovema/maven-auto-releaser) during the **creation step**.
Main advantage is that the repositories with *release trigger branches* does not rely on the **Maven auto releaser** tool once they have been initialized (especially if release environment has no access to the Internet). On the other hand, the **Maven auto releaser** tool becomes ***very hard to update in this mode***.

### List of supported properties in *release.properties*

| Property                 | Description                                                 | Example            |
|--------------------------|-------------------------------------------------------------|--------------------|
| DEV\_VERSION             | The next development version                                | 1.0.2-SNAPSHOT     |
| RELEASE\_VERSION         | The next release version                                    | 1.0.1              |
| GIT\_USER\_NAME          | Value of git config user.name                               | "John Doe"         |
| GIT\_USER\_EMAIL         | Value of git config user.email                              | john.doe@gmail.com |
| INCREMENT\_POLICY        | The increment policy. Values can be: revision, minor, major | revision           |
| SOURCE\_BRANCH           | The branch to checkout to initiate releases                 | master             |
| RELEASE\_TRIGGER\_BRANCH | The release trigger branch which initiates releases         | release-trigger    |

### Supported **Continuous Integration** backends

Currently, only Gitlab CI is supported, though adding other Continuous Integration tool based on configuration files should be easy.

#### Gitlab CI requirements

* Gitlab & Gitlab CI installed
* The Gitlab CI runner used to execute release jobs must be able to clone and push from and to the repositories of the projects to release (with SSH keys)
* Only one Gitlab CI runner must be running at a time: either have only one runner or assign all the projects to be released to the same runner

## Getting started

1. clone this repository

```shell
git clone https://github.com/debovema/maven-auto-releaser.git
```

2. enter into the directory

```shell
cd maven-auto-releaser
```

3. create a release trigger branch on the repositories

```shell
. ./mavenAutoRelease.sh && createReleaseTriggerBranch <URL of the Git repository>
```

4. follow the instructions of the README file created on the release trigger branch of the Git repository

## Licensing

The Maven auto releaser tool is licensed under the Apache License, Version 2.0. See [LICENSE](https://github.com/debovema/maven-auto-releaser/blob/master/LICENSE) for the full license text.

