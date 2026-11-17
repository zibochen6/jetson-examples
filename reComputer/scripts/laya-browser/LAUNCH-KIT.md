# Overseas developer launch kit

Status: review drafts. Publish only after the image and case validation are complete.
Primary goal: developers run a real task on their own Orin NX16GB. All channels
link to the case README; its primary action is `reComputer run laya-browser`.

## Reuse the Wiki media

Use the original files unchanged, in this order:

1. [Flight animation](https://files.seeedstudio.com/wiki/Jetson/Application/jetson-laya-flight-search-demo.gif)
2. [Whiteboard animation](https://files.seeedstudio.com/wiki/Jetson/Application/jetson-laya-whiteboard-demo.gif)

Credit: Seeed Studio Wiki, “Local Browser Agent on Jetson Orin”.
Record file URLs/hashes in `assets/source-resources.json`. The animations show the
existing application; Docker validation comes from VALIDATION.md. The Wiki's
32.8-second historical task must not be relabeled as a Docker measurement. The
original flight animation contains a burned-in “books flight tickets” caption;
its actual scope is searching and opening fare options, with no order/payment.
The separate video compilation uses corrected captions and an explicit source label.

Existing optional artwork:

- [Cover](https://files.seeedstudio.com/wiki/Jetson/Application/jetson-laya-cover-en-v3-dark.png)
- [Execution and verification diagram](https://files.seeedstudio.com/wiki/Jetson/Application/jetson-laya-verified-action-loop-en.png)

For channels requiring video, use the original recording behind the Wiki animation
if available. A GIF-to-MP4 conversion is a reused demo clip, not a new recording;
keep its original timing and label the source. Publish the original GIF directly
on GitHub/Wiki. New recording is not a prerequisite for reusing these assets.

## LinkedIn draft

Your Jetson can run a local agent that searches real flights and edits a whiteboard.

This example pairs Laya, which selects among available actions, with Qwen3.5-4B,
which parses requests and generates text. Playwright performs the inputs, and the
application checks the actual route, date and fare options before reporting success.

The Docker image includes both models, Chromium and the CUDA runtime dependencies.
On a supported reComputer Industrial J4012 / Orin NX16GB with an X11 desktop, start with:

`reComputer run laya-browser`

The first demo searches Trip.com. The second changes boxes, colors and connections
on the same local whiteboard. Model inference runs on the device; flight search
uses the live website. This release covers bounded workflows and does not submit orders.

Try the case and tell us which device/software version you used and whether your
first task completed. Setup and validation: https://github.com/zibochen6/jetson-examples/tree/codex/laya-browser-docker/reComputer/scripts/laya-browser

Attach the flight animation; follow up with the whiteboard animation on a later day.

## YouTube title and description draft

Title: Local Browser Agent on Jetson | Laya + Qwen in Docker

Description:

Run local models on reComputer Industrial J4012 / Jetson Orin NX16GB to operate
Trip.com and edit a local whiteboard. The complete Docker image includes the
application, pinned Laya/Qwen weights, Chromium and CUDA dependencies.

Qwen parses the request. Laya selects a legal action. Playwright executes it. The
program independently verifies the result. No order or payment is submitted.

Requirements: Orin NX16GB, L4T36.4.3, Docker with NVIDIA Runtime and a logged-in
X11 desktop. Image download and model loading are separate from task execution.

Run: `reComputer run laya-browser`

Setup and Docker validation: https://github.com/zibochen6/jetson-examples/tree/codex/laya-browser-docker/reComputer/scripts/laya-browser
Source: https://github.com/zibochen6/jetson-browser-assistant
Wiki: https://wiki.seeedstudio.com/jetson/local_decision_model_laya/

This clip reuses the original Wiki demonstrations. It is not a new Docker benchmark; task duration varies. Flight searches require internet; the installed whiteboard is local.

## Discord / forum pilot invitation

We have a Docker-packaged local browser agent for Orin NX16GB ready for developer
testing. It combines Laya action selection, Qwen request parsing, a real Chromium
browser and independent result checks. Both models are included in the image.

Try a future-date Trip.com flight search, or create and modify a small whiteboard:
`reComputer run laya-browser` / `reComputer run laya-browser whiteboard`.

Please include your device, L4T version, image digest, setup stage and task outcome
in your feedback. Share sanitized logs only. Setup/validation: https://github.com/zibochen6/jetson-examples/tree/codex/laya-browser-docker/reComputer/scripts/laya-browser

## Release sequence and review

- Day0, after validation: image + case README + Wiki update; publish the main demonstration.
- Day2: LinkedIn flight animation and setup link.
- Day4: community pilot invitation and whiteboard follow-up.
- Day7: collect first-install issues and update troubleshooting.
- Day14: report available channel visits and at least three external reproduction outcomes as the pilot target.

Do not infer installations from image pulls or repository stars. Keep a voluntary
feedback table with device/software, image digest, first-start result, task result
and blocker. No runtime telemetry or paid advertising is added by this example.
