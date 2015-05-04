# Class: epfl_sso
#
# This class describes integrating a Linux computer into the EPFL directory services (LDAP and Kerberos)
class epfl_sso() {
  package { ["sssd", "sssd-ldap"] :
    ensure => present
  } ->
  file { "/etc/sssd/sssd.conf" :
    ensure => present,
    content => template("epfl_sso/sssd.conf.erb"),
    mode  => 600
  } ->
  service { "sssd":
    ensure => running
  }

  class { 'nsswitch':
    passwd => ['compat', 'sss'],
    group => ['compat', 'sss'],
    netgroup => ['files', 'sss'],
    sudoers => ['files', 'sss']
  }
}
