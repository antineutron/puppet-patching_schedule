# patching_schedule

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with patching_schedule](#setup)
    * [What patching_schedule affects](#what-patching_schedule-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with patching_schedule](#beginning-with-patching_schedule)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview

A module to deploy a simple patching script, designed to patch a system once
per week and optionally reboot the system if necessary at a later date.

## Module Description

Supports:

* Apt and Yum package managers (tested on RHEL and Ubuntu)
* Full patching and security-updates-only patching
* Scheduled reboots during at-risk periods only when needed
* (Simplistic) splay of patch and reboot times, to avoid clashes
* Skip reboot based on a command (e.g. don't reboot one DHCP server if all the others are unpingable!)

## Setup

### What patching_schedule affects

* The module installs a patching script and config file into an install directory, usually /opt/patching_schedule
* A cron job is used to schedule the patch time; the script itself uses at to schedule a reboot if needed
* All output is logged to a file, and logrotate is configured to rotate the log

### Setup Requirements **OPTIONAL**

The [logrotate](https://forge.puppetlabs.com/rodjek/logrotate) module is required.

### Beginning with patching_schedule

Defaults: patch weekly on a Wednesday evening, do not auto-reboot:

    include patching_schedule

Patch at exactly 8.05AM on a monday, reboot sometime between 12.12PM and 12.22PM on a tuesday:
    
    class { 'patching_schedule':
      do_reboot => true,
      patch_day => 1,
      patch_hour => 8,
      patch_minute => 5,
      patch_splay => 0,
      reboot_day => 1,
      reboot_hour => 12,
      reboot_minute => 12,
      reboot_splay => 10,
    }

Only include security updates, and auto-reboot if needed (default: apply all available updates, do not auto-reboot):
    class { 'patching_schedule':
      do_reboot => true,
      security_only => true,
    }

## Limitations

Works on RHEL5/6, Ubuntu 12.04/14.04. Should probably work on anything RHEL-ish or Debian-ish but no promises.

