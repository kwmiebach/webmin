# caldera-driver.pl
# Functions for printer drivers as generated by COAS

%paper_sizes = ( 'a4', 'A4',
		 'a3', 'A3',
		 'a5', 'A5',
		 'letter', 'US Letter',
		 'legal', 'Legal',
		 'ledger', 'Ledger' );
$driver_dir = "/etc/sysconfig/printers";
$base_driver = "/usr/libexec/printers/genericfilter";
open(BASE, $base_driver);
$base_driver_text = join(<BASE>);
close(BASE);
$webmin_windows_driver = 1;

# is_windows_driver(path)
# Returns the server, share, username, password, workgroup, program
# if path is a webmin windows driver
sub is_windows_driver
{
return &is_webmin_windows_driver(@_);
}

# is_driver(path, &printer)
# Returns the driver name and dpi if some path is a webmin driver, or undef
sub is_driver
{
if (!$_[0]) {
	return { 'mode' => 0,
		 'desc' => "$text{'caldera_none'}" };
	}
open(DRV, $_[0]);
local @lines = <DRV>;
close(DRV);
local %conf;
if ($lines[1] =~ /^source ($driver_dir\/\S+)/) {
	# Looks like a 2.3 caldera driver! Read the sysconfig file
	&read_env_file($1, \%conf);
	if ($conf{'GSDEVICE'} eq 'NET' || $conf{'GSDEVICE'} eq 'RAW') {
		# Driver isn't even used
		return { 'mode' => 0,
			 'desc' => 'None' };
		}
	elsif ($conf{'GSDEVICE'} eq 'uniprint') {
		# Uniprint driver
		foreach $u (&list_uniprint()) {
			$desc = $u->[1] if ($u->[0] eq $conf{'UPP'});
			}
		$desc =~ s/,.*$//g;
		return { 'mode' => 3,
			 'upp' => $conf{'UPP'},
			 'paper' => $conf{'PAPERSIZE'},
			 'double' => lc($conf{'DOUBLEPAGE'}),
			 'eof' => lc($conf{'SENDEOF'}),
			 'desc' => $desc ? $desc : $conf{'UPP'} };
		}
	else {
		# A caldera printer driver
		open(COAS, $config{'coas_printers'});
		local $plist = &parse_coas(COAS);
		close(COAS);
		local ($prn, $p);
		foreach $p (values %$plist) {
			$prn = $p
				if ($p->{'type'}->{'0'} eq $conf{'GSDEVICE'} &&
				    !$desc);
			}
		return { 'mode' => 1,
			 'gsdevice' => $conf{'GSDEVICE'},
			 'gsname' => $conf{'GSNAME'},
			 'res' => $conf{'RESOLUTION'},
			 'paper' => $conf{'PAPERSIZE'},
			 'eof' => lc($conf{'SENDEOF'}),
			 'double' => lc($conf{'DOUBLEPAGE'}),
			 'gsopts' => $conf{'GSOPTS'},
			 'ddesc' => $prn->{'description'},
			 'desc' => $conf{'GSNAME'} ? $conf{'GSNAME'}
						   : $prn->{'description'} };
		}
	}
elsif (join(@lines) eq $base_driver_text) {
	# Looks like a 2.4 caldera driver!
	&read_env_file("$driver_dir/$_[1]->{'name'}", \%conf);
	if ($conf{'GSDEVICE'} eq 'NET' || $conf{'GSDEVICE'} eq 'RAW') {
		# Driver isn't even used
		return { 'mode' => 0,
			 'desc' => 'None' };
		}
	else {
		# A new caldera printer driver
		open(COAS, $config{'coas_printers'});
		local $plist = &parse_coas(COAS);
		close(COAS);
		local ($prn, $p, $type);
		foreach $p (values %$plist) {
			$type = ref($p->{'type'}) ? $p->{'type'}->{'0'}
						  : $p->{'type'};
			$prn = $p if ($type eq $conf{'GSDEVICE'} && !$prn &&
				($p->{'description'} eq $conf{'DESC'} ||
				 $p->{'description'} eq $conf{'GSNAME'}));
			}
		if (!$prn) {
			foreach $p (values %$plist) {
				$type = ref($p->{'type'}) ? $p->{'type'}->{'0'}
							  : $p->{'type'};
				$prn = $p if ($type eq $conf{'GSDEVICE'} &&
					      !$prn);
				}
			}
		return { 'mode' => 1,
			 'gsdevice' => $conf{'GSDEVICE'},
			 'gsname' => $conf{'GSNAME'},
			 'res' => $conf{'RESOLUTION'},
			 'paper' => $conf{'PAPERSIZE'},
			 'eof' => lc($conf{'SENDEOF'}),
			 'double' => lc($conf{'DOUBLEPAGE'}),
			 'gsopts' => $conf{'GSOPTS'},
			 'upp' => $conf{'UPP'},
			 'ddesc' => $prn->{'description'},
			 'desc' => $conf{'GSNAME'} ? $conf{'GSNAME'}
						   : $prn->{'description'} };
		}
	}
else {
	# A driver of some kind, but not caldera's
	return { 'mode' => 2,
		 'file' => $_[0],
		 'desc' => $_[0] };
	}
}

