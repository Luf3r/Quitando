class DemoScenario::Lock
  # ASCII "QUITANDO". It identifies the shared demo-installation/reset lock without database IDs.
  LOCK_KEY = 0x5155_4954_414E_444F

  def self.acquire!
    new.acquire!
  end

  def acquire!
    ApplicationRecord.connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_KEY})")
  end
end
