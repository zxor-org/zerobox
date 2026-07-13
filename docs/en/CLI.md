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
zerobox --nogui resource devices --source bandbbs
zerobox --nogui resource search calculator --source bandbbs --filter quickapp,free,bandbbs-category:101 --sort time
zerobox --nogui resource list --source astrobox-repo --filter quickapp,hide-paid,hide-force-paid,o65m
zerobox --nogui resource info bandbbs:6751
zerobox --nogui resource download bandbbs:6751
zerobox --nogui resource install bandbbs:6751
```

Resource lists and searches accept comma-separated filter chips through one `--filter` option:

- `quickapp`, `watchface`, `firmware`, or `miniprogram` selects one resource type
- `free` hides both paid and forced-paid resources
- `hide-paid` hides paid resources
- `hide-force-paid` hides forced-paid resources, primarily for AstroBox Repo
- Other values are treated as device or category IDs; multiple IDs can be selected in the same `--filter`

Device and category IDs are source-specific; list valid values with `resource devices --source SOURCE`

`--sort random|name|time` selects the sort order, while `--page N` and `--page-size N` control pagination

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
zerobox --nogui queue retry TASK_ID
zerobox --nogui queue start
zerobox --nogui queue pause
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

## Composable architecture

ZeroBox keeps its implementation inside an application host. GUI and CLI
clients depend only on the shared command interface.

- Linux, macOS, and Windows compose either `GUI → IPC → host` or
  `CLI → IPC → host`.
- Android and iOS compose `GUI → in-process host`, reusing the same device,
  account, resource, settings, and task implementations.
- Mobile task execution is protected by an Android foreground service or iOS
  system background task; interrupted running tasks resume as pending.
- The IPC server is a desktop adapter around the host and contains no separate
  application implementation.
- The host owns device connections, account sessions, resource access,
  operational settings, and persisted tasks.
- The GUI owns only presentation state such as themes, locale, window behavior,
  form input, and navigation.
- Device, account, and settings snapshots are resynchronized through events;
  the GUI reconnects automatically after a daemon restart.

## Desktop deployment

- The daemon is the only desktop process allowed to own Bluetooth transports
  and application state.
- GUI and CLI clients receive `device.state`, `account.state`,
  `settings.state`, and task events from the daemon.
- Device and task operations are serialized to prevent overlapping protocol
  requests.
- Detached CLI tasks and GUI downloads/installations are persisted by the
  daemon, including held, running, failed, cancelled states, and progress.
- Unix sockets live under `$XDG_RUNTIME_DIR/zerobox` on Linux. macOS uses its
  per-user or sandbox temporary directory to stay within the Unix socket path
  limit.
- Windows publishes a random loopback port and per-run authentication token in
  the user's local application-data directory. Clients verify the daemon and
  protocol version with an authenticated handshake before issuing commands.
