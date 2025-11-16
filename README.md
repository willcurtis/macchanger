# macchanger (modernised fork)

macchanger for macOS – spoof / fake MAC addresses from the command line.

This is an updated and extended fork of the original [`macchanger` script by **shilch**](https://github.com/shilch/macchanger).  
All credit for the original idea and implementation goes to the upstream author.

## Features

- Change the MAC address of a network interface on macOS
- Generate a **random, locally-administered, unicast** MAC address
- Set a **specific** MAC address
- Reset the interface back to its **permanent hardware** MAC
- Show current and permanent MAC addresses, plus **best-effort vendor lookup**
- List network devices as seen by macOS
- Safer implementation:
  - Uses `set -euo pipefail`
  - Stricter error handling and input validation
  - Works on recent macOS releases (Intel & Apple Silicon)
- Output colouring:
  - Automatically disabled when stdout is not a TTTY
  - Respects the standard `NO_COLOR` environment variable

Tested on recent macOS versions, but it should work on any reasonably modern macOS with `bash`, `ifconfig`, `networksetup`, and `openssl` available.

## Installation

### Direct install (curl)

```sh
sudo sh -c "curl -fsSL https://raw.githubusercontent.com/willcurtis/macchanger/main/macchanger.sh > /usr/local/bin/macchanger && chmod +x /usr/local/bin/macchanger"
```

### Homebrew (recommended)

1. Create or use an existing tap, for example:

   ```sh
   brew tap willcurtis/tap https://github.com/willcurtis/homebrew-tap
   ```

2. Add a `macchanger.rb` formula to your tap with contents similar to:

   ```ruby
   class Macchanger < Formula
     desc "Change or spoof your MAC address on macOS"
     homepage "https://github.com/willcurtis/macchanger"
     url "https://github.com/willcurtis/macchanger/archive/refs/tags/v1.0.0.tar.gz"
     sha256 "<fill-in-from-github-release>"
     version "1.0.0"

     def install
       bin.install "macchanger.sh" => "macchanger"
     end

     test do
       assert_match "Version:", shell_output("#<built-in function bin>/macchanger --version 2>&1")
     end
   end
   ```

3. Install via Homebrew:

   ```sh
   brew install willcurtis/tap/macchanger
   ```

Replace the `sha256` with the value from the GitHub release tarball once you create it.

### Manual install

Download `macchanger.sh` and place it somewhere on your `$PATH`, for example:

```sh
sudo install -m 0755 macchanger.sh /usr/local/bin/macchanger
```

## Usage

Type:

```sh
sudo macchanger
```

You should see:

```text
Usage: sudo macchanger [option] [device]

Options:
  -r, --random           Generate a random MAC and set it on the device
  -m, --mac MAC          Set a custom MAC address, e.g. macchanger -m aa:bb:cc:dd:ee:ff en0
  -p, --permanent        Reset the MAC address to the permanent hardware value
  -s, --show             Show current and permanent MAC address (plus vendor info)
  -l, --list-devices     List network devices as seen by macOS
  -V, --version          Print version
  -h, --help             Show help
```

### Examples

Set a **custom** MAC:

```sh
sudo macchanger -m aa:bb:cc:dd:ee:ff en0
```

Set a **random** MAC:

```sh
sudo macchanger -r en0
```

Reset to **permanent** MAC:

```sh
sudo macchanger -p en0
```

Show info (including vendor lookup):

```sh
sudo macchanger -s en0
```

List devices:

```sh
sudo macchanger -l
```

## Vendor / manufacturer lookup

`macchanger` will try to perform a best-effort OUI lookup using a local database.

By default it looks for a file in one of the following locations (first readable match wins):

- `/usr/share/misc/oui.txt`
- `/usr/share/ieee-data/oui.txt`
- `/usr/local/share/wireshark/manuf`

You can override the path with the `MACCHANGER_OUI_PATH` environment variable:

```sh
export MACCHANGER_OUI_PATH="$HOME/.local/share/oui.txt"
sudo macchanger -s en0
```

If no OUI file can be found, the vendor will be shown as `Unknown`, but the rest of the functionality still works.

## Credits

- Original script and idea by **shilch** – <https://github.com/shilch/macchanger>
- Modernisation, vendor lookup and Homebrew packaging by **Will Curtis** and community contributors.

If you publish further changes, please keep attribution to the original author and clearly document any modifications.
