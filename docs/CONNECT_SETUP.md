# Garmin Connect activity results

Climb Indoor Training records total attempts, Rope/Boulder/Auto counts, successful and failed totals, success percentage, and a readable Success / Failed pair for each type. Each climb lap also contains type and separate successful/failed/rated flags. “1 / 0” under **Rope Success / Failed** means one successful rope climb and zero failures. Success rate is successes divided by rated attempts; an unrated attempt is never guessed to be a failure.

The FIT recording has been independently decoded with Garmin’s official FIT SDK; [training-mixed-climbs.json](../validation/training-mixed-climbs.json) shows a successful Rope climb, a failed Boulder attempt, and a successful Auto climb, yielding 66.7% success. These are simulator recordings, not screenshots from a synced physical watch or Garmin Connect Mobile.

Garmin Connect obtains custom-field labels and display rules from the app’s uploaded Connect IQ package. Installing only a PRG does not register this metadata with Garmin. The official SDK’s **Core Topics → Beta Apps** explains that a private beta upload and installation lets developers test developer fields in Garmin Connect without releasing publicly. See [Garmin beta-app documentation](https://developer.garmin.com/connect-iq/core-topics/beta-apps/) and the installed SDK copy at `/private/tmp/garmin-sdk/doc/docs/Core_Topics/Beta_Apps.html`.

## Private beta setup

1. Upload `dist/Climb-Indoor-Training-beta.iq` to the [Connect IQ developer dashboard](https://apps.garmin.com/developer/dashboard) using your Garmin developer account and select the **Beta App / testing** option.
2. Install that private beta from your own uploaded apps onto the watch. Its application ID is separate from the sideload/production app, so it has separate settings/history. Use the installed beta when recording the test activity.
3. Complete attempts, select their Success/Failed results, and save the session.
4. Sync the watch through Garmin Connect. Open the new activity’s details/statistics and look for its Connect IQ fields. Lap presentation and the exact location can vary between Garmin Connect clients.

The package has been prepared locally. No account upload, public release, or physical-watch sync has been performed in this workspace. End-to-end Garmin Connect Mobile presentation therefore still requires the account upload, beta installation, and synced test activity.
