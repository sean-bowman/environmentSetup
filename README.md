# environmentSetup

A USB-deployable, one-shot provisioner for a Windows 11 engineering development
environment. A Raspberry Pi Pico, flashed as a USB HID keyboard, types a single
command that downloads and runs a PowerShell bootstrap script: installing the
full toolchain, a Python scientific stack, and VS Code with extensions, with no
manual clicking.

It is the consolidation of two older projects: a Pico "rubber ducky" firmware
and a separate VBScript-based installer. The legacy installer relied on blind
keystroke automation and VBScript (now deprecated on Windows 11) and no longer
worked; this version replaces all of that with **winget + PowerShell**.

## What it installs

| Category    | Tooling |
|-------------|---------|
| Editor      | Visual Studio Code + extensions, Claude Code |
| Languages   | Python (Miniconda 3.10), .NET SDK 10, Node.js, Rust |
| VCS         | Git |
| Python libs | numpy, scipy, pandas, matplotlib, CEA_Wrap |
| Thermo      | **REFPROP** (`ctREFPROP`) if already installed, otherwise **CoolProp** |

### REFPROP vs CoolProp

REFPROP is NIST-licensed and is **not** distributed by this repo. The bootstrap
checks for an existing `%USERPROFILE%\REFPROP` install:

- **present** → installs the `ctREFPROP` wrapper and sets `RPPREFIX`
- **absent** → installs the open-source `CoolProp` as a drop-in alternative

## How it works

```text
Pico (USB HID)  ──types──►  Run dialog
                            powershell ... irm <repo>/scripts/bootstrap.ps1 | iex
                                              │
                                              ▼
                            winget installs ─► conda env ─► pip ─► VS Code extensions
```

1. The Pico runs [`firmware/`](firmware) (CircuitPython, based on `pico-ducky`)
   and "types" [`payloads/environmentSetup.dd`](payloads/environmentSetup.dd).
2. The payload opens the Run dialog and launches
   [`scripts/bootstrap.ps1`](scripts/bootstrap.ps1) straight from this repo.
3. `bootstrap.ps1` is idempotent: re-running it skips anything already present.

## Quickstart

### Run the provisioner directly (no hardware)

```powershell
# from a clone
pwsh ./scripts/bootstrap.ps1

# or remotely, exactly as the Pico does it
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/sean-bowman/environmentSetup/main/scripts/bootstrap.ps1 | iex"
```

Useful flags: `-SkipWinget` (only refresh Python/extensions),
`-PythonVersion 3.11`.

### Flash the Pico

See [`docs/flashing.md`](docs/flashing.md) for the full flashing and arming
procedure.

## Repository layout

```text
environmentSetup/
├── firmware/      CircuitPython USB-HID firmware (GPLv2, see firmware/ATTRIBUTION.md)
├── payloads/      Ducky Script payload typed by the Pico
├── scripts/       winget + PowerShell provisioner and package lists
├── docs/          Flashing guide and images
├── LICENSE        MIT (original work): firmware is GPLv2 separately
└── .gitignore
```

## Configuration

- **Python packages:** edit [`scripts/requirements.txt`](scripts/requirements.txt).
- **VS Code extensions:** edit [`scripts/vscode-extensions.txt`](scripts/vscode-extensions.txt).

## Privileges

Installs are user-scope where possible and generally do not require admin. A few
winget packages (e.g. the .NET SDK) may request elevation; the script reports
such cases and continues rather than aborting.

## Authorized use

The Pico presents as a USB keyboard and will execute its payload on any host it
is plugged into. Use it only on machines you own or are explicitly authorized to
provision. It is a personal-productivity tool, not an offensive utility.

## Attribution

The firmware is derived from [pico-ducky](https://github.com/dbisu/pico-ducky)
by Dave Bailey, redistributed under GPLv2. See
[`firmware/ATTRIBUTION.md`](firmware/ATTRIBUTION.md). All other code and
documentation is original work by Sean Bowman.
