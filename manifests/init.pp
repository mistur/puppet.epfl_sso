# coding: utf-8
# Class: epfl_sso
#
# This class describes integrating a Linux computer into the EPFL
# directory services (LDAP and Kerberos)
#
# === Parameters:
#
# $allowed_users_and_groups::  access.conf(5)-style ACL, e.g.
#                              "user1 user2 (group1) (group2)"
#                              Note: if you run gdm, user gdm must have access
# $manage_nsswitch_netgroup::  Whether to manage the netgroup entry in
#                              nsswitch.conf
# $enable_mkhomedir::          Whether to automatically create users' home
#                              directories upon first login
# $needs_nscd::                Whether to install nscd to serve as a second
#                              layer of cache (for old distros with slow sssd)
# $auth_source::               Either "AD" or "scoldap"
# $directory_source::          Either "AD" or "scoldap"
# $join_domain:: An OU path relative to the Active Directory root,
#                e.g. "OU=IEL-GE-Servers,OU=IEL-GE,OU=IEL,OU=STI" for
#                a physical machine, or
#                "OU=STI,OU=StudentVDI,OU=VDI,OU=DIT-Services Communs"
#                for a student VM. Undefined if we do not care about
#                creating / maintaining an object in AD (which precludes
#                $directory_source = "ad"). Joining the
#                domain the first time requires credentials with write
#                access to Active Directory, which can be obtained by
#                running e.g. "kinit AD243371" (for a physical
#                machine) or "kinit itvdi-ad-sti" (for a student VM)
#                as the same user (typically root) as Puppet is
#                subsequently run as.
# $sshd_gssapi_auth::    Set to true to allow inbound ssh access with
#                        Kerberos authentication. See epfl_sso::private::sshd
#                        for the required client-side configuration
# $debug_sssd::          Turn extra debugging on in sssd if true
#
# === Actions:
#
# * Install SSSD and configure it to talk to scoldap.epfl.ch for
#   directory data (nsswitch) and to the INTRANET Active Directory domain
#   for (Kerberos-based) authentication (PAM)
#
class epfl_sso(
  $allowed_users_and_groups = undef,
  $manage_nsswitch_netgroup = true,
  $enable_mkhomedir = true,
  $auth_source = "AD",
  $directory_source = "scoldap",
  $needs_nscd = $::epfl_sso::private::params::needs_nscd,
  $ad_server = $epfl_sso::private::params::ad_server,
  $join_domain = undef,
  $sshd_gssapi_auth = undef,
  $debug_sssd = undef
) inherits epfl_sso::private::params {
  ensure_resource('class', 'quirks')
  class { "epfl_sso::private::package_sources": }

  if ( (versioncmp($::puppetversion, '3') < 0) or
       (versioncmp($::puppetversion, '5') > 0) ) {
    fail("Need version 3.x or 4.x of Puppet.")
  }

  # There appears to be no way to get validate_legacy to validate Booleans on
  # Puppet 4.9.4 as found on CentOS 7.3.1611:
  if ($manage_nsswitch_netgroup != !(! $manage_nsswitch_netgroup)) {
    fail("$manage_nsswitch_netgroup should be a Boolean (found ${manage_nsswitch_netgroup} instead)")
  }
  if (versioncmp($::puppetversion, '4') < 0) {
    validate_string($allowed_users_and_groups)
  } else {
    validate_legacy("Optional[String]", "validate_string", $allowed_users_and_groups)
  }

  if (($join_domain == undef) and ($directory_source == "AD")) {
    warn("In order to be an Active Directory LDAP client, one must join the domain (obtain a Kerberos keytab). Consider passing the $join_domain parameter to the epfl_sso class")
  }

  package { $epfl_sso::private::params::sssd_packages :
    ensure => present
  } ->
  file { '/etc/sssd/sssd.conf' :
    ensure  => present,
    content => template('epfl_sso/sssd.conf.erb'),
    # The template above uses variables $debug_sssd, $auth_source and
    # $ad_server
    owner   => root,
    group   => root,
    mode    => '0600'
  } ~>
  service { 'sssd':
    ensure => running,
    enable => true
  }

  include epfl_sso::private::pam
  epfl_sso::private::pam::module { "sss": }

  if ($needs_nscd) {
    package { "nscd":
      ensure => present
    }
  }

  # A properly configured clock is necessary for Kerberos:
  ensure_resource('class', 'ntp')

  # When a user tries to ssh into a machine that doesn't have their shell,
  # figuring it all out from the logs is quite a challenge.
  # Note: EPFL's default shell can be changed here:
  #       https://cadiwww.epfl.ch/cgi-bin/accountprefs/
  # As of Feb, 2017 the options are
  # 
  # /bin/sh
  # /bin/bash
  # /bin/tcsh
  # /bin/zsh
  # /bin/csh
  # /bin/bash2
  # /bin/ash
  # /bin/bsh
  # /sbin/nologin                

  # This seems to be the lowest common denominator across distributions:
  ensure_packages(['tcsh', 'zsh', 'bsh'])
  case $::osfamily {
    "Debian": {
      ensure_packages(['ash', 'csh'])  # In addition to above
    }
    "RedHat": {
      package { "ash":
        provider => "rpm",
        source => "http://ftp.uni-erlangen.de/mirrors/opensuse/distribution/11.4/repo/oss/suse/x86_64/ash-1.6.1-146.2.x86_64.rpm"
      }
      file { "/bin/csh":
        ensure => "link",
        target => "tcsh"
      }
    }
  }

  if ($allowed_users_and_groups != undef) {
    class { 'epfl_sso::private::access':
      allowed_users_and_groups => $allowed_users_and_groups
    }
  }

  name_service {['passwd', 'group']:
    lookup => ['compat', 'sss']
  }

  # This is necessary for RH7 and CentOS 7, and probably
  # does not hurt for older versions:
  name_service { 'initgroups':
    # https://bugzilla.redhat.com/show_bug.cgi?id=751450
    lookup => ['files [SUCCESS=continue] sss']
  }

  if ($manage_nsswitch_netgroup) {
    name_service { 'netgroup':
      lookup => ['files', 'sss']
    }
  }

  if ($enable_mkhomedir) {
    class { 'epfl_sso::private::mkhomedir': }
  }

  epfl_sso::private::pam::module { "winbind":
    ensure => "absent"
  }

  class { "epfl_sso::private::lightdm":  }

  if ($auth_source == "AD" or $directory_source == "AD") {
    class { "epfl_sso::private::ad":
      join_domain => $join_domain,
      ad_server => $ad_server
    }
  }

  if ($sshd_gssapi_auth != undef) {
    class { "epfl_sso::private::sshd":
      enable_gssapi => $sshd_gssapi_auth
    }
  }
}
