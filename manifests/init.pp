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
  }

  # Mimic "authconfig --enablesssd --enablesssdauth --updateall" using
  # https://forge.puppetlabs.com/herculesteam/augeasproviders_pam
  # TODO: also support debian-style /etc/pam.d layout (common-{auth,account,password})
  create_resources(pam,
  {
    'sss auth in system-auth' => { service => 'system-auth'},
    'sss auth in password-auth' => { service => 'password-auth'}
  },
  {
    ensure    => present,
    type      => 'auth',
    control   => 'sufficient',
    module    => 'pam_sss.so',
    arguments => 'use_first_pass',
    position  => 'before *[type="auth" and module="pam_deny.so"]',
  })
  create_resources(pam,
  {
    'sss account in system-auth' => { service => 'system-auth'},
    'sss account in password-auth' => { service => 'password-auth'}
  },
  {
    ensure    => present,
    type      => 'account',
    control   => '[default=bad success=ok user_unknown=ignore]',
    module    => 'pam_sss.so',
    position  => 'before *[type="account" and module="pam_permit.so"]',
  })
  create_resources(pam,
  {
    'sss password in system-auth' => { service => 'system-auth'},
    'sss password in password-auth' => { service => 'password-auth'}
  },
  {
    ensure    => present,
    type      => 'password',
    control   => 'sufficient',
    module    => 'pam_sss.so',
    arguments => 'use_authtok',
    position  => 'before *[type="password" and module="pam_deny.so"]',
  })
  create_resources(pam,
  {
    'sss session in system-auth' => { service => 'system-auth'},
    'sss session in password-auth' => { service => 'password-auth'}
  },
  {
    ensure    => present,
    type      => 'session',
    control   => 'optional',
    module    => 'pam_sss.so',
  })

  # We could envision making the following optional, depending on a
  # class enable parameter:
  class { "epfl_sso::mkhomedir": }
}
