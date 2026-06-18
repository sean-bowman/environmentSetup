# Firmware Attribution

The CircuitPython firmware in this `firmware/` directory is **not** original work.
It is derived from the open-source **pico-ducky** project and is redistributed
under its original license.

## Upstream

- **Project:** pico-ducky
- **Author:** Dave Bailey (dbisu, [@daveisu](https://github.com/dbisu))
- **Source:** https://github.com/dbisu/pico-ducky
- **License:** GNU General Public License v2.0 (see [`LICENSE`](LICENSE))

## Files from upstream (unmodified)

- `boot.py` — USB mass-storage visibility control via GP15
- `code.py` — entry point; board detection, payload selection, Pico W web service
- `duckyinpython.py` — Ducky Script v1.0 interpreter (USB HID keyboard injection)
- `webapp.py` — Pico W web interface for remote payload management
- `wsgiserver.py` — minimal WSGI server for the Pico W web interface
- `RESET.md` — recovery instructions
- `lib/` — bundled Adafruit support libraries (`adafruit_hid`, `adafruit_wsgi`,
  `asyncio`, `adafruit_debouncer`, `adafruit_ticks`), MIT-licensed by Adafruit

## Original contributions (Sean Bowman)

Everything outside `firmware/` is original work: the Windows provisioning scripts
(`scripts/`), the injection payload (`payloads/environmentSetup.dd`), and the
documentation. The firmware is used as an unmodified, attributed dependency to
deliver that payload.

> **GPLv2 note:** because the firmware is GPLv2, the firmware directory remains
> under GPLv2. The original Windows tooling in this repository is released under
> the repository's top-level license.
