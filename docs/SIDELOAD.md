# Sideloading to a Garmin watch

## Status

The Connect IQ SDK 9.2.0 and all five official fēnix 8 profiles are installed. The signing key is outside the repository. Climb Indoor Training passes all 57 current simulator tests. Signed release PRGs and production/private-beta IQ packages have been rebuilt; see [training-builds.log](../validation/training-builds.log) and [artifacts.json](../validation/artifacts.json). No artifact has been installed on a physical watch. A PRG sideload alone does not register the custom-field display metadata with Garmin Connect; for Connect integration use the prepared private beta and [CONNECT_SETUP.md](CONNECT_SETUP.md).

The exact physical fēnix 8 variant should be checked on the watch and matched to one of the supported product IDs in [ENVIRONMENT.md](ENVIRONMENT.md). The default build target is `fenix847mm`.

## Build a signed device artifact

1. Set `CIQ_KEY` to the external developer key path or pass the path with `--key`. Never copy the key into this repository or share its contents.
2. Confirm the chosen model's profile and build prerequisites:

   ```sh
   python3 tools/ciq.py doctor --device fenix847mm
   ```

3. Build the signed release PRG for the exact device ID:

   ```sh
   python3 tools/ciq.py build --release --device fenix847mm
   ```

   The release output is `dist/Climb-fenix847mm.prg`. Substitute the watch's exact profile ID as needed. `docs/BUILD.md` lists the available IDs and additional build options.
4. Confirm the build succeeds and the output file exists before copying it to the watch. Existing release outputs are in `dist/Climb-<device>.prg`; rebuild after any source change before sideloading.

## Copy to the watch

1. Confirm the computer and transfer method can access the watch's MTP storage. Garmin lists fēnix 8 AMOLED/Solar and fēnix 8 Pro as MTP devices and says access to MTP files requires Windows; macOS does not natively expose those files as a drive. See [Garmin's MTP device list](https://support.garmin.com/en-US/?faq=CZqibgTHMb0dAYEaj2UiU7) and [Garmin's Mac MTP guidance](https://support.garmin.com/en-US/?faq=zUa4z1zKNn39o6JiqZDHNA). Do not assume Finder will mount the watch or install an unverified third-party transfer utility.
2. Connect using a data-capable USB cable and use a supported MTP-capable transfer environment to access `GARMIN/APPS`.
3. Copy the signed release `.prg` into `GARMIN/APPS` on the watch, then safely disconnect using the transfer environment's eject procedure.
4. Open the Connect IQ app from the watch's activity/app list and launch Climb.
5. Confirm the app opens without an install or launch error before using it during a climbing session.

The user confirmed that the app screen is visible in the simulator. Automated screenshot capture remains blocked by OS automation permissions. The physical watch model and actual transfer path, install, and launch have not been verified. Treat this procedure as a plan until the checklist below is completed.

## Verification record

- SDK 9.2.0 installed: **Verified**
- Official fēnix 8 profiles installed: **Verified**
- External developer key available: **Verified; stored at `$HOME/.garmin-climb/developer_key.der`; contents were not read or documented**
- Signed release PRGs built for all five official profiles: **Verified**
- PRG copied to `GARMIN/APPS`: **Pending**
- App launched on physical fēnix 8: **Pending**
- App removed cleanly after test: **Pending**
