require 'logger'

$logger = Logger.new(STDERR)

def pam_file_of_distro(type)
  return case Facter.value(:osfamily)
         when 'RedHat'
           "/etc/pam.d/system-auth-ac"
         when 'Debian'
           "/etc/pam.d/common-#{type}"
         else
           "/etc/pam.d/*-#{type}*"
         end
end

def grep_in_pam_file(type, what)
  pam_file = (type == "*") ? "/etc/pam.d/*" : pam_file_of_distro(type)
  system("grep -q #{what} #{pam_file}")
  $? == 0
end

if Facter.value(:kernel) == 'Linux'
  Facter.add('pam_sss_configured') do
    setcode do
      grep_in_pam_file("auth", "pam_sss")
    end
  end

  Facter.add('pam_krb5_configured') do
    setcode do
      grep_in_pam_file("auth", "pam_krb5")
    end
  end

  Facter.add('pam_mkhomedir_configured') do
    setcode do
      grep_in_pam_file("session", "pam_mkhomedir")
    end
  end

  Facter.add('pam_access_configured') do
    setcode do
      grep_in_pam_file("account", "pam_access")
    end
  end

  # It's a *bad* thing to have winbind, so look for it everywhere
  Facter.add('pam_winbind_configured') do
    setcode do
      grep_in_pam_file("*", "pam_winbind")
    end
  end

end  # If Linux

