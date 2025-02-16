# Manage-Gluon-MQTT

Monitor and control Freifunk Nodes (Gluon) via MQTT

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
* Establish an autossh tunnel for MQTT port forwarding on the current host.
* Run a simple speed test.
* Reboot the Freifunk node.

IMPORTANT: This script would be benefit from some refactoring, the code is provided as is.
(Yes, I know: Large bash scripts tend to get ugly and Lua would have been much preferred.... ;) )

### More Details

The following 4 main use cases are supported:

A. Management of an (untouched) Freifunk node by **remote SSH** commands (public/private key authentication): Command results are returned as **terminal output** (stdout).

B. Management of an (untouched) Freifunk node by **remote SSH** commands (public/private key authentication): Command results are returned as **MQTT messages**. (B and A are handled simultaneously.)

C. Monitoring by **MQTT messages**: Invoked by a crontab entry, an explicit SSH call, or an inittab entry on the Gluon node, this script runs locally on the node and returns output as **MQTT messages**.

D. Local management as a daemon on the Gluon node: This script listens to **MQTT messages** and returns results a MQTT messages, too. (D does not exclude C, also the script can run as a daemon invoking commands on other, pre-configured Freifunk hosts as in A or B).

Other aspects:

* [Home assistant](https://www.home-assistant.io/docs/mqtt/discovery/) and [Homie](https://homieiot.github.io/specification/) auto-discovery for the more important topics.
* MQTT discovery is tested with the [OpenHAB MQTT binding](https://www.openhab.org/addons/bindings/mqtt/) and [HoDD](https://github.com/rroemhild/hodd)
* Script should run on [bash](https://de.wikipedia.org/wiki/Bash_(Shell)) as well as [ash](https://en.wikipedia.org/wiki/Almquist_shell) (ash is used in [OpenWrt](https://openwrt.org/) as the default shell). However, dash is used to trigger script verification in Visual Studio Code (VSC).
* If the Freifunk node has very limited memory, e.g. on [4/32 devices](https://openwrt.org/supported_devices/openwrt_on_432_devices), B might be preferred over C or D.
* In order to install the Mosquitto packages using the install command (see below), the package installation tool [opkg](https://openwrt.org/docs/guide-user/additional-software/opkg) is needed on Freifunk (Gluon) devices. opkg might not be available on [devices with limited memory](https://openwrt.org/supported_devices/openwrt_on_432_devices): Use use case A and B as a workaround.
* Remote management via a Freifunk "edge" node acting as a SSH proxy to other Freifunk nodes works well, e.g. use the [ProxyJump directive](https://www.redhat.com/sysadmin/ssh-proxy-bastion-proxyjump) in your `.ssh/config`.
* The script can install itself plus some other prerequisites. See _install_ command below.

### Prerequisites

Depending on the use case to be supported, some prequisites have to be fulfilled in order for the script to work:

* Installation of the [Mosquitto](https://mosquitto.org) packages mosquitto_pub and mosquitto_sub. They should be in every Linux repository including OpenWrt. Install with ``opkg update; opkg install mosquitto-client-nossl`` or ``apt install mosquitto-clients`` on the Gluon or any other host on which the script (and therefore the MQTT clients) are to be run.
See command ```install´´´ for more details.
(N.B.: Consider protecting the Mosquitto files from deletion during Freifunk/Gluon image updates)
* For use case A, B, and C as well as debugging purposes: 
  Enable [automatic remote invocation via SSH using public key authentication](https://openwrt.org/docs/guide-user/security/dropbear.public-key.auth)
* If you want to use the script remotely on any GNU/Linux system: Install ash from a package repository (or manually replace ash by bash in the first line), e.g. on a Raspberry: ``apt install ash``. The script is written to be compatible to both ash and bash.
* This script relies on some version of Gluon or at least OpenWRT/Raspbian/Raspberry Pi OS: It has been tested on [Gluon](https://github.com/freifunk-gluon/gluon) 2019.1.x, 2020.1.x, 2021.1.x, up to 2022.1.* from these communities:
  [Freifunk Munich](https://ffmuc.net), [Freifunk Frankfurt](https://ffm.freifunk.net).

   Please let me know or open a GitHub issue if you have success or problems with other versions or other communities.
* In case of MQTT connection problems: Ensure that incoming or outgoing MQTT connections are not blocked by a firewall - and consider my [mqtt-grep-color](https://github.com/sheilbronn/mqtt-grep-color) to verify and debug your MQTT setup more easily. See command ```install´´´ for more details.
* Only in use case A and B: To profit from zram in /var/log on Openhabian, consider adding the following line to root's crontab via ``crontab -e``:

  ```crontab
  @reboot mgm_dir=/var/log/manage_gluon_mqtt.openhabian ; mkdir -p $mgm_dir ; chown openhabian:openhab $mgm_dir ; chmod g+w $mgm_dir
  ```

### Command-line options / Invocation

* -c CMD1,CMD2,... : One or more management commands to be executed (comma-separated), see below for the details.
* -s NODE1,NODE2,+: If this script is not run locally on the node itself (localhost), pass the SSH names of one or more other Freifunk nodes (comma-seperated).
* -G : In the output add ("give) an informative line with host and command (useful für multiple commands and hosts)
* -g GROUP: If running as a daemon (D), also listen to MQTT messages for a MQTT group as well.
* -v : more, verbose output from the script as well as intermediate steps. Additional -v's add more verbosity.
* -x : each shell command in the script is echoed to stdout before execution (for debugging)
* -q : no output on stdout
* -h BROKER (host): name or IP adress of the MQTT broker.  
    Multiple -h options may be given for messages to multiple brokers.  
    Following abbreviations for public MQTT brokers may be used:  
    test for test.mosquitto.org, eclipse for iot.eclipse.ors.  
    If no broker is given, mosquitto_pub and mosquitto_sub will use their respective defaults (see their manual pages).
* -m HOST1,HOST2,... (mqtt): send to MQTT hosts (name or IP adress, implied by -p)
* -p : support Home-Assistant (HASS) and Homie auto-discovery via MQTT
* -E DAYS : apply command to those nodes only, that had been successfully contacted in the last DAYS days.
* -M : reply with an MQTT message at most once per hour, or when a value has changed (using for frequent runs from a crontab)

The commands for the -c option are:

* _bridge_: Script will become a daemon waiting for MQTT commands, any subsequent commands are ignored (Use case D)
* _bridgestop_: Try to stop another, already running bridge (A,B only)
* _echo_: Just echo the received command options
* _date_: Return the current system date (for testing purposes)
* _install_: Install if necessary the Mosquitto package, a firewall rule, a sample crontab entry, and then run _filecopy_.
* _filecopy_: Install a very reduced and space optimized version of this script itself to /sbin on the target node.
* _sh_: Invoke a remote SSH shell on the remote host (limited to A,B for security reasons)
* _discovery-update_: Issue all auto-discovery announcements as well as the values.
* _discovery-delete_: Remove all retained messages for auto-discovery.
* _wifistate_ ...
* _wifidown_ ...
* _wifiup_: Return the state of the public Freifunk wifi interface, or switch it down or up
* _wifissid_: Change name of public Wifi interface (within Freifunk community boundaries if applicable)
* _channel24_ : Change the WiFi channel of the public Freifunk wifi network (for the 2.4 Ghz channel only)
* _limit_: limit throughput (ingress and egress)
* _gluonreconfigure_: Reset to configured values and states
* _site_: return site code of Freifunk network, e.g. "ffmuc"
* _gluondata_: Lots of Gluon configuration data
* _machine-data_: Version and CPU info of the  node
* _speedtest_: Get a large file, measure the time it takes and calculate download speed in MB/s
* _state_: Load and uptime of the node
* _localclients_: Amount and fingerprints of Freifunk clients connected to the node
* _nodeinfo_:  JSON results from the invocation of `gluon-neighbour-info nodeinfo`
* _neighbours_: JSON results from the invocation of `gluon-neighbour-info neighbours`
* _statistics_: JSON results from the invocation of `gluon-neighbour-info statistics`
* _addresses_: show output of `ip -6 -j addr` (JSON).
* _showsite_: JSON info from command `gluon-show-site`
* _mountsizes_: show size, type and allocation of mounted partitions
* _memory_: show output of "free -t" as JSON
* _reboot_: Reboot the node (limited to A,B)
* _loop_: Run a command in a repeated loop (A,B only)
* _noop_: Do nothing (used for testing purposes)

### Example invocations

You might want to try some examples first before putting anything into a cron job :

Remotely on a linux box at home (gluonnode ist the FF node):

```sh
  $ manage_gluon_mqtt -s gluonnode -c mountsizes
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
  ]
```

On the Freifunk/Gluon node itself:

  ``$ manage_gluon_mqtt -m test.mosquitto.org -c state``

To run verbosely as a daemon on the target host:

  ``$ manage_gluon_mqtt -m test.mosquitto.org -c bridge -v``

### Notes / Comments

* [ ] Script always needs more refactoring
* [ ] Test for more and different Gluon versions.
* [ ] Should not have to reinstall this script plus the mosquitto tools after an OS or Gluon upgrade.
