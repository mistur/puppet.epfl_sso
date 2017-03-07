# Class: epfl_sso::private::access
#
# This class enforces access control.
#
# === Parameters:
#
# $allowed_users_and_groups::  access.conf(5)-style ACL, e.g. "user1 user2 (group1) (group2)"
class epfl_sso::private::access(
  $allowed_users_and_groups = ''
  ) {
  file { '/etc/security/access.conf':
    ensure  => present,
    content => template('epfl_sso/access.conf.erb'),
    owner   => root,
    group   => root,
    mode    => '0644'
  }
  case $::osfamily {
    "Debian": {
      create_resources(pam,
      {
        'pam_access in common-account' => { service => 'common-account'},
      },
      {
        ensure    => present,
        type      => 'account',
        control   => 'requisite',
        module    => 'pam_access.so',
        position  => 'before *[type="account" and module="pam_unix.so"]',
        })
    }
    "RedHat": {
      create_resources(pam,
      {
        'pam_access in system-auth' => { service => 'system-auth'},
        'pam_access in password-auth' => { service => 'password-auth'}
      },
      {
        ensure    => present,
        type      => 'account',
        control   => 'requisite',
        module    => 'pam_access.so',
        position  => 'before *[type="account" and module="pam_unix.so"]',
        })
    }
    default: {
      fail("Not too sure how to set up pam on ${::osfamily}-like operating systems")
    }
  }
}
