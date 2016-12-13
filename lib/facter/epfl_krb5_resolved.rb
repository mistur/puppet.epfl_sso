require 'logger'

$logger = Logger.new(STDERR)

Facter.add('epfl_krb5_resolved') do
  setcode do
    begin
       value = `dig -t srv _kerberos._tcp.intranet.epfl.ch`
       # $logger.log(1, value)
       if value == nil then
         "undefined"
       else
         !! value.index("IN\tSRV\t")
       end
    rescue Errno::ENOENT
       "undefined"
    end
  end
end
