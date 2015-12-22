#!/usr/bin/env bash
#
#UsageStart
#
# Usage: $0 <https://github.com/account/repository.git> [<branch>]
#
#UsageEnd

#Disable git command prompt (since git 2.3)
export export GIT_TERMINAL_PROMPT=0

typeset -r scriptDir=$( dirname "${0}")
source "${scriptDir}/lib/git-lib.sh"

#Main

#Environment check
environmentCheck
if [[ "${?}" -ne 0 ]]
then
	exit 1
fi

#Arguments checking
if [[ "${#}" -lt 1 || "${#}" -gt 2 ]]
then
	usage
	exit 1

#help display
elif [[ "${1}" = "-h" || "${1}" = "help" || "${1}" = "--help" ]]
then
	usage
	exit 0
fi
#Argument mapping
declare -r gitHubRespositoryUrl="${1}"
declare -r gitBranch="${2:-master}"

#Temporary directory clean up
if [[ -e tmp ]]
then
	echo -n "Deleting existing ${PWD}/tmp file-directory:..."
	rmOutput=$( rm -r tmp 0<&- 2>&1)
	if [[ "${?}" -ne 0 ]]
	then
		echo -e "[\033[31mFAILED\033[0m]"
		echo "${rmOutput}"
		exit 1
	fi
	echo -e "[\033[32mOK\033[0m]"
fi

#Clone the target git repository
echo -n "Cloning $(echo ${gitHubRespositoryUrl} | sed -e 's|https*://[^/]*/||' -e 's/.git$//' ) repository:..."
cloneOutput=$( ${gitCommand} clone --depth 1 --branch "${gitBranch}" "${gitHubRespositoryUrl}" tmp 2>&1 )
if [[ "${?}" -ne 0 ]]
then
	echo -e "[\033[31mFAILED\033[0m]"
	echo "${cloneOutput}" >&2
	exit 1
fi
echo -e "[\033[32mOK\033[0m]"

cd tmp 2>/dev/null
if [[ "${?}" -ne 0 ]]
then
	echo "Cannot go into tmp git clone directory" >&2
	exit 1
fi

#Checking new component versions with Maven
echo -n "Checking property version upgrades:..."
versionOutput=$( mvn -U versions:display-plugin-updates  versions:display-property-updates 2>&1 )
if [[ "${?}" -ne 0 ]]
then
	echo -e "[\033[31mFAILED\033[0m]"
	echo "${versionOutput}" >&2
	exit 1
fi
declare -ri countUpgrade=$( echo "${versionOutput}" | grep -- "->" | grep '${' | wc -l )
echo -e "[\033[32mOK\033[0m] -> ${countUpgrade} upgrade(s) found"

typeset -i scriptReturnCode=0

