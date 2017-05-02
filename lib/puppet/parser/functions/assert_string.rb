module Puppet::Parser::Functions
  newfunction(:assert_string, :doc => <<-EOS
Like stdlib's validate_string, but without the deprecation nonsense.
EOS
             ) do |args|
    unless args.length > 0 then
      raise Puppet::ParseError, ("validate_string(): wrong number of arguments (#{args.length}; must be > 0)")
    end

    args.each do |arg|
      unless arg.is_a?(String)
        raise Puppet::ParseError, ("#{arg.inspect} is not a string.  It looks to be a #{arg.class}")
      end
    end
    
  end
end
