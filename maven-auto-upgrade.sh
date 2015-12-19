#!/usr/bin/env bash
#
#UsageStart
#
# Usage: $0 <https://github.com/account/repository.git> [<branch>]
#
#UsageEnd

function usage
{
	sed -e '/^#UsageStart/,/^#UsageEnd/!d' -e 's/^#//' -e '/^UsageStart/d' -e '/^UsageEnd/d' "${0}" >&2
}

function compareVersions
{
	typeset IFS='.'
	typeset -a version1=( $1 )
	typeset -a version2=( $3 )

	for (( n=0; n<4; n+=1 ))
	do
		if [[ "${version1[n]}" =~ '^[0-9]+$' && "${version2[n]}" =~ '^[0-9]+$' ]]
		then
			if [[ "${version1[n]}" -gt "${version2[n]}" ]]
			then
				return "${n}"
			elif [[ "${version1[n]}" -lt "${version2[n]}" ]]
			then
				return "${n}"
			fi
		else
			if [[ "${version1[n]}" > "${version2[n]}" ]]
			then
				return "${n}"
			elif [[ "${version1[n]}" < "${version2[n]}" ]]
			then
				return "${n}"
			fi
		fi
	done

	return -1
}

function commitMessage
{
	typeset upgradedProperty="${1}"
	typeset upgradeOutput="${2}"

	typeset versionUpgrade=$( echo "${upgradeOutput}" | grep '^\[INFO\] Updated ${'"${upgradedProperty}"'}' | grep -o "[^ ]* to [^ ]*$" | sed 's/to/->/' )

	#Version comparaison for Emoji arrow type
	compareVersions ${versionUpgrade}
	typeset versionDelta="${?}"
	if [[ "${versionDelta}" -eq 0 ]]
	then
		typeset arrowEmoji=":arrow_double_up:"
	elif [[ "${versionDelta}" -eq 2 ]]
	then
		typeset arrowEmoji=":arrow_up_small:"
	#Default Emoji
	else
		typeset arrowEmoji=":arrow_up:"
	fi

	#print the git commit message on the standard output
	echo ":construction_worker:${arrowEmoji} ${upgradedProperty} upgrade ${versionUpgrade}"
}

function commitDetails
{
	typeset upgradedProperty="${1}"
	typeset upgradeOutput="${2}"

	typeset versionUpgrade=$( echo "${upgradeOutput}" | grep '^\[INFO\] Updated ${'"${upgradedProperty}"'}' | grep -o "[^ ]* to [^ ]*$" | sed 's/to/->/' )

	typeset commitDescription="Upgraded artifact details:\n"
	typeset upgradedArtifactDetails=$( echo "${upgradeOutput}" | grep "^\[INFO\] artifact " | grep -o "[^ ]*:[^ ]*:[^ ]*" | sort -u )
	while read line
	do
		commitDescription="${commitDescription}${line} ${versionUpgrade}\n"
	done <<< "${upgradedArtifactDetails}"

	#print the git commit details on the standard output
	echo -e "${commitDescription}"
}

#Main

#Git command check
echo -n "Verifying Git version:..."
typeset -r gitVersion=$( git --version 2>&1 )
if [[ ${?} -ne 0 ]]
then
	echo -e "[\033[31mNOT FOUND\033[0m]"
	echo "$0 needs Git, check your installation and the PATH environment variable" >&2
	exit 1
fi
echo -e "[\033[32mOK\033[0m] -> ${gitVersion}"

#GitHub hub command check (optionnal)
echo -n "Verifying GitHub Hub version:..."
typeset -r hubVersion=$( hub --version 2>&1 )
if [[ ${?} -ne 0 ]]
then
	gitCommand="git"
	echo -e "[\033[33mNOT FOUND\033[0m]"
	echo "$0 optionally needs GitHub hub command to create some pull-request (https://hub.github.com), check your installation and the PATH environment variable" >&2
else
	gitCommand="hub"
	echo -e "[\033[32mOK\033[0m] -> "$( echo "${hubVersion}" | tail -n 1 )
fi

#Maven command check
echo -n "Verifying Maven version:..."
typeset -r mavenVersion=$( mvn --version 2>&1 )
if [[ ${?} -ne 0 ]]
then
	echo -e "[\033[31mNOT FOUND\033[0m]"
	echo "${mavenVersion}" >&2
	echo "$0 needs Maven, check your installation and the PATH environment variable" >&2
	exit 1
fi
echo -e "[\033[32mOK\033[0m] -> "$( echo "${mavenVersion}" | awk '{ print $1,$2,$3 ; exit }' )

