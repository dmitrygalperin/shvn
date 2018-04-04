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

init() {
    dirName=$1
    if ssh ${user}@${shvn_host} "[ -d ${shvnDir}/${dirName} ]"
    then
        printf "${red}There is already a repository with name ${dirName}${end}\n"
        exit 1
    fi
    printf "Initializing new repository with name ${dirName}\n"
    ssh ${user}@${shvn_host} "mkdir ${shvnDir}/${dirName}"
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
    tar -czf /tmp/${version}.tar.gz .
    printf "Pushing to remote\n"
    scp /tmp/${version}.tar.gz ${user}@${shvn_host}:${shvnDir}/${repo}
    printf "${grn}Successfully pushed version ${version} to remote${end}\n"
}

ctype=$1
arg=$2

case $ctype in
    init)
        init ${arg}
        ;;
    destroy)
        destroy ${arg}
        ;;
    push)
        push
        ;;
    *)
        printf "${red}Unknown argument: ${ctype}${end}\n"
esac

