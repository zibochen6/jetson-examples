# Local Browser Agent on Jetson with Laya + Qwen

> Preview: the Docker build and full on-device acceptance are not yet complete.
> The launcher refuses to run without a verified image identity. Read
> [VALIDATION.md](VALIDATION.md) before trying this candidate.

Run local models on a reComputer Industrial J4012 / Orin NX 16GB to search real
Trip.com flights and edit a local whiteboard. The complete ARM64 Docker image
includes the application, CUDA Python environment, Chromium, both models and the
compiled llama.cpp server. No Python installation, compilation or model download
is performed on first application startup.

[简体中文](README.zh-CN.md) · [How the decision model works](https://wiki.seeedstudio.com/jetson/local_decision_model_laya/)
· [Application source](https://github.com/zibochen6/jetson-browser-assistant)

## Watch the existing demos

![Flight search: set conditions, inspect real candidates and open fare options](https://files.seeedstudio.com/wiki/Jetson/Application/jetson-laya-flight-search-demo.gif)

*Flight demonstration reused unchanged from the Seeed Wiki. One-way search,
nonstop filtering, price sorting and matching fare options. No order is submitted.*

![Whiteboard: create boxes and arrows, recolor Jetson and add Robot Arm on the same canvas](https://files.seeedstudio.com/wiki/Jetson/Application/jetson-laya-whiteboard-demo.gif)

*Whiteboard demonstration reused unchanged from the same Wiki. These animations
show existing application behavior; Docker acceptance is recorded separately in
[VALIDATION.md](VALIDATION.md). Asset URLs/checksums: [source resources](assets/source-resources.json).*

## Requirements

| Item | First release |
| --- | --- |
| Device | reComputer Industrial J4012 / Jetson Orin NX **16GB** |
| Host | JetPack 6.2 / **L4T 36.4.3**, ARM64 Linux |
| Desktop | Logged-in **X11** desktop and display; run as its normal user |
| Host tools | Docker, Docker Compose v2, NVIDIA Container Runtime, `xauth` |
| Network | Image pull on first deployment; Trip.com requires internet |
| Disk | Release-specific requirement in `release.json`; allow extra space for user records |

The host GPU driver is supplied through NVIDIA Runtime. Other JetPack releases,
8GB devices, Wayland and headless/SSH-forwarded displays are outside this release's
validation. Running from SSH is possible when it connects to the device's existing
X11 desktop; the browser still appears on the Jetson display.

## Install and run

Use a jetson-examples version containing this case. For an unreleased source checkout:

```bash
pip3 install .
reComputer run laya-browser check
reComputer run laya-browser
```

The launcher checks the host and display, pulls the tested image digest when
missing, validates its ARM64 content ID, and starts one container. Wait for
`Models ready` and `Task>`. The visible browser and read-only Live Flow appear on
the Jetson desktop. No automatic screen recording is started.

Paste a flight request with a **future** ISO date, for example:

```text
Find one-way flights from Shenzhen to Shanghai on 2026-12-15 for 1 adult in economy. Nonstop only, lowest price first. Show up to 3 options and open the fare options for one matching flight.
```

Check the route, date, nonstop condition, actual price sort and matching fare
options. Site prices, availability and verification prompts can change. Login or
CAPTCHA requires the user. The assistant never submits an order or payment.

After completing the task, enter `exit` at `Task>` to leave the terminal session.
Models/browser remain resident. To use the same models for the whiteboard:

```bash
reComputer run laya-browser whiteboard
```

On a blank board, paste:

```text
Draw three labeled boxes: Camera on the left, Jetson in the center, and Display on the right. Connect Camera to Jetson and Jetson to Display with arrows.
```

Then, without clearing/reopening the board:

```text
Make Jetson green. Add a box labeled Robot Arm below Jetson and connect Jetson to Robot Arm. Keep everything else.
```

The existing canvas is restored on later launches. Use its **Open scene** file
control to open an editable export. Clear/replace a board only deliberately.

## Controls and persistent data

| Action | Control |
| --- | --- |
| Cancel a running task | Ctrl+C; wait for the prompt to return |
| Leave the interactive session | `exit` / `quit` at `Task>` |
| Check services without loading models | `reComputer run laya-browser status` |
| Stop/remove only this case's container | `reComputer clean laya-browser` |
| Start again with saved data | `reComputer run laya-browser` |

Default runtime directory: `~/reComputer/laya-browser`. Set `JETSON_LAYA_HOME` to
another **absolute**, new/empty directory before the first launch, and use the same
value for subsequent commands. This directory is independent of any native
jetson-browser checkout and the installed Python package.

`persistent/` contains the browser profile, configuration overrides, logs,
flight `runs/` and `whiteboard-runs/`. Whiteboard exports include `.excalidraw`,
PNG and verification reports. Back up this directory; cleanup does not delete it
or the image. Model weights remain in the immutable image and are not copied to
the data volume. Do not edit the runtime's application/model symlinks.

One interactive session is allowed at a time. Finish/cancel a task and exit its
prompt before switching scenes. Restarting the container never replays an old task.
Status/check do not create model tasks. A healthy unchanged deployment is reused.
The example's internal control ports are not published on the host or LAN.

## Offline preparation and updates

On a machine that can pull ARM64 images, obtain the exact reference from `release.json`:

```bash
docker pull chenduola6/jetson-laya-browser:0.1.0-rc1-jp62-r36.4.3-arm64
docker save chenduola6/jetson-laya-browser:0.1.0-rc1-jp62-r36.4.3-arm64 -o laya-browser-image.tar
sha256sum laya-browser-image.tar
```

Transfer the archive, verify its checksum and use `docker load -i laya-browser-image.tar`.
The launcher checks the loaded image ID against the release manifest. Whiteboard
works without model/CDN access after import; the flight website still needs internet.

Upgrades are explicit: finish tasks, clean this example, update the case package,
then run again. Keep the previous image and a backup of `persistent/` to return to
a previous release. No automatic latest-image update is performed.

## Model roles and measured results

Qwen3.5-4B parses requests/generates text; Laya v19s selects among current legal
actions; Playwright executes; the program independently verifies actual results.
Laya receives text state/candidates, not screenshots. Site adapters, dates and
whiteboard layout are implemented in code. Model `DONE` does not prove completion.

Image download, model loading and input waiting are outside task timing. Parsing,
browser opening when required, inference, UI input, website waits, verification and
saving are included. Human waiting is also included and separately reported.
Historical native-demo timings are not Docker performance promises.

Project/application licenses and model/component notices remain with the image.
See [upstream third-party notices](https://github.com/zibochen6/jetson-browser-assistant/blob/main/THIRD_PARTY.md).
Please report the image digest, device/L4T version, error stage and sanitized logs
when requesting help. Do not upload browser profiles or personal task records.
