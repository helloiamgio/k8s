IPS=($(kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{" "}{end}' | tr ' ' '\n' | sort -V))

MIN_IP=${IPS[0]}
MAX_IP=${IPS[-1]}

ip2dec() {
    local IFS=.
    read -r a b c d <<< "$1"
    echo $((a*256**3 + b*256**2 + c*256 + d))
}

dec2ip() {
    local ip=$1
    echo "$(( (ip >> 24) & 255 )).$(( (ip >> 16) & 255 )).$(( (ip >> 8) & 255 )).$(( ip & 255 ))"
}

MIN_DEC=$(ip2dec $MIN_IP)
MAX_DEC=$(ip2dec $MAX_IP)

DIFF=$((MAX_DEC - MIN_DEC + 1))
PREFIX=32
while [ $DIFF -gt 1 ]; do
    PREFIX=$((PREFIX - 1))
    DIFF=$((DIFF / 2))
done

echo "Node CIDR: ${MIN_IP}/$PREFIX"
