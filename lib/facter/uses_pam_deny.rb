require 'logger'

$logger = Logger.new(STDERR)

Facter.add('uses_pam_deny') do
  setcode do
    system("grep -q pam_deny /etc/pam.d/*auth*")
    $? == 0
  end
end

