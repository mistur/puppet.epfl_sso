class epfl_sso::private::ldap {
  case $::osfamily {
    'Debian': {
      $packages_needed_for_ca_certs = []
      $trusted_cert_dir = "/etc/ssl/certs"
    }
    'RedHat': {
      $packages_needed_for_ca_certs = ["nss-tools"]
      $trusted_cert_dir = "/etc/openldap/certs"
    }
  }
  define trusted_ca_cert(
    $ensure = "present",
    $url
  ) {
    $pkg = $::epfl_sso::private::ldap::packages_needed_for_ca_certs
    ensure_packages($pkg)

    $trusted_cert_dir = $::epfl_sso::private::ldap::trusted_cert_dir
    $cert_pem_path = "${trusted_cert_dir}/${title}.pem"
    if ('true' == $url_is_pem) {
      $cert_retrieve_command = inline_template('wget -O <%= @cert_pem_path %> <%= @url %>')
    } else {
      $tmpcer = inline_template('<%= @trusted_cert_dir %>/<%= File.basename @url %>')
      $cert_retrieve_command = inline_template('true ; set -e -x; wget -O <%= @tmpcer %> <%= @url %> ; openssl x509 -inform der -outform pem -in <%= @tmpcer %> -out <%= @cert_pem_path %>; rm <%= @tmpcer %>')
    }

    case $::osfamily {
      'Debian': {
        fail("Don't know how to manage trusted certs for Debian")
      }
      'RedHat': {
        $openldap_certs_dir = "/etc/openldap/certs"
        $certutil_base_cmd = "certutil -d ${openldap_certs_dir}"
        if ($ensure == "present") {
          exec { $cert_retrieve_command:
            path => $::path,
            creates => $cert_pem_path
          } ~>
          exec { "${certutil_base_cmd} -n ${title} -t TCu,Cu,Tuw -A -a -i ${cert_pem_path}":
            path => $::path,
            unless => "${certutil_base_cmd} -L | grep ${title}",
            require => Package[$pkg]
          }
        } else {  # Disable
          file { $cert_pem_path:
            ensure => "absent"
          }
          exec { "${certutil_base_cmd} -D -n ${title}":
            path => $::path,
            onlyif => "${certutil_base_cmd} -L | grep ${title}",
            require => Package[$pkg]
          }
        }
      }
    }
  }
}
