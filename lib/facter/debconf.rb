require 'logger'

$logger = Logger.new(STDERR)

case Facter.value(:osfamily)
    when 'Debian'
      Facter.add('debconf_libpam_runtime_profiles') do
        setcode do
           Facter::Core::Execution.exec('debconf-get-selections |sed -n "/^libpam-runtime\tlibpam-runtime\/profiles/p" |cut -f4-')
        end
      end

end
