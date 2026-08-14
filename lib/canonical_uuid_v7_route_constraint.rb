class CanonicalUuidV7RouteConstraint
  UUID_V7_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

  def matches?(request)
    UUID_V7_PATTERN.match?(request.params.fetch("id", ""))
  end
end
