hex-describe.md: hex-describe.pl
	pod2markdown $< $@

hex-describe.html: hex-describe.pl
	pod2html $< $@

hex-describe-tutorial.html: hex-describe.pl
	perl $< get /help > $@

local-test:
	tilix --action=session-add-down --command "/home/alex/perl5/perlbrew/perls/perl-5.28.1/bin/morbo --mode development --listen http://*:3000 hex-describe.pl"
	tilix --action=session-add-down --command "/home/alex/perl5/perlbrew/perls/perl-5.28.1/bin/morbo --mode development --listen http://*:3010 text-mapper.pl"
	cd ../face && tilix --action=session-add-down --command "/home/alex/perl5/perlbrew/perls/perl-5.28.1/bin/morbo --mode development --listen http://*:3020 face.pl"
