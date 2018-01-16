# Maven auto releaser

## What it does

The **Maven auto releaser** is a tool to automate the release process of large and complex Maven projects — especially those with a multi-level hierarchy — using Git as their Source Code Management tool.

## How it works?

This tool is composed of **two parts**:

* a script to create *release trigger branches* on the repositories of the projects to release
* a set of Continuous Integration configuration and scripts files which will trigger the actual Maven release the classical way (i.e. with the [maven-release-plugin](http://maven.apache.org/maven-release/maven-release-plugin) or the [unleash-maven-plugin](https://github.com/shillner/unleash-maven-plugin))

### The *release trigger branch* concept

The main idea is to create a Git branch on all repositories of the projects to release called the *release trigger branch*.
This branch will be composed of:
* a Continuous Integration configuration file (for Gitlab CI, it's the *.gitlab-cy.yml*). In this file, a trigger is set to be executed **whenever a commit is pushed on the _release trigger branch_**.
* a *release.properties* file with information for the next version to be released 
* a script caled by the Continuous Integration trigger.
* 

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

