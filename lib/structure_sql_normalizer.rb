class StructureSqlNormalizer
  def self.normalize!(path)
    contents = File.binread(path)
    trailing_newline_start = contents.bytesize

    trailing_newline_start -= 1 while trailing_newline_start.positive? && contents.getbyte(trailing_newline_start - 1) == "\n".ord

    return if contents.bytesize - trailing_newline_start < 2

    File.binwrite(path, contents.byteslice(0, trailing_newline_start) + "\n".b)
  end
end
