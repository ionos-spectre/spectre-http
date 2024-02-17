require_relative '../lib/spectre/http'

RSpec.describe 'HTTP' do
  it 'should do some request' do
    Spectre::Http.https 'dummyjson.com' do
      method 'GET'
      path 'products/1'
    end

    expect(Spectre::Http.response.code).to eq 200
  end
end
