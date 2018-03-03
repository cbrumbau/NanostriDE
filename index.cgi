#!/usr/bin/perl
##
# index.pl
# 
# Creates job id for submission and serves index page.
#
# Chris Brumbaugh, cbrumbau@soe.ucsc.edu, 06/04/2011
##

# Add local libraries
BEGIN {
	push (@INC, "./lib");
}

use strict;
use warnings;

use CGI;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser); 

my $cgi = new CGI;
print $cgi->header('text/html');

sub printIndexPage {
	my $job_id = shift;
	print <<ENDHTML1;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=iso-8859-1"/>
<meta name="description" content="description"/>
<meta name="keywords" content="keywords"/> 
<meta name="author" content="author"/> 
<link rel="stylesheet" type="text/css" href="/css/default.css" media="screen"/>
<link rel="stylesheet" type="text/css" href="/css/plupload.queue.css"/>
<style type="text/css">
#invalidnumber { color:red; }
</style>
<title>NanoStriDE - NanoString Differential Expression</title>
</head>
<script type="text/javascript">
ENDHTML1
	print ("var job_id = \"".$job_id."\";\n");
	print <<ENDHTML2;
</script>
<script type="text/javascript" src="/js/process_multiupload.js"></script>
<body>
<div class="container">

	<noscript>

	<div class="holder_top"></div>

	<div class="holder">
		<h1>This Site Requires JavaScript</h1>
		<p>
			Please enable JavaScript for this site.
			<a target="_new" href="http://www.google.com/search?q=How+do+I+enable+JavaScript&amp;btnI=1">
			Please click here for information</a> on how to do this.<br/>
			Once JavaScript is enabled <a href="javascript:window.location.reload()">click here to reload</a> this site.
		</p>
	</div>

	<div class="holder_bottom"></div>

	</noscript>

	<div class="title">
		<h1 id="title">NanoStriDE</h1>
		<h3>NanoString Differential Expression</h3>
	</div>

	<div class="navigation">
		<a href="/about.html">About</a>
		<a href="/license.html">License</a>
		<a href="/faq.html">FAQ</a>
		<a href="/">Upload Data</a>
		<div class="clearer"><span></span></div>
	</div>

	<div class="holder_top"></div>

	<div class="holder">
		<form action="/cgi-bin/process_multiupload.cgi" enctype="multipart/form-data"
					id="upload_form" method="post" onsubmit="return checkform_multipleupload(this);">
			<h3><label>E-mail address:&nbsp;<input type="text" name="email" size="30"/></h3>
			<br label class="num-features" />
			<h3><label class="num-features">How many groups do you want to compare?&nbsp;</label><input type="text" class="num-features" id="number" value="2"/>&nbsp;&nbsp;<input type="button" class="num-features" id="update" value="Select" onclick="return update_div();"/></h3><span id="invalidnumber"></span>
			<br label class="num-features" />
			<p class="num-features">Example: For a control vs. case study, enter the number "2". To compare across three different tissues, enter the number "3".</p>
			<div id="uploader">
			</div>
		</form>
	</div>

	<div class="holder_bottom"></div>

	<div class="holder_top"></div>

	<div class="holder">

		<div class="footer">&copy; 2011 <a href="mailto:admin\@nanostride.soe.ucsc.edu">Chris Brumbaugh</a>. Valid <a href="http://jigsaw.w3.org/css-validator/check/referer">CSS</a> &amp; <a href="http://validator.w3.org/check?uri=referer">XHTML</a>. Template design by <a href="http://arcsin.se">Arcsin</a>
		</div>

	</div>

	<div class="holder_bottom"></div>

</div>
</body>
</html>
ENDHTML2
}

# Generate random tmp ID:
my @time_data = localtime(time);
$time_data[5] += 1900;
my $join_time = join ('-', @time_data);
# Final job id = time joined by hyphens + random number
my $job_id = $join_time."_".int(rand(4096));

# Print out new page with options to submit
printIndexPage ($job_id);

exit(0);