#Arguments checking
if [[ ${#} -lt 1 || ${#} -gt 2 ]]
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
typeset -r gitHubRespositoryUrl="${1}"
typeset -r gitBranch="${2:-master}"

#Temporary directory clean up
if [[ -d tmp ]]
then
	rm -r tmp 2>/dev/null
fi

#Clone the target git repository
echo -n "Cloning $(basename ${gitHubRespositoryUrl} ):..."
typeset cloneOutput=$( ${gitCommand} clone --depth 1 "${gitHubRespositoryUrl}" tmp 2>&1 )
if [[ ${?} -ne 0 ]]
then
	echo -e "[\033[31mFAILED\033[0m]"
	echo "${cloneOutput}" >&2
	rm -r tmp 2>/dev/null
	exit 1
fi
echo -e "[\033[32mOK\033[0m]"

cd tmp 2>/dev/null
if [[ ${?} -ne 0 ]]
then
	echo "Cannot use tmp git clone directory" >&2
	exit 1
fi

#Checkout the target branch (default: master)
echo -n "Checkout branch ${gitBranch}:..."
typeset checkoutReturn=$( ${gitCommand} checkout "${gitBranch}" 2>&1 )
if [[ "${?}" -ne 0 ]]
then
	echo -e "[\033[31mFAILED\033[0m]"
	echo "${checkoutReturn}" >&2
	returnCode=1
	continue
fi
echo -e "[\033[32mOK\033[0m]"

#Checking new component versions with Maven
echo -n "Checking property version upgrades:..."
typeset -r versionOutput=$( mvn -U versions:display-plugin-updates  versions:display-property-updates )
if [[ ${?} -ne 0 ]]
then
	echo "${versionOutput}" >&2
	rm -rf tmp 2>/dev/null
	exit 1
fi
typeset countUpgrade=$( echo "${versionOutput}" | grep -- "->" | grep '${' | wc -l )
echo -e "[\033[32mOK\033[0m] -> ${countUpgrade} upgrade(s) found"

typeset returnCode=0

#Loop on each property that can be upgraded
echo "${versionOutput}" | grep -- "->" | grep '${' | while read line
do
	typeset property=$( echo "${line}" | awk '{print $2}' | sed -e 's/^${//' -e 's/}$//' )
	typeset versionDelta=$( echo "${line}" | awk '{ print $(NF-2),$(NF-1),$NF }' )

	echo -e "\nUpgrade detected of ${property} property: ${versionDelta}"

	#Get back to the pull-request target branch (default: master)
	echo -n "Checkout branch ${gitBranch}:..."
	typeset checkoutReturn=$( ${gitCommand} checkout "${gitBranch}" 2>&1 )
	if [[ "${?}" -ne 0 ]]
	then
		echo -e "[\033[31mFAILED\033[0m]"
		echo "${checkoutReturn}" >&2
		returnCode=1
		continue
	fi
	echo -e "[\033[32mOK\033[0m]"

	#Do the dependency/plugin upgrade by changing its property with Maven
	echo -n "Modifying property ${property}:..."
	typeset updateOutput=$( mvn -U versions:update-property -Dproperty="${property}" 2>&1 )
	if [[ "${?}" -ne 0 ]]
	then
		echo -e "[\033[31mFAILED\033[0m]"
		echo "${updateOutput}" >&2
		returnCode=1
		continue
	fi
	echo -e "[\033[32mOK\033[0m]"

	#Create and checkout a new branch for the property upgrade
	typeset branchVersionUpgrade=$( echo "${updateOutput}" | grep '^\[INFO\] Updated ${'"${property}"'}' | grep -o "[^ ]* to [^ ]*$" | sed 's/ /_/g' )
	echo -n "Create and checkout branch ${branchVersionUpgrade}:..."
	typeset checkoutReturn=$( ${gitCommand} checkout --track -b "${property}_upgrade_${branchVersionUpgrade}" 2>&1 )
	if [[ "${?}" -ne 0 ]]
	then
		echo -e "[\033[31mFAILED\033[0m]"
		echo "${checkoutReturn}" >&2
		returnCode=1
		continue
	fi
	echo -e "[\033[32mOK\033[0m]"

	${gitCommand} add -u
	if [[ "${?}" -ne 0 ]]
	then
		returnCode=1
		continue
	fi

	${gitCommand} commit -m "$(commitMessage "${property}" "${updateOutput}")" -m "$(commitDetails "${property}" "${updateOutput}")"
	if [[ "${?}" -ne 0 ]]
	then
		returnCode=1
		continue
	fi

	${gitCommand} push origin "${property}_upgrade_${branchVersionUpgrade}"
	if [[ "${?}" -ne 0 ]]
	then
		returnCode=1
		continue
	fi

	if [[ ${gitCommand} = "hub" ]]
	then
		typeset version=$( echo "${updateOutput}" | grep '^\[INFO\] Updated ${'"${property}"'}' | grep -o "[^ ]* to [^ ]*$" | sed 's/to/->/' )

		hub pull-request  -m "${property} upgrade ${version}" -b "${gitBranch}" -h "${property}_upgrade_${branchVersionUpgrade}"
		if [[ "${?}" -ne 0 ]]
		then
			returnCode=1
		fi
	fi

done

exit "${returnCode}"
