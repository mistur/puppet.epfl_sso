module Puppet::Parser::Functions
  newfunction(:assert_bool, :doc => <<-EOS
Like stdlib's validate_bool, but without the deprecation nonsense.
EOS
             ) do |args|
    unless args.length > 0 then
      raise Puppet::ParseError, ("validate_bool(): wrong number of arguments (#{args.length}; must be > 0)")
    end

    args.each do |arg|
      unless function_is_bool([arg])
        raise Puppet::ParseError, ("#{arg.inspect} is not a boolean.  It looks to be a #{arg.class}")
      end
    end
    
  end
end
