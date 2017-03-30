class epfl_sso::private::ldap {
  case $::osfamily {
    'Debian': {
      $packages_needed_for_ca_certs = []
      $trusted_cert_dir = "/usr/share/ca-certificates/epfl"
      $cert_extension = "crt"
    }
    'RedHat': {
      $packages_needed_for_ca_certs = ["nss-tools"]
      $trusted_cert_dir = "/etc/openldap/certs"
      $cert_extension = "pem"
    }
  }
  define trusted_ca_cert(
    $ensure = "present",
    $url
  ) {
    $pkg = $::epfl_sso::private::ldap::packages_needed_for_ca_certs
    ensure_packages($pkg)

    $trusted_cert_dir = $::epfl_sso::private::ldap::trusted_cert_dir
    $cert_pem_basename = "${title}.${::epfl_sso::private::ldap::cert_extension}"
    $cert_pem_path = "${trusted_cert_dir}/${cert_pem_basename}"

    $url_is_pem = inline_template('<%= (@url.ends_with? "pem") ? "true" : "false" >')
    if ('true' == $url_is_pem) {
      $cert_retrieve_command = inline_template('wget -O <%= @cert_pem_path %> <%= @url %>')
    } else {
      $tmpcer = inline_template('<%= @trusted_cert_dir %>/<%= File.basename @url %>')
      $cert_retrieve_command = inline_template('true ; set -e -x; wget -O <%= @tmpcer %> <%= @url %> ; openssl x509 -inform der -outform pem -in <%= @tmpcer %> -out <%= @cert_pem_path %>; rm <%= @tmpcer %>')
    }

    $wget_package = "wget"
    ensure_packages($wget_package)

    case $::osfamily {
      'Debian': {
        $cert_conf_file = "/etc/ca-certificates.conf"
        $file_line = "${title} in ${cert_conf_file}"
        file_line { $file_line:
          path => $cert_conf_file,
          line => "epfl/${cert_pem_basename}",
          ensure => $ensure
        } ~>
        exec { "update-ca-certificates":
          path => $::path,
          refreshonly => true,
          require => File_line[$file_line]
        }

        if ($ensure == "present") {
          file { $trusted_cert_dir:
            ensure => "directory"
          } ->
          exec { $cert_retrieve_command:
            path => $::path,
            creates => $cert_pem_path,
            require => Package[$wget_package]
          } ~> Exec["update-ca-certificates"]
          
        } else {
          file { $cert_pem_path:
            ensure => "absent"
          } ~> Exec["update-ca-certificates"]
        }
      }
      'RedHat': {
        $openldap_certs_dir = "/etc/openldap/certs"
        $certutil_base_cmd = "certutil -d ${openldap_certs_dir}"
        if ($ensure == "present") {
          exec { $cert_retrieve_command:
            path => $::path,
            creates => $cert_pem_path,
            require => Package[$wget_package]
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
