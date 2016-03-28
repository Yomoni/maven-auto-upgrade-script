# maven-auto-upgrade-script

[![License](https://img.shields.io/github/license/Yomoni/maven-auto-upgrade-script.svg)](https://github.com/Yomoni/maven-auto-upgrade-script/blob/master/LICENSE)

Maven auto upgrade script check for any existing maven dependency and/or plugin upgrade. For each upgrade, a new branch is created with a single upgrade and a pull request is submitted from this branch.

***

## Installation

Clone the git repository with this command:
```bash
git clone https://github.com/Yomoni/maven-auto-upgrade-script.git
```

## Requirements

* _git_ must be installed, version 2.3 or above is recommended
* Maven must be installed and the _mvn_ command must works (in the PATH environment variable with the associated JAVA_HOME/JDK)
* [_hub_](https://hub.github.com/) must be installed and configured to generate pull-request directly in GitHub

## Launch

### Single repository check

Check of dependencies upgrades on a remote git repository (with a temporary clone) or an local existing one can be done with this command:
```bash
maven-auto-upgrade.sh <target git repository URL|git clone directory> [<target checked branch>]
```
If no target branch is specified, the default branch _master_ is used. If the repository already exists, no ```bash git pull``` command is used to synchronize the repository.

Execution example command:
```bash
maven-auto-upgrade.sh https://github.com/Sylvain-Bugat/RundeckMonitor.git
```
output of this example:
```bash
Verifying Git version:...[OK] -> git version 2.7.0
Verifying GitHub Hub version:...[OK] found hub command -> hub version 2.2.2
Verifying Maven version:...[OK] -> Apache Maven 3.3.3
Cloning Sylvain-Bugat/RundeckMonitor repository:...[OK]
Checking property version upgrades:...[OK] -> 1 upgrade(s) found

Upgrading slf4j.version property from 1.7.18 to 1.7.19
Checkout of main branch master:...[OK]
Checking existence of the remote slf4j.version_upgrade_1.7.18_to_1.7.19:...[OK]
Modifying property assertj.version:...[OK]
Create and checkout branch slf4j.version_upgrade_1.7.18_to_1.7.19:...[OK]
Adding modified pom.xml to commit files:...[OK]
Commiting modified pom.xml files:...[OK]
Pushing the commit to the git repository:...[OK]
Creating the associated GitHub pull-request:...[OK] -> https://github.com/Sylvain-Bugat/RundeckMonitor/pull/33
Deleting clone /cygdrive/c/maven-auto-upgrade-script/RundeckMonitor:...[OK]

```

Created pull request on this example: https://github.com/Sylvain-Bugat/RundeckMonitor/pull/33

### Multiple repository check

The check of multiple existing/remote git repository can be done with this command:
```bash
maven-multi-repository-auto-upgrade.sh <target git repository URL|git clone directory> [<target git repository URL|git clone directory>] [...]
```

In multiple repository check, the default branche _master_ is used

Execution example command:
```bash
maven-multi-repository-auto-upgrade.sh https://github.com/Sylvain-Bugat/RundeckMonitor.git https://github.com/Sylvain-Bugat/aws-ec2-start-stop-tools.git
```

Command output exemple:
```bash
Verifying Git version:...[OK] -> git version 2.7.0
Verifying GitHub Hub version:...[OK] found hub command -> hub version 2.2.2
Verifying Maven version:...[OK] -> Apache Maven 3.3.3

Check Maven dependencies upgrades of https://github.com/Sylvain-Bugat/RundeckMonitor.git repository
Cloning Sylvain-Bugat/RundeckMonitor repository:...[OK]
Checking property version upgrades:...[OK] -> 0 upgrade(s) found
Deleting clone /cygdrive/c/maven-auto-upgrade-script/RundeckMonitor directory:...[OK]

Check Maven dependencies upgrades of https://github.com/Sylvain-Bugat/aws-ec2-start-stop-tools.git repository
Cloning Sylvain-Bugat/aws-ec2-start-stop-tools repository:...[OK]
Checking property version upgrades:...[OK] -> 1 upgrade(s) found

Upgrading assertj.version property from 2.3.0 to 2.4.0
Checkout of main branch master:...[OK]
Checking existence of the remote branch assertj.version_upgrade_2.3.0_to_2.4.0:...[OK]
Modifying property assertj.version:...[OK]
Create and checkout branch 2.3.0_to_2.4.0:...[OK]
Adding modified pom.xml to commit files:...[OK]
Commiting modified pom.xml files:...[OK]
Pushing the commit to the git repository:...[OK]
Creating the associated GitHub pull-request:...[OK] -> https://github.com/Sylvain-Bugat/aws-ec2-start-stop-tools/pull/52
Deleting clone /cygdrive/c/maven-auto-upgrade-script/aws-ec2-start-stop-tools directory:...[OK]
```

## Troubleshooting

### _git_ cannot commit to the cloned repository

This error occurs

### _git_ cannot clone private repository

Error output example:
```bash
Verifying Git version:...[OK] -> git version 2.7.0
Verifying GitHub Hub version:...[OK] found hub command -> hub version 2.2.2
Verifying Maven version:...[OK] -> Apache Maven 3.3.3
Cloning Sylvain-Bugat/private-repo repository:...[FAILED]
Cloning into 'private-repo'...
fatal: could not read Username for 'https://github.com': terminal prompts disabled
```
Same solution as the previous question, try to execute a ```bash git push``` command before executing the script to tempoprary remmber GitHub access.

### _hub_ cannot create the pull request on GitHub

Try to execute a hub command like this in a already cloned git repository:
```
hub ci-status
```
If it's the first hub execution, user name/password are required to create to register a [personal access token](https://github.com/settings/tokens) on your GitHub account.

### Upgrade I refuse/don't want are spammed

At each execution a pull request is created if a new version is found and if an existing branch with the same version upgread is not already found.

If you don't want an upgrade or you don't want to apply it right now you can keep the associated branch alive as long as you want. But for some strange/incompatible version the dependency version may be completely ignored.

### Not release version upgrade are generated

There are some case were not release version are detected even if only release repostory are used:
* Alpha/beta versions (A)
* Release canditate versions (RC)
* Draft versions
* Milestone versions (M)
 
To ignore versions of dependencies and/or plugins, the versions plugin configuration can be modified. Such configuration example on [Rundeck Monitor](https://github.com/Sylvain-Bugat/RundeckMonitor/blob/master/dependencies-check-rules.xml).

### Some upgrade are not detected

These scripts uses ```bash mvn versions:display-plugin-updates  versions:display-property-updates``` to find dependency/plugin version upgrade. Dependency version with direct version configuration like this cannot be detected and upgraded:
```xml
<dependency>
	<groupId>org.slf4j</groupId>
	<artifactId>slf4j-ext</artifactId>
	<version>1.7.19</version>
</dependency>
```

### My git repository is not on GitHub

These scripts can be used without the [_hub_](https://hub.github.com/) command, in this case, branch with new dependecy/plugin version are commited be no associted pull request can be created and the merge must be done manually.

### Another issue/bug, feature requests or questions?

Issues, bugs, and feature requests should be submitted on [GitHub maven-auto-upgrade-script issue tracking](https://github.com/Yomoni/maven-auto-upgrade-script/issues).

## Thanks to

* [Maven](https://maven.apache.org/) :construction_worker:
* [Versions Maven plugin](http://www.mojohaus.org/versions-maven-plugin/) :arrow_double_up:
* [_git_](https://git-scm.com/) and [_hub_](https://hub.github.com/) :smirk:
* [GitHub](https://github.com/) :laughing:
* [Yomoni](https://www.yomoni.fr/) :moneybag:
