# coding: utf-8
# Class: epfl_sso
#
# This class describes integrating a Linux computer into the EPFL
# directory services (LDAP and Kerberos)
#
# === Parameters:
#
# $allowed_users_and_groups::  access.conf(5)-style ACL, e.g.
#                              "user1 user2 (group1) (group2)"
#                              Note: if you run gdm, user gdm must have access
# $manage_nsswitch_netgroup::  Whether to manage the netgroup entry in nsswitch.conf
# $enable_mkhomedir::          Whether to automatically create users' home
#                              directories upon first login
# $needs_nscd::                Whether to install nscd to serve as a second
#                              layer of cache (for old distros with slow sssd)
# $pam_success_actions::       What to use as the [success= ] stanza, keyed
#                              by PAM stage ("auth", "account", "session" or
#                              "password")

class epfl_sso(
  $allowed_users_and_groups = undef,
  $manage_nsswitch_netgroup = true,
  $enable_mkhomedir = true,
  $needs_nscd = $::epfl_sso::private::params::needs_nscd,
  $pam_success_actions = $::epfl_sso::private::params::pam_success_actions
) inherits epfl_sso::private::params {
  ensure_resource('class', 'quirks')

  if ( (versioncmp($::puppetversion, '3') < 0) or
       (versioncmp($::puppetversion, '4') > 0) ) {
    fail("Need version 3.x of Puppet.")
  }

  validate_string($allowed_users_and_groups)
  validate_bool($manage_nsswitch_netgroup)

  package { $epfl_sso::private::params::sssd_packages :
    ensure => present
  } ->
  file { '/etc/sssd/sssd.conf' :
    ensure  => present,
    content => template('epfl_sso/sssd.conf.erb'),
    owner   => root,
    group   => root,
    mode    => '0600'
  } ~>
  service { 'sssd':
    ensure => running,
    enable => true
  }

  include epfl_sso::private::pam
  epfl_sso::private::pam::module { "sss": }

  if ($needs_nscd) {
    package { "nscd":
      ensure => present
    }
  }

  # A properly configured clock is necessary for Kerberos:
  ensure_resource('class', 'ntp')

  # When a user tries to ssh into a machine that doesn't have their shell,
  # figuring it all out from the logs is quite a challenge.
  # Note: EPFL's default shell can be changed here:
  #       https://cadiwww.epfl.ch/cgi-bin/accountprefs/
  # As of Feb, 2017 the options are
  # 
  # /bin/sh
  # /bin/bash
  # /bin/tcsh
  # /bin/zsh
  # /bin/csh
  # /bin/bash2
  # /bin/ash
  # /bin/bsh
  # /sbin/nologin                

  # This seems to be the lowest common denominator across distributions:
  ensure_packages(['tcsh', 'zsh', 'bsh'])
  case $::osfamily {
    "Debian": {
      ensure_packages(['ash', 'csh'])  # In addition to above
    }
    "RedHat": {
      package { "ash":
        provider => "rpm",
        source => "http://ftp.uni-erlangen.de/mirrors/opensuse/distribution/11.4/repo/oss/suse/x86_64/ash-1.6.1-146.2.x86_64.rpm"
      }
      file { "/bin/csh":
        ensure => "link",
        target => "tcsh"
      }
    }
  }

  if ($allowed_users_and_groups != undef) {
    class { 'epfl_sso::private::access':
      allowed_users_and_groups => $allowed_users_and_groups
    }
  }

  name_service {['passwd', 'group']:
    lookup => ['compat', 'sss']
  }

  # This is necessary for RH7 and CentOS 7, and probably
  # does not hurt for older versions:
  name_service { 'initgroups':
    # https://bugzilla.redhat.com/show_bug.cgi?id=751450
    lookup => ['files [SUCCESS=continue] sss']
  }

  if ($manage_nsswitch_netgroup) {
    name_service { 'netgroup':
      lookup => ['files', 'sss']
    }
  }

  if ($enable_mkhomedir) {
    class { 'epfl_sso::private::mkhomedir': }
  }

  epfl_sso::private::pam::module { "winbind":
    ensure => "absent"
  }
  #
  # Show manual login in latest ubuntu in case where the display manager is lightDM
  #
  case $::osfamily {
    'Debian': {
      if ($::operatingsystemrelease in ['15.04', '15.10', '16.04', '16.10'] and $::operatingsystem == 'Ubuntu') {
        if (str2bool($::is_lightdm_active)) {
          file { "/etc/lightdm/lightdm.conf.d" :
            ensure => directory
          }
          file { "/etc/lightdm/lightdm.conf.d/50-show-manual-login.conf" :
            content => inline_template("#
# Managed by Puppet, DO NOT EDIT
# /etc/puppet/modules/epfl_sso/manifests/init.pp
#
[Seat:*]
greeter-show-manual-login=true
")
          }~>service { "lightdm" :
            ensure => running # Restart lightdm if the 50-show-manual-login.conf file changes
          }
        }
      } else {
        notify {"Enabling the manual greeter on version $::operatingsystemrelease of Ubuntu is not supported. Please check https://github.com/epfl-sti/puppet.epfl_sso":}
      }
    }
  }
}
