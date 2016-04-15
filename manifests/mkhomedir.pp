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
  if $lsbdistid == 'RedHat' {
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

  # See https://wiki.debian.org/LDAP/PAM
  # From https://help.ubuntu.com/lts/serverguide/sssd-ad.html:
  # Home directories with pam_mkhomedir (optional)
  #  When logging in using an Active Directory user account, it is likely that user has no home directory.
  #  This can be fixed with pam_mkdhomedir.so, which will create the user's home directory on login.
  #  Edit /etc/pam.d/common-session, and add this line directly after session required pam_unix.so:
  #  `session    required    pam_mkhomedir.so skel=/etc/skel/ umask=0022`
  if $lsbdistid == 'Ubuntu' {
    $default_pam_session_lines = [
      'session  [default=1] pam_permit.so',
      'session requisite pam_deny.so',
			'session required  pam_permit.so',
			'session optional  pam_umask.so',
			#'session required  pam_vas3.so create_homedir',
			#'session requisite pam_vas3.so echo_return',
			'session required  pam_unix.so',
			'session required  pam_mkhomedir.so skel=/etc/skel/ umask=0022',
		]

		file { 'pam_session_lines':
			ensure  => file,
			path    => '/etc/pam.d/common-session',
			content => template('epfl_sso/common-session.erb'),
			owner   => 'root',
			group   => 'root',
			mode    => '0644',
		}
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
}
