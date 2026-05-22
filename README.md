# benkesmith-digital-handwriting

[![Apache 2.0 License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

A Cordova plugin that performs **offline handwriting recognition** by processing stroke coordinates (`x`, `y`, and time vectors) directly on-device. Powered by **Google ML Kit Digital Ink Recognition** on Android. Works on both **Android** and **iOS**.

## Features

- **True Stroke-Based Recognition:** Analyzes pen tracking paths/coordinates instead of static images for higher accuracy and speed.
- **On-Device Offline Processing:** Recognition runs completely local to the device without requiring cloud API connections.
- **Automatic Language Pack Download:** Dynamically fetches the required language models (~20MB) directly upon first usage.

## Installation

```bash
cordova plugin add https://github.com/ragcsalo/benkesmith-digital-handwriting.git

