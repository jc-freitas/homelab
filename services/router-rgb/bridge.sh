#!/bin/sh
# Native OpenWrt multicolor LED -> Home Assistant MQTT light.
# Dependencies: mosquitto-client-ssl, jsonfilter. No network/firewall changes.
set -u
CONFIG=${ROUTER_RGB_CONFIG:-/etc/router-rgb/config}
[ -r "$CONFIG" ] || { echo "router-rgb: missing $CONFIG" >&2; exit 1; }
. "$CONFIG"
: "${MQTT_HOST:?}" "${MQTT_USERNAME:?}" "${MQTT_PASSWORD:?}"
MQTT_PORT=${MQTT_PORT:-1883}
MQTT_BASE=${MQTT_BASE:-homelab/router/rgb}
RGB_LED=${RGB_LED:-/sys/class/leds/rgb:status}
STATE_FILE=${STATE_FILE:-/etc/router-rgb/state.json}
UNIQUE_ID=${UNIQUE_ID:-openwrt_router_rgb}
DISCOVERY_TOPIC="homeassistant/light/$UNIQUE_ID/config"
LAST_BRIGHTNESS=255
SUB_PID=
WORK=

log() { logger -t router-rgb "$*"; }
uint8() {
    case "$1" in ''|*[!0-9]*) return 1 ;; esac
    [ "${#1}" -le 3 ] && [ "$1" -le 255 ]
}
field() { jsonfilter -s "$1" -e "$2" 2>/dev/null; }
publish() {
    mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" \
        -q 1 -r -t "$1" -m "$2"
}
read_led() {
    [ "$(cat "$RGB_LED/multi_index")" = 'red green blue' ] || return 1
    read -r R G B < "$RGB_LED/multi_intensity" || return 1
    read -r BRIGHTNESS < "$RGB_LED/brightness" || return 1
    uint8 "$R" && uint8 "$G" && uint8 "$B" && uint8 "$BRIGHTNESS" || return 1
    [ "$BRIGHTNESS" -eq 0 ] || LAST_BRIGHTNESS=$BRIGHTNESS
    LED_STATE=OFF
    [ "$BRIGHTNESS" -eq 0 ] || LED_STATE=ON
}
state_json() {
    printf '{"state":"%s","brightness":%s,"color_mode":"rgb","color":{"r":%s,"g":%s,"b":%s}}' \
        "$LED_STATE" "$BRIGHTNESS" "$R" "$G" "$B"
}
report() {
    read_led || return 1
    publish "$MQTT_BASE/state" "$(state_json)" || return 1
    publish "$MQTT_BASE/availability" online
}
save_state() {
    # Called only on accepted changes: no periodic flash writes.
    printf '{"state":"%s","brightness":%s,"color":{"r":%s,"g":%s,"b":%s}}\n' \
        "$LED_STATE" "$LAST_BRIGHTNESS" "$R" "$G" "$B" > "$STATE_FILE.new" &&
        mv "$STATE_FILE.new" "$STATE_FILE"
}
apply_command() {
    payload=$1
    state=$(field "$payload" '@.state')
    brightness=$(field "$payload" '@.brightness')
    color=$(field "$payload" '@.color')
    case "$state" in ''|ON|OFF) ;; *) return 1 ;; esac
    [ -n "$state$brightness$color" ] || return 1
    if [ -n "$brightness" ]; then uint8 "$brightness" || return 1; fi
    if [ -n "$color" ]; then
        nr=$(field "$payload" '@.color.r'); ng=$(field "$payload" '@.color.g'); nb=$(field "$payload" '@.color.b')
        uint8 "$nr" && uint8 "$ng" && uint8 "$nb" || return 1
    fi
    read_led || return 1
    target=$BRIGHTNESS
    if [ -n "$brightness" ]; then
        target=$brightness
        [ "$target" -eq 0 ] || LAST_BRIGHTNESS=$target
    elif [ "$state" = ON ] && [ "$target" -eq 0 ]; then
        target=$LAST_BRIGHTNESS
    fi
    [ "$state" != OFF ] || target=0
    if [ -n "$color" ]; then R=$nr; G=$ng; B=$nb; fi
    # Validation finishes before touching sysfs. Linux scales RGB by brightness.
    echo none > "$RGB_LED/trigger" || return 1
    echo "$R $G $B" > "$RGB_LED/multi_intensity" || return 1
    echo "$target" > "$RGB_LED/brightness" || return 1
    read_led && save_state
}
discover() {
    # IDs/topics come from root-owned configuration, never MQTT input.
    publish "$DISCOVERY_TOPIC" "{\"name\":\"RGB\",\"unique_id\":\"$UNIQUE_ID\",\"schema\":\"json\",\"command_topic\":\"$MQTT_BASE/set\",\"state_topic\":\"$MQTT_BASE/state\",\"availability_topic\":\"$MQTT_BASE/availability\",\"brightness\":true,\"supported_color_modes\":[\"rgb\"],\"optimistic\":false,\"qos\":1,\"retain\":false,\"icon\":\"mdi:router-wireless\",\"device\":{\"identifiers\":[\"$UNIQUE_ID\"],\"name\":\"Roteador\",\"manufacturer\":\"OpenWrt\",\"model\":\"Linux multicolor LED\"},\"origin\":{\"name\":\"OpenWrt RGB bridge\",\"sw_version\":\"1.0\"}}"
}
cleanup() {
    trap - EXIT INT TERM
    [ -z "$SUB_PID" ] || kill "$SUB_PID" 2>/dev/null
    publish "$MQTT_BASE/availability" offline >/dev/null 2>&1
    if [ -n "$WORK" ]; then
        rm -f "$WORK/commands"
        rmdir "$WORK" 2>/dev/null
    fi
}
if [ "${ROUTER_RGB_LIBRARY_ONLY:-0}" = 1 ]; then return 0; fi
# Read and write just this LED; never restart networking or the LED subsystem.
read_led || { log 'unsupported LED layout or inaccessible sysfs'; exit 1; }
if [ -r "$STATE_FILE" ]; then
    saved=$(cat "$STATE_FILE")
    saved_brightness=$(field "$saved" '@.brightness')
    if uint8 "$saved_brightness" && [ "$saved_brightness" -gt 0 ]; then LAST_BRIGHTNESS=$saved_brightness; fi
    apply_command "$saved" || log 'saved state rejected; keeping current LED'
