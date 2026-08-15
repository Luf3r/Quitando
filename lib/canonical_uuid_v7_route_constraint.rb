class CanonicalUuidV7RouteConstraint
  UUID_V7_FORMAT = "[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"
  UUID_V7_PATTERN = /\A#{UUID_V7_FORMAT}\z/
  ROUTE_PATTERN = /#{UUID_V7_FORMAT}/

  def initialize(*parameter_names)
    @parameter_names = parameter_names.presence || [ :id ]
  end

  def matches?(request)
    @parameter_names.all? do |parameter_name|
      UUID_V7_PATTERN.match?(request.path_parameters.fetch(parameter_name.to_sym, ""))
    end
  end
end
