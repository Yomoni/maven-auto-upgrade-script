
#Disable git command prompt (since git 2.3)
export export GIT_TERMINAL_PROMPT=0

function usage
{
	sed -e '/^#UsageStart/,/^#UsageEnd/!d' -e 's/^#//' -e '/^UsageStart/d' -e '/^UsageEnd/d' "${0}" >&2
}

#Compare 2 versions and return the most important digit found (1:major, 2:minor, 3:patch, -1:unknown)
function compareVersions
{
	declare IFS='.'
	declare -a version1=( $1 )
	declare -a version2=( $3 )

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

#Function du print the commit message on the standard output
function commitMessage
{
	declare upgradedProperty="${1}"
	declare upgradeOutput="${2}"

	declare versionUpgrade=$( echo "${upgradeOutput}" | grep '^\[INFO\] Updated ${'"${upgradedProperty}"'}' | grep -o "[^ ]* to [^ ]*$" | sed 's/to/->/' )

	#Version comparaison for upgrade Emoji arrow type
	compareVersions ${versionUpgrade}
	declare versionDelta="${?}"
	if [[ "${versionDelta}" -eq 0 ]]
	then
		declare arrowEmoji=":arrow_double_up:"
	elif [[ "${versionDelta}" -eq 2 ]]
	then
		declare arrowEmoji=":arrow_up_small:"
	#Default upgrade Emoji
	else
		declare arrowEmoji=":arrow_up:"
	fi

	#print the git commit message on the standard output
	echo ":construction_worker:${arrowEmoji} ${upgradedProperty} upgrade ${versionUpgrade}"
}

#Function to print the commit details message with updated dependencies on the standard output
function commitDetails
{
	declare upgradedProperty="${1}"
	declare upgradeOutput="${2}"

	declare versionUpgrade=$( echo "${upgradeOutput}" | grep '^\[INFO\] Updated ${'"${upgradedProperty}"'}' | grep -o "[^ ]* to [^ ]*$" | sed 's/to/->/' )

	declare commitDescription="Upgraded artifact details:\n"
	declare upgradedArtifactDetails=$( echo "${upgradeOutput}" | grep "^\[INFO\] artifact " | grep -o "[^ ]*:[^ ]*:[^ ]*" | sort -u )
	while read line
	do
		commitDescription="${commitDescription}${line} ${versionUpgrade}\n"
	done <<< "${upgradedArtifactDetails}"

	#print the git commit details on the standard output
	echo -e "${commitDescription}"
}

#Function to check git/hub/Maven command access
function environmentCheck
{
	#Verify if the environment check has been already done
	if [[ "${environmentChecked}" ]]
	then
		return 0
	fi

	#Git command check
	echo -n "Verifying Git version:..."
	gitVersionOutput=$( git --version 2>&1 )
	if [[ "${?}" -ne 0 ]]
	then
		echo -e "[\033[31mNOT FOUND\033[0m]"
		echo "$0 needs Git, check your installation and the PATH environment variable" >&2
		return 1
	fi
	gitVersion=$( echo "${gitVersionOutput}" | grep "^git " | cut -d' ' -f 3 )
	if [[ "${gitVersion}" < "2.3" ]]
	then
		echo -e "[\033[33mOLD VERSION DETECTED\033[0m] -> "$( echo "${gitVersionOutput}" | grep "^git " )
		echo "$0 optionaly needs git 2.3 version or greater for non-interactive git commands by using GIT_TERMINAL_PROMPT=0" >&2
	else
		echo -e "[\033[32mOK\033[0m] -> "$( echo "${gitVersionOutput}" | grep "^git " )
	fi

	#GitHub hub command check (optional)
	echo -n "Verifying GitHub Hub version:..."
	#Check hub command as git alias (if sourced or global one)
	echo "${gitVersionOutput}" | grep "^hub " >/dev/null
	if [[ "${?}" -eq 0 ]]
	then
		echo -e "[\033[32mOK\033[0m] found into git command -> "$( echo "${gitVersionOutput}" | grep "^hub " )
		export hubCommand="git"

	#Test hub as an external command (default installation)
	else
		hubVersionOutput=$( hub --version 2>&1 )
		if [[ "${?}" -ne 0 ]]
		then
			echo -e "[\033[33mNOT FOUND\033[0m]"
			echo "$0 optionaly needs GitHub hub command to create some pull-request (https://hub.github.com), check your GitHub Hub installation and the PATH environment variable" >&2
		else
			export hubCommand="hub"
			echo -e "[\033[32mOK\033[0m] found hub command -> "$( echo "${hubVersionOutput}" | grep "^hub " )
		fi
	fi

	#Maven command check
	echo -n "Verifying Maven version:..."
	mavenVersion=$( mvn --version 2>&1 )
	if [[ "${?}" -ne 0 ]]
	then
		echo -e "[\033[31mNOT FOUND\033[0m]"
		echo "${mavenVersion}" >&2
		echo "$0 needs Maven, check your installation and the PATH environment variable" >&2
		return 1
	fi
	echo -e "[\033[32mOK\033[0m] -> "$( echo "${mavenVersion}" | awk '{ print $1,$2,$3 ; exit }' )

	#Flag the environment check
	export environmentChecked=OK
	return 0
}
