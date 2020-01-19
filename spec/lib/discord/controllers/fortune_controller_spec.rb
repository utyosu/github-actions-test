require './spec/rails_helper'
require './spec/spec_helper'

describe FortuneController do
  let(:discord_author) { build(:fake_discord_user) }
  let(:author) { User.get_by_discord_user(discord_author) }
  let(:message_event) { build(:fake_message_event, author: discord_author) }

  describe '#get' do
    before { described_class.get(message_event) }

    it 'save activity' do
      expect(Activity.last).to have_attributes(user: author, content: 'fortune')
    end
  end
end
