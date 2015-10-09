# A simple module to automatically apply patches on a weekly basis,
# optionally rebooting the machine afterwards during a separate downtime period.

class patching_schedule (
  # Where to install the patching script (in a patching_schedule subdirectory)
  String[1] $install_dir = $patching_schedule::params::install_dir,

  # Should the machine automaticall schedule a reboot as needed?
  Boolean $do_reboot = $patching_schedule::params::do_reboot,

  # Day, hour and minute to apply patches, and splay in minutes to avoid simultaneous load
  Integer $patch_day  = $patching_schedule::params::patch_day ,
  Integer $patch_hour = $patching_schedule::params::patch_hour,
  Integer $patch_minute = $patching_schedule::params::patch_minute,
  Integer $patch_splay = $patching_schedule::params::patch_splay,

  # Day, hour and minute to reboot if needed, another splay setting to avoid the world collapsing
  Integer $reboot_day  = $patching_schedule::params::reboot_day ,
  Integer $reboot_hour = $patching_schedule::params::reboot_hour,
  Integer $reboot_minute = $patching_schedule::params::reboot_minute,
  Integer $reboot_splay = $patching_schedule::params::reboot_splay,
  Integer $reboot_delay = $patching_schedule::params::reboot_delay,
  String $reboot_message = $patching_schedule::params::reboot_message,

  # Email notification from and to address
  String $notification_email_from = $patching_schedule::params::notification_email_from,
  Array[String] $notification_email_to   = $patching_schedule::params::notification_email_to  ,

  # Should all available patches be applied, or just security updates?
  Boolean $security_only = $patching_schedule::params::security_only,

  # Run a command before rebooting - if the command is successful, reboot (e.g. ping another host)
  String $reboot_onlyif = $patching_schedule::params::reboot_onlyif,

  # Write logs of patching/reboot scheduling here
  String[1] $logfile = $patching_schedule::params::logfile,
) inherits patching_schedule::params {

  # Implement splay - add a random (but per-host consistent) extra delay to the patching and rebooting times
  $real_patch_minute = $patch_minute + fqdn_rand($patch_splay)
  $real_reboot_minute = $reboot_minute + fqdn_rand($reboot_splay)

  # The script wants the reboot time as a string  
  $reboot_at = "$reboot_day $reboot_hour $real_reboot_minute"

  ensure_resource('file', [$install_dir], {ensure => directory})
  file {["${install_dir}/patching_schedule", "${install_dir}/patching_schedule/sbin", "${install_dir}/patching_schedule/etc"]:
	ensure => directory,
	owner => root,
	group => root,
  }

  # Install script and templated config file
  file{"${install_dir}/patching_schedule/etc/autopatch.conf":
    ensure => present,
    content => template("patching_schedule/autopatch.conf.erb"),
  }

  file{"${install_dir}/patching_schedule/sbin/autopatch":
    ensure => present,
    source => "puppet:///modules/patching_schedule/autopatch.sh",
    owner  => "root",
    group  => "root",
    mode   => "0700",
    require => File["${install_dir}/patching_schedule/etc/autopatch.conf"],
  }
  
  # Install the cron job that applies patches
  cron{ "patching_schedule":
    user => root,
    command => "${install_dir}/patching_schedule/sbin/autopatch",
    day => $patch_day,
    hour => $patch_hour,
    minute => $real_patch_minute,
    require => File["${install_dir}/patching_schedule/sbin/autopatch"],
  }
  
  # Ensure the log gets rotated, and keep a reasonable number of them
  logrotate::rule { 'patching_schedule':
    path         => $logfile,
    rotate       => 20,
    rotate_every => 'week',
    require => File["${install_dir}/patching_schedule/sbin/autopatch"],
  }

}
