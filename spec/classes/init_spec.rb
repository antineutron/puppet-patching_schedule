require 'spec_helper'
describe 'patching_schedule' do

  context 'with defaults for all parameters' do
    it { should contain_class('patching_schedule') }
  end
end
