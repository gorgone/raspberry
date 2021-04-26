#!/bin/bash

clear

DOCKER_URL="https://download.docker.com/linux"
packages="gnupg docker-compose ca-certificates apt-transport-https"

get_version(){
	echo -e " -> Get Linux Version"
	sleep 2
	dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
	ID=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
	case "$dist_version" in
		10) dist_version="buster" ;;
		9)  dist_version="stretch";;
		8)  dist_version="jessie" ;;
	esac
	echo -e "    $ID : $dist_version"
}

get_docker_gpg(){
	echo -e " -> Get & Install Docker GPG-Key"
	curl -fsSL $DOCKER_URL/$ID/gpg | \
	APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add -qq - >/dev/null
}

add_docker_repo(){
	echo -e "\n -> add Docker Repo"
	apt_repo="deb [arch=$(dpkg --print-architecture)] $DOCKER_URL/$ID $dist_version stable"
	echo $apt_repo > /etc/apt/sources.list.d/docker.list
	echo -e "    $apt_repo\n"
}

docker_install(){
	error=0
	need_install=0
	get_docker_gpg
	echo -e " -> Refresh Repos"
	apt-get update -qq >/dev/null

	echo -e " -> Check packages"
for e in $packages; do
	p_i=$(dpkg -s $e 2>/dev/null| grep '^Status' | head -1 | awk '$1=$1' | cut -d' ' -f 3)

	if [ "$p_i" = "ok" ]; then
		echo "    $e already installed"
	else
		pre_reqs="$e "$pre_reqs
		need_install=1
	fi
done

	echo ""
	if [[ $need_install = 1 ]]; then
		echo -e " -> Install : $pre_reqs"
		DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $pre_reqs >/dev/null
	fi

	pkg_pattern=".*-0~$ID-$dist_version" #pkg_pattern="$(echo "$VERSION" | sed "s/-ce-/~ce~.*/g" | sed "s/-/.*/g").*-0~$ID-$dist_version" #old version

	pkg_version=""
	pkg_version=$(apt-cache madison docker-ce | grep $pkg_pattern | head -1 | awk '{$1=$1};1' | cut -d' ' -f 3)
	if [ -n "$pkg_version" ]; then
		echo -e " -> Install : docker-ce     Version=$pkg_version"
		apt-get install -y -qq --no-install-recommends docker-ce=$pkg_version >/dev/null
	else
		echo -e "    Install : docker-ce failed"
		e_out="docker-ce"
		error=1
	fi

	cli_pkg_version=""
	cli_pkg_version=$(apt-cache madison docker-ce-cli | grep $pkg_pattern | head -1 | awk '{$1=$1};1' | cut -d' ' -f 3)
	if [ -n "$cli_pkg_version" ]; then
		echo -e " -> Install : docker-ce-cli Version=$cli_pkg_version"
		apt-get install -y -qq --no-install-recommends docker-ce-cli=$cli_pkg_version >/dev/null
	else
		echo -e "    Install : docker-ce-cli failed"
		e_out=$e_out" docker-ce-cli"
		error=1
	fi

	if [[ $error = 0 ]]; then
		echo -e "\n    Docker Installed"
	else
		echo -e "\n    Docker Install failed"
		echo -e "    $e_out not installed"
	fi
}

#################
# BEGIN Install #
#################

echo -e "\n -> Update System\n    =============\n"
sleep 2
apt update -y

echo -e "\n -> Upgrade System\n    ==============\n"
sleep 2
apt upgrade -y

echo -e "\n -> Docker Installation\n    ===================\n"
sleep 2
#bash <(curl -fsSL https://get.docker.com) #(docker fat ugly online install version)
get_version
add_docker_repo
docker_install

echo -e "\n -> Create portainer_data Volume\n    ============================\n"
sleep 2
echo -en "    "; docker volume create portainer_data

echo -e "\n -> Portainer Installation\n    ======================\n"
sleep 2
result=$( docker images -q portainer/portainer-ce )
if [[ -n "$result" ]]; then
	echo "    portainer already exists"
else
	docker run -d -p 8000:8000 -p 9000:9000 \
	--name=portainer \
	--restart=always \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v portainer_data:/data portainer/portainer-ce
fi

if [[ "$ID" == "raspbian" ]]; then
	echo -e "\n -> Optional Install Raspbian Kernel Update ?"
	echo -en "    (y/Y or n/N) : "
	while read -r -n1 key; do
		if [[ $key == $'y' ]] || [[ $key == $'Y' ]]; then
			echo -e "\n"; rpi-update; break;
		fi
		if [[ $key == $'n' ]] || [[ $key == $'N' ]]; then
			echo -e "\n"; break;
		fi
	done
fi

echo -e "\n -> Done!\n    =====\n"
sleep 5
