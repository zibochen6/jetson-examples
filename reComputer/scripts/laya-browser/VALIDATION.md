# Docker acceptance

This file records the new Docker delivery separately from the original native
application demonstrations. The Wiki animations are reused unchanged and are not
evidence that this Docker image has passed end-to-end acceptance.

Current state: candidate build submitted; target connection must be restored to
inspect completion and perform full image/task acceptance. See
`release.json` for the fixed image content and validation state. Do not describe
this candidate as a production-tested image until the results below are recorded.

## Recorded checks — 2026-11-17

| Check | Observed result |
| --- | --- |
| Application model-free suite on the target source checkout | **108 passed in 48.57s** |
| Application GitHub CI | Passed; [draft application PR](https://github.com/zibochen6/jetson-browser-assistant/pull/1) |
| Case launcher tests | **7 passed** locally |
| Package contents | Wheel and sdist contain launcher, configuration, English/Chinese docs and source-resource manifest |
| Installed case discovery and status | Passed from `/tmp` in an isolated Jetson environment; no model loaded and no application data created |
| NVIDIA base image, ordinary UID, read-only root | `cuInit=0`, `cuDeviceGetCount=0`, one GPU detected |
| Complete application image | Last observed compiling the CUDA llama.cpp server; completion not yet inspected |
| Docker model inference, desktop and business tasks | **Pending**, not substituted with native history or animations |

The base CUDA check does not establish PyTorch/model/browser success. Dependencies
were installed successfully during the complete-image build, and the source
weights were staged after size/SHA verification. The target became unreachable
after the development computer changed networks. No kernel/device failure has
been established. No finished image digest, public push or offline image archive
is claimed.

## Resume after connectivity is restored

1. Inspect the existing build log and Docker process/image state before starting
   another build; the remote job may have continued after the connection loss.
2. Complete the fixed source build if necessary. Run real CUDA, model, desktop,
   flight, whiteboard and lifecycle checks below.
3. Push only the accepted candidate image, use `docker/release_manifest.py` in the
   application repository to record its exact ID/digest, and update this report.
4. Rebuild/reinstall the final case package; remove the preview guard text only
   when the corresponding acceptance evidence exists.

## Required target checks

- ARM64 image includes pinned weights, Chromium and compiled CUDA llama.cpp.
- New data directory and image-only first start; no host Python/model dependency.
- Real CUDA calculation, Qwen inference and Laya decision on the Jetson.
- Native X11 browser display, model session and read-only Live Flow.
- Real flight queries/fare verification, same-canvas whiteboard edits and exports.
- Cancel, terminal exit, container restart, clean/recreate and data retention.
- Imported image works without model/CDN downloads; flight network remains required.
- Preserve image digest, source revision, device versions, timings and failures.
