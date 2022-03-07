
######## jupiter // ip addr show ########
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq master br-wan state UP group default qlen 1000
    link/ether 9c:3d:cf:ea:e6:ff brd ff:ff:ff:ff:ff:ff
3: dummy0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether c6:45:1f:35:78:f0 brd ff:ff:ff:ff:ff:ff
4: teql0: <NOARP> mtu 1500 qdisc noop state DOWN group default qlen 100
    link/void 
7: br-wan: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 9c:3d:cf:ea:e6:ff brd ff:ff:ff:ff:ff:ff
    inet 192.168.178.56/24 brd 192.168.178.255 scope global br-wan
       valid_lft forever preferred_lft forever
    inet6 2a01:c23:c10c:9600:9e3d:cfff:feea:e6ff/64 scope global dynamic noprefixroute 
       valid_lft 7016sec preferred_lft 3416sec
    inet6 fe80::9e3d:cfff:feea:e6ff/64 scope link 
       valid_lft forever preferred_lft forever
8: local-port@local-node: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-client state UP group default qlen 1000
    link/ether 9c:3d:cf:ea:e6:ff brd ff:ff:ff:ff:ff:ff
9: local-node@local-port: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 16:41:95:40:f7:dc brd ff:ff:ff:ff:ff:ff
    inet 10.80.152.1/21 brd 10.80.159.255 scope global local-node
       valid_lft forever preferred_lft forever
    inet6 fd62:f45c:4d09:103::1/128 scope global deprecated 
       valid_lft forever preferred_lft 0sec
    inet6 fe80::1441:95ff:fe40:f7dc/64 scope link 
       valid_lft forever preferred_lft forever
11: bat0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-client state UNKNOWN group default qlen 1000
    link/ether 9c:3d:cf:ea:e6:ff brd ff:ff:ff:ff:ff:ff
    inet6 fe80::9e3d:cfff:feea:e6ff/64 scope link 
       valid_lft forever preferred_lft forever
12: primary0: <BROADCAST,NOARP,UP,LOWER_UP> mtu 1532 qdisc noqueue master bat0 state UNKNOWN group default qlen 1000
    link/ether 26:7e:97:5b:9f:cb brd ff:ff:ff:ff:ff:ff
    inet6 fe80::247e:97ff:fe5b:9fcb/64 scope link 
       valid_lft forever preferred_lft forever
13: br-client: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 9c:3d:cf:ea:e6:ff brd ff:ff:ff:ff:ff:ff
    inet6 2001:678:ed0:103:9e3d:cfff:feea:e6ff/64 scope global dynamic noprefixroute 
       valid_lft 7196sec preferred_lft 3596sec
    inet6 2001:678:e68:103:9e3d:cfff:feea:e6ff/64 scope global dynamic noprefixroute 
       valid_lft 7021sec preferred_lft 3421sec
    inet6 fd62:f45c:4d09:103:9e3d:cfff:feea:e6ff/64 scope global dynamic noprefixroute 
       valid_lft 86390sec preferred_lft 14390sec
    inet6 fe80::9e3d:cfff:feea:e6ff/64 scope link 
       valid_lft forever preferred_lft forever
288: wg_mesh_vpn: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1420 qdisc noqueue state UNKNOWN group default qlen 1000
    link/none 
    inet6 fe80::2f4:a1ff:fea0:c4c4/64 scope link 
       valid_lft forever preferred_lft forever
289: mesh-vpn: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1350 qdisc tbf master bat0 state UNKNOWN group default qlen 1000
    link/ether 26:7e:97:5b:9f:cf brd ff:ff:ff:ff:ff:ff
    inet6 fe80::247e:97ff:fe5b:9fcf/64 scope link 
       valid_lft forever preferred_lft forever
332: mesh0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1532 qdisc noqueue master bat0 state UP group default qlen 1000
    link/ether 26:7e:97:5b:9f:c9 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::247e:97ff:fe5b:9fc9/64 scope link 
       valid_lft forever preferred_lft forever
333: mesh1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1532 qdisc noqueue master bat0 state UP group default qlen 1000
    link/ether 26:7e:97:5b:9f:cd brd ff:ff:ff:ff:ff:ff
    inet6 fe80::247e:97ff:fe5b:9fcd/64 scope link 
       valid_lft forever preferred_lft forever
334: wan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-wan state UP group default qlen 1000
    link/ether 26:7e:97:5b:9f:cb brd ff:ff:ff:ff:ff:ff
    inet6 fe80::247e:97ff:fe5b:9fcb/64 scope link 
       valid_lft forever preferred_lft forever
