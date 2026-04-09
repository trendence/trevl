# frozen_string_literal: true

RSpec.describe Trevl::Auth::BearerToken do
  it "adds Authorization header" do
    auth = described_class.new("my-secret-token")
    headers = {"Content-Type" => "application/json"}
    auth.apply(headers)

    expect(headers["Authorization"]).to eq("Bearer my-secret-token")
  end

  it "does not modify other headers" do
    auth = described_class.new("token")
    headers = {"Accept" => "text/html"}
    auth.apply(headers)

    expect(headers["Accept"]).to eq("text/html")
    expect(headers.keys).to contain_exactly("Accept", "Authorization")
  end
end
