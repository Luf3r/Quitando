module TurboRefreshResponse
  private

  def respond_with_refresh(location:)
    respond_to do |format|
      format.html { redirect_to location, status: :see_other }
      format.turbo_stream { render turbo_stream: %(<turbo-stream action="refresh"></turbo-stream>).html_safe }
    end
  end
end
