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
      $pam_arguments = []
    }
    'Debian': {
      $pam_mkhomedir_session = {
        'mkhomedir session in common-session' => { service => 'common-session'},
        'mkhomedir session in common-session-noninteractive' => { service => 'common-session-noninteractive'},
      }
      $pam_arguments = ['skel=/etc/skel/', 'umask=0022']
    }
  }
  create_resources(pam, $pam_mkhomedir_session,
      {
        ensure    => present,
        type      => 'session',
        control   => 'required',
        module    => "pam_mkhomedir.so",
        arguments => $pam_arguments
      })
}
