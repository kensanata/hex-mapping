hex-describe.md: hex-describe.pl
	pod2markdown $< $@

hex-describe.html: hex-describe.pl
	pod2html $< $@

hex-describe-tutorial.html: hex-describe.pl
	perl $< get /help > $@
