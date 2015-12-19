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

#git check
echo -n "Verify git version:..."
typeset gitVersion=$( git --version 2>&1 )
if [[ ${?} -ne 0 ]]
then
	echo "[NOT FOUND]"
	echo "$0 needs git, check your installation and the PATH environment variable" >&2
	exit 1
fi
echo "[OK] -> ${gitVersion}"

#GitHub hub check (optionnal)
echo -n "Verifying hub version:..."
typeset hubVersion=$( hub --version 2>&1 )
if [[ ${?} -ne 0 ]]
then
	gitCommand="git"
	echo "[NOT FOUND]"
	echo "$0 optionally needs GitHub hub command to create some pull-request (https://hub.github.com), check your installation and the PATH environment variable" >&2
else
	gitCommand="hub"
	echo "[OK] -> "${hubVersion}
fi

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

typeset -r gitHubRespositoryUrl="${1}"
typeset -r gitBranch="${2:-master}"

rm -rf tmp 2>/dev/null
hub clone --depth 1 "${gitHubRespositoryUrl}" tmp
if [[ ${?} -ne 0 ]]
then
	rm -rf tmp 2>/dev/null
	exit 1
fi

cd tmp

typeset -r versionOutput=$( mvn -U versions:display-plugin-updates  versions:display-property-updates )
if [[ ${?} -ne 0 ]]
then
	rm -rf tmp 2>/dev/null
	exit 1
fi

typeset returnCode=0

echo "${versionOutput}" | grep -- "->" | grep '${' | while read line
do
	echo "Upgrade detected: ${line}"

	typeset property=$( echo "${line}" | awk '{print $2}' | sed -e 's/^${//' -e 's/}$//' )

	#Get back to the pull-request target branch (default: master)
	hub checkout "${gitBranch}"
	if [[ "${?}" -ne 0 ]]
	then
		returnCode=1
		continue
	fi

	typeset updateOutput=$( mvn -U versions:update-property -Dproperty="${property}" )
	if [[ "${?}" -ne 0 ]]
	then
		returnCode=1
		continue
	fi

	typeset branchVersionUpgrade=$( echo "${updateOutput}" | grep '^\[INFO\] Updated ${'"${property}"'}' | grep -o "[^ ]* to [^ ]*$" | sed 's/ /_/g' )

	hub checkout --track -b "${property}_upgrade_${branchVersionUpgrade}"
	if [[ "${?}" -ne 0 ]]
	then
		returnCode=1
		continue
	fi

	hub add -u
	if [[ "${?}" -ne 0 ]]
	then
		returnCode=1
		continue
	fi

	hub commit -m "$(commitMessage "${property}" "${updateOutput}")" -m "$(commitDetails "${property}" "${updateOutput}")"
	if [[ "${?}" -ne 0 ]]
	then
		returnCode=1
		continue
	fi

	hub push origin "${property}_upgrade_${branchVersionUpgrade}"
	if [[ "${?}" -ne 0 ]]
	then
		returnCode=1
		continue
	fi

	typeset version=$( echo "${updateOutput}" | grep '^\[INFO\] Updated ${'"${property}"'}' | grep -o "[^ ]* to [^ ]*$" | sed 's/to/->/' )

	hub pull-request  -m "${property} upgrade ${version}" -b "${gitBranch}" -h "${property}_upgrade_${branchVersionUpgrade}"
	if [[ "${?}" -ne 0 ]]
	then
		returnCode=1
	fi

done

exit "${returnCode}"
