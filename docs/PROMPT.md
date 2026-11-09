# Doing this with an AI coding agent

Agents like Claude Code are good at this: they can read `dumpsys` output, look up unfamiliar package names, and drive the TV's menus with screenshots. Give the agent this repo as context and a prompt along these lines:

```text
My Android TV is slow and full of ads. It's on my local network and I've enabled
USB debugging. Help me debloat it using the method in this repo.

Rules:
- Find the TV yourself (mDNS / adb), connect, and wait for me to accept the
  debugging prompt on the TV.
- Diagnose first: memory, CPU, storage, biggest processes. Tell me what you find
  before changing anything.
- Snapshot the current state and keep an undo path for every change.
- Only use `pm disable-user --user 0`, never uninstall system packages.
- Don't touch inputs/tuner, Play Services, system UI, settings, voice search,
  casting, or the manufacturer's update service.
- Show me the list of packages before disabling, and ask about anything I might use.
- Flush state (`cmd appops write-settings`, wait ~20s) before any reboot, then
  reboot and verify the changes persisted.
- When replacing the launcher, install the new one first.
- Tell me what can't be done instead of guessing.
```

Tips:

- Share the TV's model and `pm list packages` output early. Agents give much better answers with the real package list than with generic debloat lists.
- Ask for screenshots when it drives on-screen menus, so you can see what it's pressing.
- Turn USB debugging off on the TV when you're done.
