class epfl_sso::private::params {
  $krb5_domain = "INTRANET.EPFL.CH"
  $ad_server = "ad3.intranet.epfl.ch"
  $is_puppet_apply = ! $::servername

  case "${::operatingsystem} ${::operatingsystemrelease}" {
         'Ubuntu 12.04': {
           $sssd_packages = ['sssd']
           $needs_nscd = true
         }
         default: {
           $sssd_packages = ['sssd', 'sssd-ldap']
           $needs_nscd = false
         }
  }

  case $::osfamily {
    'Debian': {
      $pam_modules_managed_by_distro = ["krb5", "mkhomedir", "sss", "winbind" ]
    }
  }

  $krb5_conf_file = $::osfamily ? {
    "Darwin" => "/private/etc/krb5.conf",
    default  => "/etc/krb5.conf"
  }
}
