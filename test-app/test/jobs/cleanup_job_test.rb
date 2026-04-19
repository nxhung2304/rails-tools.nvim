# frozen_string_literal: true

class CleanupJobTest < ActiveJob::TestCase
  test 'cleans up old logs' do
    old_log = logs(:old)
    recent_log = logs(:recent)

    CleanupJob.perform_now(:logs, older_than: 30.days.to_i)

    assert_raises(ActiveRecord::RecordNotFound) { old_log.reload }
    assert_nothing_raised { recent_log.reload }
  end
end