# create_windows_driver(&printer, &driver)
sub create_windows_driver
{
return &create_webmin_windows_driver(@_);
}

# create_driver(&printer, &driver)
sub create_driver
{
&lock_file("$driver_dir/$_[0]->{'name'}");
if ($_[1]->{'mode'} == 0) {
	unlink("$driver_dir/$_[0]->{'name'}");
	&unlock_file("$driver_dir/$_[0]->{'name'}");
	return undef;
	}
elsif ($_[1]->{'mode'} == 2) {
	unlink("$driver_dir/$_[0]->{'name'}");
	&unlock_file("$driver_dir/$_[0]->{'name'}");
	return $_[1]->{'file'};
	}
else {
	# Create or update the parameters file
	local %conf;
	&read_env_file("$driver_dir/$_[0]->{'name'}", \%conf);
	$conf{'GSDEVICE'} = $_[1]->{'gsdevice'};
	$conf{'GSNAME'} = $_[1]->{'gsname'};
	$conf{'NAME'} = $_[0]->{'name'};
	$conf{'RESOLUTION'} = $_[1]->{'res'};
	$conf{'PAPERSIZE'} = $_[1]->{'paper'};
	$conf{'DESC'} = $_[0]->{'desc'};
	$conf{'SENDEOF'} = $_[1]->{'eof'};
	$conf{'DOUBLEPAGE'} = $_[1]->{'double'};
	$conf{'GSOPTS'} = $_[1]->{'gsopts'};
	$conf{'UPP'} = $_[1]->{'upp'};
	&write_env_file("$driver_dir/$_[0]->{'name'}", \%conf);
	&unlock_file("$driver_dir/$_[0]->{'name'}");

	&lock_file("$config{'spool_dir'}/$_[0]->{'name'}");
	mkdir("$config{'spool_dir'}/$_[0]->{'name'}", 0755);
	&unlock_file("$config{'spool_dir'}/$_[0]->{'name'}");
	local $drv = "$config{'spool_dir'}/$_[0]->{'name'}/printfilter";
	&lock_file($drv);
	if ($gconfig{'os_version'} >= 2.4) {
		# Create the 2.4 driver program
		&copy_source_dest($base_driver, $drv);
		}
	else {
		# Create the 2.3 driver program
		open(DRIVER, $base_driver);
		local @lines = <DRIVER>;
		close(DRIVER);
		&open_tempfile(DRV, ">$drv");
		&print_tempfile(DRV, "#!/bin/bash\n");
		&print_tempfile(DRV, "source $driver_dir/$_[0]->{'name'}\n");
		&print_tempfile(DRV, @lines);
		&close_tempfile(DRV);
		}
	&unlock_file($drv);
	return $drv;
	}
}

# delete_driver(name)
sub delete_driver
{
&delete_webmin_driver($_[0]);
&lock_file("$driver_dir/$_[0]");
unlink("$driver_dir/$_[0]");
&unlock_file("$driver_dir/$_[0]");
}

