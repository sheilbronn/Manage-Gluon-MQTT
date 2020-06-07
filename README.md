# Manage-Gluon-MQTT

Monitor and control Freifunk Nodes (Gluon) by MQTT

## manage_gluon_mqtt

**manage_gluon_mqtt** is a shell script supporting a simple integration of Freifunk nodes into a MQTT network. The focus is on monitoring but maybe extended to control operations for a private MQTT network:

Supported functions/return information:

* Data about software versions and the auto-updater on the node
* Query and possibly set UCI values
* Query, stop and start the Freifunk public Wifi interface
* Temporarely modify the Freifunk SSID (within the limits of the local Freifunk community)
* Query amount and fingerprint of locally connected Freifunk Wifi clients
* Query static and dynamic data (returned as JSON): nodeinfo, neighbours,statistics as well as the output from ``gluon-show-site´´.
* Invoke a reboot

IMPORTANT: The script needs quite some refactoring, the code is provided as is. Yes, I know, it's ugly ;)

### More Details

The following 4 different use cases are supported:
A. Management of an (untouched) Freifunk node by **remote SSH** commands (public/private key authentication): Command results are returned as **terminal output** (stdout)
B. Management of an (untouched) Freifunk node by **remote SSH** commands (public/private key authentication): Command results are returned as **MQTT messages**.
C. Monitoring by **MQTT messages**: Invoked by an explicit SSH call or by cron, this script runs locally on the Freifunk node, returning its output as **MQTT messages**.
D. Local management like a daemon: This script listens to **MQTT messages** and returns results a MQTT messages, too. (D does not exclude C)

Other aspects:
* Home assistant and Homie auto-discovery for important topics.
* Script runs on bash as well as ash (used in OpenWrt)
* If the freifunk node has very limited memory, e.g. on 4/32 devices, B may be preferred over C or D.
* Remote management via a Freifunk "edge" node acting as a SSH proxy is supported.

### Prerequisites

Depending on the use case to be supported, some prequisites have to be fulfilled in order the the script work:

* Installation of the "Mosquitto" packages mosquitto_pub and mosquitto_sub
* Automatic remote invocation via SSH using private/public key authentication
* Some version of Gluon or at least OpenWRT: So far, this script has only been tested on Freifunk München nodes with Gluon 2019.1.*. Please let me know or open an issue, if you have success or problems with other versions

### Command-line options / Invocation

* -c (commands): One or more management commands to be executed (comma-separated)
* -s (server): If the script is not run locally on a Freifunk node, the SSH names of one or more Freifunk nodes maybe passed with -s (comma-seperated)
* -v (verbose): more output from the script as well as intermediate steps
* -x (execute): each shell command is echoed to stdout before execution (for debugging)
* -q (quit): no output on stdout
* -h (host): name or IP adress of the MQTT broker (momentarily still -m).
    The public test broker test.mosquitto.org may be abbreviated as -h test.
    If no broker is given, mosquitto_pub and mosquitto_sub will use their defaults (see their manual pages)
* -m (mqtt): use MQTT or not (currently only implied by -p)
* -p : support Homie or Home-Assitant auto-discovery (not fully implemented yet)

Supported commands for the -c option are - names might change during refactoring:

* mqtt: Script will become a daemon waiting for MQTT commands, subsequent commands are ignored (Use case D)
* noop: Do nothing (for testing purposes)
* sh: Invoke a remote SSH shell on the remote host (limited to A,B for security!)
* homie-update: Issue all auto-discovery announcements as well as the values. (NB: Command name might change in future versions)
* homie-delete: Remove all retained messages for auto-discovery. (NB: Command name might change in future versions)
* ffstatus ...
* ffdown ...
* ffup: Return status of the public Freifunk wifi interface, or switch it down or up
* ffotherssid: Change name of public Wifi interface (within community boundaries)
* ffgluonreconfigure: Reset interface name back to original
* gluon-data
* machine-data: Version and CPU info of the node
* status: Load and uptime of the node
* localclients: Amount and fingerprints of clients attached to the node
* nodeinfo ...
* neighbours ...
* statistics: JSON results from the invocation of ``gluon-neighbour-info´´ with these commands as the resp. option.
* gluon-show-site: JSON info from command ``gluon-show-site´´
* reboot: Reboot the node (limited to A,B)

### Example invocations

(to be documented after refactoring)

### Notes / Comments

* Script needs heavy refactoring
* To ease debugging of the installation consider using the script mqtt-grep-color (from my other Github repo)