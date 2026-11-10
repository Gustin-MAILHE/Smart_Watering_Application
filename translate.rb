require 'yaml'
require 'net/http'
require 'json'
require 'uri'

fr_data = YAML.load_file('config/locales/fr.yml')

def translate_hash(hash)
  hash.transform_values do |value|
    case value
    when Hash
      translate_hash(value)
    when String
      translate_text(value)
    else
      value
    end
  end
end

def translate_text(text)
  uri = URI.parse("https://translate.argosopentech.com/translate")
  response = Net::HTTP.post(
    uri,
    {q: text, source: "fr", target: "en", format: "text" }.to_json,
    "Content-Type" => "application/json"
  )
  result = JSON.parse(response.body)
  result["translatedText"] || text
  rescue => e
    puts "Erreur sur : #{text} -> #{e.message}"
    text
end

en_data = { "en" => translate_hash(fr_data["fr"])}

File.open('config/locales/en.yml', "w", encoding: "utf-8") do |f|
  f.write(en_data.to_yaml)
end
puts "Traduction terminée dans config/locales/en.yml !"
