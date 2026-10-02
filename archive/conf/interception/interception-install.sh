#!/bin/sh

sudo apt install -y libudev-dev libyaml-cpp-dev
git clone https://gitlab.com/interception/linux/tools.git interception-tools
cd interception-tools
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
cd build && sudo make install
cd ../.. && rm -rf interception-tools

git clone https://gitlab.com/interception/linux/plugins/caps2esc.git
cd caps2esc
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
cd build && sudo make install
cd ../.. && rm -rf caps2esc

git clone https://gitlab.com/oarmstrong/ralt2hyper
cd ralt2hyper
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
cd build && sudo make install
cd ../.. && rm -rf ralt2hyper

sudo mkdir -p /etc/interception
sudo cp ../udevmon.yaml /etc/interception/udevmon.yaml
sudo cp udevmon.service /lib/systemd/system/
sudo systemctl enable --now udevmon.service
