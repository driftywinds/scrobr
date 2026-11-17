# Scrobr Privacy Policy

**Effective date:** 17 November 2026

Scrobr is an Android client for Scrob, self-hosted media tracking software.
This policy explains what the Scrobr app does with data. It does not describe
the Scrob server you choose to connect to — that server is controlled by you or
its operator, not by the Scrobr app developer.

## The short version

- Scrobr has **no developer-operated backend**, no analytics, no advertising,
  no tracking SDKs and no crash reporting.
- The app does **not collect, sell, rent or share personal data** with the
  developer or with data brokers.
- Everything you save is either stored on your Android device or sent directly
  to the Scrob server you configure.
- Calendar-release notifications are generated locally on your device.

## Information stored on your device

Scrobr stores the following in the app's private Android storage:

- The address of the Scrob server you enter.
- Account details you choose to save, including usernames, session tokens and,
  if you use API-key sign-in, the API key.
- App preferences such as theme colours, calendar length, library visibility
  and notification settings.
- Local caches, including the calendar, Up Next rows, lists and images, so the
  app opens faster and can show recent data after a refresh.
- Backup status information. Backup files are written only to the folder you
  explicitly select.

Your password is sent to your server when you sign in. Scrobr does not save your
password; it stores the session token returned by the server.

This local data is protected by Android's app sandbox. Scrobr does not encrypt
its local preferences with an additional app-specific password.

## Network requests

Scrobr talks directly to the Scrob server you configure, normally through its
`/api/proxy` endpoints. Those requests include your session credentials and the
media, history, list or calendar data needed for the screen you are using. Your
server and its operator can see your IP address and the requests you make,
subject to that server's own privacy practices.

Media images are normally loaded through your server's image proxy. When you
sign in with an API key, some images may load directly from public metadata
services such as `image.tmdb.org` or `artworks.thetvdb.com`; those services
receive the image request and are governed by their own policies.

Links to external services such as YouTube, GitHub or your Scrob web UI open in
your browser or the relevant app. Scrobr does not control those services.

The Scrobr developer does not operate a server that receives your app data.

## Permissions

Scrobr requests only the permissions needed for its features:

- **Internet** — to communicate with your Scrob server and load artwork.
- **Notifications** (optional) — to show calendar-release notifications.
- **Folder access** (optional) — to write backups to a folder you choose.

Scrobr does not request location, contacts, camera, microphone, health, SMS or
call-log access.

## Calendar-release notifications

If you enable **Calendar releases**, Scrobr periodically checks your Scrob
calendar from your device and caches the results locally. When an episode or
movie is due to release, the app creates a local Android notification on your
device. No notification data is sent to the developer or to a push service.

You can turn this off at any time in **Settings → Notifications**.

## Backups

If you configure scheduled backups, Scrobr downloads a backup from your Scrob
server and writes it to the folder you selected using Android's Storage Access
Framework. The app does not upload that backup anywhere else. Backup files
remain until you delete them or remove the folder.

## Sharing

Scrobr does not share your data with the developer, advertisers or data brokers.
Data is transmitted only to:

- the Scrob server you configure;
- public image services when API-key mode loads artwork directly; and
- external sites you deliberately open from the app.

The app does not include third-party advertising or analytics SDKs.

## Retention and deletion

Local app data remains on your device until you clear the app's storage or
uninstall the app. Logging out removes the active session from the device.
Backups remain in the folder you chose until you delete them.

Data stored on your Scrob server is controlled by that server's operator. To
access, correct or delete it, use your server's account tools or contact its
administrator. The Scrobr app developer cannot access or delete data held on a
server they do not operate.

## Children

Scrobr is not directed at children under 13 and does not knowingly collect
personal information from children.

## Security

Use an HTTPS server address where possible. The security of data stored on your
Scrob server depends on how that server is configured and operated. No method of
storage or transmission is completely secure.

## Changes

If this policy changes, the effective date above will be updated and the new
version will be published in this repository.

## Contact

For privacy questions, open an issue at
<https://github.com/driftywinds/scrobr/issues>.
