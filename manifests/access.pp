# Class: epfl_sso::access
#
# This class enforces access control.
#
# === Parameters:
#
# $allowed_users_and_groups::  access.conf(5)-style ACL, e.g. "user1 user2 (group1) (group2)"
class epfl_sso::access(
  $allowed_users_and_groups = ''
  ) {
  file { "/etc/security/access.conf":
    ensure => present,
    content => template("epfl_sso/access.conf.erb"),
    owner => root,
    group => root,
    mode  => 644
  }
  # TODO: also support debian-style /etc/pam.d layout (common-{auth,account,password})
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
