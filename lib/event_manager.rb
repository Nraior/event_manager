require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legsislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  key = File.read('secret.key').strip
  civic_info.key = key

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"
  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone_number(phone_number)
  number = phone_number.to_s
  if number.length == 10
    number
  elsif number.length == 11 && number[0] == '1'
    number[1..]
  else
    nil
  end
end

def get_most_registered_hour(content)
  content.rewind
  max_hours = content.each_with_object(Hash.new(0)) do |row, hours|
    registered_date = row[:regdate]
    time_parsed = Time.strptime(registered_date, '%m/%d/%y %H:%M')
    hour = time_parsed.strftime('%k')
    hours[hour] += 1
  end
  max_registration_count = max_hours.max_by { |_, v| v }[1]

  max_hours.filter do |_, registed_at_hour|
    registed_at_hour == max_registration_count
  end
end

def get_most_registered_wday(content)
  content.rewind
  max_wdays = content.each_with_object(Hash.new(0)) do |row, wdays|
    registered_date = row[:regdate]
    date_parsed = Date.strptime(registered_date, '%m/%d/%y')
    day_of_week = date_parsed.strftime('%A')

    wdays[day_of_week] += 1
  end
  max_registration_count = max_wdays.max_by { |_, v| v }[1]

  max_wdays.filter do |_, registed_count|
    registed_count == max_registration_count
  end
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new(template_letter)

puts "Most registration hours: #{get_most_registered_hour(contents)}"
puts "Most registration day: #{get_most_registered_wday(contents)}"

contents.each do |row|
  id = row[0]
  name = row[:first_name] # used in erb
  zipcode = clean_zipcode(row[:zipcode])
  number_stripped = row[:homephone].to_s.tr('^0-9', '')
  number = clean_phone_number(number_stripped) # used in erb

  legislators = legsislators_by_zipcode(zipcode) # used in erb

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end
