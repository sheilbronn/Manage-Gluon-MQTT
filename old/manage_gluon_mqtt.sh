#!/usr/bin/env ash
# shellcheck shell=ash

#
# manage_gluon_mqtt
#
# Monitor and control Freifunk nodes (Gluon) by MQTT
#
# Repo: https://github.com/sheilbronn/Manage-Gluon-MQTT
#

### Some fixed parameters and prelimenary (fixed) settings ....

wifiupsleep="7" # seconds to sleep after "wifi up"
uci_opt_ssid1="wireless.wan_radio0"
ff_if_pub1="client0"
ff_if_priv1="wlan0-1"
ff_if_pub2="wlan0-1"
ff_if_priv2="wlan0-2"
gluondir="/lib/gluon"
ssidbase="muenchen.freifunk.net"
sitecode="" #  will be set to something like "ffmuc".... but you can also freeze it here
macidsfile="/srv/openhab2-conf/phones" # file is only for presence detection in mapping known phones to known people at....

set -o noglob  # "noglob"" will limit security and escaping problems:
scriptname="${0##*/}"
userconfigdir="$HOME/.${scriptname%.sh}"
areaid="$( { cat /proc/sys/kernel/hostname 2>/dev/null || hostname || echo "unknown" ; } )"
[ "$areaid" = "openHABianPi" -o "$areaid" = "unknown" ] && areaid="${areaid}-$( awk -F ":" -e '{ print $5$6 }' < /sys/class/net/eth0/address )"
areaid="$( echo "$areaid" | awk -- '{ print tolower($0) }' )" # lowercase only

# ssid_len=9
ifipv6="bat0"
ffssid=".*"
uci_opt_ssid="$uci_opt_ssid1"
ff_if_pub="$ff_if_pub1" # DEFECT: needs to be made specific for each host...
ff_if_priv="$ff_if_priv1"

umask -S u=rwx,g=rx,o= # no rights for others
alias noxxing="local - ; set +x"

# Notes for future enhancements:
# ping ff host and up/down own public if accordingly
# ( ping -c 3 2001:608:a01:103:62e3:27ff:febd:b8ba && echo yes ) || echo no    
# ( ping -c 3 2001:608:a01:103:62e3:27ff:febd:b8be && ( ( iwinfo | fgrep $ff_if_pub ) || ( wifi up ; echo wifi upped. ) )  ) || ( iw dev client0 del ; echo if downed )
# scan repeatedly for public Wifi and up/down own public if accordingly:
# ( { for i in 1 1 1 1 2 ; do iw dev mesh0 scan ; sleep $i ; done } | fgrep -w '6e:a3:09:ea:31:e1' && ( ( iwinfo | fgrep $ff_if_pub ) || ( wifi up ; echo wifi upped. ) )  ) || ( iw dev $ff_if_pub del ; echo if downed )
# ( { for i in 1 2 2 ; do iw dev mesh0 scan ; sleep $i ; done } | egrep -A 9 -w '6e:a3:09:ea:31:e0' | grep SSID:.muenchen.freifunk.net/muc_sued && ( ( iwinfo | fgrep $ff_if_pub ) || ( wifi up ; echo wifi upped. ) )  ) || ( iwinfo | fgrep $ff_if_pub && iw dev $ff_if_pub del ; echo if downed )

show_help() {
	cat 1>&2 << EOF
   Usage: $scriptname ... -v -c command ...
   Execute arbitrary as well as predefined commands on Freifunk nodes using uci and other commands. Return values on stdout or MQTT.
   Either, automatic (e.g. key-based) access to the Freifunk node using SSH or local execution is possible.
EOF
}

sort_and_tail_file() {
	noxxing
	local __tmpfile="$tmpdir/tailfile"
	local __fn="$1"
	local __tailcnt=${2:-20}
	local __colno=${3:-1}

	[ -r "$__fn" ] && [ -w "$__fn" ] && sort -k $(( __colno + 1 )) "$__fn" | uniq -f "$__colno" | tail -"$__tailcnt" | sort -k $(( __colno + 1 )) > $__tmpfile \
		&& cat "$__tmpfile" > "$__fn" && rm -f "$__tmpfile"
	[ "$bMoreVerbose" ] && debug_if_verbose "sort_and_tail_file($1,$2,$3): lines: $( wc -l < "$1" )"
	}

tail_file() {
	noxxing
	local __tmpfile="$tmpdir/tailfile"
	local __fn="$1"
	local __tailcnt=${2:-20}

	[ -r "$__fn" ] && [ -w "$__fn" ] && tail -"$__tailcnt" "$__fn" > $__tmpfile && cat "$__tmpfile" > "$__fn" && rm -f "$__tmpfile"	
	}

exec_locally() { # tried to avoid cost of running "sh -c", no success so far...
		sh -c "$1"
	}

extract_uci_values() {
	local _fresult="$( echo "$@" | xargs -r -n 1 | sed 's/.*=//g' )"
	# echo "extract_uci_values returns: <$_fresult>" 1>&2
	echo "$_fresult"
	}

query_uci_on_host() { # query (show) possibly many UCI values from a host and return them all
	local __lines="$( $ssh_cmd "uci show $1" )"s
	# echo "lines: $__lines" 1>&2
	echo "$__lines"
	}

get_uci_on_host() {
	local __lines="$( $ssh_cmd "uci get $1 2>&1 ; ${2:+uci get $2} 2>&1 ; ${3:+uci get $3} 2>&1" )"
	echo "$__lines"
	}

query_and_extract_uci_on_host() { # query the FIRST of possibly many UCI values from a host and return its value
	local _fresult="$($ssh_cmd "uci show $1" | xargs -r -n 1 | sed 's/.*=//g' )"
	# echo "extract_uci_values returns: <$_fresult>" 1>&2
	echo "$_fresult"
	}

get_os_data_semi_starred_cached() {
	local _data=""
	local _fresult="$( storage_cache_read "$1.os_data" 1 )"
	local __os_data_fn="/usr/lib/os-release" # standard on Unix by now
	local __os_pretty_name
	local __os_id

	if [ -z "$_fresult" ] ; then
		_data="$( $ssh_cmd "cat $__os_data_fn" )" || {	_ret=$? ; return $_ret ; } # cancel func
		if [ -n "$_data" ] ; then
			storage_cache_write "$1.os_data_lined" "$_data" # keep it for now, dont need it yet
			_fresult="$( echo "$_data" | awk -F= 'BEGIN { printf  "{*os*:{" 
				} { printf comma "*" tolower($1) "*:" $2 $3 $4 $5 $6 ; comma="," } END { printf "}}" }' )" # generate new value
			 storage_cache_write "$1.os_data" "$_fresult"  # cache if new values successfulhy obtained
			__os_pretty_name="$( echo "$_data" |  awk -F=  '/^PRETTY_NAME=/ { print gensub("\"", "", "g", $2) }' )"
			 storage_cache_write "$1.os_pretty_name" "$__os_pretty_name" 
			__os_name="$( echo "$_data" |  awk -F=  '/^NAME=/ { print gensub("\"", "", "g", $2) }' )"
			 storage_cache_write "$1.os_name" "$__os_name" 
			__os_id="$( echo "$_data" |  awk -F=  '/^ID=/ { print gensub("\"", "", "g", $2) }' )"
			 storage_cache_write "$1.os_id" "$__os_id" 
		fi
	fi	
	printf "%s" "$_fresult"
	}

get_sitecode_cached() { # $1=host $2=cachetimeout
	local _data="$( storage_cache_read "$1.sitecode" "${2:-1}" )"
	if [ -z "$_data" ] ; then
		_data="$( $ssh_cmd "[ -d $gluondir ] && cat $gluondir/site.json"  )" || { _ret=$? ; return $_ret ; }
		if [ -n "$_data" ] ; then
			_data="$( echo "$_data" | jsonfilter_func .site_code )"
			storage_cache_write "$1.sitecode" "$_data"
		fi
	fi
	printf "%s" "$_data"
	}

get_most_frequent_sitecode() {
		local - ; set +o noglob # needed here
		local _data="$( cat "$cachedir"/*.sitecode.cached 2>/dev/null | sort | uniq -c | awk 'NR==1 { print $2 }' )"
		echo "${_data:-LOCAL}"
		[ "$_data" ] || return 1
	}

get_public_if_cached() { # $1=host $2=cachetimeout  ## TODO ## -1 for forced reloading
	local -
	local _data="$( storage_cache_read "$1.iwinfo" "${2:-99}" )"
	if [ -z "$_data" ] ; then
		# should find a solution based on iw ...:
		_data="$( $ssh_cmd "command -v iwinfo >/dev/null && iwinfo" | sed -e 's/^  */;/' -e 's/   */;/' | awk '/^$/ { print l ; l = "" ; next } { l = l $0 ; next }' )" ||
				 {	_ret=$? ; return $_ret ; }
		if echo "$_data" | grep -q "Mode: Master;.*;Encryption: none" ; then #  .... cache result only if at least the public Freifunk if is up and running
			_data="$( echo "$_data" | sed -e 's/;Type:.*//' )" # shorten uninteresting stuff
			storage_cache_write "$1.iwinfo" "$_data"
		fi
	fi
	# set -x
	_data="$( echo "$_data" | awk -F ";" '/;Mode: Master/ && /;Encryption: none/ { print $1 } ' )"
	if [ -z "$_data" ] ; then
		debug_if_verbose "Using default for public interface: $ff_if_pub1" # use 'client0' as fallback
		echo "$ff_if_pub1"
	else
		[ "$_data" != "$ff_if_pub1" ] && debug_if_verbose "Unusual public interface: $_data ..."
		echo "$_data"
	fi
}

get_gluon_domains_starred_cached() {
	local _data="$( storage_cache_read "$1.gluondomains" 1 )"

	if [ -z "$_data" ] ; then
		_data="$( $ssh_cmd "ls -1 "$gluondir/domains" 2>&1" )" || {	_ret=$? ; return $_ret ; } # cancel func
		if [ -n "$_data" ] ; then
			_data=$( echo "$_data" | sed -e 's/[^_]*_//' -e 's/.json//' )
			storage_cache_write "$1.gluondomains" "$_data"
		fi
	fi
	_data=$( echo "$_data" | awk 'BEGIN { printf "[" } { printf comma "*" $0 "*" ; comma="," } END { printf "]" }' )
	printf "%s" "$_data"
}

