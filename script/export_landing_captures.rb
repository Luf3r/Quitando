require "vips"

def export_capture(source, destination, crop_height, crop_width = nil)
  image = Vips::Image.new_from_file(source)
  image = image.crop(0, 0, crop_width || image.width, crop_height)
  image.webpsave(destination, Q: 88, strip: true)
  image
end

light_desktop = export_capture("tmp/polish/dashboard-light-desktop.png", "app/assets/images/landing/dashboard-summary.webp", 1080)
light_desktop.resize(720.0 / light_desktop.width).webpsave("app/assets/images/landing/dashboard-summary-720.webp", Q: 88, strip: true)
light_mobile = export_capture("tmp/polish/dashboard-light-mobile.png", "app/assets/images/landing/dashboard-summary-mobile.webp", 1285, 464)

dark_desktop = export_capture("tmp/polish/dashboard-dark-desktop.png", "app/assets/images/landing/dashboard-summary-dark.webp", 1080)
dark_desktop.resize(720.0 / dark_desktop.width).webpsave("app/assets/images/landing/dashboard-summary-dark-720.webp", Q: 88, strip: true)
dark_mobile = export_capture("tmp/polish/dashboard-dark-mobile.png", "app/assets/images/landing/dashboard-summary-dark-mobile.webp", 1285, 464)

logo = Vips::Image.new_from_file("public/quitando-logo.png")
trim_x, trim_y, trim_width, trim_height = logo[3].find_trim(background: [ 0 ], threshold: 1)
icon_size = [ trim_width, trim_height ].max
left = trim_x - ((icon_size - trim_width) / 2)
top = trim_y - ((icon_size - trim_height) / 2)
icon = logo.crop(left, top, icon_size, icon_size)
icon_variants = [
  [ 16, "favicon-16x16.png" ],
  [ 32, "favicon-32x32.png" ],
  [ 48, "favicon-48x48.png" ],
  [ 180, "apple-touch-icon.png" ]
]
icon_variants.each do |size, filename|
  icon.resize(size.to_f / icon_size).pngsave(File.join("public", filename), compression: 9, strip: true)
end

puts "Light desktop: #{light_desktop.width}x#{light_desktop.height}; light mobile: #{light_mobile.width}x#{light_mobile.height}"
puts "Dark desktop: #{dark_desktop.width}x#{dark_desktop.height}; dark mobile: #{dark_mobile.width}x#{dark_mobile.height}"
puts "Logo trim: #{trim_width}x#{trim_height}; icon crop: #{icon_size}x#{icon_size}"