335: wan1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-wan state UP group default qlen 1000
    link/ether 26:7e:97:5b:9f:cf brd ff:ff:ff:ff:ff:ff
    inet6 fe80::247e:97ff:fe5b:9fcf/64 scope link 
       valid_lft forever preferred_lft forever
336: client1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-client state UP group default qlen 1000
    link/ether 26:7e:97:5b:9f:cc brd ff:ff:ff:ff:ff:ff
    inet6 fe80::247e:97ff:fe5b:9fcc/64 scope link 
       valid_lft forever preferred_lft forever
337: client0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-client state UP group default qlen 1000
    link/ether 26:7e:97:5b:9f:c8 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::247e:97ff:fe5b:9fc8/64 scope link 
       valid_lft forever preferred_lft forever

######## hera-e // ip addr show ########
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: dummy0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether f6:da:fb:30:99:ae brd ff:ff:ff:ff:ff:ff
3: eth0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc fq_codel master br-wan state DOWN group default qlen 1000
    link/ether ec:08:6b:33:69:41 brd ff:ff:ff:ff:ff:ff
4: eth1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc fq_codel master br-client state DOWN group default qlen 1000
    link/ether ec:08:6b:33:69:3f brd ff:ff:ff:ff:ff:ff
6: br-client: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether ec:08:6b:33:69:40 brd ff:ff:ff:ff:ff:ff
    inet6 2001:678:ed0:103:ee08:6bff:fe33:6940/64 scope global dynamic noprefixroute 
       valid_lft 7195sec preferred_lft 3595sec
    inet6 2001:678:e68:103:ee08:6bff:fe33:6940/64 scope global dynamic noprefixroute 
       valid_lft 7020sec preferred_lft 3420sec
    inet6 fd62:f45c:4d09:103:ee08:6bff:fe33:6940/64 scope global dynamic noprefixroute 
       valid_lft 86105sec preferred_lft 14105sec
    inet6 fe80::ee08:6bff:fe33:6940/64 scope link 
       valid_lft forever preferred_lft forever
7: br-wan: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether ec:08:6b:33:69:41 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::ee08:6bff:fe33:6941/64 scope link 
       valid_lft forever preferred_lft forever
8: local-port@local-node: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-client state UP group default qlen 1000
    link/ether ec:08:6b:33:69:40 brd ff:ff:ff:ff:ff:ff
9: local-node@local-port: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 16:41:95:40:f7:dc brd ff:ff:ff:ff:ff:ff
    inet 10.80.152.1/21 brd 10.80.159.255 scope global local-node
       valid_lft forever preferred_lft forever
    inet6 fd62:f45c:4d09:103::1/128 scope global deprecated 
       valid_lft forever preferred_lft 0sec
    inet6 fe80::1441:95ff:fe40:f7dc/64 scope link 
       valid_lft forever preferred_lft forever
10: bat0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-client state UNKNOWN group default qlen 1000
    link/ether ec:08:6b:33:69:40 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::ee08:6bff:fe33:6940/64 scope link 
       valid_lft forever preferred_lft forever
11: primary0: <BROADCAST,NOARP,UP,LOWER_UP> mtu 1532 qdisc noqueue master bat0 state UNKNOWN group default qlen 1000
    link/ether 72:c8:f8:77:0a:23 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::70c8:f8ff:fe77:a23/64 scope link 
       valid_lft forever preferred_lft forever
29834: wg_mesh_vpn: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1420 qdisc noqueue state UNKNOWN group default qlen 1000
    link/none 
    inet6 fe80::294:dbff:fec7:512/64 scope link 
       valid_lft forever preferred_lft forever
29835: mesh-vpn: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1350 qdisc noqueue master bat0 state UNKNOWN group default qlen 1000
    link/ether 72:c8:f8:77:0a:27 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::70c8:f8ff:fe77:a27/64 scope link 
       valid_lft forever preferred_lft forever
29844: mesh0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1532 qdisc noqueue master bat0 state UP group default qlen 1000
    link/ether 72:c8:f8:77:0a:21 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::70c8:f8ff:fe77:a21/64 scope link 
       valid_lft forever preferred_lft forever
29845: wan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-wan state UP group default qlen 1000
    link/ether 72:c8:f8:77:0a:23 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::70c8:f8ff:fe77:a23/64 scope link 
       valid_lft forever preferred_lft forever
