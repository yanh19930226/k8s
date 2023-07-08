#!/bin/bash
#
#********************************************************************
#Author:            yanh
#QQ:                891367701
#Date:              2020-07-05
#FileName:          install_kubernetes.sh
#URL:               http://yande.com
#Description:       The install_kubernetes.sh script
#Copyright (C):     2020 All rights reserved
#********************************************************************

#说明:安装Kubernetes服务器内存建议至少2G

KUBE_VERSION="1.23.5"
#KUBE_VERSION="1.24.4"
KUBE_VERSION2=$(echo $KUBE_VERSION |awk -F. '{print $2}')

DOMAIN=yande.org
KUBEAPI_IP=172.31.0.100
MASTER1_IP=172.31.0.4
MASTER2_IP=172.31.0.5
MASTER3_IP=172.31.0.6
NODE1_IP=172.31.0.7
NODE2_IP=172.31.0.8

MASTER1=master1
MASTER2=master2
MASTER3=master3
NODE1=node1
NODE2=node2
POD_NETWORK="192.168.0.0/16"
SERVICE_NETWORK="10.96.0.0/12"
IMAGES_URL="registry.aliyuncs.com/google_containers"
CIR_DOCKER_VERSION=0.2.5
CIR_DOCKER_URL="https://github.com/Mirantis/cri-dockerd/releases/download/v${CIR_DOCKER_VERSION}/cri-dockerd_${CIR_DOCKER_VERSION}.3-0.ubuntu-${UBUNTU_CODENAME}_amd64.deb"
LOCAL_IP=`hostname -I|awk '{print $1}'`

. /etc/os-release

COLOR_SUCCESS="echo -e \\033[1;32m"
COLOR_FAILURE="echo -e \\033[1;31m"
END="\033[m"


color () {
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_NORMAL="echo -en \E[0m"
    echo -n "$1" && $MOVE_TO_COL
    echo -n "["
    if [ $2 = "success" -o $2 = "0" ] ;then
        ${SETCOLOR_SUCCESS}
        echo -n $"  OK  "    
    elif [ $2 = "failure" -o $2 = "1"  ] ;then 
        ${SETCOLOR_FAILURE}
        echo -n $"FAILED"
    else
        ${SETCOLOR_WARNING}
        echo -n $"WARNING"
    fi
    ${SETCOLOR_NORMAL}
    echo -n "]"
    echo 
}

check () {
    if [ $ID = 'ubuntu' -a ${VERSION_ID} = "20.04"  ];then
        true
    else
        color "不支持此操作系统，退出!" 1
        exit
    fi
}

install_prepare () {
    cat >> /etc/hosts <<EOF

$KUBEAPI_IP $DOMAIN
$MASTER1_IP $MASTER1
$MASTER2_IP $MASTER2
$MASTER3_IP $MASTER3
$NODE1_IP $NODE1
$NODE2_IP $NODE2
EOF
    hostnamectl set-hostname $(awk -v ip=$LOCAL_IP '{if($1==ip && $2 !~ "kubeapi")print $2}' /etc/hosts)
    swapoff -a
    sed -i '/swap/s/^/#/' /etc/fstab
    color "安装前准备完成!" 0
    sleep 1
}

install_docker () {
    apt update
    apt -y install docker.io || { color "安装Docker失败!" 1; exit 1; }
    cat > /etc/docker/daemon.json <<EOF
{
"registry-mirrors": [
"https://docker.mirrors.ustc.edu.cn",
"https://hub-mirror.c.163.com",
"https://reg-mirror.qiniu.com",
"https://registry.docker-cn.com"
],
 "exec-opts": ["native.cgroupdriver=systemd"] 
}
EOF
    systemctl restart docker.service
    docker info && { color "安装Docker成功!" 0; sleep 1; } || { color "安装Docker失败!" 1 ; exit 2; }
}

