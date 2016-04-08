Facter.add('epfl_krb5_resolved') do
  setcode do
    value = Facter::Core::Execution.exec('dig -t srv _kerberos._tcp.intranet.epfl.ch')
    if value == nil then
      "undefined"
    else 
      !! value.index("IN\tSRV\t")
    end
  end
end