# driver_input(&printer, &driver)
sub driver_input
{
local $mode = $_[1]->{'mode'};
printf "<tr> <td><input type=radio name=mode value=0 %s> %s</td>\n",
	$mode == 0 ? 'checked' : '', $text{'caldera_none'};
print "<td>($text{'caldera_nonemsg'})</td> </tr>\n";
printf "<tr> <td><input type=radio name=mode value=2 %s> %s</td>",
	$mode == 2 ? 'checked' : '', $text{'caldera_prog'};
printf "<td><input name=program size=40 value='%s'></td> </tr>\n",
	$mode == 2 ? $_[0]->{'iface'} : '';

# Normal driver options
printf "<tr> <td valign=top><input type=radio name=mode value=1 %s> %s</td>\n",
	$mode == 1 ? 'checked' : '', $text{'caldera_coas'};
print "<td><table width=100%>\n";

local $sels = $gconfig{'os_version'} < 2.4 ? 5 : 10;
print "<tr> <td valign=top><b>$text{'caldera_printer'}</b></td>\n";
print "<td colspan=3><select size=$sels name=gsdevice onChange='setres(0)'>\n";
open(COAS, $config{'coas_printers'});
local $plist = &parse_coas(COAS);
close(COAS);
local ($i, $j, $p, $k, $found, $select_res);
foreach $p (values %$plist) {
	if ($p->{'description'} eq $_[1]->{'gsname'} &&
	    $p->{'type'}->{'0'} ne $_[1]->{'gsdevice'}) {
		# COAS has changed the device
		$_[1]->{'gsname'} = undef;
		}
	}
foreach $k (sort { $a <=> $b } keys %$plist) {
	$p = $plist->{$k};
	local $type = ref($p->{'type'}) ? $p->{'type'}->{'0'}
					: $p->{'type'};
	next if ($type =~ /NET|RAW/);
	local @thisres = values %{$p->{'resolution'}};
	#local $got = ($_[1]->{'gsname'} eq $p->{'description'} &&
	#	      $_[1]->{'gsdevice'} eq $type) ||
	#	     (!$_[1]->{'gsname'} && !$found &&
	#	      $_[1]->{'gsdevice'} eq $type);
	local $got = $_[1]->{'ddesc'} eq $p->{'description'};
	printf "<option %s value='%s'>%s</option>\n",
		$got ? 'selected' : '',
		$p->{'description'}.";".join(";", @thisres),
		$p->{'description'};
	$found = $p if ($got);
	$select_res = &indexof($_[1]->{'res'}, @thisres) if ($got);
	map { $gotres{$_}++ } @thisres;
	}
print "</select><select name=res size=$sels>\n";
foreach $r (sort { $a <=> $b} keys %gotres) {
	printf "<option %s>%s</option>\n",
		$_[1]->{'res'} eq $r ? 'selected' : '', $r;
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'caldera_eof'}</b></td>\n";
printf "<td><input type=radio name=eof value=true %s> $text{'yes'}\n",
	$_[1]->{'eof'} eq 'true' ? 'checked' : '';
printf "<input type=radio name=eof value=false %s> $text{'no'}</td>\n",
	$_[1]->{'eof'} eq 'true' ? '' : 'checked';

print "<td><b>$text{'caldera_paper'}</b></td> <td><select name=paper>\n";
foreach $p (sort { $a cmp $b } keys %paper_sizes) {
	printf "<option value='%s' %s>%s</option>\n",
		$p, $_[1]->{'paper'} eq $p ? 'selected' : '',
		$paper_sizes{$p};
	}
print "</select></td> </tr>\n";

print "<tr> <td><b>$text{'caldera_double'}</b></td>\n";
printf "<td><input type=radio name=double value=true %s> $text{'yes'}\n",
	$_[1]->{'double'} eq 'true' ? 'checked' : '';
printf "<input type=radio name=double value=false %s> $text{'no'}</td>\n",
	$_[1]->{'double'} eq 'true' ? '' : 'checked';

if ($found) {
	$_[1]->{'gsopts'} =~ s/\s*$found->{'gsoptions'}\s*//;
	}
print "<td><b>$text{'caldera_gsopts'}</b></td>\n";
printf "<td><input name=gsopts size=30 value='%s'></td> </tr>\n",
	$_[1]->{'gsopts'};

print "</table></td></tr>\n";

if ($gconfig{'os_version'} < 2.4) {
	# Uniprint driver options
	printf "<tr> <td valign=top><input type=radio name=mode value=3 %s> %s</td>\n",
		$mode == 3 ? 'checked' : '', $text{'caldera_uniprint'};
	print "<td><table width=100%>\n";

	print "<tr> <td valign=top><b>$text{'caldera_printer'}</b></td>\n";
	print "<td colspan=3><select name=uniprint size=5>\n";
	foreach $u (&list_uniprint()) {
		printf "<option value=%s %s>%s</option>\n",
			$u->[0], $u->[0] eq $_[1]->{'upp'} ? 'selected' : '',
			$u->[1];
		}
	closedir(DIR);
	print "</select></td> </tr>\n";

	print "<tr> <td><b>$text{'caldera_eof'}</b></td>\n";
	printf "<td><input type=radio name=ueof value=true %s> $text{'yes'}\n",
		$_[1]->{'eof'} eq 'true' ? 'checked' : '';
	printf "<input type=radio name=ueof value=false %s> $text{'no'}</td>\n",
		$_[1]->{'eof'} eq 'true' ? '' : 'checked';

	print "<td><b>$text{'caldera_paper'}</b></td> <td><select name=upaper>\n";
	foreach $p (sort { $a cmp $b } keys %paper_sizes) {
		printf "<option value='%s' %s>%s</option>\n",
			$p, $_[1]->{'paper'} eq $p ? 'selected' : '',
			$paper_sizes{$p};
		}
	print "</select></td> </tr>\n";

	print "<tr> <td><b>$text{'caldera_double'}</b></td>\n";
	printf "<td><input type=radio name=udouble value=true %s> $text{'yes'}\n",
		$_[1]->{'double'} eq 'true' ? 'checked' : '';
	printf "<input type=radio name=udouble value=false %s> $text{'no'}</td>\n",
		$_[1]->{'double'} eq 'true' ? '' : 'checked';

	print "</table></td></tr>\n";
	}

return <<EOF;
<script>
function setres(sel)
{
var idx = document.forms[0].gsdevice.selectedIndex;
var v = new String(document.forms[0].gsdevice.options[idx].value);
var vv = v.split(";");
var res = document.forms[0].res;
res.length = 0;
for(var i=1; i<vv.length; i++) {
	res.options[i-1] = new Option(vv[i], vv[i]);
	}
if (res.length > 0) {
	res.options[sel].selected = true;
	}
}
setres($select_res);
</script>
EOF
}

