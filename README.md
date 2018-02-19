# Maven auto releaser

## What it does

The **Maven auto releaser** is a release engineering tool to automate the release process of Maven projects using Git as their Source Code Management tool and Gitlab CI for Continuous Integration builds.

## How it works

This tool is composed of **two parts**:

1. **a creation step**: a script to create *release trigger branches* on the repositories of the projects to release. This step is a one-shot action for a given repository.
2. **an execution runtime**: a set of configuration, scripts and Continuous Integration files which will trigger the actual Maven release the classical way (i.e. with the [maven-release-plugin](http://maven.apache.org/maven-release/maven-release-plugin) or the [unleash-maven-plugin](https://github.com/shillner/unleash-maven-plugin)). This execution runtime is used whenever a release is to be created on a given repository.

### The *release trigger branch* concept

The main idea behind the *release trigger branch* concept is to create a Git branch on all repositories of the projects to release called the *release trigger branch*.

This branch will be composed of:
* a Continuous Integration configuration file (for Gitlab CI, it's the *.gitlab-ci.yml*). In this file, a trigger is set to be executed **whenever a commit is pushed on the _release trigger branch_**.
* a *release.properties* file with information on the next version to be released.
* an execution script, *release.sh*, called by the Continuous Integration trigger. It will execute the actual release Maven build.
* a *README.md* file with built-in help to guide end-users in the release process of their Maven projects

### Remote vs Standalone mode

The content of *release.sh* file of the *release trigger branch* differs whether the **remote mode** or **local mode** is selected during the [**creation step**](#how-it-works).

The difference between the two modes are:
* in **remote mode** the **creation step** will only write links to the actual scripts which will be downloaded from this repository (https://github.com/debovema/maven-auto-releaser) by the **execution runtime** based on the version used during the **creation step**.
Main advantage is that it is easy to update to the latest version of the **Maven auto releaser** tool by changing the version in the existing *release trigger branches* of your repositories.
* **local mode** will copy the content of scripts at their current version from this repository (https://github.com/debovema/maven-auto-releaser) during the **creation step**.
Main advantage is that the repositories with *release trigger branches* does not rely on the **Maven auto releaser** tool once they have been initialized (especially if release environment has no access to the Internet). On the other hand, the **Maven auto releaser** tool becomes ***harder to update in this mode***.

### Properties configuration

There are two properties file used by the **Maven auto releaser**: *branch.properties* and *release.properties*:
* *branch.properties* is used to provide parameters for the *release trigger branch* creation step. It is expected to be created in the same directory as the *maven-auto-release.sh* script.
* *release.properties* is used to provide parameters for the trigger and execution of releases. It is stored directly on the *release trigger branch*. To edit this file without triggering release, **add the [ci skip] prefix in the commit message** before pushing.

#### List of supported properties in *release.properties*

| Property                 | Description                                                                                            | Example (is default?) |
|--------------------------|--------------------------------------------------------------------------------------------------------|-----------------------|
| DEV\_VERSION             | The next development version                                                                           | 1.0.2-SNAPSHOT        |
| RELEASE\_VERSION         | The next release version                                                                               | 1.0.1                 |
|                          |                                                                                                        |                       |
| GIT\_USER\_EMAIL         | Value of git config user.email                                                                         | john.doe@gmail.com    |
| GIT\_USER\_NAME          | Value of git config user.name                                                                          | "John Doe"            |
| INCREMENT\_POLICY        | The increment policy. Values can be: revision, minor, major                                            | revision (yes)        |
| MAVEN\_RELEASER          | The Maven plugin used to release<br />Values can be: maven, unleash                                    | unleash (yes)         |
| RELEASE\_TRIGGER\_BRANCH | The release trigger branch which initiates releases                                                    | release-trigger (yes) |
| SOURCE\_BRANCH           | The branch to checkout to initiate releases                                                            | master (yes)          |
| UNLEASH\_WORKFLOW\_URL   | (optional, if MAVEN\_RELEASER == unleash) an URL to fetch the Maven unleash plugin workflow at runtime |                       |

#### List of supported properties in *branch.properties*

All properties of *release.properties* file can be set in *branch.properties* (except DEV\_VERSION and RELEASE\_VERSION).
They will be forwarded to the *release.properties* during *release trigger branch* creation.
In addition, these properties are also available specifically in creation step:

| Property                 | Description                                                         | Default value       |
|--------------------------|---------------------------------------------------------------------|---------------------|
| DOCKER\_IMAGE            | The Docker image for Gitlab CI builds to be set in *.gitlab-ci.yml* | debovema/docker-mvn |
| MODE\_SCRIPT\_CONTENT    | The mode for script content. <br />Values can be: remote, local     | remote              |

### Supported **Continuous Integration** backends

Currently, only Gitlab CI is supported, though adding other Continuous Integration tool based on configuration files should be easy.

#### Gitlab CI requirements

* Gitlab & Gitlab CI installed
* Only Docker Gitlab runners are supported (at the moment)
* A Docker image with following packages installed: cUrl, Bash, Git, OpenSSH client, Java, Maven

## Getting started

1. clone this repository

```shell
git clone https://github.com/debovema/maven-auto-releaser.git
```

2. enter into the directory

```shell
cd maven-auto-releaser
```

3. checkout the latest Git tag (= latest release) (or any version you want to use):

```shell
git checkout $(git describe --tags)
```

4. edit the *branch.properties* file with properties to customize

5. create a release trigger branch on a Git repository

```shell
GIT_REPOSITORY_URL=<URL of the Git repository> bash -c 'source ./maven-auto-release.sh && createReleaseTriggerBranch $GIT_REPOSITORY_URL'
```

6. follow the instructions of the README file created on the release trigger branch of the Git repository

## Licensing

The **Maven auto releaser** tool is licensed under the Apache License, Version 2.0. See [LICENSE](https://github.com/debovema/maven-auto-releaser/blob/master/LICENSE) for the full license text.
