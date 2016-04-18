# puppet.epfl_sso
UNIX single sign-on using EPFL's LDAP and Kerberos servers

# Apply one-shot

[Install Puppet standalone](https://docs.puppetlabs.com/puppet/3.8/reference/pre_install.html#standalone-puppet) then:

```
puppet module install domq/epfl_sso
puppet apply -e 'class { "epfl_sso":  allowed_users_and_groups => "user1 user2 (group1) (group2)" }'
```
