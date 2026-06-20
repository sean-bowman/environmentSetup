# Flashing the Pico and Deploying the Payload

This guide covers installing CircuitPython on a Raspberry Pi Pico / Pico W,
copying the firmware, and arming the environment-setup payload.

## 1. Install CircuitPython

1. Download the CircuitPython UF2 for your exact board from
   [circuitpython.org/downloads](https://circuitpython.org/downloads):
   - Raspberry Pi Pico → `raspberry_pi_pico`
   - Raspberry Pi Pico W → `raspberry_pi_pico_w`
   - Pico 2 / Pico 2 W are also supported (10.2.0+)
   Use the latest stable release (10.2.0 or newer).
2. Hold the **BOOTSEL** button while plugging the Pico into USB. It mounts as a
   drive named `RPI-RP2`.
3. Copy the `.uf2` file onto `RPI-RP2`. The board reboots and remounts as
   `CIRCUITPY`.

## 2. Copy the firmware

Copy the contents of this repo's [`firmware/`](../firmware) directory onto the
`CIRCUITPY` drive so the layout is:

```text
CIRCUITPY/
├── boot.py
├── code.py
├── duckyinpython.py
├── webapp.py            (Pico W web interface; harmless on plain Pico)
├── wsgiserver.py
├── lib/                 (copy everything from firmware/lib/)
│   ├── adafruit_hid/
│   ├── adafruit_wsgi/
│   ├── asyncio/
│   ├── adafruit_debouncer.mpy
│   └── adafruit_ticks.mpy
├── secrets.py           (Pico W only: see step 3)
└── payload.dd           (see step 4)
```

## 3. Wi-Fi secrets (Pico W only)

Copy [`firmware/secrets.example.py`](../firmware/secrets.example.py) to
`secrets.py` on the `CIRCUITPY` drive and set your own AP SSID/password. The
plain Pico ignores this file.

## 4. Deploy the payload

Copy [`payloads/environmentSetup.dd`](../payloads/environmentSetup.dd) to the
`CIRCUITPY` root **renamed to `payload.dd`**.

> The `irm` URL in the payload points at `github.com/sean-bowman/environmentSetup`.
> Change it only if you fork the repo to a different account.

**The device is now armed.** The next time it is plugged into a host, it will
type the bootstrap command. Unplug it until you intend to run it.

## Setup mode (edit without auto-running)

To stop the payload from firing so you can edit files on the Pico, put it in
**setup mode**: connect **pin 1 (GP0)** to **pin 3 (GND)** with a jumper before
plugging in. See [`docs/images/setup-mode.png`](images/setup-mode.png).

## USB drive visibility (GP15)

`boot.py` controls whether the Pico presents its filesystem to the host:

- **Pico:** GP15 floating → USB visible; GP15 → GND → hidden
- **Pico W:** GP15 floating → hidden (so the web UI owns the filesystem);
  GP15 → GND → visible

## Pico W web interface

When powered as a Pico W (and not running a payload), it starts a Wi-Fi access
point and serves a payload manager at `http://192.168.4.1:80` with endpoints:
`/`, `/new`, `/ducky`, `/edit/<file>`, `/write/<file>`, `/run/<file>`,
`/api/run/<number>`.

## Recovery (nuke a bricked Pico)

Hold **BOOTSEL**, plug in, and copy a `flash_nuke.uf2`
([from Raspberry Pi](https://datasheets.raspberrypi.com/soft/flash_nuke.uf2))
onto `RPI-RP2`, then reinstall CircuitPython. See
[`firmware/RESET.md`](../firmware/RESET.md).