install_kubeadm () {
    apt-get update && apt-get install -y apt-transport-https
    curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 
    cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
    apt-get update
    apt-cache madison kubeadm |head
    ${COLOR_FAILURE}"5秒后即将安装: kubeadm-"${KUBE_VERSION}" 版本....."${END}
    ${COLOR_FAILURE}"如果想安装其它版本，请按ctrl+c键退出，修改版本再执行"${END}
    sleep 6

    #安装指定版本
    apt install -y  kubeadm=${KUBE_VERSION}-00 kubelet=${KUBE_VERSION}-00 kubectl=${KUBE_VERSION}-00
    [ $? -eq 0 ] && { color "安装kubeadm成功!" 0;sleep 1; } || { color "安装kubeadm失败!" 1 ; exit 2; }
    
    #实现kubectl命令自动补全功能    
    kubectl completion bash > /etc/profile.d/kubectl_completion.sh
}

#Kubernetes-v1.24之前版本无需安装cri-dockerd
install_cri_dockerd () {
    [ $KUBE_VERSION2 -lt 24 ] && return
    if [ ! -e cri-dockerd_${CIR_DOCKER_VERSION}.3-0.ubuntu-${UBUNTU_CODENAME}_amd64.deb ];then
        curl -LO $CIR_DOCKER_URL || { color "下载cri-dockerd失败!" 1 ; exit 2; }
    fi
    dpkg -i cri-dockerd_${CIR_DOCKER_VERSION}.3-0.ubuntu-${UBUNTU_CODENAME}_amd64.deb 
    [ $? -eq 0 ] && color "安装cri-dockerd成功!" 0 || { color "安装cri-dockerd失败!" 1 ; exit 2; }
    sed -i '/^ExecStart/s#$# --pod-infra-container-image registry.aliyuncs.com/google_containers/pause:3.7#'   /lib/systemd/system/cri-docker.service
    systemctl daemon-reload 
    systemctl restart cri-docker.service
    [ $? -eq 0 ] && { color "配置cri-dockerd成功!" 0 ; sleep 1; } || { color "配置cri-dockerd失败!" 1 ; exit 2; }
}

#只有Kubernetes集群的第一个master节点需要执行下面初始化函数
kubernetes_init () {
    if [ $KUBE_VERSION2 -lt 24 ] ;then
        kubeadm init --control-plane-endpoint=${DOMAIN} \
                 --kubernetes-version=v${KUBE_VERSION}  \
                 --pod-network-cidr=${POD_NETWORK} \
                 --service-cidr=${SERVICE_NETWORK} \
                 --token-ttl=0  \
                 --image-repository ${IMAGES_URL}   \
                 --upload-certs                
    else
    #Kubernetes-v1.24版本前无需加选项 --cri-socket=unix:///run/cri-dockerd.sock
        kubeadm init --control-plane-endpoint=${DOMAIN} \
                 --kubernetes-version=v${KUBE_VERSION}  \
                 --pod-network-cidr=${POD_NETWORK} \
                 --service-cidr=${SERVICE_NETWORK} \
                 --token-ttl=0  \
                 --upload-certs \
                 --image-repository=${IMAGES_URL} \
                 --cri-socket=unix:///run/cri-dockerd.sock
    fi
    [ $? -eq 0 ] && color "Kubernetes集群初始化成功!" 0 || { color "Kubernetes集群初始化失败!" 1 ; exit 3; }
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
}

reset_kubernetes() {
    kubeadm reset -f --cri-socket unix:///run/cri-dockerd.sock
    rm -rf  /etc/cni/net.d/  $HOME/.kube/config
}


check 

PS3="请选择编号(1-4): "
ACTIONS="
初始化新的Kubernetes集群
加入已有的Kubernetes集群
退出Kubernetes集群
退出本程序
"
select action in $ACTIONS;do
    case $REPLY in 
    1)
        install_prepare
        install_docker
        install_kubeadm
        install_cri_dockerd
        kubernetes_init
        break
        ;;
    2)
        install_prepare
        install_docker
        install_kubeadm
        install_cri_dockerd
        $COLOR_SUCCESS"加入已有的Kubernetes集群已准备完毕,还需要执行最后一步加入集群的命令 kubeadm join !"${END}
        break
        ;;
    3)
        reset_kubernetes
        break
        ;;
    4)
        exit
        ;;
    esac
done