fi
if [ "${1:-}" = --apply ]; then
    apply_command "${2:-}" && report
    exit $?
fi
trap cleanup EXIT INT TERM
WORK=$(mktemp -d /tmp/router-rgb.XXXXXX) || exit 1
mkfifo "$WORK/commands" || exit 1
mosquitto_sub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USERNAME" -P "$MQTT_PASSWORD" \
    -i "$UNIQUE_ID" -q 1 -v -t "$MQTT_BASE/set" -t homeassistant/status \
    --will-topic "$MQTT_BASE/availability" --will-payload offline --will-qos 1 --will-retain \
    > "$WORK/commands" &
SUB_PID=$!
# Hold the reader open even through read timeouts; otherwise the writer gets SIGPIPE.
exec 3< "$WORK/commands"
discover || log 'discovery publish failed; will retry'
report || log 'initial state publish failed; will retry'
log 'bridge started'
while kill -0 "$SUB_PID" 2>/dev/null; do
    if IFS=' ' read -r -t 30 topic payload <&3; then
        case "$topic" in
            "$MQTT_BASE/set")
                if apply_command "$payload"; then report || log 'state publish failed';
                else log 'LED command invalid or driver unavailable'; fi
                ;;
            homeassistant/status)
                if [ "$payload" = online ]; then discover; report; fi
                ;;
        esac
    else
        # Catch external LED changes and restore availability after broker reconnect.
        discover >/dev/null 2>&1
        report >/dev/null 2>&1
    fi
done
exit 1
