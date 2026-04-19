# frozen_string_literal: true

class CleanupJob < ApplicationJob
  queue_as :default

  def perform(resource_type, older_than: 30.days)
    case resource_type
    when :logs
      cleanup_logs(older_than)
    when :temp_files
      cleanup_temp_files(older_than)
    when :sessions
      cleanup_sessions(older_than)
    end
  end

  private

  def cleanup_logs(older_than)
    Log.where('created_at < ?', older_than).delete_all
  end

  def cleanup_temp_files(older_than)
    TempFile.where('created_at < ?', older_than).delete_all
  end

  def cleanup_sessions(older_than)
    Session.where('updated_at < ?', older_than).delete_all
  end
end
