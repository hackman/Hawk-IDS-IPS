#!/bin/bash
chain=in_hawk
comments=''
# Validate if the system supports iptables comments
if ! iptables -L INPUT -nv|grep hawk_comment; then
	iptables -A INPUT -s 127.0.0.88 -m comment --comment "hawk_comment"
	if [[ $? == 0 ]]; then
		comments=1
		iptables -D INPUT -s 127.0.0.88 -m comment --comment "hawk_comment"
	fi
fi

if [[ -n $comments ]]; then
	sed -i '/block_comments/s/0/1/' /etc/hawk/hawk.conf
fi

# Make sure that we have our iptables chain and traffic is going trough it
if ! iptables -L -nv|grep -q $chain; then
    iptables -N $chain
    if ! iptables -L INPUT -nv|grep -q $chain; then
        iptables -A INPUT -j $chain
    fi 
fi

# Add the new chain to the configuration
if ! grep -q :$chain /etc/sysconfig/iptables; then
	sed -i "/:OUTPUT/a:$chain [0:0]" /etc/sysconfig/iptables
fi

# Add a rule to pass all traffic trough our new chain
if ! grep '\-j in_hawk' /etc/sysconfig/iptables; then
	last_rule=$(awk '/INPUT/{a=NR}END{print a}' /etc/sysconfig/iptables)
	sed -i "${last_rule}i-A INPUT -j in_hawk" /etc/sysconfig/iptables
fi