29846: client0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-client state UP group default qlen 1000
    link/ether 72:c8:f8:77:0a:20 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::70c8:f8ff:fe77:a20/64 scope link 
       valid_lft forever preferred_lft forever
29847: vx_mesh_wan: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1430 qdisc noqueue master bat0 state UNKNOWN group default qlen 1000
    link/ether 72:c8:f8:77:0a:20 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::70c8:f8ff:fe77:a20/64 scope link 
       valid_lft forever preferred_lft forever

######## ares-e // ip addr show ########
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: dummy0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether ca:55:05:5f:da:13 brd ff:ff:ff:ff:ff:ff
3: eth0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc fq_codel master br-wan state DOWN group default qlen 1000
    link/ether ec:08:6b:33:6f:25 brd ff:ff:ff:ff:ff:ff
4: eth1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc fq_codel master br-client state DOWN group default qlen 1000
    link/ether ec:08:6b:33:6f:23 brd ff:ff:ff:ff:ff:ff
6: br-client: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether ec:08:6b:33:6f:24 brd ff:ff:ff:ff:ff:ff
    inet6 2001:678:e68:103:ee08:6bff:fe33:6f24/64 scope global dynamic noprefixroute 
       valid_lft 7018sec preferred_lft 3418sec
    inet6 2001:678:ed0:103:ee08:6bff:fe33:6f24/64 scope global dynamic noprefixroute 
       valid_lft 7193sec preferred_lft 3593sec
    inet6 fd62:f45c:4d09:103:ee08:6bff:fe33:6f24/64 scope global dynamic noprefixroute 
       valid_lft 86045sec preferred_lft 14045sec
    inet6 fe80::ee08:6bff:fe33:6f24/64 scope link 
       valid_lft forever preferred_lft forever
7: br-wan: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether ec:08:6b:33:6f:25 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::ee08:6bff:fe33:6f25/64 scope link 
       valid_lft forever preferred_lft forever
8: local-port@local-node: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-client state UP group default qlen 1000
    link/ether ec:08:6b:33:6f:24 brd ff:ff:ff:ff:ff:ff
9: local-node@local-port: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 16:41:95:40:f7:dc brd ff:ff:ff:ff:ff:ff
    inet 10.80.152.1/21 brd 10.80.159.255 scope global local-node
       valid_lft forever preferred_lft forever
    inet6 fd62:f45c:4d09:103::1/128 scope global deprecated 
       valid_lft forever preferred_lft 0sec
    inet6 fe80::1441:95ff:fe40:f7dc/64 scope link 
       valid_lft forever preferred_lft forever
10: bat0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-client state UNKNOWN group default qlen 1000
    link/ether ec:08:6b:33:6f:24 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::ee08:6bff:fe33:6f24/64 scope link 
       valid_lft forever preferred_lft forever
11: primary0: <BROADCAST,NOARP,UP,LOWER_UP> mtu 1532 qdisc noqueue master bat0 state UNKNOWN group default qlen 1000
    link/ether fe:cc:1f:5e:29:f3 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::fccc:1fff:fe5e:29f3/64 scope link 
       valid_lft forever preferred_lft forever
10300: mesh0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1532 qdisc noqueue master bat0 state UP group default qlen 1000
    link/ether fe:cc:1f:5e:29:f1 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::fccc:1fff:fe5e:29f1/64 scope link 
       valid_lft forever preferred_lft forever
10301: wan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-wan state UP group default qlen 1000
    link/ether fe:cc:1f:5e:29:f3 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::fccc:1fff:fe5e:29f3/64 scope link 
       valid_lft forever preferred_lft forever
10302: client0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-client state UP group default qlen 1000
    link/ether fe:cc:1f:5e:29:f0 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::fccc:1fff:fe5e:29f0/64 scope link 
       valid_lft forever preferred_lft forever
10931: wg_mesh_vpn: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1420 qdisc noqueue state UNKNOWN group default qlen 1000
    link/none 
    inet6 fe80::2cb:43ff:fe83:26eb/64 scope link 
       valid_lft forever preferred_lft forever
10932: mesh-vpn: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1350 qdisc tbf master bat0 state UNKNOWN group default qlen 1000
    link/ether fe:cc:1f:5e:29:f7 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::fccc:1fff:fe5e:29f7/64 scope link 
       valid_lft forever preferred_lft forever

######## zeus-i (zeus) // ip addr show ########
