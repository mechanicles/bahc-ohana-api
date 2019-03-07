Geocoder.configure(
  lookup: :google,
  http_proxy: ENV['QUOTAGUARD_URL'],
  always_raise: [
    Geocoder::OverQueryLimitError,
    Geocoder::RequestDenied,
    Geocoder::InvalidRequest,
    Geocoder::InvalidApiKey
  ],
  api_key: ENV['GOOGLE_MAPS_API_KEY']
)
