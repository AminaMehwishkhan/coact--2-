---
title: CoAct
emoji: 🤖
colorFrom: blue
colorTo: purple
sdk: docker
app_port: 7860
pinned: false
license: mit
---

# CoAct — Consensus-Gated Bimanual Manipulation

Two SO-ARM100 arms watch a shared table from opposite sides. Each grounds a spoken
instruction in its own camera image. Nothing moves until both independently localise the
same physical object.

This Space runs the full system: MuJoCo physics, both agent cameras rendered live through
EGL, detection from those pixels, and OpenVINO-backed scoring. The camera panels show what
each agent actually sees.

Source and benchmark: https://github.com/AminaMehwishkhan/coact--1-

Free CPU hardware renders at a few frames per second, so the arms move slowly. The recorded
episode on the page is the same system running at full speed.
