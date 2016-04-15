# Class: epfl_sso::mkhomedir
#
# Automatically create home directories upon login of a new user
class epfl_sso::mkhomedir() {
  case $::osfamily {
    'RedHat': {
      if $lsbdistid == 'RedHat' {
        package { 'oddjob-mkhomedir' :
          ensure => present
        }
      }
    }

    'Debian': {
      case "${::operatingsystem} ${::operatingsystemrelease}" {
         'Ubuntu 16.04': {
              # http://packages.ubuntu.com/search?suite=xenial&keywords=oddjob-mkhomedir
              package { 'oddjob-mkhomedir' :
                ensure => present
              }
         }
         default: {
              package { 'libpam-modules' :
                ensure => present
              }
         }
      }
    }
  }

  # Mimic "authconfig --enablemkhomedir"
  case $::osfamily {
    'RedHat': {
      $pam_mkhomedir_session = {
        'mkhomedir session in system-auth' => { service => 'system-auth'},
        'mkhomedir session in password-auth' => { service => 'password-auth'}
      }
    }
    'Debian': {
      $pam_mkhomedir_session = {
        'mkhomedir session in common-auth' => { service => 'common-auth'},
      }
    }
  }
  create_resources(pam, $pam_mkhomedir_session,
      {
        ensure    => present,
        type      => 'session',
        control   => 'optional',
        module    => 'pam_mkhomedir.so',
      })
}
