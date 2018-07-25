# Cyberchop 
## A Simple way to control your kids access to internet at home ![Say Thanks](https://img.shields.io/badge/Say%20Thanks-!-1EAEDB.svg)

#### Introduction
Cyberchop is a webapp designed to control the usage of internet of various devices your home via a single interface using a low end cheap linux devices like [Raspberry Pi](https://www.raspberrypi.org/) or [CHIP](https://getchip.com/) to manage kids online time. It can control the internet of devices in an OS agnostic way. 

The implementation is influenced by utilites like [netcut](http://www.arcai.com/netcut/) for Windows and [TuxCut](https://github.com/a-atalla/tuxcut) by @a-atalla for Linux. 

The goal of the project was to able to control both via bash shell as well as web. 

You can set up your hardware to be accessed from the internet via various methods for.e.g Wormhole feature in [Dataplicity](https://www.dataplicity.com/) for Raspberry Pi. But before exposing your device to public internet go read the internet for steps to harden your device defences. 

Any help in contributing to this project will be appreciated

* Development in bash shell & python
* Testing on various devices and reporting [issues](https://github.com/maharishi/cyberchop/issues/new?template=bug_report.md)
* Configuration best practices for lighttpd server
* Any recommended best practices for shell scripting, python, OS Hardening
* Setting up wikis & FAQs
* Donations for [coffee](http://paypal.me/Maharishi/1)

#### Installation

Installation is simple via bash terminal on target device

```bash
git clone https://github.com/maharishi/cyberchop.git

cd cyberchop

sudo chmod 750 *.sh

./setup.sh

./websetup.sh #if you want to control via a web view
```

#### Future Direction

Please go through the project feature [todo list](https://github.com/maharishi/cyberchop/projects/1#column-3059019) to get an idea what is planned for future. If there is anything that needs to be added, please add a [feature request](https://github.com/maharishi/cyberchop/issues/new?template=feature_request.md).

