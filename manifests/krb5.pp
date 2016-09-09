# coding: utf-8
# Class: epfl_sso::krb5
#
# Integrate the computer into Kerberos
#
# This class is the translation in Puppet of
# https://fuhm.net/linux-and-active-directory/
#
# Unlike Windows, this approach does *not* preclude cloning - A number
# of VMs can share the same Kerberos credentials with no issues.
# *However*, one should *not* run this class periodically in this use
# case (or alternatively, all clones should have a different hostname)
#
# === Parameters:
#
# $initialize::  True iff we want to create credentials (as opposed to
#            renewing them). AS FOR NOW THIS IS THE ONLY SUPPORTED
#            MODE OF OPERATION. Requires running "kinit AD123456"
#            first (replace 123456 with your SCIPER)
#
# $ad_server::
#
# $ou_path::
#
# === Actions:
#
# * Create Active Directory-compatible entries in /etc/krb5.keytab
#   (updating them is not supported yet)
#
class epfl_sso::krb5(
  $initialize = false,
  $ad_server = "ad3.intranet.epfl.ch",
  $ou_path = "O=STI"
) {
  if (! $::epfl_krb5_resolved) {
    fail("Cannot resolve KRB5 server; DNS resolv.conf configuration is probably wrong.")
  }
  if (! $initialize) {
    fail("Kerberos credential refresh is not supported yet.")
  }
  if (! $::epfl_krb5_resolved) {
    fail("FATAL: fact 'epfl_krb5_resolved' is not working.")
  }
  if ($::epfl_krb5_resolved == "false") {
    fail("Unable to resolve KDC in DNS – You must use the EPFL DNS servers.")
  }

  # TODO: this is Debian-ish only
  $packages = [ "krb5-user", "libpam-krb5", "msktutil" ]
  ensure_packages($packages)

  file { "/etc/krb5.conf":
    content => template("epfl_sso/krb5.conf.erb")
  }

  exec { "Create AD-compliant /etc/krb5.keytab entries":
    path => $::path,
    command => "/bin/echo 'Please run kinit AD123456 first'",
    unless => "msktutil -c --server ${ad_server} -b '${ou_path}' --no-reverse-lookups",
    require => [Package[$packages], File["/etc/krb5.conf"]]
  }
}
