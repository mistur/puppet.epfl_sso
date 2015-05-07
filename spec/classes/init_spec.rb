require 'spec_helper'
describe 'epfl_sso' do

  context 'with defaults for all parameters' do
    it { should contain_class('epfl_sso') }
  end
end
