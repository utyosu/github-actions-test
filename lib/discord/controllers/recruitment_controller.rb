module RecruitmentController
  extend self

  def show(channel = $recruitment_channel)
    Recruitment.clean_invalid
    channel.send_message("```\n#{recruitments_message}\n```")
  end

  def destroy_expired_recruitment
    destroyed_recruitments = []
    Recruitment.active.each do |recruitment|
      if recruitment.reserve_at.present?
        if recruitment.reserve_at < Time.zone.now - Settings::RESERVE_OVER_TIME
          reserve_recruitment_over_time(recruitment)
        elsif recruitment.reserve_at < Time.zone.now
          reserve_recruitment_on_time(recruitment)
        end
      elsif (recruitment.created_at + Settings::EXPIRE_TIME) < Time.zone.now
        temporary_recruitment_expired(recruitment)
      end
    end
  end

  def open(message_event)
    user = User.get_by_discord_user(message_event.author)
    recruit_message = get_message_content(message_event)
    recruitment = Recruitment.create(content: recruit_message)
    recruitment.join(user)
    if recruitment.reserve_at.present?
      message_event.send_message(I18n.t('recruitment.open_reserved', name: user.name, label_id: recruitment.label_id, time: recruitment.reserve_at.to_simply))
    else
      message_event.send_message(I18n.t('recruitment.open_standard', name: user.name, label_id: recruitment.label_id, time: (recruitment.created_at + Settings::EXPIRE_TIME).to_simply))
    end
    self.show
    TwitterController.recruitment_open(recruitment)
  end

  def close(message_event)
    recruitment = get_recruitment_by_message_event(message_event)
    return if recruitment.blank?
    user = User.get_by_discord_user(message_event.author)

    recruitment.update(enable: false)
    message_event.send_message(I18n.t('recruitment.close', name: user.name, label_id: recruitment.label_id))
    self.show
    TwitterController.recruitment_close(recruitment)
  end

  def join(message_event)
    recruitment = get_recruitment_by_message_event(message_event)
    user = User.get_by_discord_user(message_event.author)
    return if recruitment.blank? || recruitment.attended?(user)

    recruitment.join(user)
    message_event.send_message(I18n.t('recruitment.join', name: user.name, label_id: recruitment.label_id))
    self.show
    TwitterController.recruitment_join(recruitment)

    return unless recruitment.full?
    if recruitment.reserve_at.present? && recruitment.reserve_at.in_time_zone > Time.zone.now
      message_event.send_message(I18n.t('recruitment.reserve_full', time: recruitment.reserve_at.to_simply))
    else
      recruitment.update(enable: false)
      message_event.send_message("#{recruitment.mentions}\n#{I18n.t('recruitment.one_time_notification')}")
      message_event.send_message(I18n.t("recruitment.one_time_close", label_id: recruitment.label_id))
      self.show
      TwitterController.recruitment_close(recruitment)
    end
  end

  def leave(message_event)
    recruitment = get_recruitment_by_message_event(message_event)
    user = User.get_by_discord_user(message_event.author)
    return if recruitment.blank? || !recruitment.attended?(user)
    TwitterController.recruitment_leave(recruitment)
    message_event.send_message(I18n.t('recruitment.cancel', name: user.name, label_id: recruitment.label_id))
    self.show
    recruitment.leave(user)
  end

  def resurrection(message_event)
    user = User.get_by_discord_user(message_event.author)
    recruitment = Recruitment.order("updated_at DESC").where(enable: false).first
    return if recruitment.blank?
    recruitment.set_label_id
    recruitment.update(enable: true)
    message_event.send_message(I18n.t('recruitment.resurrection', name: user.name, label_id: recruitment.label_id))
    self.show
  end

  private

  def get_recruitment_by_message_event(message_event)
    label_id = Extractor.extraction_number(get_message_content(message_event))
    if label_id.nil?
      message_event.send_message(I18n.t('recruitment.error_two_numbers'))
      return nil
    end
    return Recruitment.get_by_label_id(label_id)
  end

  def recruitments_message
    recruitments = Recruitment.active
    return I18n.t('recruitment.not_found') if recruitments.blank?
    recruitment_message = recruitments.sort_by{|recruitment|
      recruitment.label_id
    }.map{|recruitment|
      recruitment.to_format_string
    }.join("\n")
    return recruitment_message
  end

  def reserve_recruitment_on_time(recruitment)
    if recruitment.capacity <= recruitment.reserved
      recruitment.update(enable: false)
      mention = recruitment.mentions
      $recruitment_channel.send_message("#{mention}\n#{I18n.t('recruitment.reserve_notification', label_id: recruitment.label_id)}")
      $recruitment_channel.send_message("```\n#{recruitment.to_format_string}\n```")
      $recruitment_channel.send_message(I18n.t('recruitment.reserve_close', label_id: recruitment.label_id))
      self.show
      TwitterController.recruitment_close(recruitment)
    elsif !recruitment.notificated
      recruitment.update(notificated: true)
      $recruitment_channel.send_message(I18n.t('recruitment.reserve_on_time', label_id: recruitment.label_id, vacant: recruitment.vacant))
      self.show
    end
  end

  def reserve_recruitment_over_time(recruitment)
    recruitment.update(enable: false)
    $recruitment_channel.send_message(I18n.t('recruitment.one_time_over', label_id: recruitment.label_id, time: Settings::RESERVE_OVER_TIME/60))
    self.show
    TwitterController.recruitment_close(recruitment)
  end

  def temporary_recruitment_expired(recruitment)
    recruitment.update(enable: false)
    $recruitment_channel.send_message(I18n.t('recruitment.reserve_over', label_id: recruitment.label_id))
    self.show
    TwitterController.recruitment_close(recruitment)
  end
end
