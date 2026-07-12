# ZeroBox CLI and daemon

ZeroBox exposes its desktop automation surface through `--nogui`. The desktop
daemon owns Bluetooth connections and task state; short-lived CLI processes
connect over a per-user Unix socket on Linux/macOS or loopback IPC on Windows.
The desktop GUI uses the same daemon connection and never opens a second
Bluetooth transport.

## Start and inspect the daemon

```sh
zerobox --nogui daemon start
zerobox --nogui daemon status
zerobox --nogui daemon stop
```

Commands automatically start the daemon unless `--no-autostart` is supplied.
The current Flutter Bluetooth plugins still require a logged-in desktop session
on Linux; `--nogui` suppresses the window but does not support an SSH session
without a display server.

## Devices and local installation

```sh
zerobox --nogui device paired
zerobox --nogui device scan --timeout 10
zerobox --nogui device connect AA:BB:CC:DD:EE:FF
zerobox --nogui device info
zerobox --nogui install quickapp ./demo.rpk
zerobox --nogui install watchface ./face.mwz --device AA:BB:CC:DD:EE:FF
```

Use `--detach` to enqueue an installation and return its task ID immediately.
Add `--wait` to wait for that persistent task and return an exit code based on
its final result.

## Resources

```sh
zerobox --nogui resource sources
zerobox --nogui resource search calculator --source bandbbs --type quickapp
zerobox --nogui resource info bandbbs:6751
zerobox --nogui resource download bandbbs:6751
zerobox --nogui resource install bandbbs:6751
```

## Device content, accounts and settings

```sh
zerobox --nogui app list
zerobox --nogui app launch com.example.app
zerobox --nogui app uninstall com.example.app
zerobox --nogui watchface list
zerobox --nogui watchface set FACE_ID
zerobox --nogui watchface remove FACE_ID
zerobox --nogui account list
zerobox --nogui account login amazfit --username user@example.com
zerobox --nogui account logout bandbbs
zerobox --nogui settings list
zerobox --nogui settings set auto_reconnect true
```

Use `--password-stdin` for non-interactive account login. Passwords are not
accepted as command-line options.

## Queue, logs and machine output

```sh
zerobox --nogui queue list
zerobox --nogui queue get TASK_ID
zerobox --nogui queue wait TASK_ID
zerobox --nogui queue watch
zerobox --nogui queue cancel TASK_ID
zerobox --nogui queue remove TASK_ID
zerobox --nogui logs watch
zerobox --nogui --json device status
```

`--json` emits a JSON result and JSONL progress/events. CLI exit codes are:

| Code | Meaning |
| ---: | --- |
| 0 | Success |
| 2 | Invalid usage |
| 3 | File error |
| 4 | No suitable device |
| 5 | Connection failure |
| 6 | Resource validation failure |
| 7 | Installation failure |
| 8 | Daemon failure |
| 70 | Internal error |

## Mobile execution

Android and iOS do not start a desktop-style daemon. They execute the same
device core in-process. Android installation queues are protected by a
foreground data-sync service. iOS uses a finite system background task. Mobile
task metadata is persisted; an operation interrupted by process suspension is
restored as pending so the user can resume it. The shared command protocol does
not depend on desktop IPC.

## Desktop architecture

- The daemon is the only desktop process allowed to own Bluetooth transports.
- GUI and CLI clients receive `device.state` snapshots from the daemon.
- Device operations are serialized to prevent overlapping protocol requests.
- Detached and GUI installation tasks are persisted by the daemon, including
  status and progress.
- Unix sockets live under `$XDG_RUNTIME_DIR/zerobox` on Linux and the user
  Application Support directory on macOS, with a compatibility fallback for
  the former `/tmp` endpoint during upgrades.
- Windows publishes a random loopback port and per-run authentication token in
  the user's local application-data directory. Clients verify the daemon and
  protocol version with an authenticated handshake before issuing commands.
