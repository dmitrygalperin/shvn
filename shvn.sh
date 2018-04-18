#!/bin/bash
source /home/produ/shvn/shvn.cnf

red=$'\e[1;31m'
grn=$'\e[1;32m'
end=$'\e[0m'

load_shvn_file() {
    source .shvn 2>/dev/null
    if [ -z ${repo+x} ]
    then
        printf "${red}Current directory is not an shvn repository${end}\n"
        exit 1
    fi
}

update_shvn_file() {
	printf "repo=${repo}\nversion=${version}\n" > .shvn
}

update_remote_shvn_file() {
	ssh ${user}@${shvn_host} "printf head=%s $1 > ${shvnDir}/${2}/.shvn"
}

load_remote_shvn_file() {
	scp ${user}@${shvn_host}:${shvnDir}/${1}/.shvn /tmp/.shvn
	source /tmp/.shvn
	if [ -z ${head+x} ]
	then
		printf "${red}Not an shvn repository: $1${end}\n"
		exit 1
	fi
}

init() {
    dirName=$1
    if ssh ${user}@${shvn_host} "[ -d ${shvnDir}/${dirName} ]"
    then
        printf "${red}There is already a repository with name ${dirName}${end}\n"
        exit 1
    fi
    printf "Initializing new repository with name ${dirName}\n"
    ssh ${user}@${shvn_host} "mkdir ${shvnDir}/${dirName}"
	update_remote_shvn_file -1 ${dirName}
    printf "Creating .shvn file\n"
    printf "repo=${dirName}\nversion=-1\n" > .shvn
    printf "${grn}Successfully created new repository ${dirName}${end}\n"     
}

destroy() {
    load_shvn_file
    printf "Destroying repository ${repo}\n"
    ssh ${user}@${shvn_host} "rm -rf ${shvnDir}/${repo}"
    rm .shvn
    printf "${grn}Successfully destroyed repository ${repo}${end}\n"
}

push() {
    load_shvn_file
    printf "Packaging local version\n"
    version=$((version+1))
    update_shvn_file
	update_remote_shvn_file ${version} ${repo}
    tar -czf /tmp/${version}.tar.gz .
    printf "Pushing to remote\n"
    scp /tmp/${version}.tar.gz ${user}@${shvn_host}:${shvnDir}/${repo}
    printf "${grn}Successfully pushed version ${version} to remote${end}\n"
}

clone() {
	load_remote_shvn_file $1
	if [ -d ./$1 ]
	then
		printf "${red}Directory ${1} already exists.${end}\n"
		exit 1
	fi
    printf "Cloning ${1}\n"
	mkdir $1
	scp ${user}@${shvn_host}:${shvnDir}/${1}/${head}.tar.gz /tmp
	tar -xzf /tmp/${head}.tar.gz -C ./$1
	printf "${grn}Successfully cloned repository ${1}${end}\n"
}

pull() {
	load_shvn_file
	load_remote_shvn_file $repo
	if [ "$version" == "$head" ]
	then
		printf "${grn}Current version up to date with remote. No pull necessary.${end}\n"
		exit 1
	fi
	printf "Pulling latest version\n"
	scp ${user}@${shvn_host}:${shvnDir}/${repo}/${head}.tar.gz /tmp
	tar -xzf /tmp/${head}.tar.gz -C .
	printf "${grn}Successfully pulled version ${head}${end}\n"
}

deploy() {
	case $1 in
		staging)
			declare -a ips=($frontend_staging $backend_staging $database_staging)
			;;
		prod)
			declare -a ips=($frontend_prod $backend_prod $database_prod1 $database_prod2)
			;;
	esac
	for ip in "${ips[@]}"
	do
		printf "${grn}Killing Python on ${ip}${end}\n"
		ssh ${user}@${ip} "killall -9 python3 > /dev/null 2> /dev/null; killall -9 python > /dev/null 2> /dev/null"
		printf "${grn}Pulling current project version on ${ip}${end}\n"
		ssh ${user}@${ip} "cd /home/produ/it490; /home/produ/shvn/shvn.sh pull"
		printf "${grn}Starting application server on ${ip}${end}\n"
		ssh ${user}@${ip} "/home/produ/start.sh > /dev/null 2> /dev/null &"
	done
}

rollback() {
	load_shvn_file
	load_remote_shvn_file $repo
	version=$((version+1))
	update_remote_shvn_file $version $repo
	#scp ${user}@${shvn_host}:${shvnDir}/${repo}/${1}.tar.gz ${user}@${shvn_host}:${shvnDir}/${repo}/${version}.tar.gz
	ssh ${user}@${shvn_host} "cp ${shvnDir}/${repo}/${1}.tar.gz ${shvnDir}/${repo}/${version}.tar.gz"
	pull
}

ctype=$1
arg=$2

case $ctype in
    init)
        init ${arg}
        ;;
    destroy)
        destroy
        ;;
    push)
        push
        ;;
	pull)
		pull
		;;
	rollback)
		rollback ${arg}
		;;
	clone)
		clone ${arg}
		;;
	deploy)
		deploy ${arg}
		;;
    *)
        printf "${red}Unknown argument: ${ctype}${end}\n"
esac

