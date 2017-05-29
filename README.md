# puppet.epfl_sso
UNIX single sign-on using EPFL's LDAP and Kerberos servers

# Apply one-shot

[Install Puppet standalone](https://docs.puppetlabs.com/puppet/3.8/reference/pre_install.html#standalone-puppet) then, as *root*:

  1. `puppet module install epflsti-epfl_sso` # Install the module
  2. `puppet apply -e "class { 'quirks': }  class { 'quirks::pluginsync': }"` # Repeat if prompted to
  3. Finaly, apply the epfl_sso class:  <pre>
      puppet apply -e "class { 'epfl_sso':
          allowed_users_and_groups => 'user1 user2 (group1) (group2)',
          join_domain => 'OU=IEL-GE-Servers,OU=IEL-GE,OU=IEL,OU=STI',
          auth_source => 'AD',
          directory_source => 'AD'
      }"
</pre>

_Note:_ `user1` & `user2` are GASPAR usernames and `group1` and `group2` are [EPFL groups](https://groups.epfl.ch) which are visible in ldap.epfl.ch.


And if you want NFS connectivity too:
```
puppet apply -e "class { 'epfl_sso::nfs': }"
```

## Applying the latest version
(in case the one on puppet lab is now up-to-date; please try the one-shot method first !)

### The git clone method
  1. Be sure to remove previous version: `puppet module uninstall epflsti-epfl_sso` (add `--ignore-changes` if needed)
  1. Go in the puppet folder: `cd /etc/puppet/module`
  1. Remove `epfl_sso` (but it should have been done from step 1)
  1. Clone the repo here: `git clone https://github.com/epfl-sti/puppet.epfl_sso.git /etc/puppet/module/epfl_sso`
  1. Apply one-shot step#3

### The tar.gz method
  1. Be sure to remove previous version: `puppet module uninstall epflsti-epfl_sso` (add `--ignore-changes` if needed)
  1. Clone the repo: `git clone https://github.com/epfl-sti/puppet.epfl_sso.git`
  1. tar the repo: `tar -czvf epfl_sso_latest.tar.gz puppet.epfl_sso`
  1. Install the module: `puppet module install epfl_sso_latest.tar.gz`
  1. Apply one-shot step#3
