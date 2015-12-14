#!/usr/bin/env bash

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

typeset version=$( hub --version )
if [[ ${?} -ne 0 ]]
then
	exit 1
fi

echo "${version}"

rm -rf tmp 2>/dev/null
hub clone $1 tmp
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

echo "${versionOutput}" | grep -- "->" | grep '${' | while read line
do
	echo "Upgrade detected: ${line}"

	typeset property=$( echo "${line}" | awk '{print $2}' | sed -e 's/^${//' -e 's/}$//' )

	typeset updateOutput=$( mvn -U versions:update-property -Dproperty="${property}" )

	typeset branchVersionUpgrade=$( echo "${updateOutput}" | grep '^\[INFO\] Updated ${'"${property}"'}' | grep -o "[^ ]* to [^ ]*$" | sed 's/ /_/g' )

	hub checkout -b "${property}_upgrade_${branchVersionUpgrade}"

	hub push origin "${property}_upgrade_${branchVersionUpgrade}"

	hub add -u

	hub commit -m "$(commitMessage "${property}" "${updateOutput}")" -m "$(commitDetails "${property}" "${updateOutput}")"
	hub push

	typeset version=$( echo "${updateOutput}" | grep '^\[INFO\] Updated ${'"${property}"'}' | grep -o "[^ ]* to [^ ]*$" | sed 's/to/->/' )

	hub pull-request  -m "${property} upgrade ${version}" -b "master" -h "${property}_upgrade_${branchVersionUpgrade}"

done

exit 0
