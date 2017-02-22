class epfl_sso::private::params {
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
      password => "done",
      # For account and session, there is no evidence at this time of
      # pam_deny being used in the wild
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
}
