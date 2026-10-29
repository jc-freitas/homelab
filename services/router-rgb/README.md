# Router RGB LED

A native OpenWrt service exposes a Linux multicolor status LED as a Home Assistant MQTT light. It supports RGB color, brightness and on/off, reports actual sysfs state, restores the selected state after restarting, and uses MQTT discovery and availability. No Docker container or Home Assistant restart is required.

The driver must expose `/sys/class/leds/rgb:status` with `multi_index` equal to `red green blue` and brightness from 0 to 255. Tested on an Acer Predator Connect W6x running OpenWrt.

## Install

1. Install the clients on OpenWrt: `apk add mosquitto-client-ssl jsonfilter`.
2. Create a dedicated `router_rgb` user on your MQTT broker, using `mosquitto_passwd` for a Mosquitto password file. Reload the broker after changing its password file.
3. Copy `config.example` to `/etc/router-rgb/config` on the router, fill in the broker and credentials, and set mode `600`. Keep this file out of Git.
4. Copy `bridge.sh` to `/usr/sbin/router-rgb` and `router-rgb.init` to `/etc/init.d/router-rgb`; set both executable.
5. Run `/etc/init.d/router-rgb enable` and `/etc/init.d/router-rgb start`.

The Home Assistant MQTT integration discovers a device named **Roteador** with an **RGB** light. It can be renamed in Home Assistant. Use a different `UNIQUE_ID` and `MQTT_BASE` for each router.

Commands use the MQTT light JSON schema, for example:

```json
{"state":"ON","brightness":32,"color":{"r":0,"g":0,"b":255}}
```

The bridge saves accepted changes in `/etc/router-rgb/state.json`; periodic checks do not write flash. Other tools' LED changes are reflected in HA within 30 seconds. Color channels and brightness are validated before writing the driver. Effects and gradual transitions are not implemented.

Check service health with `/etc/init.d/router-rgb status` and `logread -e router-rgb`. Stop and disable this service to return control to the usual OpenWrt LED configuration; delete its retained discovery message if removing the entity from HA.

Validated through HA: two colors at low brightness, off/on with brightness restoration, invalid brightness rejection, and recovery after service restart. The initial LED state was restored after testing.
