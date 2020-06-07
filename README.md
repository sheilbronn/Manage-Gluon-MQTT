# Manage-Gluon-MQTT

Monitor and control Freifunk Nodes (Gluon) by MQTT

## manage_gluon_mqtt

**manage_gluon_mqtt** is a shell script supporting a simple integration of Freifunk nodes into a [MQTT](https://en.wikipedia.org/wiki/MQTT) network. The focus is on monitoring but maybe extended to control operations for a private MQTT network:

Supported functions/return information:

* Data about software versions and the auto-updater on the node
* Query and possibly set [UCI](https://openwrt.org/docs/guide-user/base-system/uci) values
* Query, stop and start the Freifunk public Wifi interface
* Temporarely modify the Freifunk SSID (within the limits of the local Freifunk community)
* Query amount and fingerprint of locally connected Freifunk Wifi clients
* Query static and dynamic [Gluon](https://gluon.readthedocs.io/en/latest/) data (returned as [JSON](https://de.wikipedia.org/wiki/JavaScript_Object_Notation)): nodeinfo, neighbours,statistics as well as the output from `gluon-show-site`.
* Invoke a reboot on the Freifunk node.

IMPORTANT: The script needs quite some refactoring, the code is provided as is. Yes, I know, it's ugly ;)

### More Details

The following 4 different use cases are supported:

A. Management of an (untouched) Freifunk node by **remote SSH** commands (public/private key authentication): Command results are returned as **terminal output** (stdout)

B. Management of an (untouched) Freifunk node by **remote SSH** commands (public/private key authentication): Command results are returned as **MQTT messages**.

C. Monitoring by **MQTT messages**: Invoked by an explicit SSH call or by cron, this script runs locally on the Freifunk node, returning its output as **MQTT messages**.

D. Local management like a daemon: This script listens to **MQTT messages** and returns results a MQTT messages, too. (D does not exclude C, also the script can run as a daemon invoking commands on pre-configured Freifunk hosts as in A or B)

Other aspects:

* [Home assistant](https://www.home-assistant.io/docs/mqtt/discovery/) and [Homie](https://homieiot.github.io/specification/) auto-discovery for important topics.
* MQTT discovery is tested with the [OpenHAB MQTT binding](https://www.openhab.org/addons/bindings/mqtt/) and [HoDD](https://github.com/rroemhild/hodd)
* Script runs on [bash](https://de.wikipedia.org/wiki/Bash_(Shell)) as well as [ash](https://en.wikipedia.org/wiki/Almquist_shell) (ash is used in [OpenWrt](https://openwrt.org/) as the default shell).
* If the Freifunk node has very limited memory, e.g. on [4/32 devices](https://openwrt.org/supported_devices/openwrt_on_432_devices), B might be preferred over C or D.
* In order to install the Mosquitto packages, the package installation opkg is needed on Freifunk (Gluon) devices. opkg might not be available on [devices with limited memory](https://openwrt.org/supported_devices/openwrt_on_432_devices): Use case A and B as a workaround.
* Remote management via a Freifunk "edge" node acting as a SSH proxy to other Freifunk nodes works well, e.g. use the [ProxyJump directive](https://www.redhat.com/sysadmin/ssh-proxy-bastion-proxyjump) in your `.ssh/config`.

### Prerequisites

Depending on the use case to be supported, some prequisites have to be fulfilled in order the the script work:

* Installation of the [Mosquitto](https://mosquitto.org) packages mosquitto_pub and mosquitto_sub. They should be in every Linux repository, including OpenWrt.
* For use case A, B, and C as well as debugging purposes: 
  Enable Automatic [remote invocation via SSH using public key authentication](https://openwrt.org/docs/guide-user/security/dropbear.public-key.auth)
* If you want to use the script remotely: Install ash from a package repository or replace ash by bash in the first line.
* Freifunk relies on some version of Gluon or at least OpenWRT: So far, this script has only been tested on [Freifunk Munich](https://ffmuc.net) nodes with [Gluon](https://github.com/freifunk-gluon/gluon) 2019.1.*. Please let me know or open a GitHub issue if you have success or problems with other versions
* In case of MQTT connection problems: Ensure that incoming or outgoing MQTT connections are not blocked by a firewall - consider my [mqtt-grep-color](https://github.com/sheilbronn/mqtt-grep-color) to verify and debug your MQTT setup more easily.

### Command-line options / Invocation

* -c (commands): One or more management commands to be executed (comma-separated), see below for details.
* -s (server): If the script is not run locally on the Freifunk node itself (localhost), the SSH names of one or more other Freifunk nodes maybe passed with -s (comma-seperated)
* -g (give): In the output add an informative line with host and command (useful für multiple commands and hosts)
* -v (verbose): more, verbose output from the script as well as intermediate steps
* -x (execute): each shell command is echoed to stdout before execution (for debugging)
* -q (quit): no output on stdout
* -h (host): name or IP adress of the MQTT broker (momentarily still -m).
    The public test broker test.mosquitto.org may be abbreviated as -h test.
    If no broker is given, mosquitto_pub and mosquitto_sub will use their defaults (see their manual pages)
* -m (mqtt): use MQTT or not (currently only implied by -p)
* -p : support Homie or Home-Assistant auto-discovery (not fully verified yet)

Supported commands for the -c option are - names might change during refactoring:

* *mqtt*: Script will become a daemon waiting for MQTT commands, subsequent commands are ignored (Use case D)
* *noop*: Do nothing (for testing purposes)
* *sh*: Invoke a remote SSH shell on the remote host (limited to A,B for security!)
* *homie-update*: Issue all auto-discovery announcements as well as the values. (NB: Command name might change in future versions)
* *homie-delete*: Remove all retained messages for auto-discovery. (NB: Command name might change in future versions)
* *ffstatus* ...
* *ffdown* ...
* *ffup*: Return status of the public Freifunk wifi interface, or switch it down or up
* *ffotherssid*: Change name of public Wifi interface (within community boundaries)
* *ffgluonreconfigure*: Reset interface name back to original
* *gluon-data*
* *machine-data*: Version and CPU info of the node
* *status*: Load and uptime of the node
* *localclients*: Amount and fingerprints of clients attached to the node
* *nodeinfo* ...
* *neighbours* ...
* *statistics*: JSON results from the invocation of `gluon-neighbour-info` with these commands as the resp. option.
* *gluon-show-site*: JSON info from command `gluon-show-site`
* *reboot*: Reboot the node (limited to A,B)

### Example invocations

You might want to try the following examples on the command line first

### Notes / Comments

* [ ] Script needs heavy refactoring
* [ ] Handle more and different Gluon versions gracefully.
