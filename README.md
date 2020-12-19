# Manage-Gluon-MQTT

Monitor and control Freifunk Nodes (Gluon) by MQTT

## manage_gluon_mqtt

**manage_gluon_mqtt** is a shell script supporting a simple integration of Freifunk nodes into a [MQTT](https://en.wikipedia.org/wiki/MQTT) network. The focus is on monitoring but allows for extension to control operations within a private MQTT network:

Supported functions/return information:

* Data about software versions and the auto-updater on the node
* Query and possibly set [UCI](https://openwrt.org/docs/guide-user/base-system/uci) values (works on any OpenWrt router)
* Query, stop and start the Freifunk public Wifi interface
* Temporarely modify the Freifunk SSID (but within the limits of the local Freifunk community)
* Query fingerprints and number of locally connected Freifunk clients (Wifi)
* Query static and dynamic [Gluon](https://gluon.readthedocs.io/en/latest/) data (returned as [JSON](https://de.wikipedia.org/wiki/JavaScript_Object_Notation)): _nodeinfo_, _neighbours_, _statistics_ as well as the output from `gluon-show-site`.
* Query static and dynamic [OpenWrt](https://openwrt.org) config data
* Run a simple speed test
* Reboot the Freifunk node.

IMPORTANT: This script would be benefit from some refactoring, the code is provided as is.
(Yes, I know: Large bash scripts tend to get ugly and Lua would have been preferred.... ;) )

### More Details

The following 4 main different use cases are supported:

A. Management of an (untouched) Freifunk node by **remote SSH** commands (public/private key authentication): Command results are returned as **terminal output** (stdout).

B. Management of an (untouched) Freifunk node by **remote SSH** commands (public/private key authentication): Command results are returned as **MQTT messages**. (B and A are handled simultaneously.)

C. Monitoring by **MQTT messages**: Invoked by an explicit SSH call, init or by cron, this script runs locally on the Freifunk node, returning its output as **MQTT messages**.

D. Local management as a daemon on the node: This script listens to **MQTT messages** and returns results a MQTT messages, too. (D does not exclude C, also the script can run as a daemon invoking commands on other, pre-configured Freifunk hosts as in A or B).

Other aspects:

* [Home assistant](https://www.home-assistant.io/docs/mqtt/discovery/) and [Homie](https://homieiot.github.io/specification/) auto-discovery for important topics.
* MQTT discovery is tested with the [OpenHAB MQTT binding](https://www.openhab.org/addons/bindings/mqtt/) and [HoDD](https://github.com/rroemhild/hodd)
* Script should run on [bash](https://de.wikipedia.org/wiki/Bash_(Shell)) as well as [ash](https://en.wikipedia.org/wiki/Almquist_shell) (ash is used in [OpenWrt](https://openwrt.org/) as the default shell). Dash is used to trigger script verification in Visual Studio Code (VSC).
* If the Freifunk node has very limited memory, e.g. on [4/32 devices](https://openwrt.org/supported_devices/openwrt_on_432_devices), B might be preferred over C or D.
* In order to install the Mosquitto packages, the package installation tool [opkg](https://openwrt.org/docs/guide-user/additional-software/opkg) is needed on Freifunk (Gluon) devices. opkg might not be available on [devices with limited memory](https://openwrt.org/supported_devices/openwrt_on_432_devices): Use use case A and B as a workaround.
* Remote management via a Freifunk "edge" node acting as a SSH proxy to other Freifunk nodes works well, e.g. use the [ProxyJump directive](https://www.redhat.com/sysadmin/ssh-proxy-bastion-proxyjump) in your `.ssh/config`.
* The script can install itself plus some other prerequisites. See below.

### Prerequisites

Depending on the use case to be supported, some prequisites have to be fulfilled in order for the script to work:

* Installation of the [Mosquitto](https://mosquitto.org) packages mosquitto_pub and mosquitto_sub. They should be in every Linux repository, including OpenWrt, e.g. ``opkg update; opkg install mosquitto-client-nossl`` or ``apt install mosquitto-clients`` on the host on which the script (and therefore the MQTT clients) are to be run.
See command ```install´´´ for more details.
N.B.: Consider protecting the Mosquitto files from deletion during Freifunk/Gluon image updates
* For use case A, B, and C as well as debugging purposes: 
  Enable [automatic remote invocation via SSH using public key authentication](https://openwrt.org/docs/guide-user/security/dropbear.public-key.auth)
* If you want to use the script remotely: Install ash from a package repository (or manually replace ash by bash in the first line), e.g. on a Raspberry: ``apt install ash``. The script is written to be compatible to both ash and bash.
* This script relies on some version of Gluon or at least OpenWRT/Raspbian/Raspberry Pi OS: It has been tested on [Gluon](https://github.com/freifunk-gluon/gluon) 2019.1.*, 2020.1.* and 2020.2.* from these communities:
  [Freifunk Munich](https://ffmuc.net), [Freifunk Frankfurt](https://ffm.freifunk.net).

   Please let me know or open a GitHub issue if you have success or problems with other versions or other communities.
* In case of MQTT connection problems: Ensure that incoming or outgoing MQTT connections are not blocked by a firewall - consider my [mqtt-grep-color](https://github.com/sheilbronn/mqtt-grep-color) to verify and debug your MQTT setup more easily. See command ```install´´´ for more details.
* Only in use case A and B: To profit from zram in /var/log on Openhabian, consider adding the following line to root's crontab via ``crontab -e``:

  ```crontab
  @reboot mgm_dir=/var/log/manage_gluon_mqtt.openhabian ; mkdir -p $mgm_dir ; chown openhabian:openhab $mgm_dir ; chmod g+w $mgm_dir
  ```

### Command-line options / Invocation

* -c (commands): One or more management commands to be executed (comma-separated), see below for the details.
* -s (server): If the script is not run locally on the Freifunk node itself (localhost), the SSH names of one or more other Freifunk nodes maybe passed with -s (comma-seperated)
* -g (give): In the output add an informative line with host and command (useful für multiple commands and hosts)
* -v (verbose): more, verbose output from the script as well as intermediate steps. Additional -v's add more verbosity.
* -x (execute): each shell command is echoed to stdout before execution (for debugging)
* -q (quit): no output on stdout
* -h (host): name or IP adress of the MQTT broker (momentarily still -m).
    The public test broker test.mosquitto.org may be abbreviated as -h test. iot.eclipse.ors as -h eclipse.
    If no broker is given, mosquitto_pub and mosquitto_sub will use their defaults (see their manual pages)
* -m (mqtt): use MQTT or not (currently only implied by -p)
* -p : support Homie or Home-Assistant auto-discovery (not fully verified yet)

Supported commands for the -c option are - names might change during refactoring:

* *mqtt*: Script will become a daemon waiting for MQTT commands, subsequent commands are ignored (Use case D)
* *noop*: Do nothing (for testing purposes)
* *install*: Install if necessary the Mosquitto package, a firewall rule, a sample crontab entry, and the script itself (to /sbin).
* *sh*: Invoke a remote SSH shell on the remote host (limited to A,B for security!)
* *homie-update*: Issue all auto-discovery announcements as well as the values. (NB: Command name might change in future versions)
* *homie-delete*: Remove all retained messages for auto-discovery. (NB: Command name might change in future versions)
* *ffstatus* ...
* *ffdown* ...
* *ffup*: Return status of the public Freifunk wifi interface, or switch it down or up
* *ffotherssid*: Change name of public Wifi interface (within community boundaries)
* *ffgluonreconfigure*: Reset interface name back to original
* *gluon-data*: Lots of Gluon configuration data
* *machine-data*: Version and CPU info of the node
* *speedtest*: Get a larger file, measure the time it takes and calculate download speed im MB/s
* *status*: Load and uptime of the node
* *localclients*: Amount and fingerprints of clients attached to the node
* *nodeinfo* ...
* *neighbours* ...
* *statistics*: JSON results from the invocation of `gluon-neighbour-info` with these commands as the resp. option.
* *showsite*: JSON info from command `gluon-show-site`
* *mountsizes*: show size, type and allocation of mounted partitions
* *memory*: show output of "free -t" as JSON
* *reboot*: Reboot the node (limited to A,B)

### Example invocations

You might want to try the following examples on the command line first before putting them into a cron job :

* Remote on a linux box at home (gluonnode ist the FF node):
  ```manage_gluon_mqtt -s gluonnode -c mountsizes
 [
  {
    "mountpoint": "/rom",
    "filesystem": "/dev/root",
    "type": "squashfs",
    "spaceavail": "0",
    "spaceused": "2.3M",
    "percentused": "100%",
    "spacetotal": "2.3M"
  },
  ...
  ]```
* On the FF node itself: 
  ```manage_gluon_mqtt -m test.mosquitto.org -s gluonnode -c ffstatus```

### Notes / Comments

* [ ] Script needs more refactoring
* [ ] Handle more and different Gluon versions gracefully.
* [ ] Should not have to reinstall this script plus the mosquitto tools after an OS or Gluon upgrade.
