#!/usr/bin/env bash

sudo mkdir /opt/android-sdk
sudo chown 1000:1000 /opt/android-sdk

sdkmanager --install "cmdline-tools;latest"
sdkmanager --install "build-tools;35.0.1"
sdkmanager --install "platforms;android-35"
sdkmanager --install "platform-tools;35.0.2"
yes y | sdkmanager --licenses