#Loop on each property that can be upgraded
echo "${versionOutput}" | grep -- "->" | grep '${' | while read line
do
	declare property=$( echo "${line}" | awk '{print $2}' | sed -e 's/^${//' -e 's/}$//' )
	declare versionDelta=$( echo "${line}" | awk '{ print $(NF-2),$(NF-1),$NF }' )

	echo -e "\nUpgrading ${property} property from $( echo ${versionDelta} | sed 's/->/to/' )"

	#Check the existance of the remote branch before
	declare targetbranchUpgrade="${property}_upgrade_"$( echo "${versionDelta}" | sed -e 's/ -> /_to_/g' )
	echo -n "Checking existence of the remote branch ${targetbranchUpgrade}:..."
	${gitCommand} ls-remote --heads 2>&1 | grep "${targetbranchUpgrade}" >/dev/null
	if [[ "${?}" -eq 0 ]]
	then
		echo -e "[\033[33mALREADY EXISTS\033[0m] -> skipping this upgrade"
		continue
	fi
	echo -e "[\033[32mOK\033[0m]"

	#Get back to the pull-request target branch (default: master)
	echo -n "Checkout of main branch ${gitBranch}:..."
	checkoutReturn=$( ${gitCommand} checkout "${gitBranch}" 2>&1 )
	if [[ "${?}" -ne 0 ]]
	then
		echo -e "[\033[31mFAILED\033[0m]"
		echo "${checkoutReturn}" >&2
		scriptReturnCode=1
		continue
	fi
	echo -e "[\033[32mOK\033[0m]"

	#Do the dependency/plugin upgrade by changing its property with Maven
	echo -n "Modifying property ${property}:..."
	updateOutput=$( mvn -U versions:update-property -Dproperty="${property}" 2>&1 )
	if [[ "${?}" -ne 0 ]]
	then
		echo -e "[\033[31mFAILED\033[0m]"
		echo "${updateOutput}" >&2
		scriptReturnCode=1
		continue
	fi
	echo -e "[\033[32mOK\033[0m]"

	#Create and checkout a new branch for the property upgrade
	declare branchVersionUpgrade=$( echo "${updateOutput}" | grep '^\[INFO\] Updated ${'"${property}"'}' | grep -o "[^ ]* to [^ ]*$" | sed 's/ /_/g' )
	echo -n "Create and checkout branch ${branchVersionUpgrade}:..."
	checkoutReturn=$( ${gitCommand} checkout --track -b "${property}_upgrade_${branchVersionUpgrade}" 2>&1 )
	if [[ "${?}" -ne 0 ]]
	then
		echo -e "[\033[31mFAILED\033[0m]"
		echo "${checkoutReturn}" >&2
		scriptReturnCode=1
		continue
	fi
	echo -e "[\033[32mOK\033[0m]"

	echo -n "Adding modified pom.xml to commit files:..."
	gitAddReturn=$( ${gitCommand} add -u )
	if [[ "${?}" -ne 0 ]]
	then
		echo -e "[\033[31mFAILED\033[0m]"
		echo "${gitAddReturn}" >&2
		scriptReturnCode=1
		continue
	fi
	echo -e "[\033[32mOK\033[0m]"

	echo -n "Commiting modified pom.xml files:..."
	gitCommitReturn=$( ${gitCommand} commit -m "$(commitMessage "${property}" "${updateOutput}")" -m "$(commitDetails "${property}" "${updateOutput}")" 2>&1 )
	if [[ "${?}" -ne 0 ]]
	then
		echo -e "[\033[31mFAILED\033[0m]"
		echo "${gitCommitReturn}" >&2
		scriptReturnCode=1
		continue
	fi
	echo -e "[\033[32mOK\033[0m]"

	echo -n "Pushing the commit to the git repository:..."
	gitPushReturn=$( ${gitCommand} push origin "${property}_upgrade_${branchVersionUpgrade}" 2>&1 )
	if [[ "${?}" -ne 0 ]]
	then
		echo -e "[\033[31mFAILED\033[0m]"
		echo "${gitPushReturn}" >&2
		scriptReturnCode=1
		continue
	fi
	echo -e "[\033[32mOK\033[0m]"

	if [[ "${gitCommand}" = "hub" ]]
	then
		declare version=$( echo "${updateOutput}" | grep '^\[INFO\] Updated ${'"${property}"'}' | grep -o "[^ ]* to [^ ]*$" | sed 's/to/->/' )

		echo -n "Creating the associated GitHub pull-request:..."
		hubPullRequestReturn=$( hub pull-request  -m "${property} upgrade ${version}" -b "${gitBranch}" -h "${property}_upgrade_${branchVersionUpgrade}" 2>&1 )
		if [[ "${?}" -ne 0 ]]
		then
			echo -e "[\033[31mFAILED\033[0m]"
			echo "${hubPullRequestReturn}" >&2
			scriptReturnCode=1
		fi
		echo -e "[\033[32mOK\033[0m]"
		echo "${hubPullRequestReturn}" >&2
	fi

done

exit "${scriptReturnCode}"