storage_write() { # write a key/value pair to a dir 
	noxxing
	if [ -z "$1" ] ; then
		echo "##INVALIDPARAM##"
		error_and_exit "storage_write($1.$4, \"$2\", $3) with ##INVALIDPARAM##"
	else
		mkdir -p "$3" && echo "$2" > "$3/$1.$4"
		debug_if_verbose "storage_write($1.$4, \"$2\", $3) returned $retcode"
	fi
	}
storage_user_write() {  # write a key/value pair permanently across script invocations 
	storage_write "$1" "$2" "$userconfigdir" "persisted"
	}
storage_cache_write() { # write a key/value pair to be cached across script invocations from the same user
	storage_write "$1" "$2" "$cachedir"      "cached"
	}
storage_read() { # read key/value pair from cache or user storage  (1:searchkey, 2:cachetime, 2: filesuffix, 3:dir)
	noxxing
	local __file="$3/$1.$4"
	local __maxcachedays="${2:-2}"
	local _fresult=""
	local __value=""
	local __deloutput=""

	if [ -z "$1" ] ; then
		_fresult="##INVALIDPARAM##"
		error_and_exit "STORAGE_READ($1,...) with $_fresult"
	elif [ ! -r "$__file" ] ; then
		_fresult="##NOTFOUND##"
	else
		[ "$4" = "cached" ] && __deloutput="$( find "$__file" -mtime +"$__maxcachedays" | head -1 | xargs -r -t rm 2>&1 )" # cache invalidated after n days and remove file
		if [ -n "$__deloutput" ] ; then
			_fresult="##NOTFOUND##" # cache is invalid
		else
			__value="$( cat "$__file" )" && _fresult="##FOUND##"  # read value from cache file
			[ "$__value" ] || _fresult="##EMPTY##"
		fi
	fi
	debug_if_verbose "STORAGE_READ($1,$2,$3,${4%ed})=\"$( shorten_string "$__value" 23 )\" ($_fresult)" 1>&2
	echo "${__value}" # _fresult values are ignored for now
	[ -z "$__value" ] && return 1
	return 0
	}

storage_cache_read() { # read a key/value pair to be cached across script invocations from the same user; empty cache after n day(s)
	noxxing
	storage_read "$1" "$2" "$cachedir" "cached"
	return $?
	}

storage_user_read() { # read a key/value pair across script invocations
	storage_read "$1" "$2" "$userconfigdir" "persisted"
	return $?
	}

error() {
	noxxing
	echo "$scriptname: ERROR: $1" 1>&2
	}

error_and_exit() {
	noxxing
	error "$* ... Exiting."
	exit 1
	}

echo_if_not_quiet() {
	noxxing
	[ "$bQuiet" ] || echo "$*"
	}

debug_if_verbose() {
	noxxing
	[ "$bVerbose" ] && echo "$*" 1>&2
 }

shorten_string() { # $1=string $2=maxlen
	noxxing
	printf "%.${2:-5}s%s" "$1" "$( [ ${#1} -gt "${2:-5}" ] && printf ... )"
	}

jsonfilter_func() {  #  jsonfilter_func(filterexpr,moreparam)=result
	noxxing
	local _data 
	if [ "$jsonfilter" = "jsonfilter" ] ; then
		_data=$( jsonfilter -e "@$1" $2 )      # $2 is unquoted to avoid complaint when missing
	elif [ "$jsonfilter" = "jq" ] ; then
		_data=$( jq         -r  "$1" $2 )
	else
		error_and_exit "\$jsonfilter is undefined"
	fi
	printf "%s" "$_data"
}
shorten_ethernet_addr_in_json() { # remove some bytes für anonymization
	[ "$1" = "skip" ] && cat && return 0
	sed -e 's/\([*"][a-f0-9][a-f0-9]:[a-f0-9][a-f0-9]:\)[a-f0-9][a-f0-9]:[a-f0-9][a-f0-9]\(:[a-f0-9][a-f0-9]:[a-f0-9][a-f0-9][*"]\)/\1...\2/g' "$@"	
	}

deny_if_mqtt() {
	noxxing
	[ "$commandsToDo" = "mqtt" ] && echo_if_not_quiet "Mqtt $command ignored." && return 0
	return 1
	}

publish_to_mqtt() {
	noxxing
	debug_if_verbose "PUBLISH_TO_MQTT: TOPIC=$1  MSG=$2 ${3:+ OPTIONS=$3} ${bMoreVerbose:+ (\$mqtthost=$mqtthost)}"
	if [ "$cmd_mospub" != "true" ] ; then
		 $cmd_mospub $mqtthost -t "$1" -m "$2" -i "${sitecode}_$sTargetHost" $3  || debug_if_verbose "$cmd_mospub failed..." #  $3  passed without quotes on purpose
	fi
	}

publish_to_mqtt_starred() {		# publish_to_mqtt_starred(expandableTopic,message,moreMsoquittoOptions)
	if [ -n "$mqtthost" -o "$homie" ] && [ "$cmd_mospub" != "true" ] ; then
		local _topic="$( echo $1 | sed -e "s,^/,$sitecode/$sTargetHost/," )"	# ... expand shortcuts starting with "/"
		publish_to_mqtt  "$_topic" "$( echo "$2" | tr \" \' | tr "*" \" )" "$3" # ...  replace double quotes by single quotes and stars by double quotes
	fi
	}

reply_to_mqtt_status() {
	[ "$1" ] && [ "$mqtthost" -o "$homie" ] && publish_to_mqtt_starred "/$command/STATUS" "{*status*:*$1*${2:+,*details*:*$2* }}"
	[ "$1" != "OK" ] && logger -p daemon.error -t error "$2"
}

hass_announce() { # $sitecode "$nodename" "publicwifi/localclients" "Readable name" "$ad_devname" "value_json.count" "$icontype"
	local _topicpart="${3%/set}"
	local _topicword="$( basename "$_topicpart" )"
	local _command_topic_string="$( [ "$3" != "$_topicpart" ] && echo ",*cmd_t*:*~/set*" ) "    # determined by suffix ".../set"
	local _hassdevicestring="*dev*:{*name*:*$5*, *mdl*:*Gluon Freifunk Node*, *mf*:*Freifunk*, *ids*: [*${scriptname}${1:+_$1}_$2*]}"
	local _msg=""
	# mdi icons from https://cdn.materialdesignicons.com/5.4.55/

	[ "$bDeleteAnnouncement" != "yes" ] && 
		_msg="{*name*:*$( echo ${5:+$5-}$4 | tr " " "-" | tr -d "()" )*,*friendly_name*:*${5:+$5 }$_topicword*, ${_hassdevicestring:+$_hassdevicestring,}
			*~*:*${1:+$1/}$2/$_topicpart*, *stat_t*:*~* ${6:+,*value_template*:*{{ $6 \}\}*} $_command_topic_string ${7:+,*icon*:*mdi:mdi-$7*} }"
	publish_to_mqtt_starred "homeassistant/sensor/${2}$_topicword/config" "$_msg" "-r"
	
}
	
homie_state_is_ready() {
	tmpfile="$tmpdir/homie_state"
	mosquitto_sub $mqtthost -t "homie/$1/\$state" -C 1 > $tmpfile &
	pid=$! 
	sleep 2
	kill $pid 2>/dev/null
	ret="$( cat $tmpfile )"
	rm $tmpfile
	expr "$ret" "=" "ready"
	}

homie_line() {
		[ "$homie" ] || return
		publish_to_mqtt "homie/$1" "$2"
	}

homie_meta() {
		noxxing
		# debug_if_verbose "homie_meta($1,$2,$3)"
		local _msg="$2" ; [ "$bDeleteAnnouncement" = "yes" ] && _msg="" # bDeleteAnnouncement used in side effect from global var
		local _topic="$( echo $1 | sed -e "s,^/,homie/$homie/,"  -e 's,\(.*/\)\([!/]*\),\1$\2,' )" # ... expand shortcuts starting with "/"

		publish_to_mqtt "$_topic" "$_msg" -r
		# sleep 1
	}

