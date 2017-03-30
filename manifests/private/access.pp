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
  include epfl_sso::private::pam
  epfl_sso::private::pam::module { "access": }
}
