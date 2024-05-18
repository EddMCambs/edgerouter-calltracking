#!/bin/bash
set -u
set -o pipefail

###
# Begin TTLs per service. Don't change unless you're having issues with a specific service
###
export MEETTTL=${GLOBALTTL}
export TEAMSTTL=${GLOBALTTL}
export ZOOMTTL=${GLOBALTTL}
export JITSITTL=${GLOBALTTL}
export SLACKTTL=${GLOBALTTL}
###
# End TTLS per service
###

# Function to toggle state in Home Assistant
function set_server_state() {
  target_state=$1
  curl -s -X POST -H "Authorization: Bearer ${HOMEASSITANT_API_KEY}" \
                  -H "Content-Type: application/json" \
                  --retry 5 \
                  -d "{\"state\":\"${target_state}\", \"attributes\":{\"friendly_name\": \"${YOUR_NAME} Call Status\", \"icon\":\"mdi:phone-in-talk\"}}" \
                  ${HOMEASSISTANT_URI}/api/states/input_boolean.${HOMEASSISTANT_BOOLEAN_NAME}
}

# Get the initial on_call state
on_call=$(curl -s -X GET --retry 5 -H "Authorization: Bearer ${HOMEASSITANT_API_KEY}" ${HOMEASSISTANT_URI}/api/states/input_boolean.${HOMEASSISTANT_BOOLEAN_NAME} | jq -r ".state")

# Loop forever
while [[ 1 ]]
do
  # Store wether we're on a call at the start of a loop
  on_call_old=$on_call
  # Default to off unless we find a call
  on_call="off"

  # If we're looking for a new call, we want a TTL of 0, so this turns you on to a call immediately, else use the configured TTLs for call ending
  if [[ $on_call_old == "off" ]]; then
    export MEETTTLCHECK=0
    export TEAMSTTLCHECK=0
    export ZOOMTTLCHECK=0
    export JITSITTLCHECK=0
    export SLACKTTLCHECK=0
  else
    export MEETTTLCHECK=${MEETTTL}
    export TEAMSTTLCHECK=${TEAMSTTL}
    export ZOOMTTLCHECK=${ZOOMTTL}
    export JITSITTLCHECK=${JITSITTL}
    export SLACKTTLCHECK=${SLACKTTL}
  fi

  # Get all the ipv4 and ipv6 connections the firewall is tracking
  callconnections=$(conntrack -L -s ${CLIENT_IPV4_ADDRESS} -p udp 2>/dev/null \
                     | grep ${CLIENT_IPV4_ADDRESS} | awk '{print $3, $5, $6, $7}')

  callconnections+=$'\n'$(conntrack -L -s ${CLIENT_IPV6_ADDRESS} -p udp 2>/dev/null \
                     | grep ${CLIENT_IPV6_ADDRESS} | awk '{print $3, $5, $6, $7}')

  # These are, in order:
  # Meet
  # Teams
  # Zoom
  # Jitsi
  # Slack
  if  \
        echo "$callconnections" | grep -e 'dst=74.125.250.' -e 'dst=142.250.82.' -e 'dst=2001:4860:4864:5:' -e 'dst= 2001:4860:4864:6:' | awk -v t="$MEETTTLCHECK" '$1<t {exit 1}'  || \
        echo "$callconnections" | grep -e 'sport=500[0-5][0-9] dport=\(3478\|3479\|3480\|3481\)' | awk -v t="$TEAMSTTLCHECK" '$1<t {exit 1}'  || \
        echo "$callconnections" | grep -e 'dport=88[0-1][0-9]' | awk -v t="$ZOOMTTLCHECK" '$1<t {exit 1}'  || \
        echo "$callconnections" | grep -e 'dport=10000' | awk -v t="$JITSITTLCHECK" '$1<t {exit 1}'  || \
        echo "$callconnections" | grep -e 'dst=99.77.1[2-9][0-9]' | awk -v t="$SLACKTTLCHECK" '$1<t {exit 1}' \
    ; then
      on_call="on"
  fi
  if [[ $on_call != $on_call_old ]] ; then
    set_server_state $on_call
    if [[ ${VERBOSE} -gt 0 ]]; then
      echo "Toggled from ${on_call_old} to ${on_call}"
    fi
    sleep 60 # to avoid spamming the HA server
  else
    if [[ ${VERBOSE} -gt 0 ]]; then
      echo "No change, still set to ${on_call_old}"
    fi
  fi
  sleep 5
done