announce_disco() { # $1: <homie-host>,  $2: "-d" if retained advertisements are to be deleted.
	# NB: $sTargetHost and optionally $bDeleteAnnouncement must have been set!

	local -
	local nAnnouncementDay="$( storage_cache_read "$sTargetHost.nAnnouncementDay" 9999 )"

	if [ "$2" = "-d" -o "$bDeleteAnnouncement" = "yes" ] ; then
		debug_if_verbose "announce_disco($1,$2,bDeleteAnnouncement=$bDeleteAnnouncement): deleting advertisements"
		bDeleteAnnouncement="yes" # used in side effect in homie_meta, will be resetted further down
	else
		[ "$sSshUser" = "NOUSER" ] && { homie_line "$1/\$stats/uptime" "$( cut -f 1 -d . < /proc/uptime )" ; }
		
		if [ -n "$nAnnouncementDay" ] && [ "$(date "+%j")" -eq "$nAnnouncementDay" -a -z "$bForceMQTTAnnounce" ] && homie_state_is_ready $1 >/dev/null ; then
			debug_if_verbose "ANNOUNCE_DISCO(): skip announcements, homie state is ready... (bForceMQTTAnnounce=\"$bForceMQTTAnnounce\")" # (re-)announce ONLY IF restart or new day or necessary 
			return 0
		fi
		os_data="$( get_os_data_semi_starred_cached "$sTargetHost" 1 )" # refresh data from host if old or no data available
		ad_devname="$( echo "$1" | awk -- '{ print toupper(substr($i,1,1)) substr($i,2) }' )"
		ad_fwname="$( storage_cache_read "$sTargetHost.os_name" 9999 )"
		ad_fwversion="$( storage_cache_read "$sTargetHost.os_pretty_name" 9999 )"
		ad_impl="$( storage_cache_read "$sTargetHost.os_id" 9999 )"
		debug_if_verbose "announce_disco($1,$2): announcing with $ad_devname,$ad_fwname,$ad_fwversion,$ad_impl"
	fi

	publish_to_mqtt "debug/$1" "HOMIE ANOUNCEMENTS BEGIN"

	homie_meta /homie "3.0.1"
	homie_meta /state init	
	homie_meta /name  "$ad_devname"

	[ "$ad_fwversion" -o "$2" ] && homie_meta /fw/version     "$ad_fwversion"
	[ "$ad_fwname"    -o "$2" ] && homie_meta /fw/name        "$ad_fwname"
	[ "$ad_impl"      -o "$2" ] && homie_meta /implementation "$ad_impl"

	# homie_meta $1 "stats/interval" 600

	homie_meta /nodes		"publicwifi,gluondata"
	homie_meta /publicwifi/name       "Public Wifi"
	homie_meta /publicwifi/type       "Public Wifi Network"
	homie_meta /publicwifi/properties "clientscount,state,ssidshort,lastdate"

	# Defaults are ... settable=false   retained=true
	homie_meta /publicwifi/clientscount/name "Public WiFi client count"
	homie_meta /publicwifi/clientscount/retained	false
	homie_meta /publicwifi/clientscount/datatype	integer
	homie_meta /publicwifi/clientscount/unit   	"#"
	homie_meta /publicwifi/clientscount/format	"-1:9999"

	homie_meta /publicwifi/state/name "Public WiFi state"
	homie_meta /publicwifi/state/settable true
	homie_meta /publicwifi/state/datatype boolean

	homie_meta /publicwifi/ssidshort/name "Public WiFi short SSID"
	homie_meta /publicwifi/ssidshort/retained false
	_gluondomains=$( storage_cache_read "$sTargetHost.gluondomains" 99 )
	if [ "$_gluondomains" ] ; then
		_wifi_domains="$( echo $_gluondomains | tr -d "][*" )" # rough hack...
		debug_if_verbose "wifi_domains: $_wifi_domains"
		homie_meta /publicwifi/ssidshort/settable true
		homie_meta /gluondata/ssidshort/datatype enum
		homie_meta /gluondata/ssidshort/format "$_wifi_domains" # rough hack...
	else
		homie_meta /publicwifi/ssidshort/settable false
		homie_meta /publicwifi/ssidshort/datatype string
		homie_meta /gluondata/ssidshort/format ""
	fi

	# Defaults are for ... settable=false 
	homie_meta /publicwifi/lastdate/name "Last date sent"
	homie_meta /publicwifi/lastdate/retained false
	homie_meta /publicwifi/lastdate/datatype DateTime
	# homie_meta /publicwifi/lastdate/unit "#"
	# homie_meta /publicwifi/lastdate/format "0:9999"

	homie_meta /gluondata/name       "Node Data"
	homie_meta /gluondata/type       "Gluon Data"
	homie_meta /gluondata/properties "autoupdater-branch,autoupdater-enabled,gluon-version,release,model,core-domain"

	homie_meta /gluondata/autoupdater-branch/name "Autoupdater Branch"
	homie_meta /gluondata/autoupdater-branch/retained false
	homie_meta /gluondata/autoupdater-branch/datatype string

	homie_meta /gluondata/autoupdater-enabled/name "Autoupdater Enabled"
	homie_meta /gluondata/autoupdater-enabled/retained false
	homie_meta /gluondata/autoupdater-enabled/datatype boolean

	homie_meta /gluondata/gluon-version/name "Gluon Version"
	homie_meta /gluondata/gluon-version/retained false
	homie_meta /gluondata/gluon-version/datatype string

	homie_meta /gluondata/release/name "Local Release"
	homie_meta /gluondata/release/retained false	
	homie_meta /gluondata/release/datatype string	

	homie_meta /gluondata/model/name "Hardware Model"
	homie_meta /gluondata/model/retained false	
	homie_meta /gluondata/model/datatype string	

	homie_meta /gluondata/core-domain/name "Core Domain"
	homie_meta /gluondata/core-domain/retained false	
	homie_meta /gluondata/core-domain/datatype string	

	homie_meta /gluondata/gluon-domains/name "Gluon Domains"
	homie_meta /gluondata/gluon-domains/retained false	
	homie_meta /gluondata/gluon-domains/datatype string	

	homie_meta /state ready

	# https://www.home-assistant.io/docs/mqtt/discovery/
	# <discovery_prefix>/<component>/[<node_id>/]<object_id>/config

	hass_announce "$sitecode" "$1" "publicwifi/localclients"  "Local Clients"     "$ad_devname" "" "counter"  # 5: value_json.count
	hass_announce "$sitecode" "$1" "publicwifi/ssidshort/set" "Short public SSID" "$ad_devname" "" "wifi"  # 5: value_json.count
	hass_announce "$sitecode" "$1" "publicwifi/state/set"     "State of public SSID" "$ad_devname" "" "toggle-switch"  # 5: value_json.count
	hass_announce "$sitecode" "$1" "publicwifi/lastdate"  	  "Last date wifi check" "$ad_devname" "" "clock-check-outline"  # 5: value_json.count
	
	publish_to_mqtt "debug/$1" "HOMIE ANOUNCEMENTS END"

	bDeleteAnnouncement="" # end of side effect 
	storage_cache_write "$sTargetHost.nAnnouncementDay" "$( date "+%j" )" # support reducing it to only once per day
	}

hass_init() {
	# homeassistant/switch/0x7cb03eaa0a096d9c/switch/config 
	# {"payload_off":"OFF","payload_on":"ON","value_template":"{{ value_json.state }}","command_topic":"zigbee2mqtt/Osram-Smart-Plus/set","state_topic":"zigbee2mqtt/Osram-Smart-Plus","json_attributes_topic":"zigbee2mqtt/Osram-Smart-Plus","name":"Osram-Smart-Plus_switch","unique_id":"0x7cb03eaa0a096d9c_switch_zigbee2mqtt","device":{"identifiers":["zigbee2mqtt_0x7cb03eaa0a096d9c"],"name":"Osram-Smart-Plus","sw_version":"Zigbee2mqtt 1.13.0","model":"Smart+ plug (AB3257001NJ)","manufacturer":"OSRAM"},"availability_topic":"zigbee2mqtt/bridge/state"}

	# homeassistant/sensor/0x00158d0003a401e2/linkquality/config 
	# {"icon":"mdi:signal","unit_of_measurement":"lqi","value_template":"{{ value_json.linkquality }}","state_topic":"zigbee2mqtt/Aqara-Sensor","json_attributes_topic":"zigbee2mqtt/Aqara-Sensor","name":"Aqara-Sensor_linkquality","unique_id":"0x00158d0003a401e2_linkquality_zigbee2mqtt","device":{"identifiers":["zigbee2mqtt_0x00158d0003a401e2"],"name":"Aqara-Sensor","sw_version":"Zigbee2mqtt 1.13.0","model":"MiJia temperature & humidity sensor (WSDCGQ01LM)","manufacturer":"Xiaomi"},"availability_topic":"zigbee2mqtt/bridge/state"}
string='{
   "availability_topic" : "zigbee2mqtt/bridge/state",
   "value_template" : "{{ value_json.linkquality }}",
   "unit_of_measurement" : "lqi",
   "unique_id" : "0x00158d0003a401e2_linkquality_zigbee2mqtt",
   "json_attributes_topic" : "zigbee2mqtt/Aqara-Sensor",
   "icon" : "mdi:signal",
   "device" : {
      "name" : "Aqara-Sensor",
      "identifiers" : [
         "zigbee2mqtt_0x00158d0003a401e2"
      ],
      "sw_version" : "Zigbee2mqtt 1.13.0",
      "model" : "MiJia temperature & humidity sensor (WSDCGQ01LM)",
      "manufacturer" : "Xiaomi"
   },
   "state_topic" : "zigbee2mqtt/Aqara-Sensor",
   "name" : "Aqara-Sensor_linkquality"
 }'

	node_id=0x00158d0003a401e2
	typ=linkquality
	dev=Aqara-Sensor
	true publish_to_mqtt_starred "homeassistant/sensor/$node_id/$typ/config" "{
   *availability_topic* : *zigbee2mqtt/bridge/state*,
   *value_template* : *{{ value_json.$typ }}*,
   *unit_of_measurement* : *lqi*,
   *unique_id* : *${node_id}_${typ}_zigbee2mqtt*,
   *json_attributes_topic* : *zigbee2mqtt/$dev*,
   *icon* : *mdi:signal*,
   *device* : {
      *name* : *$dev*,
      *identifiers* : [
         *zigbee2mqtt_$node_id*
      ],
      *sw_version* : *Gluon blabla*,
      *model* : *Freifunk Device Typ yxz*,
      *manufacturer* : *Freifunk-MUC*
   },
   *state_topic* : *zigbee2mqtt/$dev*,
   *name* : *${dev}_$typ*
 }"
	
	# homeassistant/sensor/sensorBedroomT/config
    #  {"device_class": "temperature", "name": "Temperature", "state_topic": "homeassistant/sensor/sensorBedroom/state", "unit_of_measurement": "°C", "value_template": "{{ value_json.temperature}}" } 

	# ffmuc/alt-solln/publicwifi/localclients {"count":"3","localclients":[ {"addr":"3c:cd:...:7f:8a","name":"3c:cd:...:7f:8a"}, {"addr":"6c:c7:...:7e:de","name":"6c:c7:...:7e:de"}, {"addr":"b4:9c:...:25:5e","name":"b4:9c:...:25:5e"}],"host":"alt-solln"}
	
	}

# Initialize our own variables:
OPTIND=1         # reset to 1 in case getopts has been used previously in the shell.
bQuiet=""
bVerbose=""

bDoAllOfIt=""
commands="" # commands="mesh-id"
option_to_query=""
write_uci_val=""

determine_cmd_mospub() {
		cmd_mospub="true" # use the command "true" as unfunctional default
		command -v "mosquitto_pub" >/dev/null && cmd_mospub="mosquitto_pub"
		debug_if_verbose "Variable/command \$cmd_mospub is *$cmd_mospub* (true is dummy!)."
	}
determine_cmd_mospub

jsonfilter=$( command -v jq 2>/dev/null ) || jsonfilter=$( command -v jsonfilter 2>/dev/null ) || error_and_exit "jsonfilter or jq must be available."
jsonfilter=$( basename $jsonfilter )
json_pp="cat" && command -v json_pp >/dev/null && json_pp="json_pp"

