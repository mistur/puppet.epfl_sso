# puppet.epfl_sso
UNIX single sign-on using EPFL's LDAP and Kerberos servers

# Apply one-shot

[Install Puppet standalone](https://docs.puppetlabs.com/puppet/3.8/reference/pre_install.html#standalone-puppet) then, as `root`:

```
puppet module install epflsti-epfl_sso
puppet apply -e "class { "quirks":}  class { 'quirks::pluginsync': }"   # Repeat if prompted to
puppet apply -e 'class { "epfl_sso":  allowed_users_and_groups => "user1 user2 (group1) (group2)" }'
```

And if you would like Kerberos with that?
```
puppet apply -e 'class { "epfl_sso::krb5":  join_domain => "OU=IEL-GE-Servers,OU=IEL-GE,OU=IEL,OU=STI" }'
```

Turn on inbound ssh access using Kerberos credentials:
```
puppet apply -e 'class { "epfl_sso::krb5::ssh": }'
```

Turn on Kerberized NFSv4 client support:
```
puppet apply -e 'class { "epfl_sso::nfs": }'
```
