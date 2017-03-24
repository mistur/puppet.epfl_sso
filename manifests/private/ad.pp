# coding: utf-8
# Class: epfl_sso::private::ad
#
# Integrate this computer into EPFL's Active Directory
#
# This class is the translation into Puppet of
# https://fuhm.net/linux-and-active-directory/
#
# Unlike Windows, this approach does *not* preclude cloning - A number
# of VMs can share the same Kerberos credentials with no issues.
# *However*, one should *not* run this class periodically in this use
# case (or alternatively, all clones should have a different hostname)
#
# === Parameters:
#
# $join_domain:: An OU path relative to the Active Directory root,
#                e.g. "OU=IEL-GE-Servers,OU=IEL-GE,OU=IEL,OU=STI" for
#                a physical machine, or
#                "OU=STI,OU=StudentVDI,OU=VDI,OU=DIT-Services Communs"
#                for a student VM. Undefined if we do not care about
#                creating / maintaining an object in AD. Joining the
#                domain the first time requires credentials with write
#                access to Active Directory, which can be obtained by
#                running e.g. "kinit AD243371" (for a physical
#                machine) or "kinit itvdi-ad-sti" (for a student VM)
#                as the same user (typically root) as Puppet is
#                subsequently run as.
#
# $ad_server::   The Active Directory server to use
#
# === Actions:
#
# * Create EPFL-compatible /etc/krb5.conf
#
# * Deploy pam_krb5.so in an "opportunistic" configuration: grab a TGT if we can,
#   but fail gracefully otherwise
#
# * Optionally (depending on $join_domain), create or update Active
#   Directory-compatible credentials in /etc/krb5.keytab . Note that cloning
#   virtual machines that are registered in the domain suffers from the same
#   kind of issues as on the Windows platform; as each VM instance will try
#   to update the Kerberos password for the AD entry, they will quickly diverge
#   since only one of them will succeed to do so.

class epfl_sso::private::ad(
  $ad_server,
  $join_domain
) inherits epfl_sso::private::params {
  if ($::epfl_krb5_resolved == "false") {
    fail("Unable to resolve KDC in DNS – You must use the EPFL DNS servers.")
  }

  # Kerberos clients that insist on "authenticating" their peer using a
  # reverse DNS are in for a surprise for some of the hosts... Among which,
  # the AD servers themselves :(
  define etchosts_line($ip) {
    file_line { "${title} in /etc/hosts":
      path => "/etc/hosts",
      line => "${ip} ${title}.intranet.epfl.ch ${title}.epfl.ch",
      ensure => "present"
    }
  }
  epfl_sso::private::ad::etchosts_line { "ad1": ip => "128.178.15.227" }
  epfl_sso::private::ad::etchosts_line { "ad2": ip => "128.178.15.228" }
  epfl_sso::private::ad::etchosts_line { "ad3": ip => "128.178.15.229" }

  case $::osfamily {
    "Debian": {
      $_package_of_dig = "dnsutils"
      $_other_packages_to_install = [ "krb5-user", "libpam-krb5", "msktutil" ] 
    }
    "RedHat": {
      $_package_of_dig = "bind-utils"
      # https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Managing_Smart_Cards/installing-kerberos.html
      $_other_packages_to_install = [ "krb5-workstation", "krb5-libs", "pam_krb5", "msktutil" ]
    }
    default: {
      fail("Not sure how to install Kerberos dependencies on ${::osfamily}-family Linux")
    }
  }

  $_all_packages = union([$_package_of_dig], $_other_packages_to_install)
  ensure_packages([$_all_packages])
  if (! $::epfl_krb5_resolved) {
    Package[$_package_of_dig] ~>
    exec { "echo 'dig was installed - Please run Puppet again'; exit 2":
      path => $::path,
      refreshonly => true
    }
  }

  if ($join_domain) {
    $_msktutil_command = inline_template('msktutil -c --server <%= @ad_server %> -b "<%= @join_domain %>" --no-reverse-lookups --enctypes 24 --computer-name <%= @hostname.upcase %>')
    exec { "${_msktutil_command}":
      path => $::path,
      command => "/bin/echo 'mkstutil -c failed - Please run kinit <ADSciper or \"itvdi-ad-sti\"> first'; false",
      unless => $_msktutil_command,
      require => [Package[$_all_packages], File["/etc/krb5.conf"]]
    }
  }

  file { "/etc/krb5.conf":
    content => template("epfl_sso/krb5.conf.erb")
  }

  include epfl_sso::private::pam
  epfl_sso::private::pam::module { "krb5": }
}
