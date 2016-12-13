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
class epfl_sso(
  $allowed_users_and_groups = undef,
  $manage_nsswitch_netgroup = true,
  $enable_mkhomedir = true,
  $needs_nscd = $::epfl_sso::private::params::needs_nscd
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
  ensure_resource('package', ['tcsh', 'zsh', 'ash', 'bsh', 'csh'])

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

  # Mimic "authconfig --enablesssd --enablesssdauth --updateall" using
  # https://forge.puppetlabs.com/herculesteam/augeasproviders_pam
  case $::osfamily {
    'RedHat': {
        $pam_classes = {
               'auth' =>  {
                   'sss auth in system-auth' => { service => 'system-auth'},
                   'sss auth in password-auth' => { service => 'password-auth'}
               },
               'account' =>  {
                   'sss account in system-auth' => { service => 'system-auth'},
                   'sss account in password-auth' => { service => 'password-auth'}
               },
               'password' =>  {
                   'sss password in system-auth' => { service => 'system-auth'},
                   'sss password in password-auth' => { service => 'password-auth'}
               },
               'session' =>  {
                   'sss session in system-auth' => { service => 'system-auth'},
                   'sss session in password-auth' => { service => 'password-auth'}
               },
        }
        $shoot_winbind_in = {}
     }
     'Debian': {
        $pam_classes = {
               'auth' =>  {
                   'sss auth in common-auth' => { service => 'common-auth'},
               },
               'account' =>  {
                   'sss account in common-account' => { service => 'common-account'}
               },
               'password' =>  {
                   'sss password in common-password' => { service => 'common-password'}
               },
               'session' =>  {
                   'sss session in common-session' => { service => 'common-session'},
                   'sss session in common-session-noninteractive' => { service => 'common-session-noninteractive'}
               },
        }
        $shoot_winbind_in = {
          'no winbind in common-auth' => {
            service => 'common-auth',
            type => 'auth',
          },
          'no winbind in common-account' => {
            service => 'common-acount',
            type => 'account',
          },
          'no winbind in common-password' => {
            service => 'common-password',
            type => 'password',
          },
          'no winbind in common-session' => {
            service => 'common-session',
            type => 'session',
          },
          'no winbind in common-session-noninteractive' => {
            service => 'common-session-noninteractive',
            type => 'session',
          }
        }

    }
  }
  # Some versions of Ubuntu use pam_deny as a catch-all blocker, and
  # successful authentication operations need to jump over it:
  $success_action = $::uses_pam_deny ? {
    "true" => "1",  # There is no such thing as a Boolean fact
    default => "ok"
  }
  create_resources(pam, $pam_classes['auth'],
      {
        ensure    => present,
        type      => 'auth',
        control   => "[success=${success_action} default=ignore]",
        module    => 'pam_sss.so',
        arguments => 'use_first_pass',
        position  => 'before *[type="auth" and module="pam_deny.so"]',
      })
  create_resources(pam, $pam_classes['account'],
      {
        ensure    => present,
        type      => 'account',
        control   => "[default=bad success=${success_action} user_unknown=ignore]",
        module    => 'pam_sss.so',
        position  => 'before *[type="account" and module="pam_permit.so"]',
      })
  create_resources(pam, $pam_classes['password'],
      {
        ensure    => present,
        type      => 'password',
        control   => "[success=${success_action} new_authtok_reqd=done default=ignore]",
        module    => 'pam_sss.so',
        arguments => 'use_authtok',
        position  => 'before *[type="password" and module="pam_deny.so"]',
      })
  create_resources(pam, $pam_classes['session'],
      {
        ensure    => present,
        type      => 'session',
        control   => 'optional',
        module    => 'pam_sss.so',
      })

  create_resources(pam, $shoot_winbind_in,
      {
        ensure    => absent,
        module    => 'pam_winbind.so',
      })

  if ($enable_mkhomedir) {
    class { 'epfl_sso::private::mkhomedir': }
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
        } else {
          notify {"LightDM is not the default display manager, nothing changed.":}
        }
      } else {
        notify {"Enabling the manual greeter on version $::operatingsystemrelease of Ubuntu is not supported. Please check https://github.com/epfl-sti/puppet.epfl_sso":}
      }
    }
  }
}