if [ -d $gluondir ] ; then   # I'm running on Gluon (which itself is based on OpenWrt)
	# mqtthost="-h test.mosquitto.org"
	ffhosts="localhost"
	macidsfile="/tmp/phones"
elif [ -x /usr/sbin/print_map.sh ] ; then # ... could be running on some other freifunk on OpenWrt   (need to be made more granular for OpenWrt..)
	mqtthost="-h test.mosquitto.org"
	ffhosts="localhost"
	macidsfile="/tmp/phones"
else                                      # on rest-of-world (e.g. Raspi or some fullblown OpenWrt)
	mqtthost="-h localhost"
	macidsfile="/srv/openhab2-conf/phones"
fi

cachedir="/tmp/${scriptname%.sh}.$( id -nu )"
tmpdir="$cachedir/$$" && mkdir -p "$tmpdir"
debugfile="$tmpdir/debugfile"
clientcollectionfile=""
echo "$0  "  "$@" > "$debugfile"

[ $# -eq 0 ] && { show_help ; exit 1 ; } # at least one parameter on the command line is required

while getopts "?h:gvxqas:pi:f:m:n:c:o:w:" opt   # https://wiki.bash-hackers.org/howto/getopts_tutorial
do
    case "$opt" in
    \?) show_help
        exit 1
        ;;
    h|s)  ffhosts="$OPTARG" # one or more Freifunk node(s)
		if expr index ."$ffhosts" "+*" > /dev/null # substitute a literal + or * for a set of predefined hosts
		then
			# the values used for + should be stored externally in the file $userconfigdir/myhosts.persisted:
			# "host1,host2,host3" (without double quotes)

			myhostcollection=""
			[ "$myhostcollection" ] || myhostcollection="$( storage_user_read myhosts )"
			[ "$myhostcollection" ] || error_and_exit "config for collection of hosts is missing ($userconfigdir/myhosts.persisted)"
			ffhosts="$( echo "$ffhosts" | sed -e "s/[+*]/$myhostcollection/g" |	tr -d -c "a-zA-Z.,-" )" # replace and sanitize
			workonallclients="yes"
		fi
	    ffssid="$ffssid1"
        ;;
    g)  bGiveHost="yes"
		;;
    v)  [ "$bVerbose" = "yes" ] && bMoreVerbose="yes"
		bVerbose="yes"
		;;
	x)  bVerbose="yes"
		set -o xtrace
        ;;
	q)	bQuiet="yes"
		;;
    a)  bDoAllOfIt=yes
		bForceMQTTAnnounce="yes" # -a forces auto-discovery announcements even if retained before' ...
		;;
	m)  [ "$cmd_mospub" = "true" ] && error "mosquitto_pub is missing!"
		case "$OPTARG" in  #  http://www.steves-internet-guide.com/mqtt-hosting-brokers-and-servers/
		test)    mqtthost="-h test.mosquitto.org" ;;
		eclipse) mqtthost="-h mqtt.eclipse.org"   ;;
        hivemq)  mqtthost="-h broker.hivemq.com"   ;;
		*)       mqtthost="-h $( echo "$OPTARG" | tr -c -d '0-9a-z_.' )" ;; # clean up for sec purposes
		esac
		;;
	p)  homie="yes"
		[ "$cmd_mospub" = "true" ] && error_and_exit "MQTT client mosquitto_pub is not installed, but -$opt was requested..."
		;;
	i)	areaid="$OPTARG"
		;;
	f)  additional_option="$OPTARG"
		filetocopy="$OPTARG" 
		commands="filecopy"
		;;
	n)  one_additional_option="$OPTARG"
		ffssid="$OPTARG"
		;;
    c)  commands="$OPTARG" # one or more, comma-seperated command to be executed
        ;;
    o)  option_to_query="$OPTARG" ; commands="uciquery"
		# echo option_to_query="$option_to_query"
        ;;
    w)  write_uci_val="$OPTARG" ; commands="uciwrite"
		# echo write_uci_val="$write_uci_val"
        ;;
    esac
done

shift "$((OPTIND-1))"   # Discard the options parsed so far and leave the rest of the cmd line...

if [ "$homie" -o "$mqtthost" ] ; then # enable MQTT
	: debug_if_verbose "MQTT commands not aliased."
else
	debug_if_verbose "MQTT commands are aliased."
	alias publish_to_mqtt_starred="true skipped publish_to_mqtt_starred"
	alias homie_line="true skipped homie_line"
	alias homie_meta="true skipped homie_meta"
fi

