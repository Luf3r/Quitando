require "tempfile"
require_relative "../../lib/structure_sql_normalizer"

RSpec.describe StructureSqlNormalizer do
  it "reduz duas quebras finais a uma" do
    Tempfile.create([ "structure", ".sql" ]) do |file|
      file.binmode
      file.write("CREATE TABLE examples ();\n\n".b)
      file.flush

      described_class.normalize!(file.path)

      expect(File.binread(file.path)).to eq("CREATE TABLE examples ();\n".b)
    end
  end

  it "preserva byte a byte um arquivo que já possui uma quebra final" do
    Tempfile.create([ "structure", ".sql" ]) do |file|
      contents = "CREATE TABLE examples ();\n".b
      file.binmode
      file.write(contents)
      file.flush

      described_class.normalize!(file.path)

      expect(File.binread(file.path)).to eq(contents)
    end
  end
end
