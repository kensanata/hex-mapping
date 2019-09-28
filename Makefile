hex-describe.md: hex-describe.pl
	pod2markdown $< $@

hex-describe.html: hex-describe.pl
	pod2html $< $@

hex-describe-tutorial.html: hex-describe.pl
	perl $< get /help > $@

# the following target requires your shell to be tilix, and it requires the following hex-describe.conf file:
# {
#   hex_describe_url => 'http://localhost:3000',
#   text_mapper_url => 'http://localhost:3010',
#   face_generator_url => 'http://localhost:3020',
# }
local-test:
	tilix --action=session-add-down --title "Hex Describe" --command "/home/alex/perl5/perlbrew/perls/perl-5.28.1/bin/morbo --mode development --listen http://*:3000 hex-describe.pl"
	tilix --action=session-add-down --title "Text Mapper" --command "/home/alex/perl5/perlbrew/perls/perl-5.28.1/bin/morbo --mode development --listen http://*:3010 text-mapper.pl"
	cd ../face && tilix --action=session-add-down --title "Face Generator" --command "/home/alex/perl5/perlbrew/perls/perl-5.28.1/bin/morbo --mode development --listen http://*:3020 face.pl"
