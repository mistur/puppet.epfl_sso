# Class: epfl_sso::mkhomedir
#
# Automatically create home directories upon login of a new user
class epfl_sso::mkhomedir() {
  case $::osfamily {
    'RedHat': {
      if $lsbdistid == 'RedHat' {
        notify {"[epfl_sso::mkhomedir] Check install of oddjob-mkhomedir package for ${lsbdistid} (v${operatingsystemrelease})": }
        package { 'oddjob-mkhomedir' :
          ensure => present
        }
      }
      # Mimic "authconfig --enablemkhomedir"
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

    'Debian': {
      if $operatingsystemrelease != '16.04' {
        notify {"[epfl_sso::mkhomedir] Check install of libpam-modules package for ${lsbdistid} (v${operatingsystemrelease})": }
        package { 'libpam-modules' :
          ensure => present
        }
      }
      # http://packages.ubuntu.com/search?suite=xenial&keywords=oddjob-mkhomedir
      if $operatingsystemrelease == '16.04' {
        notify {"[epfl_sso::mkhomedir] Check install of oddjob-mkhomedir package for ${lsbdistid} (v${operatingsystemrelease})": }
        package { 'oddjob-mkhomedir' :
          ensure => present
        }
      }
    }
  }

  # Mimic "authconfig --enablemkhomedir"
  case $::osfamily {
    'RedHat': {
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
    'Debian': {
      create_resources(pam,
      {
        'mkhomedir session in common-auth' => { service => 'common-auth'},
      },
      {
        ensure    => present,
        type      => 'session',
        control   => 'optional',
        module    => 'pam_mkhomedir.so',
      })
    }
  }
}
