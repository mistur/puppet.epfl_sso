# Class: epfl_sso::mkhomedir
#
# Automatically create home directories upon login of a new user
class epfl_sso::mkhomedir() {
  # RedHat-only
  package { 'oddjob-mkhomedir' :
    ensure => present
  }

  # Mimic "authconfig --enablemkhomedir"
  # TODO: also support debian-style /etc/pam.d layout (common-{auth,account,password})
  create_resources(pam,
  {
    'mkhomedir session in system-auth' => { service => 'system-auth'},
    'mkhomedir session in password-auth' => { service => 'password-auth'}
  },
  {
    ensure    => present,
    type      => 'session',
    control   => 'optional',
    module    => 'pam_mkhomedir.so',
  })
}
