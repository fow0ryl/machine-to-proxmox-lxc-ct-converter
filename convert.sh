#!/bin/bash
if ! command -v pct &> /dev/null
then
    echo "pct could not be found. This script must be run on proxmox host"
#    exit 1
fi

# set defaults
name="DietPi-LXC"
ip="dhcp"
bridge="vmbr0"
gateway=""
port="22"
#storage="local-lvm"
storage="local-btrfs"
rootsize="2"
memory="2048"
cores="2"
password="dietpi"

usage()
{
    cat <<EOF

$1 
 -h|--help
 -n|--name [ target lxc container name (default: $name) ]
 -v|--vm-host [ source virtual machine ssh uri (IP or hostname) ]
 -P|--port [ ssh port on source virtual machine (default:$port) ]  
 -i|--id [ target lxc container proxmox container id]
 -s|--root-size [ target lxc container rootfs size in GB (default: $rootsize GB) ]
 -I|--ip [ target container ip (default: $ip) ]
 -b|--bridge [ bridge interface (default: $bridge) ]  
 -g|--gateway [ gateway ip (default: DHCP) ] 
 -m|--memory [ target lxc container memory in MB (default: $memory) ]
 -c|--cores [ target lxc container cpu cores (defalut: $cores) ]
 -d|--disk-storage [ target proxmox storage pool (default: $storage) ]
 -p|--password  [root password for container (min. 5 chars) ]

EOF
    return 0
}

usage "$(basename $0)"

options=$(getopt -o n:v:P:i:s:I:b:g:m:c:d:p:f -l help,name:,vm-host:,port:,id:,root-size:,ip:,bridge:,gateway:,memory:,cores:,disk-storage:,password:,foo: -- "$@")

if [ $? -ne 0 ]; then
    exit 1
fi
eval set -- "$options"

while true
do
    echo "1: $1 || 2: $2"
	case "$1" in
        -h|--help)      usage $0 && exit 0
						;;
        -n|--name)      name="$2"; shift 2
						;;
        -v|--vm-host)   vmhost="$2"; shift 2
						;;
        -P|--port)      port="$2"; shift 2
						;;
        -i|--id)        id="$2"; shift 2
						;;
        -s|--root-size) rootsize="$2"; shift 2
						;;
		-I|--ip)        ip="$2/24"; shift 2
						;;
        -b|--bridge)    bridge="$2"; shift 2
						;;
        -g|--gateway)   gateway=",gw=$2"; shift 2
						;;
        -m|--memory)    memory="$2"; shift 2
						;;
        -c|--cores)     cores="$2"; shift 2
						;;
        -p|--password)  password="$2"; shift 2
						;;
        -o|--storage)   storage="$2"; shift 2
						;;
        --)             shift 2; break
						;;
        *)              break
						;;
    esac
done

# Get the next available VMID if not given
if [ "$id" = "" ]; then
   id=$(pvesh get /cluster/nextid)
fi

collectFS() {
    tar -czvvf - -C / \
        --exclude="sys" \
        --exclude="dev" \
        --exclude="run" \
        --exclude="proc" \
        --exclude="*.log" \
        --exclude="*.log*" \
        --exclude="*.gz" \
        --exclude="*.sql" \
        --exclude="swap.img" \
        .
}

# remove old file to allow ssh work without errors
rm -rf "/tmp/$name.tar.gz"

ssh -p"$port" "root@$vmhost" "$(typeset -f collectFS); collectFS" \
    > "/tmp/$name.tar.gz"

if [ -f /tmp/$name.tar.gz ]; then
#   cat <<EOF >/tmp/lxc-create.sh
# #!/bin/bash
pct create $id "/tmp/$name.tar.gz" \
 --description "DietPi LXC" \
 --hostname $name \
 --features nesting=1 \
 --memory "$memory" \
 --cores "$cores" \
 --net0 name=eth0,ip="$ip",ip6=auto,bridge="$bridge",firewall=1"$gateway" \
 --rootfs "$rootsize" \
 --storage "$storage" \
 --password "$password"
#EOF

   if [ $? -eq 0 ]; then
      rm -rf "/tmp/$name.tar.gz"
   fi

fi 

exit
