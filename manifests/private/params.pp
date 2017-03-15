class epfl_sso::private::params {
  $krb5_domain = "INTRANET.EPFL.CH"

  case "${::operatingsystem} ${::operatingsystemmajrelease}" {
         'Ubuntu 12.04': {
           $sssd_packages = ['sssd']
           $needs_nscd = true
         }
         default: {
           $sssd_packages = ['sssd', 'sssd-ldap']
           $needs_nscd = false
         }
  }
  # Some versions of Ubuntu and RedHat use a pam_deny line as a catch-all
  # blocker, and successful authentication operations need to interrupt
  # the control flow before it reaches there:
  $_pam_success_actions_with_pam_deny = {
      auth => "done",
      password => "ok",
      # For account and session, we actively make sense that pam_deny.so
      # is not in use (see below).
      account => "ok",
      session => "ok"
  }
  $_pam_success_actions_without_pam_deny = {
      auth => "ok",
      account => "ok",
      password => "ok",
      session => "ok"
  }
  $pam_success_actions = $::uses_pam_deny ? {
    "true" => $_pam_success_actions_with_pam_deny,
    default => $_pam_success_actions_without_pam_deny
  }

  define pam_deny_makes_no_sense_in() {
    pam { "pam_deny makes no sense in ${title}":
      ensure  => absent,
      service => $title,
      module  => 'pam_deny.so',
    }
  }

  # Unfortunately this seems to have no effect on Xenial :(
  epfl_sso::private::params::pam_deny_makes_no_sense_in { ["common-account",
                                                           "common-session"]: }
}
