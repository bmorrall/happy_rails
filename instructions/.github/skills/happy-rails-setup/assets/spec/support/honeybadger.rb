RSpec.configure do |config|
  config.before do |example|
    if example.metadata[:honeybadger]
      expect(Honeybadger).to receive(:notify).at_least(:once).and_call_original
    else
      expect(Honeybadger).not_to receive(:notify)
    end
  end
end
