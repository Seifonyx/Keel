# Testing Keel on your iPhone

CI checks that Keel compiles, that the update rules pass their unit tests, and that the .ipa is
Keel's (bundle id, name, version, `keel://` scheme). Everything below can only be checked on the phone.
Keep SideStore installed until step 5 works.

1. **Install.** In SideStore, add `https://github.com/Seifonyx/Keel/releases/download/keel-latest/keel-source.json`
   and install Keel. Home screen shows "Keel" with the hull icon. Inside, screens say Keel (not SideStore) and the
   sign-in and Settings screens are terracotta, not purple. Settings → App Icon offers Keel, Ink, Terracotta, Sea, Paper.
2. **Set up.** Open Keel, sign in, import the pairing file, turn the VPN on. Check refresh works:
   tap **Refresh All** in My Apps. Expiry dates move forward.
3. **Move Setpoint over.** In Keel → Sources, add Setpoint's source and install Setpoint.
   Check Setpoint opens and still has your data (the same bundle id should keep it, but this is the first real test).
4. **Auto-update screen.** My Apps → clock button. Switches show: Auto-update on, Only on Wi-Fi off, Also update Keel off.
5. **Update now.** Push a change to Setpoint and wait for its release. In Keel's Auto-update screen tap
   **Update apps now**. Setpoint updates, and "Updated Setpoint 0.1.x → 0.1.y" appears under Recent.
6. **Update link.** After the next Setpoint build, open `keel://update` in Safari. Keel opens and updates Setpoint.
7. **On open.** After another build, close Keel fully, open it, wait a minute: Setpoint updates (once per 10 minutes at most).
8. **Shortcut.** Set up the automation from the README. Run it once by hand from Shortcuts: Keel opens, and the
   Shortcut shows a short result ("Updated Setpoint." or "All apps are up to date.").
9. **Wi-Fi only.** Turn it on, switch Wi-Fi off, tap Update apps now: Recent says "Waiting for Wi-Fi." and nothing installs.
10. **Failure is safe.** Turn the VPN off and tap Update apps now: Recent says Keel isn't connected, Setpoint still opens.
11. **Background.** Leave Keel in the background overnight with background refresh on. Next day: apps are refreshed
    (dates moved) and any new Setpoint build is installed; a notification says what was updated.
12. **Refresh still works after a week.** The real test: after 7+ days nothing has expired.
13. Once 1–12 pass, delete SideStore.

If something fails, the Recent list on the Auto-update screen and Settings → Error Log show the reason.
