class FakeMessageEvent
  attr_accessor :author, :content

  def initialize
    @messages = []
  end

  def send_message(text)
    @messages << text
  end

  def include_message?(text)
    @messages.any?{|m|m.include?(text)}
  end

  def send_file(file)
    # Do nothing
  end
end

FactoryBot.define do
  factory :fake_message_event do
    sequence(:author) { build(:fake_discord_user) }
    content { '' }
  end
end
