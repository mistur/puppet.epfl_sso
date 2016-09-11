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
  $needs_nscd = $::epfl_sso::params::needs_nscd
) inherits epfl_sso::params {
  if ( (versioncmp($::puppetversion, '3') < 0) or
       (versioncmp($::puppetversion, '4') > 0) ) {
    fail("Need version 3.x of Puppet.")
  }

  validate_string($allowed_users_and_groups)
  validate_bool($manage_nsswitch_netgroup)

  package { $epfl_sso::params::sssd_packages :
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

  if (! $::epfl_krb5_resolved) {
    fail("FATAL: fact 'epfl_krb5_resolved' is not working.")
  }
  if ($::epfl_krb5_resolved == "false") {
    fail("Unable to resolve KDC in DNS – You must use the EPFL DNS servers.")
  }

  if ($allowed_users_and_groups != undef) {
    class { 'epfl_sso::access':
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
  create_resources(pam, $pam_classes['auth'],
      {
        ensure    => present,
        type      => 'auth',
        control   => '[success=ok default=ignore]',
        module    => 'pam_sss.so',
        arguments => 'use_first_pass',
        position  => 'before *[type="auth" and module="pam_deny.so"]',
      })
  create_resources(pam, $pam_classes['account'],
      {
        ensure    => present,
        type      => 'account',
        control   => '[default=bad success=ok user_unknown=ignore]',
        module    => 'pam_sss.so',
        position  => 'before *[type="account" and module="pam_permit.so"]',
      })
  create_resources(pam, $pam_classes['password'],
      {
        ensure    => present,
        type      => 'password',
        control   => '[success=ok new_authtok_reqd=done default=ignore]',
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
    class { 'epfl_sso::mkhomedir': }
  }
}
