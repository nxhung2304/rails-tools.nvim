# frozen_string_literal: true

RSpec.describe CleanupJob do
  describe '#perform' do
    it 'cleans up old logs' do
      old_log = create(:log, created_at: 60.days.ago)
      recent_log = create(:log, created_at: 1.day.ago)

      described_class.perform_now(:logs, older_than: 30.days)

      expect { old_log.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { recent_log.reload }.not_to raise_error
    end
  end
end
