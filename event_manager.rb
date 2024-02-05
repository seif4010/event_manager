require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone_number(phone)
  clean_number = phone.to_s.gsub(/\D/, '')
  case clean_number.length
  when 10 then clean_number
  when 11 then clean_number[1..-1] if clean_number[0] == '1'
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  phone = clean_phone_number(row[:phone_number])

  if phone
    puts "Valid Phone Number: #{phone}"
  else
    puts "Invalid Phone Number: #{row[:phone_number]}"
    next # Skip the rest of the loop for invalid phone numbers
  end

  registration_time = DateTime.strptime(row[:registration_date], '%m/%d/%y %H:%M')
  registration_hours = Hash.new(0).tap { |h| h[registration_time.hour] += 1 }

  peak_hours = registration_hours.max_by { |hour, count| count }
  puts "Peak Registration Hours: #{peak_hours[0]}:00 - #{peak_hours[0]}:59 (#{peak_hours[1]} registrations)"

  registration_days = Hash.new(0).tap { |h| h[registration_time.wday] += 1 }
  peak_day = registration_days.max_by { |day, count| count }
  puts "Peak Registration Day: #{Date::DAYNAMES[peak_day[0]]} (#{peak_day[1]} registrations)"

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
end