# parse_driver()
# Parse driver selection from %in and return a driver structure
sub parse_driver
{
if ($in{'mode'} == 0) {
	return { 'mode' => 0 };
	}
elsif ($in{'mode'} == 2) {
	$in{'program'} =~ /^(\S+)/ && -x $1 ||
		&error(&text('caldera_eprog', $in{'program'}));
	return { 'mode' => 2,
		 'file' => $in{'program'} };
	}
elsif ($in{'mode'} == 1) {
	# Normal ghostscript driver
	open(COAS, $config{'coas_printers'});
	local $plist = &parse_coas(COAS);
	close(COAS);
	$in{'gsdevice'} || &error($text{'caldera_edriver'});
	$in{'gsdevice'} =~ s/;(.*)$//;
	local ($p, $prn);
	foreach $p (values %$plist) {
		$prn = $p if ($p->{'description'} eq $in{'gsdevice'});
		}
	local $gsdevice = ref($prn->{'type'}) ? $prn->{'type'}->{'0'}
					      : $prn->{'type'},
	$gsdevice eq 'PostScript' || $in{'res'} ||
		&error($text{'caldera_eres'});
	if ($prn->{'gsoptions'}) {
		$in{'gsopts'} .= " ".$prn->{'gsoptions'};
		}
	return { 'mode' => 1,
		 'gsdevice' => $gsdevice,
		 'upp' => $prn->{'uniprint'},
		 'gsname' => $in{'gsdevice'},
		 'res' => $in{'res'},
		 'paper' => $in{'paper'},
		 'eof' => $in{'eof'},
		 'double' => $in{'double'},
		 'gsopts' => $in{'gsopts'} };
	}
else {
	# Uniprint ghostscript driver under 2.3
	$in{'uniprint'} || &error($text{'caldera_edriver'});
	return { 'mode' => 3,
		 'gsdevice' => 'uniprint',
		 'upp' => $in{'uniprint'},
		 'paper' => $in{'upaper'},
		 'eof' => $in{'ueof'},
		 'double' => $in{'udouble'} };
	}
}

# parse_coas(handle)
sub parse_coas
{
local $h = $_[0];
local (%rv, $_);
while(<$h>) {
	s/#.*$//g;
	s/\r|\n//g;
	if (/^\s*(\S+)\s+{/) {
		# start of a section
		local $k = $1;
		$rv{$k} = &parse_coas($h);
		}
	elsif (/^\s*}/) {
		# end of a section
		last;
		}
	elsif (/^\s*(\S+)\s+(.*)/) {
		# a value in a section
		$rv{$1} = $2;
		}
	}
return \%rv;
}

1;

