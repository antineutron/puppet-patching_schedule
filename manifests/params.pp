class patching_schedule::params (
  # Where to install the patching script (in a patching_schedule subdirectory)
  String[1] $install_dir = "/opt",

  # Should the machine automaticall schedule a reboot as needed?
  Boolean $do_reboot = false,

  # Day, hour and minute to apply patches, and splay in minutes to avoid simultaneous load
  Integer $patch_day  = 3,
  Integer $patch_hour = 17,
  Integer $patch_minute = 10,
  Integer $patch_splay = 10,

  # Day, hour and minute to reboot if needed, another splay setting to avoid the world collapsing
  Integer $reboot_day  = 4,
  Integer $reboot_hour = 8,
  Integer $reboot_minute = 10,
  Integer $reboot_splay = 10,
  Integer $reboot_delay = 5,
  String $reboot_message = "Applying security updates",

  # Email notification from and to address
  String $notification_email_from = "root",
  String $notification_email_to   = "root",

  # Should all available patches be applied, or just security updates?
  Boolean $security_only = false,

  # Run a command before rebooting - if the command is successful, reboot (e.g. ping another host)
  String $reboot_onlyif = "",

  # Write logs of patching/reboot scheduling here
  String[1] $logfile = "/var/log/autopatch.log",
){}
