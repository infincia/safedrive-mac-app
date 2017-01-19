**Note:** This is a beta version of SafeDrive for Mac, it may not be feature-complete.

If you find a bug, please report it to the person you obtained the build from.

#### Changelog

**Changes in 0.9.20**

- Includes SafeDrive SDDK 0.3.2
- Fix issue with code signing/updates
- Fix crash due to embedded library not being found
- Fix high CPU use on mount/unmount
- Fix settings menu not being disabled before login

**Changes in 0.9.19**

- Includes SafeDrive SDDK 0.3.0

- Ensure initial window isn't transparent
    - Resolves [SD-133](https://jira.safedrive.io/browse/SD-133)
    
- Includes updated OSXFUSE package for osx 10.12 support

- Includes encrypted sync 
    - Adding folders as encrypted should work and is the default
    - When adding a folder there will be an options button at the bottom,
      click that and check or uncheck the encrypted box
    
- Known issues:
    - Progress display during a sync isn't wired up
    - Restore of encrypted folders isn't wired up
    - Entering a previously generated recovery phrase isn't implemented yet
    - Finder extension may not load at the moment



**Changes in 0.9.18**

- Add ability to delete sync folders when removing them from the account
    - Resolves [SD-86](https://jira.safedrive.io/browse/SD-86)
    
- Automatically select first row in sync manager when folders load
    - Resolves [SD-99](https://jira.safedrive.io/browse/SD-99)
    
- Use shell mv command instead of sftp when removing sync folders
    - Resolves [SD-85](https://jira.safedrive.io/browse/SD-85)

**Changes in 0.9.17**

- Add separate update channel for release builds

**Changes in 0.9.16**

- Merge sync manager and preferences window together
    - Resolves [SD-111](https://jira.safedrive.io/browse/SD-111)

- Move preferences window subviews to their own XIB objects
    - Helps separate them into manageable units

- Move away from using the NSTabView component
    - Allows more flexibility on layout and design
    - Fixes some minor visual glitches due to changes among OS X versions

- Update all 3rd party libraries
    - Moving to Realm 1.0.x fixes [SD-98](https://jira.safedrive.io/browse/SD-98)

- Build app for staging and production environments
    - Resolves [SD-30](https://jira.safedrive.io/browse/SD-30)

- Fix race condition related crash in sync scheduler

**Changes in 0.9.15**

- Fix for display of "restoring" even during a sync
- Previous build may not have copied all resources into bundle

**Changes in 0.9.14**

- Update dependencies
- Add support for restoring folder contents from SafeDrive

**Changes in 0.9.13**

- Add ability to cancel syncs
- Add newer rsync and SSHFS binaries
- Add sync progress display
- Add sync bandwidth use display
    - Can be higher than network use due to compression

- Move sync folder contents to /Storage when removed from account
- Add opt-out alerts when a crash happens
- Add confirmation prompts when removing folders or cancelling a sync
- Bugfixes
    - Compact database on startup
    - Prevent DB size from growing endlessly
    - Fix windows jumping around on OS X 10.10+
    - Excessive logging removed

**Changes in 0.9.12**

- Bugfix for 10.9 issue
- Update dependencies

**Changes in 0.9.11**

- Bugfixes
- Functional changes during sync:
    - rsync --delete added to remove files no longer present in local folder
    - preserve modification times
    - preserve permissions
    - preserve symlinks

**Change in 0.9.10**

- Several bug fixes
    - Initial sync when folders added works
    - Correctly reset state when user changes

- Allow individual folder sync times to be set
- Track individual sync events to show last success/failure
- Display next scheduled sync time for each sync folder

**Changes in 0.9.9**

- First install window added
    - Ensures OSXFUSE is installed before continuing

- Remove mount-time checks for sshfs and osxfuse
    - No longer needed, both are guaranteed to be available before mounting is possible

**Changes in 0.9.8**

- Bundle SSHFS 2.5.0 inside app

**Changes in 0.9.7**

- Fix for rsync refusing to accept ssh server fingerprints
    - This is a security vulnerability!
    - Needs to be fixed by SSH CA before post-beta use

**Changes in 0.9.6**

- Fix for group folder being missing at launch
- Guard against inability to open local database

**Changes in 0.9.5**

- Fix for autoscheduler time logic

**Changes in 0.9.4**

- Add automatic sync scheduler
    - Independent schedules for each sync folder
    - Allows for hourly, daily, weekly, monthly schedules

- Add UI for controlling sync schedules to sync manager
- Add display of last sync date to sync manager
- Converted large portions of the code to Swift
- Finder extension now shows status of sync folders in realtime

**Changes in 0.9.3**

- Whitelist specific error domains for telemetry API submission
    - Avoids submitting things like network timeouts or incorrect password warnings

**Changes in 0.9.2**

- Add clientVersion field to telemetry API reports
- Add fix for remote sync paths with non shell safe characters
- Disable debug logging in Finder extension for now
- Don't log account status/details at all inside the account loop

**Changes in 0.9.1**

- Fix rsync paths with whitespace
- Fix account switching issue
- Add support for dynamic reconfiguration of watched folders in Finder extension
- Use specific file badges for idle/sync/error states in Finder extension
- Don't report account status errors to the telemetry API
- Don't spam current account status & details to the telemetry API
- Fix [recently disclosed security issue](https://github.com/sparkle-project/Sparkle/releases/tag/1.13.1) in Sparkle update framework

**Changes in 0.9.0**

- Add folder sync system and management window
    - **NOTE**: This requires changes to individual SafeDrive account configuration before use!
    - Uses rsync under-the-hood
    - Ensures added sync directories don't conflict with existing parent/subdirectories
    - Click the circular "sync" button in a row to sync a folder
        - Sync is triggered manually in this build
        - Auto-scheduler being tested

- Includes libssh2 for custom SFTP commands
- Add support for SafeDrive telemetry API
    - Submits error reports with recent internal logs
    - Error messages are very "raw" right now, some are only intended for UI display
        - This will be improved with new builds once we start seeing real world error logs during testing

**Changes in 0.0.14**

- Fix uncaught exception in settings window on OS X < 10.10

**Changes in 0.0.13**

•Re-enable TLS and remove compile time App Transport Security exceptions

•Pass SDAPI failure responses up the stack to the UI when they're available

    - Otherwise directly pass the HTTP error up to the UI as it's all we have. 
    - This may need some localization and would be a good idea to report the error via in-app analytics

- Fix for issue with SSHFS
    - In certain cases, authentication could fail but the mount would still end up in the OSXFUSE mount table, so the system thought it was mounted and as a result, so did the app. This broke the UI, and we must remove it manually to keep things in a consistent state.

- Includes temporary settings UI with some pre-rendered elements
    - Some have known UI glitches (blurring, temporary placement for debugging)

**Changes in 0.0.12**

•Add Crashlytics support

**Changes in 0.0.11**

•Fix bug that used test credentials during mounts

•Ensure account window fields have placeholders when not filled in

- Catch mount errors containing SSHFS output "failed to mount"
- Ensure volume space meter resets when volume is not mounted
- Ensure custom volume names are used
- Reset volume name field in account window when not set

**Changes in 0.0.10**

•Fix bug preventing app from running on OS X 10.8/10.9

•Use OS X system package manager to detect OSXFUSE and SSHFS installations

**Changes in 0.0.9**

- Implement all current SD APIs under the hood
- Add self-update system for app (Sparkle framework)
    - Option to manually check for updates added to dropdown menu
    - 2nd launch will ask the user if they want to auto-update

- Implement multiple panels in preferences window
- Add account display to preferences area
    - Assigned storage
    - Used storage
    - Account expiration date
    - Status

- Add volume size and used space meter to preferences area
- Add preference for auto mounting SafeDrive at app launch
- Switch to **testing.safedrive.io** for API
    - **Note:** Using insecure HTTP on port 80 for now!!!
    - **App Transport Security** now has a temporary TLS exception for the testing domain _only_

- Display beta testing notes at launch

Bugfixes:

- Disable "next" button in connect screen while email or password field are empty
- Disable all fields on connect screen while a mount is in progress

Known Issues:

- Certain operations may pause longer than necessary, particularly while a mount is in progress
- Sync folder list is not enabled in UI yet
    - Will be turned on in 0.0.10

**Changes in 0.0.8**

- Add background service daemon

- Add automatic deployment/upgrade manager for background service daemon
- Add complete 3-way IPC system based on XPC
- Add typed, versioned IPC protocols (v4 in this build):

    - App -> Service
    - Finder -> Service
    - Finder -> App

- Display service status in preferences window
- Add Finder option to directly show preferences window in main app

Bugfixes:

- Don't force app to foreground on launch

**Changes in 0.0.7a**

- Deploy alpha of Finder extension
    - Support link in Finder menu bar works
    - Restore links in right-click menu aren't wired to IPC yet
    - Folder badges (colored dots) are just to make it obvious when extension is running

**Changes in 0.0.7**

- Switch to 93.113.136.95 server, add its host key fingerprints to the bundled known_hosts file
- Handle empty volume name field by using a default value of SafeDrive
- Assign the main apps code ID to the askpass binary to avoid unnecessary keychain prompts
- Codesign main app with both the ID & certificate chain (fixes some keychain issues, delete existing safedrive.io keychain items before testing!!!)
- Workaround for an OpenSSH bug that broke askpass unless X11 was available
- If app is run from a bad location, ask user if they want to automatically move it to /Applications
- Don’t print unhandled stderr output to the error field
- Detect if OSXFUSE or SSHFS aren't installed, show a helpful error
- Set the preferences and account window levels to be in front of the default level
- Prevent preference and account windows from being minimized or zoomed

**Changes in 0.0.6**

- Re-enable preferences option in dropdown
- Temporary preferences window with autostart and volume stats wired up
- Retrieve and display the actual error from keychain failures for now
- Add possible custom port option to SSHFS command options
- Remove error fade animations for now

**Changes in 0.0.5**

- Temporary dropdown menu item to show about window for testing purposes
- Use DCOAboutWindow to display a nice version of the credits and licenses
- Open Finder to the SafeDrive folder when a volume is mounted

**Changes in 0.0.4**

- Force app to foreground when error is displayed in login window
- Clear error display as soon as login button is pressed again
- Hopefully resolve all keychain errors
- Display an appropriate error to the user if the keychain causes an error
- Use 10.8+ compatible NSURL methods in SDMountController in test mode
- Disable some unnecessary logging

**Changes in 0.0.3**

- Add handler for "Not a directory" in SFTP stderr if volume doesn't exist

**Changes in 0.0.2**

- Replace fileURLWithFileSystemRepresentation: which is 10.9+ only

**Changes in 0.0.1a1**

- Make sure most notifications are posted on the main thread
- Only modify SDMountController's mountState property from the main thread
- Fix for 10.8/10.9: use -rangeOfString: instead of -containsString:
- Custom NSURL category for generating SSH URLs properly on 10.8+
- Custom 10.8+ compatible NSURL initializer for SSH scheme, with escaping for account, password, and volume name
- Add ecdsa and ed25519 host fingerprints for sd.infincia.com