# find a name for the collection of all clients here:
for ffhost in $( echo "${ffhosts:-localhost}" | tr -s "," " " ) # for each given host, maybe just one... (tr needed on ash)
do
	if [ "$ffhost" = "localhost" ] ; then
		sSshUser="NOUSER"
		ssh_cmd="exec_locally" # ssh_cmd="sh -c"
		sTargetHost="$areaid"
	else
		sSshUser="root@$ffhost"
		ssh_cmd="ssh -T $sSshUser -q" 
		sTargetHost=$( echo "$ffhost" | tr "A-Z" "a-z" | sed -e 's/\..*//' -e 's/-e$//' ) # remove any trailing "-e" and domain name
	fi
	
	[ -z "$sitecode" ] && sitecode="$( get_sitecode_cached "$sTargetHost" || get_most_frequent_sitecode )" # Cant do it earlier: Need a $sTargetHost to determine a default...

	tmpfilemqtt="$tmpdir/mqtt.$ffhost"
	new_ssid=""

	[ "$bVerbose" -a "$bGiveHost" ] && echo "######"
	[ "$bVerbose" -o "$bGiveHost" ] && echo "######  $sSshUser / $sTargetHost / $commands / " "$@" "######"

	if [ "$option_to_query" ] ; 	then
		uci_val="$( query_uci_on_host "$option_to_query" )"

		if [ "$bDoAllOfIt" ] ; then
			echo "$uci_val"
			continue
		fi
		
		uci_val="$(extract_uci_values "$uci_val")"

		if [ -z "$write_uci_val" ]  ; 		then
			echo "$uci_val" # it was a query only = no writes
		elif [ "$( echo "$uci_val" | wc -l )" -gt 1 ] ; then
			error_and_exit "key :$option_to_query: had returned more than one line!"
		else
			$ssh_cmd "uci set $option_to_query=$write_uci_val ; uci commit $option_to_query" 
			# echo $option_to_query was changed: "$(query_uci_on_host $option_to_query)". 1>&2
		fi
	else
		commandsToDo="$commands"

		if [ "$commandsToDo" = "mqtt" ] ; then
			# spawn a subprocess that will wait for a MQTT message....
			sSysMqqtDummyTopic='$SYS/broker/uptime'
			readonly fPipe="$tmpdir/f" 
			mkfifo "$fPipe" || error_and_exit "Could not create $fPipe (retval=$?)."
			_prefix="-t $sitecode/$sTargetHost"
			_subscriptions="$_prefix/+/get $_prefix/+/+/get $_prefix/+/set $_prefix/+/+/set"
			[ "$homie" ] && _subscriptions="$_subscriptions -t homie/$sTargetHost/+/+/set" 
			debug_if_verbose "SUBSCRIBING to MQTT broker: \"$mqtthost $_subscriptions\", homie=$homie"
			_last_will_options="--will-topic $sitecode/$sTargetHost/mqtt/STATUS --will-payload OFF"
			mosquitto_sub -v -R $mqtthost $_subscriptions -t "$sSysMqqtDummyTopic/maximum" $_last_will_options | awk -e '{ print strftime("MQTT ") $0 ; fflush() } ' > $fPipe  &  #  pipe non-stale commands from MQTT broker 
			# set +x
			readonly nPidMosquitto=$!
			command="mqtt" && reply_to_mqtt_status "ON" "started subprocess PID $nPidMosquitto, subscribed $( echo "$_subscriptions" | sed -e 's/-t //g' )"
			while sleep 120 ; do echo PERIODIC noop ; done  > $fPipe  &  #  pipe periodic stuff into the pipe to make it wakeup
			readonly nPidPeriodic=$!
			trap_function() { 
					rm -f $fPipe
					kill $nPidMosquitto $nPidPeriodic
					command="mqtt" && reply_to_mqtt_status "OK" "ending"
 					debug_if_verbose "$scriptname: kill'ed $nPidMosquitto $nPidPeriodic, sent MQTT, now stopping at $( date )" 
				}			
			trap 'trap_function' INT QUIT TERM
			# trap "kill $nPidMosquitto $nPidPeriodic ; rm -f $fPipe" INT QUIT EXIT  # variables are set now for cleaning up
		fi
		# NB: OpenHab Homie autodiscovery doesn't like uppercase characters at the beginning...
		[ "$homie" ] && os_data="$( get_os_data_semi_starred_cached "$sTargetHost" 1 )" && homie="$( echo "$sTargetHost" | awk -- '{ print tolower(substr($i,1,1)) substr($i,2) }' )" &&
			 [ "$commandsToDo" != "homie-delete" ] && announce_disco "$homie"
		
		debug_if_verbose "Entering command loop (commandsToDo=$commandsToDo)"
		while [ "$commandsToDo" ] ; do
			if [ "$commandsToDo" = "mqtt" ]  ;  then
				# set -x
				read -r sPipeType command commandopts < "$fPipe" ; nReadCode=$? 
				[ "$nReadCode" -ne 0 ] && sleep 1 && reply_to_mqtt_status "ERROR" "Read error from pipe $fPipe (retval=$nReadCode)" && 
						error_and_exit "Read error from pipe $fPipe (retval=$nReadCode)." 

				if [ "$sPipeType" = "MQTT" ] ; then 
					# set -x
					_prefix="$( echo "$command" | awk -v FS=/ '{ print $1 "/" $2 }' )"
					_msg="$( echo "$commandopts" | awk '{ print $1 }' )" && [ "$_msg" = "(null)" ] && _msg=""
					debug_if_verbose "Read raw MQTT command: $command  $_msg  (prefix=$_prefix, sitecode=$sitecode)"
					case "$_prefix" in
					"homie/$sTargetHost"|"$sitecode/$sTargetHost") 
						# _fullcommand="$( echo "$command" | awk -v FS=/ 'NF && NF-1 { print $3 ( $4 && $4 != "get" ? "/" $4 : "" ) ( $5 && $5 != "get" ? "/" $5 : "" ) }' )${_msg:++$_msg}" 
						command="$( echo "$command" | awk -v FS=/ 'NF && NF-1 { print $3 ( $4 && $4 != "get" ? "/" $4 : "" ) ( $5 && $5 != "get" ? "/" $5 : "" ) }' )" 
						# set -x
						case "$command" in
						localclients*|publicwifi/localclients*)				command="localclients" ;;
						ffstatus*)		command="ffstatus" ;; 
						ffup*)			command="ffup"   ;;
						ffdown*)		command="ffdown" ;;
						echo*)			command="echo"   ;;
						loop*)			command="loop"   ;;
						sitecode*)		command="sitecode"  ;;
						gluon-data*)	command="gluondata" ;;
						machine-data*)	command="machine-data" ;;
						ffotherssid*)		command="ffotherssid_$_msg" ;;
						publicwifi/ssidshort/set) command="ffotherssid_$_msg" ;;

						publicwifi/state/set) 	[ $_msg = "true"  -o $_msg = "ON"  ] && command="ffup"
												[ $_msg = "false" -o $_msg = "OFF" ] && command="ffdown"
											;;
						esac
						;;
					*)     command="$( echo "$command" | awk -v FS=/ 'NF && NF-1 { print ( $(NF-1) ) }' )" 
						;; # extract last part of topic, must have at least one /
					esac
					command=${command%/get} && command=${command%/GET}
					debug_if_verbose "Mapped MQTT command: $command"
				fi
			else
				     command="$( echo "$commandsToDo" | cut -d "," -f 1     )"
				commandsToDo="$( echo "$commandsToDo" | cut -d "," -f 2- -s )"
			     commandopts="$( echo "$command"      | cut -d "+" -f 2- -s )" # split further...
				     command="$( echo "$command"      | cut -d "+" -f 1     )"
			fi			
			    command="$( echo "$command"     | tr -c -d "A-Za-z0-9_-" )" # for security reasons
			commandopts="$( echo "$commandopts" | tr -c -d "A-Za-z0-9_-" )" # for security reasons

			case "$command" in
			mqtt|noop|ignore|echo)
				debug_if_verbose "Command $command $commandopts ($( date +%T ))"
				[ "$command" = "echo" ] && reply_to_mqtt_status "OK" "Command $command $commandopts"
				;;
			loop)
				commandopts="${commandopts:-10}"
				if [ 1 -lt "$commandopts" -a "$commandopts" -lt 11 ]  ; then
					startval="$( $ssh_cmd "date -u +%s" )" && echo_if_not_quiet "$startval" 
						for i in $( seq 2 $((commandopts - 1)) ) ; do
							echo_if_not_quiet "$( $ssh_cmd "date -u +%s" )"
						done && 
						  endval="$( $ssh_cmd "date -u +%s" )" && echo_if_not_quiet "$endval"
					reply_to_mqtt_status "OK" "Command $command: Performed $commandopts-times /bin/date in $(( endval - startval)) seconds: $startval-$endval"
				else
					reply_to_mqtt_status "ERROR" "Command $command: Invalid parameter '$commandopts'"
				fi
				;;
			install)
				deny_if_mqtt && continue
				targetuser="$( $ssh_cmd "id -nu" )"
				if [ -z "$targetuser" ] ; then
					echo_if_not_quiet "targetuser on targethost could not be determined remotely. Pls debug/establish SSH setup..."
					continue # abort case
				fi

				if [ "$ssh_cmd" != "exec_locally" ] || [ "$targetuser" = "root" ] ; then
					echo_if_not_quiet "Remote targetuser is $targetuser: Shall copy this script to /sbin later..."
					commandsToDo="filecopy${commandsToDo:+,$commandsToDo}"
					filetocopy="$0"
				fi

				os_data="$( get_os_data_semi_starred_cached "$sTargetHost" 1 )"
				debug_if_verbose "$os_data"

				# ... try to install mosquitto if not there yet
				if [ "$( $ssh_cmd "command -v mosquitto_pub" 2>/dev/null )" ] ; then
					echo_if_not_quiet "mosquitto_pub is already installed on $ffhost..."
				else
					echo_if_not_quiet "mosquitto_pub was not found on $ffhost... trying to install..."
					installcmd=$( $ssh_cmd "command -v opkg || command -v apt || echo nothing" 2>/dev/null ) 					
					case "$( basename "$installcmd" )" in
					opkg)
						$ssh_cmd "opkg update ; opkg install mosquitto-client-nossl"
						;;
					apt)
						$ssh_cmd "apt update && apt install mosquitto-clients"
						;;
					nothing)
						error_and_exit "ERROR: opkg / apt not found on $ffhost. Stopping..."
						;;
					esac
				fi
				# set -x
				# hare a quite Gluon-specific part. Trying to determine by checking for the UCI entry autoupdater_branch
				autoupdater_branch="$( get_uci_on_host "autoupdater.settings.branch" )"
				debug_if_verbose "autoupdater_branch=$autoupdater_branch"
				if [ -z "$autoupdater_branch" ] ; then
					# Probably Non-Freifunk 
					echo_if_not_quiet "Stopping for target $sTargetHost (no autoupdater_branch uci setting)..." 
					continue
				else
					storage_cache_write "$sTargetHost.autoupdater_branch" "$autoupdater_branch"
					echo_if_not_quiet "autoupdater config found ... assuming freifunk node ... adding firewall rules for MQTT..."
					# works for Ulmer Software w/o Gluon, too... DONT KNOW IF NECESSARY ON ALL GLUON VERSIONS
					# set -x
					$ssh_cmd "xargs ${bVerbose:+-t} -n 1 uci set ; uci commit" << EOF
						firewall.local_client_mqtt=rule
						firewall.local_client_mqtt.dest_port='1883'
						firewall.local_client_mqtt.src='local_client'
						firewall.local_client_mqtt.name='local_client_mqtt'
						firewall.local_client_mqtt.target='ACCEPT'
						firewall.local_client_mqtt.proto='tcp'
						firewall.wan_mqtt=rule
						firewall.wan_mqtt.dest_port='1883'
						firewall.wan_mqtt.src='wan'
						firewall.wan_mqtt.name='wan_mqtt'
						firewall.wan_mqtt.target='ACCEPT'
						firewall.wan_mqtt.proto='tcp'
						firewall.mesh_mqtt=rule
						firewall.mesh_mqtt.dest_port='1883'
						firewall.mesh_mqtt.src='mesh'
						firewall.mesh_mqtt.name='mesh_mqtt'
						firewall.mesh_mqtt.target='ACCEPT'
						firewall.mesh_mqtt.proto='tcp'
						firewall.client_mqtt=rule
						firewall.client_mqtt.dest_port='1883'
						firewall.client_mqtt.src='mesh'
						firewall.client_mqtt.name='client_mqtt_mqtt'
						firewall.client_mqtt.target='ACCEPT'
						firewall.client_mqtt.proto='tcp'
