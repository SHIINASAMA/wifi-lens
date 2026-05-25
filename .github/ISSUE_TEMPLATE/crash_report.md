---
name: Crash report
about: WiFi Lens quit unexpectedly
title: ''
labels: crash
assignees: ''
---

**What were you doing when it crashed?**
<!-- e.g. "Had the spectrum view open for 10 minutes", "Just clicked Export PNG" -->

**Can you reproduce it?**
<!-- Does it happen every time you do the same thing, or was it a one-off? -->

**Environment**
- macOS version: <!-- e.g. 15.4 -->
- Mac model:
- WiFi Lens version: <!-- "About WiFi Lens" in the menu bar -->
- Installation: <!-- GitHub Release / built from source -->

**Crash log**
WiFi Lens writes crash reports to `~/Library/Logs/DiagnosticReports/`. Look for a file starting with `WiFi Lens` and ending with `.ips` or `.crash`, with a timestamp matching when the crash happened.

Drag and drop the crash log file here, or paste its contents.
If you are using the App Store version, the file name may start with `WiFi Lens PRO`.

**Console output (optional)**
If the crash is reproducible, launch WiFi Lens from Terminal and attach any output:
```sh
/Applications/WiFi\ Lens.app/Contents/MacOS/WiFi\ Lens
```
