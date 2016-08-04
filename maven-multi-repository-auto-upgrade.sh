#!/usr/bin/env bash
#
#UsageStart
#
# Usage: $0 <https://github.com/account1/repository1.git|git directory> [<https://github.com/account2/repository2.git|git directory>, ... ]
#        The target branch on these repositories is the master branch
#
#UsageEnd

#Change current directory to the script one
cd $( dirname "${0}")
typeset -r scriptDir="${PWD}"
#Source git function library
source "${scriptDir}/lib/git-lib.sh"

#Main

#Arguments checking
if [[ "${#}" -lt 1 ]]
then
	usage
	exit 1
fi

#help display
if [[ "${1}" = "-h" || "${1}" = "help" || "${1}" = "--help" ]]
then
	usage
	exit 0
fi

#Environment check
environmentCheck
if [[ "${?}" -ne 0 ]]
then
	exit 1
fi

#Sub-script execution right check
if [[ ! -x "${scriptDir}/maven-auto-upgrade.sh" ]]
then
	chmod u+x "${scriptDir}/maven-auto-upgrade.sh"
fi

#Script return code
typeset -i multiScriptReturnCode=0

#Loop on repositories
for gitRepository in ${*}
do
	echo -e "\nCheck Maven dependencies upgrades of ${gitRepository} repository"
	"${scriptDir}/maven-auto-upgrade.sh" "${gitRepository}"
	if [[ "${?}" -ne 0 ]]
	then
		multiScriptReturnCode=1
	fi
done

exit "${multiScriptReturnCode}"