EOF
					{ $ssh_cmd "[ -d $gluondir ] && gluon-reconfigure" ; } || debug_if_verbose "Trying to find $gluondir or gluon-reconfigure failed..."
				fi
				# sending out a "MQTT test message" to test whether its working
				_pubcmd="$cmd_mospub -h test.mosquitto.org" # caution: Freifunk/Gluon seems to need IPV6 connectivity, not all brokers have it!
				_topic="\"$sitecode/\`tr A-Z a-z < /proc/sys/kernel/hostname\`/installation\""
				$ssh_cmd "$_pubcmd -t $_topic -r -m \"TEST\"" 
				retval=$?
				# set -x
				if [ $retval = 0 ] ; then
					debug_if_verbose "$_pubcmd $_topic succeeded on remote host."
					# set -x
					$ssh_cmd "mosquitto_sub -h test.mosquitto.org -t $_topic -v -C 1 -W 5  --remove-retained"
					# set +x
				else
					echo_if_not_quiet "$_pubcmd failed with $retval on remote host (might happen sometimes)"
				fi

				if $ssh_cmd "crontab -l" | grep "$scriptname" ; then
					debug_if_verbose "A crontab entry containing $scriptname has been found... Not modifying crontab."
				else
					echo_if_not_quiet "crontab entry with $scriptname not found... adding a simple one... pls modify later!"
					cronentry="*/30 * * * * sleep 15 ; $scriptname -c machine-data -m test.mosquitto.org"
					$ssh_cmd "{ crontab -l ; echo \"$cronentry\" ; } | crontab - ; ${bVerbose:+echo crontab is now: ; crontab -l}"
				fi
				# still missing: make it run as an MQTT daemon!
				;;
			filecopy)
				deny_if_mqtt && continue
				[ -z "$filetocopy" ] && filetocopy="$commandopts"
				debug_if_verbose "Command $command: $filetocopy ($( pwd))"
				[ -n "$filetocopy" ] && scp -p "$filetocopy" "$sSshUser":/sbin && debug_if_verbose "$filetocopy copied to $sSshUser:/sbin"
				;;
			sh)
				deny_if_mqtt && continue
				ssh "$sSshUser" # start a remote shell
				;;
			homie-update|disco-update|discovery-update)
				commandsToDo="localclients,ffstatus,gluondata,machine-data,$commandsToDo"
				
				uptimecmd="cat /proc/uptime" && [ "$ffhost" != localhost ] && uptimecmd="$0 -h $ffhost $uptimecmd" 
				homieuptime=$( $uptimecmd ) && homie_line "$homie/\$stats/uptime" "$( echo "$homieuptime" | cut -f 1 -d . )"
				;;
			homie-delete|disco-delete|discovery-delete)
				deny_if_mqtt && continue
				homie="$( echo "$sTargetHost" | awk -- '{ print tolower(substr($i,1,1)) substr($i,2) }' )" # duplicated code...
				announce_disco "$homie" "-d"
				;;
			ffdown)
				# deny_if_mqtt && continue
				ff_if_pub="$( get_public_if_cached "$sTargetHost" )"
				# [ -z "$ff_if_pub" ] && debug_if_verbose "defaulting to public interface $ff_if_pub1" &&  ff_if_pub="$ff_if_pub1"
				new_ssid=$( $ssh_cmd "iw dev $ff_if_pub del" 2>&1 ) # stop Freifunk public interface
				echo "$new_ssid" | grep -q 'No such.* device' && reply_to_mqtt_status "ERROR" "$new_ssid" && new_ssid=""
				echo_if_not_quiet "$sTargetHost: Ran wifi down on public $ff_if_pub (new_ssid=$new_ssid)"
				homie_line "$homie/publicwifi/clientscount" "-1"
				[ "$new_ssid" ] && reply_to_mqtt_status "OK" "new_ssid=$new_ssid"
				commandsToDo="ffstatus${commandsToDo:+,$commandsToDo}"
				;;
			ffup|ffstatus)
				ff_if_pub="$( get_public_if_cached "$sTargetHost" )"
				# [ -z "$ff_if_pub" ] && debug_if_verbose "defaulting to public interface $ff_if_pub1" &&  ff_if_pub="$ff_if_pub1"
				debug_if_verbose "Now doing $command on host $sTargetHost (if=$ff_if_pub) ..."
				retval=0
				if [ "$command" = "ffup" ] ; then
					reply_to_mqtt_status "ONGOING" "Will run $command for $sTargetHost" 
					tempstr="$( $ssh_cmd "wifi up && sleep $wifiupsleep && iwinfo $ff_if_pub info" )"
				elif [ "$new_ssid" ] ; then
					debug_if_verbose "Reused new_ssid=$new_ssid..."
					tempstr="$new_ssid"
				else
					debug_if_verbose "$( $ssh_cmd "iwinfo $ff_if_pub info" 2>&1 )"
					tempstr="$( $ssh_cmd "iwinfo $ff_if_pub info" 2>&1 )"
				fi
				retval=$?			
				homie_line "$homie/publicwifi/lastdate" "$( date -Iseconds )"
				if [ "$retval" != 0 -o -z "$tempstr" ] || echo "$tempstr" | grep -w -q -E "open failed|connect failed|No such" ; then
					# something went wrong...
					tempstr="$( echo "$tempstr" | xargs echo )"
					error "retval=$retval for executing $command - $tempstr" 
					homie_line "$homie/publicwifi/state" "false" 
					if [ "$retval" = 1 ] ; then
						reply_to_mqtt_status "OFF" "retval=$retval"
						publish_to_mqtt_starred "/publicwifi/state"     "OFF"
					elif [ "$retval" = 255 ] ; then
						reply_to_mqtt_status "OFF" "retval=$retval (unreachable?)"
						publish_to_mqtt_starred "/publicwifi/state"     "OFF" # better: ERROR ?
					else
						reply_to_mqtt_status "ERROR" "retval=$retval // $tempstr"
						publish_to_mqtt_starred "/publicwifi/state"     "OFF"  # better: ERROR ?
					fi
				else # ... went ok.
					new_ssid=$( echo "$tempstr" | sed -e '/ESSID/s/[^:]*: //' -e 's/\"//g'  -e '1q' )
					echo "$new_ssid"
					new_ssid_short="$( printf "%s" "$new_ssid" | sed -e 's,.*/,,' -e 's/"//g'  )"
					reply_to_mqtt_status "OK" "$new_ssid" 
					homie_line "$homie/publicwifi/state"		"true"
					homie_line "$homie/publicwifi/ssidshort" 	"$new_ssid_short"
					publish_to_mqtt_starred "/publicwifi/state"     "ON"
					publish_to_mqtt_starred "/publicwifi/ssidshort" "$new_ssid_short"
				fi
				;;
			ffcond)
				deny_if_mqtt && continue
				result=$( $ssh_cmd '{ for i in 1 2 2 ; do iw dev mesh0 scan ; sleep $i ; done } | tee /tmp/wifis ; echo ++++++++++++ ; iwinfo | fgrep client0 '  )
				ifresult=$( echo "$result" | grep -A 3 '++++++++++' | grep -m 2 "client0 *ESSID:" )
				if echo "$result" | grep -A 9 -w '6e:a3:09:ea:31:e00' | grep -w "SSID:.$ssidbase"
				then
					# client0   ESSID: "muenchen.freifunk.net/welt"
					echo_if_not_quiet "To be upped..."
					if [ -z "$ifresult" ] ; then commandsToDo="ffup${commandsToDo:+,$commandsToDo}" ; fi
				else	
					echo_if_not_quiet "To be downed..."
					if [ -n "$ifresult" ] ; then commandsToDo="ffdown${commandsToDo:+,$commandsToDo}" ; fi
				fi
				debug_if_verbose commandsToDo=$commandsToDo
				# ( ( iwinfo | fgrep client0 ) || ( wifi up ; echo wifi upped. ) )  ) || ( iwinfo | fgrep client0 && iw dev client0 del ; echo if downed )
				;;
			ffotherssid|ffotherssid1|ffotherssid2|ffotherssid_*|ffotherssid-*)
				ff_if_pub="$( get_public_if_cached "$sTargetHost" )"
				# [ -z "$ff_if_pub" ] && debug_if_verbose "defaulting to public interface $ff_if_pub1" &&  ff_if_pub="$ff_if_pub1"

				# ["freising", "gauting", "muc_cty", "muc_nord", "muc_ost", "muc_sued", "muc_west", "uml_nord", "uml_ost", "uml_sued", "uml_west", "welt"]
				# $ssh_cmd "ip link set $ff_if_pub up" # start Freifunk public interface
				# $ssh_cmd "true" || { echo_if_not_quiet "target not reachable, aborting this command...." ; continue ; }
				otherssid="${commandopts:-welt}"
				case "$command" in
					ffotherssid1)  _shortssid="uml_nord" 	;;
					ffotherssid2)  _shortssid="uml_west"	;;
					ffotherssid_*) _shortssid="$( echo ${command#ffotherssid_} | tr -d '}{)( ,.=' )"
						[ -z "$_shortssid" ] && echo_if_not_quiet "Empty shortssid: ${command#ffotherssid_}" && continue
						;;
					ffotherssid-*) _shortssid="$( echo ${command#ffotherssid-} | tr -d '}{)( ,.=' )"
						[ -z "$_shortssid" ] && echo_if_not_quiet "Empty shortssid: ${command#ffotherssid-}" && continue
						;;
				esac
				command="ffotherssid"
				# further checks for allowed and lawful SSID values among gluon domains ....
				if expr match "$( get_gluon_domains_starred_cached "$sTargetHost" )" ".*\*${_shortssid}[*]" > /dev/null ; then
					otherssid="$ssidbase/$_shortssid"	
					reply_to_mqtt_status "ONGOING" "Setting short SSID: $_shortssid"
				else
					reply_to_mqtt_status "ERROR" "Illegal shortssid: $_shortssid"
					publish_to_mqtt_starred "/gluondata/gluon-domains" "$( get_gluon_domains_starred_cached $sTargetHost )"
					echo_if_not_quiet "Illegal shortssid: $_shortssid" && continue
				fi
				result=$( $ssh_cmd "iwinfo $ff_if_pub info | sed -e 's/: /:/' -e 's/ESSID/SSIDPREV/' -e '1q' ; uci set wireless.client_radio0.ssid=$otherssid ; 
				              wifi up ; sleep $wifiupsleep ; iwinfo $ff_if_pub info | sed -e 's/: /:/' -e '1q' " 2>&1 )
				retval=$?
				#### uci set wireless.client_radio0.ssid=$otherkey ; uci set wireless.client_radio0.encryption=psk2 ; 
				#### while true ; do sleep 1 ; date ; iwinfo $ff_if_pub info | grep SSID ; done
				### result=$( ssh -i ~/.ssh/id_rsa4096_ff -o ProxyCommand="ssh -v -W [2001:608:a01:103:ee08:6bff:fe33:6940]:%p alt-solln" root@[2001:608:a01:103:ee08:6bff:fe33:6940] uname -a )
				# echo "$result" >> $debugfile
				if [ "$retval" = 255 ] ; then
					_logmsg="target not reachable (SSH return code 255), aborting ffotherssid command...." 
					echo_if_not_quiet "$_logmsg" 
					reply_to_mqtt_status "ERROR" "$_logmsg"
					continue
				elif [ -z "$result" ] ; then
					_logmsg="ffotherssid commands on remote host returned empty string..." 
					echo_if_not_quiet "$_logmsg" 
					reply_to_mqtt_status "ERROR" "$_logmsg"
					continue
				else
					prev_ssid=$( printf "$result" | grep SSIDPREV: | cut -d : -f 2 )
					new_ssid=$(  printf "$result" | grep ESSID:    | cut -d : -f 2 | tr -d \" )
					echo_if_not_quiet "%s: Set ssid=%s, then wifi up. Now $new_ssid. // id=$(id -nu)/$(id -u)\n" "$sTargetHost" "$otherssid"
					commandsToDo="ffstatus${commandsToDo:+,$commandsToDo}" # ... implicitly followed by a ffstatus
				fi
				;;
			ffgluonreconfigure)
				deny_if_mqtt && continue
				ff_if_pub="$( get_public_if_cached "$sTargetHost" )"
				# [ -z "$ff_if_pub" ] && debug_if_verbose "defaulting to public interface $ff_if_pub1" &&  ff_if_pub="$ff_if_pub1"

				# $ssh_cmd "ip link set $ff_if_pub up" # start Freifunk public interface
				# 6 seconds needed for interface!
				result=$( $ssh_cmd "iwinfo $ff_if_pub info | sed -e 's/: /:/' -e 's/ESSID/SSIDPREV/' -e '1q' ; gluon-reconfigure | tail -3 ; wifi up  ; sleep $wifiupsleep ; iwinfo $ff_if_pub info | sed -e 's/: /:/' -e '1q' " )
				prev_ssid=$( printf "$result" | grep SSIDPREV | cut -d : -f 2 )
				new_ssid=$( printf "$result" | grep ESSID | cut -d : -f 2 )
				echo_if_not_quiet "$sTargetHost: Ran gluon-reconfigure, previously $prev_ssid, then wifi up, then $new_ssid. id=$(id -nu)/$(id -u)\n" 
				if [ "$prev_ssid" != "$new_ssid" ] ; then
					commandsToDo="localclients${commandsToDo:+,$commandsToDo}"
				fi
				commandsToDo="ffstatus${commandsToDo:+,$commandsToDo}" # ... implicitly followed by a ffstatus
				;;
			sitecode)
				_data="$( get_sitecode_cached "$sTargetHost" 0 )"
				if [ -z "$_data" ] ; then
					reply_to_mqtt_status "ERROR"
				else
					echo "$_data"
				fi
				;;
			gluondata)
			  os_data="$( get_os_data_semi_starred_cached "$sTargetHost" 1 )"
			  if [ -z "$os_data" ] ; then
			  	reply_to_mqtt_status "ERROR"
			  else
				output="$( $ssh_cmd "uci get autoupdater.settings.branch 2>&1 ; uci get autoupdater.settings.enabled 2>&1 ; uci get gluon.core.domain 2>&1 ; lua -e 'print(require(\"platform_info\").get_model())' 2>&1 ; cat $gluondir/gluon-version 2>&1 ; cat $gluondir/release 2>&1" )"
				autoupdaterbranch="$( echo "$output" | sed -n -e "1p" )"
				autoupdaterenabled="$( echo "$output" | sed -n -e 2s/0/false/  -e 2s/1/true/ -e "2p" )"
				gluoncoredomain="$( echo "$output" | sed -n -e "3p" )"
				routermodel="$(     echo "$output" | sed -n -e "4p" )"
				gluonversion="$(    echo "$output" | sed -n -e "5p" )"
				gluonrelease="$(    echo "$output" | sed -n -e "6p" )"

				echo_if_not_quiet "$os_data"
				publish_to_mqtt_starred "/gluondata/os-data" "$os_data"
				homie_line              "$homie/gluondata/os-data" "$os_data"

				echo_if_not_quiet "$autoupdaterbranch"
				publish_to_mqtt_starred "/gluondata/autoupdater-branch" "$autoupdaterbranch"
				homie_line                  "$homie/gluondata/autoupdater-branch" "$autoupdaterbranch"

				echo_if_not_quiet "$autoupdaterenabled"
				publish_to_mqtt_starred "/gluondata/autoupdater-enabled" "$autoupdaterenabled"
				homie_line                  "$homie/gluondata/autoupdater-enabled" "$autoupdaterenabled"

				echo_if_not_quiet "$gluoncoredomain"
				publish_to_mqtt_starred "/gluondata/core-domain" "$gluoncoredomain"
				homie_line                  "$homie/gluondata/core-domain" "$gluoncoredomain"

				echo_if_not_quiet "$routermodel"
				publish_to_mqtt_starred "/gluondata/model" "$routermodel"
				homie_line                  "$homie/gluondata/model" "$routermodel"

				newval="TBD"
				publish_to_mqtt_starred "/gluondata/site" "$newval"
				homie_line                  "$homie/gluondata/site" "$newval"

				echo_if_not_quiet "$gluonversion"
				publish_to_mqtt_starred "/gluondata/gluon-version" "${gluonversion##v}"
				homie_line                  "$homie/gluondata/gluon-version" "${gluonversion##v}"
				
				echo_if_not_quiet "$gluonrelease"
				publish_to_mqtt_starred "/gluondata/release" "${gluonrelease##v}"
				homie_line                  "$homie/gluondata/release" "${gluonrelease##v}"

				gluondomains="$( get_gluon_domains_starred_cached $sTargetHost )"
				echo_if_not_quiet "$gluondomains"
				publish_to_mqtt_starred "/gluondata/gluon-domains" "$gluondomains"
				homie_line              "$homie/gluondata/gluon-domains" "$gluondomains"

			  	reply_to_mqtt_status "OK"
			  fi
			  ;;
			machine-data)
				os_data="$( get_os_data_semi_starred_cached "$sTargetHost" 1 )"
				debug_if_verbose "os_data=$os_data"
				newval=$( $ssh_cmd "cat /proc/version /proc/cpuinfo" |  awk -v os_data="$os_data" '
					NR==1 { linuxversion=$3 ; FS=": " }
					/^machine|^Hardware/ { FS=": " ; printf "{*linuxversion*:*%s*,*machine*:*%s*,%s}", linuxversion ,$2, os_data ; exit 0 }
					' ) 
				echo_if_not_quiet "$newval"
				publish_to_mqtt_starred "/$command" "$newval"
				;;
			speedtest|speedtest0|speedtest00)
				speedtestparam="" ; [ "$bVerbose" ] || speedtestparam="-q"   ;    speedtestparam="-q"
				lastspeedtestString=$( storage_cache_read "$sTargetHost.lastspeedtest" 1 ) && lastspeedtestString=",*lastspeedtest*:*$lastspeedtestString*"
				speedtestcmd=$( storage_cache_read "$sTargetHost.speedtestmincommand" 1 ) # prefer the previous one
				# [ "$speedtestcmd" ] && command="$speedtestcmd"
				case "${speedtestcmd:-$command}" in
					speedtest)   speedtestfile="http://speedtest.tele2.net/1MB.zip"   ;;
					speedtest0)  speedtestfile="http://speedtest.tele2.net/10MB.zip"  ;;
					speedtest00) speedtestfile="http://speedtest.tele2.net/100MB.zip" ;;
				esac
				debug_if_verbose "speedtest: fetching $speedtestfile..." 
				newval=$( $ssh_cmd "date -u +%s; wget $speedtestparam -O - $speedtestfile | wc -c ; date -u +%s"  )
				retval=$?
				if [ $retval = 0 ] ; then
					starttime=$( echo "$newval" | sed -n -e "1 p" )
					filesize=$(  echo "$newval" | sed -n -e "2 p" )
					endtime=$(   echo "$newval" | sed -n -e "3 p" )
					newval=$(( endtime - starttime ))
					if [ "$newval" -lt 10 ] ; then
						debug_if_verbose "$newval is too fast, redoing: ${command}0"
						commandsToDo="${command}0${commandsToDo:+,$commandsToDo}" # try 10-times larger
					else
						speedMB=$( echo $speedKB | awk "{ printf \"%.1f\" ,  $filesize / $newval / 1024 / 1024 }" )
						echo_if_not_quiet "$speedMB"
						publish_to_mqtt_starred "/speedtest" "{*speedMB*:*$speedMB*,*size*:*$filesize*,*elapsedtime*:*$newval*${lastspeedtestString}}"
						storage_cache_write "$sTargetHost.speedtestmincommand" "$command"
						storage_cache_write "$sTargetHost.lastspeedtest" "$speedMB"
					fi
				else
					echo_if_not_quiet "ERROR: $retval"
					reply_to_mqtt_status "ERROR" "{*ERROR*:*$retval*,*file*:*$speedtestfile*${lastspeedtestString}}"
				fi
				;;
			status)
				newval=$( $ssh_cmd "cat /proc/uptime /proc/loadavg" | awk '
					NR==1 { uptime=sprintf("%d", $1) }
					NR==2 { printf "{*uptime*:*%s*,*load*:*%.2f*}", uptime ,$1 }
					'  ) # uptime in seconds
				echo_if_not_quiet "$newval"
				publish_to_mqtt_starred "/$command" "$newval"
				;;
			printmap)  
				$ssh_cmd "print_map.sh" | $json_pp # Freifunk node info as JSON for non-Gluon systems, e.g. from Ulm
				;;
			localclients)  
				clientcollectionfile="$tmpdir/clientcollection"
				touch "$clientcollectionfile" && chmod g+w "$clientcollectionfile"
				localclientsfile="$clientcollectionfile.$sTargetHost"
				[ -r $macidsfile ] || touch $macidsfile
				
				_batctl_output="$( $ssh_cmd -q "batctl translocal" )"
				retval=$?
				if [ $retval != 0 ] ;  then
					error "Connection $sSshUser failed (retval=$retval). Stopping for this node..."
				  	reply_to_mqtt_status "ERROR" "Connection $sSshUser failed (retval=$retval)"
				else
					echo "$_batctl_output" | awk '$3 == "[....W.]" { printf "%s\n", $1 }' | sort > $localclientsfile # | join -a 1 - "$macidsfile" 
				
					# ( date ; cat $localclientsfile ) >> $debugfile
					awk -- "{ print strftime(\"%Y-%m-%d_%H:%M:%S \") \$0 \" $sTargetHost\" ; fflush() ; next }" $localclientsfile >> $clientcollectionfile
					
					if command -v join >/dev/null && [ -r $macidsfile ] ; then  # prerequisites to join the data to a list of clients...
						{ sort -k 1 $localclientsfile | join -1 1 -2 1 -a 1 - $macidsfile | sort | uniq -w 17 > "$localclientsfile"_with_names ; } &&
								mv "$localclientsfile"_with_names "$localclientsfile"
					fi

					[ "$bVerbose" ] && echo "****  \$localclientsfile=$localclientsfile: ****" && cat "$localclientsfile"
					_lcount=$( wc -l < $localclientsfile )
					homie_line "$homie/publicwifi/clientscount" "$_lcount"
					## cp -p $localclientsfile /tmp/xx
					localclients=$( tr " " "," <"$localclientsfile" |
						awk -F, -v lcount="$_lcount" -v hname="$sTargetHost" 'BEGIN { printf "{*count*:*%s*,*localclients*:[", lcount } { printf comma " {*addr*:*%s*,*name*:*%s*}", $1, ($2=="")? $1 : $2 $3 $4 $5 ; comma="," } END { printf "],*host*:*%s*}",hname }' | 
						  shorten_ethernet_addr_in_json ${bDoAllOfIt:+skip} )
					echo_if_not_quiet "Local clients: $localclients"
					while read _addr _what _who ; do 
						echo "*$_addr* *$_what* *$_who*" 
						_addr="$( echo $_addr | sed -e 's/://g' )"
						_details="$_what$_who" ; [ "$_details" ] || _details="$_addr"
						publish_to_mqtt_starred "$sitecode/$areaid/$_addr" "{*lasthost*:*$sTargetHost*, *details*:*$_details*}"
					done < "$localclientsfile"
					publish_to_mqtt_starred "$sitecode/$sTargetHost/publicwifi/localclients" "$localclients"
					[ "$workonallclients" ] && nCollectedSumOfClients=$(( nCollectedSumOfClients + _lcount ))
					collectedclients="$collectedclients $( xargs < $localclientsfile )" 
					collectedclients="${collectedclients% }" # trim leading spaces
				fi
				;;
			nodeinfo|neighbours|statistics)  
				tmpfilejson="$tmpdir/$sTargetHost.$command.tmp"
				cachednodeip="$( storage_cache_read "$sTargetHost.nodeip" 10 )"
				# if [ "$cachednodeip" = "##NOTFOUND##" -o "$cachednodeip" = "##EMPTY##" ]
				__gni_cmd="gluon-neighbour-info -i br-client -p 1001 -r $command -d  " # ipaddr will be appended below
				if [ -z "$cachednodeip" ]  ;  then
					ffnodeip=$( $ssh_cmd "ip -f inet6 -o addr show dev $ifipv6" | awk -e '{ print gensub("/.*", "", "1", $4) ; exit 0 }'  ) && \
						$ssh_cmd "$__gni_cmd $ffnodeip" | tee "$tmpfilemqtt"
				else
					ffnodeip="$cachednodeip" && \
						$ssh_cmd "$__gni_cmd $ffnodeip" | tee "$tmpfilemqtt"
				fi
				debug_if_verbose "Had called $__gni_cmd $ffnodeip"
				returnsize=$( wc -l < "$tmpfilemqtt" )
				# find "$tmpdir" -name "$( basename "$tmpfile_nodeip" )" -size -26c -exec rm '{}' \; # delete file if it is too small...

				if [ -z "$ffnodeip" ] ; then
					error "Remote node IP :$ffnodeip: is empty. Command $command failed..."
				  	reply_to_mqtt_status "ERROR" "Remote node IP undetermined"
					# rm -f "$tmpfile_nodeip"
				elif [ "$returnsize" -eq 0 ]  ;  then
					error "Connection to $sSshUser or gluon-neighbour-info failed. Command $command on node ip $ffnodeip failed..."
				  	reply_to_mqtt_status "ERROR" "remote result empty"
					# rm -f $tmpfile_nodeip
				else
					[ "$ffnodeip" != "$cachednodeip" ] && storage_cache_write "$sTargetHost.nodeip" "$ffnodeip"
					storage_cache_write "$sTargetHost.$command" "$( cat $tmpfilemqtt )" # write all types to support change detection some time
					publish_to_mqtt "$sitecode/$sTargetHost/$command" "$( cat $tmpfilemqtt )"
					if [ "$command" = "statistics" ] ; then
						# node_id=$( jq -r .node_id $tmpfilemqtt )
						# publish_to_mqtt "$sitecode/$sTargetHost/nodeid" "$node_id" "-r"
						### publish_to_mqtt "$sitecode/$node_id/$command"  "$( cat $tmpfilemqtt )"  "-r"
						# publish_to_mqtt "$sitecode/$sTargetHost/ipv6" "$ffnodeip" "-r"
						### publish_to_mqtt "$sitecode/$node_id/ipv6"      "$ffnodeip" "-r"
						clients="$( jsonfilter_func ".clients.wifi" < $tmpfilemqtt )"
						# cat $tmpfilemqtt
						publish_to_mqtt_starred "/clients" "$clients"
						[ "$workonallclients" ] && nCollectedSumOfClients=$(( nCollectedSumOfClients + clients ))
						# publish_to_mqtt "$sitecode/$node_id/clients" "$clients"
					fi

					[ -f $tmpfilejson.prev ] && mv -f $tmpfilejson.prev $tmpfilejson.old
					[ -f $tmpfilejson      ] && mv -f $tmpfilejson $tmpfilejson.prev
					$json_pp < $tmpfilemqtt > $tmpfilejson
					chmod g+w $tmpfilejson
				fi
				;;
			showsite)  
				tmpfilejson="$tmpdir/$sTargetHost.$command.old"
					
				if [ -n "$( $ssh_cmd gluon-show-site | tee $tmpfilemqtt )" ]
				then
					node_id="$( jq -r .node_id $tmpfilemqtt )"
					publish_to_mqtt "$sitecode/$sTargetHost/$command" "$( tr -d '\n' < $tmpfilemqtt )"
					publish_to_mqtt "$sitecode/$node_id/$command"     "$( tr -d '\n' < $tmpfilemqtt )"
					$json_pp < $tmpfilemqtt | tee $tmpfilejson
				else
					error_and_exit "$scriptname: ssh to $sSshUser failed. Stopping..."
				fi
				# 33 * * * * /srv/openhab2-conf/manage-gluon-mqtt/manage_gluon_mqtt -c statistics
				# 43 * * * * /srv/openhab2-conf/manage-gluon-mqtt/manage_gluon_mqtt -c neighbours
				# 53 * * * * /srv/openhab2-conf/manage-gluon-mqtt/manage_gluon_mqtt -c nodeinfo
				;;
			mountsizes)
				deny_if_mqtt && continue
				_mountsizes="$( $ssh_cmd "df -Ph" | sed -e 's/\([0-9]\)\.0K/\1K/g' | jq -R -s '
					[ split("\n")  |  .[]  |
					  if test("^/") then
						gsub(" +"; " ") | split(" ") | {mountpoint:.[5], filesystem:.[0], spaceavail:.[3], spaceused:.[2], percentused:.[4], spacetotal:.[1]}
					  else
						empty
					  end ]' )"
				echo_if_not_quiet "$_mountsizes"
				# set -x
				publish_to_mqtt "${sitecode:-UNSET}/$sTargetHost/$command" "${_mountsizes}"
				set +x
				;;
			reboot)  
				deny_if_mqtt && continue
				$ssh_cmd "/sbin/reboot"
				;;
			scandirty)  
				deny_if_mqtt && continue
				# relies on the following entry in root's crontab, since only root is allowed to do a full wifi scan
				# SHELL=/bin/bash
				# * * * * * { /sbin/iw dev wlan0 scan ; sleep 2 ; /sbin/iw dev wlan0 scan ; sleep 2 ; /sbin/iw dev wlan0 scan ; } | fgrep SSID  | cut -d ":" -f 2 | xargs -n 1 | sort -u > /tmp/wifis.txt
				# { for i in 2 2 2 2 ; do /sbin/iw dev wlan0 scan ; sleep $i ; done } | fgrep SSID  | cut -d ":" -f 2 | xargs -n 1 | sort -u > /tmp/wifis.new ; mv /tmp/wifis.new /tmp/wifis.txt ; date >> /tmp/wifis.txt
				# * * * * * { for i in 1 2 1 2 ; do /sbin/iw dev wlan0 scan ; sleep $i ; done } | egrep -w '^BSS|SSID'| sed -e 's/BSS *//' -e 's/(.*//' -e 's/\t*SSID: //' -e 's/^$/./' | xargs -L2 | sort -u > /tmp/wifis.new ; mv /tmp/wifis.new /tmp/wifis.txt ; date >> /tmp/wifis.txt

				echo "$scriptname: command scandirty grepping for **$ffssid**" > "$debugfile"
				grep -wi "${ffssid}"  /tmp/wifis.txt | tee "$debugfile"
				rm -f /tmp/wifis.txt.hint
				exit 0
				;;
			*)
				echo_if_not_quiet "Illegal command=$command"
				deny_if_mqtt && continue
				error_and_exit "Unknown command: $command"
			esac
			sort_and_tail_file "$debugfile" 300
		done
	fi 
	find "$( dirname "$debugfile")" -maxdepth 1 -prune -path "$debugfile.[0-9]*" -mtime +0 -exec rm '{}' \; # remove old debug files
	
	if [ $# -gt 0 ]
	then
		# ... everything that's left in "$@" is taken as shell commands, too....
		$ssh_cmd "$@"
	fi
done

if [ -n "$nCollectedSumOfClients" ] ; then
	[ "$bVerbose" -a "$bGiveHost" ] && echo "######"
	[ "$bVerbose" -o "$bGiveHost" ] && echo "######  ALL CLIENTS " "$@" "######"
	publish_to_mqtt "$areaid/publicwifi/allclientscount" "$nCollectedSumOfClients"

	if [ "$clientcollectionfile" ] ; then
		sort_and_tail_file "$clientcollectionfile" 18 1
		[ "$bVerbose" ] && echo $clientcollectionfile: && cat "$clientcollectionfile"
		if command -v join >/dev/null && [ -r $macidsfile ]; then
			_ccwn_fn="${clientcollectionfile}_with_names"
			 { sort -k 2 "$clientcollectionfile" | join -1 2 -2 1 -a 1 - $macidsfile | sort -r -k 1 | 
			uniq -w 17 | sort -k 2 > "$_ccwn_fn" ; } && [ "$bVerbose" ] && echo "$_ccwn_fn":  && cat "$_ccwn_fn"
			mv "$_ccwn_fn" "$clientcollectionfile"
		fi
		string2="$( awk -F" " -v id="$areaid" -v lcount="$nCollectedSumOfClients" 'BEGIN { printf "{*count*:*%s*,*id*:*%s*,*localclients*:[", lcount, id } { printf comma "{*addr*:*%s*,*name*:*%s*}", $1 , ($4=="")? $1 : $4 $5 $6 $7 ; comma="," } END { printf "]}" }' < "$clientcollectionfile" |
			shorten_ethernet_addr_in_json ${bDoAllOfIt:+skip} )"
		echo_if_not_quiet "$( echo "$string2 " | tr \* \" | $json_pp )"
		publish_to_mqtt_starred "$sitecode/$areaid/alllocalclients" "$string2"		
	fi
fi

set +o noglob # globbing needed for * to work
mv "$tmpdir"/* "$cachedir" ; rmdir "$tmpdir"
find "$cachedir" -maxdepth 1 -path "$cachedir/[0-9]*" -type d -mtime +0 -exec rm -r '{}' \; # remove old debug files

# End of main.

# Old stuff:
# password=$(cat password_file)
# uci set wireless.@wifi-iface[0].encryption=psk
# uci set wireless.@wifi-iface[0].key="$password"
# uci commit wireless
# wifi