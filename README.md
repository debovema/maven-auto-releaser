# Maven auto releaser

## What it does ?

The Maven auto releaser is a tool to automate the release process of large and complex Maven projects, especially those with a multi-level hierarchy using Git as Source Code Management tool.

## How it works ?

### The release trigger branch concept

### Supported **Continuous Integration** backends

Currently, only Gitlab CI is supported, though adding other Continuous Integration tool based on configuration files should be easy.

#### Gitlab CI

## What is required ?

* Gitlab & Gitlab CI installed
* The Gitlab CI runner used to execute release jobs must be able to clone and push from and to the repositories of the projects to release (with SSH keys)
* Only one Gitlab CI runner must be running at a time: either have only one runner or assign all the projects to be released to the same runner

## Licensing

The Maven auto releaser tool is licensed under the Apache License, Version 2.0. See [LICENSE](https://github.com/debovema/maven-auto-releaser/blob/master/LICENSE) for the full license text.

