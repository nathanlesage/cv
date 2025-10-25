#!/usr/bin/env perl
# $Id: install-menu-text.pl 65951 2023-02-20 10:13:03Z siepo $
#
# Copyright 2007-2022 Norbert Preining, Karl Berry
# Copyright 2007-2008 Reinhard Kotucha
# This file is licensed under the GNU General Public License version 2
# or any later version.
#
# This file implements the text based menu system for the TeX Live installer.

use vars qw(@::end_install_hook
            $::opt_no_cls $::opt_select_repository $::run_menu);

our %vars;
our $opt_in_place;
our $tlpdb;
our @media_available;
our $media;
our $previoustlpdb;
our @collections_std;
our $texlive_release;

my $MENU_CONTINUE = -1;
our $MENU_INSTALL = 0;
our $MENU_ABORT   = 1;
our $MENU_QUIT    = 2;


my $RETURN = $MENU_CONTINUE;

my $portable_toggled = 0;
my $ptoggle_alert = "\n".
    "   !! Portable option changed;\n" .
    "   !! Directories have been reinitialized!\n";

# some strings to describe the different meanings of tlpdbopt_file_assoc
$::fileassocdesc[0] = __("None");
$::fileassocdesc[1] = __("Only new");
$::fileassocdesc[2] = __("All");

$::deskintdesc[0] = __("None");
$::deskintdesc[1] = __("Menu shortcuts");
if (wndws()) { $::deskintdesc[2] = __("Launcher"); }

sub clear_screen {
  return 0 if ($::opt_no_cls);
  system (unix() ? 'clear' : 'cls');
}

sub string_to_list {
  my $string=shift;
  return split(//, $string);
}

sub button { # for main menu: 1 char
  my $val=shift;
  my $vals=shift; # array ref to descriptions of possible values
  if (defined $vals) {
    return "[$val]";
  } else { # just yes/no
    return ($val)? '[X]':'[ ]';
  }
}

sub obutton { # for options menu: more chars allowed
  my $val=shift;
  my $vals=shift; # array ref to descriptions of possible values
  $vals = [' ', 'X'] unless defined $vals;
  return "[$$vals[$val]]";
}

sub hbar {
  return '=' x79, "\n";
}

sub toggle {
  my $var=shift;
  my $vals=shift; # array ref to descriptions of possible values
  $vals = [' ', 'X'] unless defined $vals;
  my $n_vals = @$vals;
  $vars{$var} += 1;
  $vars{$var} = 0 unless $vars{$var} < $n_vals;
}

sub menu_head {
  my $text = shift;
  clear_screen;
  print hbar(), "$text\n\n";
}

sub other_options {
  my @options=@_;
  my %opts=(
    '-' => 'deselect all',
    '+' => 'select all',
    'R' => 'return to main menu',
    'P' => 'save installation profile to \'texlive.profile\' and exit',
    'Q' => 'quit'
      );

  $opts{'I'}=$vars{'instopt_portable'} ? 'start portable installation' :
    'start installation to hard disk';

  print "\nActions:";
  if ($options[$#options] eq 'diskspace') {
    pop @options;
    calc_depends ();
    print " (disk space required: $vars{'total_size'} MB)";
  }
  print "\n";

  for my $option (@options) {
    if (defined $opts{"$option"}) {
      printf " <%s> %s\n", $option, $opts{$option};
    } else {
      die "other_options: $opts{$option} undefined.\n";
    }
  }
}

sub prompt {
  my $prompt = shift;
  print "\n$prompt: ";
  my $answer = <STDIN>;
  $answer = "q" if !defined($answer);
  chomp($answer);
  return "$answer";
}

# The menu loop. A menu is a function.  Its return value is a
# reference to another menu or to itself.
sub run_menu_text {
  my (@args) = @_;
  my $default = 0;
  # select mirror if -select-mirror is given
  if ($::opt_select_repository) {
    # network is always available
    my @mirror_list = TeXLive::TLUtils::create_mirror_list();
    print "Please select a repository:\n";
    print "Network repositories:" if ($#media_available >= 0);
    my @sel_to_index;
    my $selind = 0;
    # this is for 0 mirror.ctan.org, but it is printed last!
    push @sel_to_index, 0;
    $selind++;
    for my $i (0..$#mirror_list) {
      if ($mirror_list[$i] !~ m/^  /) {
        print "\n$mirror_list[$i]\n";
      } else {
        print " " if 1 <= $selind && $selind <= 9; # align
        print "[$selind] $mirror_list[$i]\n";
        push @sel_to_index, $i;
        $selind++;
      }
    }
    print "----\n";
    print "[0] default mirror   https://mirror.ctan.org\n";
    my $local_ind = "a";
    if ($#media_available >= 0) {
      print "Local repositories:\n";
      # we have some local media present, propose to use it
      for my $l (@media_available) {
        my ($a, $b) = split ('#', $l);
        if ($a eq 'local_compressed') {
          print "[$local_ind] compressed archive at $b\n";
          $default = $local_ind;
          #$local_ind = chr(ord($local_ind)+1);
          $local_ind++;
        } elsif ($a eq 'local_uncompressed') {
          print "[$local_ind] uncompressed archive at $b\n";
          $default = $local_ind;
          $local_ind++;
        } elsif ($a eq 'NET') {
          print "[$local_ind] cmd line repository: $b\n";
          $default = $local_ind;
          $local_ind++;
        } else {
          warn "$0: Unknown media $l";
        }
      }
    }
    print "[q] quit\n";
    $selind--;
    my $selstr = "Your selection ";
    if ($local_ind ne "a") {
      # we got at least some local repository
      if ($local_ind eq "b") {
        $selstr .= "(a,0-$selind,q)";
        $local_ind = chr(ord($local_ind)-1);
      } else {
        # that does not work!!!
        #$local_ind--;
        $local_ind = chr(ord($local_ind)-1);
        $selstr .= "(a-$local_ind,0-$selind,q)";
      }
    }
    $selstr .= " [$default]: ";
    my $got_answer = 0;
    my $ans = undef;
    while (!defined($ans)) {
      print $selstr;
      $ans = readline(*STDIN);
      if (!defined($ans)) {
        print "Please select `q' to quit the program!\n";
      } else {
        chomp($ans);
        $ans = $default if ($ans eq "");
        if ($ans =~ m/^[0-9]+$/) {
          if (0 <= $ans && $ans <= $selind) {
            my $mfull;
            if ($ans == 0) {
              $::init_remote_needed = 'ctan';
            } else {
              # only if something else but the predefined mirror is selected
              # we something here
              $mfull = TeXLive::TLUtils::extract_mirror_entry($mirror_list[$sel_to_index[$ans]]);
              print "selected mirror: ", $mfull, "\n";
              $::init_remote_needed = $mfull;
            }
          }
        } elsif ($ans =~ m/^[a-$local_ind]$/) {
          my $i = ord($ans) - ord('a');
          my $t = $media_available[$i];
          $t =~ s/^[^#]*#//;
          $::init_remote_needed = $t;
        } elsif ($ans eq 'q' || $ans eq 'Q') {
          print "Goodbye.\n";
          exit 0;
        } else {
          print "Not a valid answer: $ans.\n";
          $ans = undef;
        }
      }
    } 
  }

  # run remote init
  if (!do_remote_init($::init_remote_needed)) {
    warn "\n";
    warn "Please select a different mirror!  See info above.\n";
    print STDERR "Press Enter to exit... ";
    my $ans = readline (*STDIN);
    exit (1);
  }

  # the text mode installer does not take look at any argument
  # except -old-installation-found.
  while (@args) {
    my $f = shift @args;
    if ($f =~ m/^-old-installation-found=(.*)$/) {
      my $dn = $1;
      print "\nAn existing installation of TeX Live has been found in $dn\n";
      print "
If you want its selection of schemes/collections and various options
to be used, press `y', otherwise anything else.

Import settings from previous TeX Live installation: (y/n): ";
      chomp(my $yn = <STDIN>);
      if (defined $yn && $yn =~ m/^y$/i) {
        import_settings_from_old_tlpdb($dn);
      }
    }
  }
  my $menu=\&main_menu;
  while ($RETURN == $MENU_CONTINUE) {
    $menu=$menu->();
  }
  return($RETURN);
}
$::run_menu = \&run_menu_text;

sub binary_menu {
  my %command=(
    'self' => \&binary_menu,
    'R' => \&main_menu,
    'Q' => \&quit
      );

  my @binaries;
  my @keys=string_to_list "abcdefghijklmopstuvwxyz";
  my $index=0;
  my %keyval;
  my $selected_platform;

  menu_head "Available platforms:";

  foreach my $key (keys %vars) {
    if ($key =~ /binary_(.*)/) {
      push @binaries, $1;
    }
  }
  
  @binaries=sort TeXLive::TLUtils::sort_archs @binaries;

  foreach my $binary (@binaries) {
    printf "   %s %s %s (%s)\n", $keys[$index],
           button($vars{"binary_$binary"}),
           platform_desc($binary),
           "$binary";
    $keyval{"$keys[$index]"} = "binary_$binary";
    ++$index;
  }
  other_options qw(- + R Q diskspace);

  my $answer = prompt 'Enter letter(s) to (de)select platforms';

  my @keystrokes=string_to_list $answer;

  foreach my $keystroke (@keystrokes) {
    if ($keystroke eq '-') {
      for my $binary (@binaries) {
        $vars{"binary_$binary"}=0 if defined $vars{"binary_$binary"};
      }
    }
    if ($keystroke eq '+') {
      for my $binary (@binaries) {
        $vars{"binary_$binary"}=1 if defined $vars{"binary_$binary"};
      }
    }
    if (defined $keyval{$keystroke}) {
      toggle "$keyval{$keystroke}";
    } elsif (!defined $command{"\u$answer"}) {
      print "Unknown command: $answer\n\n";
    }
  }
  if ($vars{"binary_windows"}) {
    $vars{"collection-wintools"} = 1;
  } else {
    $vars{"collection-wintools"} = 0;
  }
  if (defined $command{"\u$answer"}) {
    return $command{"\u$answer"}->();
  } else {
    return $command{'self'}->();
  }
}


sub scheme_menu {
  my %command=(
    'self' => \&scheme_menu,
    'R' => \&main_menu,
    'Q' => \&quit
      );

  my @schemes;
  my @keys=string_to_list "abcdefghijklmnopstuvwxyz";
  my %keyval;
  my $index=0;

  menu_head 'Select scheme:';

  @schemes = schemes_ordered_for_presentation();
  foreach my $pkg (@schemes) {
    $vars{"$pkg"}=($vars{'selected_scheme'} eq $pkg)? 1:0;
  }
  push @schemes, "scheme-custom";

  foreach my $scheme (@schemes) {
    $keyval{$keys[$index]}="$scheme";
    if ($scheme ne "scheme-custom") {
      my $tlpobj = $tlpdb->get_package("$scheme");
      printf " %s %s %s\n", $keys[$index], button($vars{"$scheme"}),
             $tlpobj->shortdesc;
    } else {
      printf " %s %s custom selection of collections\n",
             $keys[$index], button($vars{'selected_scheme'} eq "scheme-custom");
    }
    ++$index;
  }

  select_scheme($vars{'selected_scheme'});

  if ($vars{"binary_windows"}) {
    $vars{"collection-wintools"} = 1;
  } else {
    $vars{"collection-wintools"} = 0;
  }

  other_options qw(R Q diskspace);
  my $answer = prompt 'Enter letter to select scheme';

  if (defined $keyval{"$answer"}) {
    $vars{'selected_scheme'}=$keyval{"$answer"};
    select_scheme($vars{'selected_scheme'});
    return $command{'self'}->();
  }
  if (defined $command{"\u$answer"}) {
    return $command{"\u$answer"}->();
  } else {
    print "Unknown command: $answer\n\n";
    return $command{'self'}->();
  }
}


sub collection_menu {
  my %command=(
    'self' => \&collection_menu,
    'R' => \&main_menu,
    'Q' => \&quit
      );

  my @collections;
  my @keys=string_to_list "abcdefghijklmnopstuvwxyzABCDEFGHIJKLMNOPSTUVWXYZ";
  my %keyval;
  my $index=0;
  my @coll_short_desc;
  my @coll_long_desc;

  menu_head 'Select collections:';

  @collections=sort @collections_std;

  foreach my $collection (@collections) {
    next if ($collection eq 'collection-perl');
    my $tlpobj = $tlpdb->get_package("$collection");
    if (length $tlpobj->shortdesc>30) {
      push @coll_long_desc, $collection;
    } else {
      push @coll_short_desc, $collection;
    }
  }
  my $singlecolumn_index=@coll_short_desc-1;

##<cols=2>
  my $lines=@coll_short_desc/2;
  ++$lines if (@coll_short_desc%2);
  for (0..$lines-1) {
    $index=$_;
    my $collection=$coll_short_desc[$index];
    my $tlpobj = $tlpdb->get_package("$collection");
    $keyval{$keys[$index]}="$collection";
    printf " %s %s %-33s", $keys[$index], button($vars{"$collection"}),
    substr($tlpobj->shortdesc,0,33);
    if (defined $coll_short_desc[$index+$lines]) {
      my $collection=$coll_short_desc[$index+$lines];
      my $tlpobj=$tlpdb->get_package("$collection");
      $keyval{$keys[$index+$lines]}="$collection";
      printf " %s %s %-32s\n", $keys[$index+$lines],
      button($vars{"$collection"}), substr($tlpobj->shortdesc,0,32);
    } else {
      print "\n";
    }
  }
##</cols=2>
  $index=$singlecolumn_index;
#  print "\n$index\n\n";
  foreach my $collection (@coll_long_desc) {
    my $tlpobj=$tlpdb->get_package("$collection");
    $keyval{$keys[$index+1]}="$collection";
    printf " %s %s %s\n", $keys[$index+1], button($vars{"$collection"}),
    $tlpobj->shortdesc;
    ++$index;
  }
##</cols=1>

  other_options qw(- + R Q diskspace);
  my $answer = prompt 'Enter letter(s) to (de)select collection(s)';

  my @keystrokes=string_to_list $answer;

  foreach my $keystroke (@keystrokes) {
    if ($keystroke eq '-') {
      for my $collection (@collections) {
        $vars{"$collection"}=0 if defined $vars{"$collection"};
      }
    }
    if ($keystroke eq '+') {
      for my $collection (@collections) {
        $vars{"$collection"}=1 if defined $vars{"$collection"};
      }
    }
    if (defined $keyval{$keystroke}) {
      toggle "$keyval{$keystroke}";
    } elsif (!defined $command{"\u$answer"}) {
      print "Unknown command: $answer\n\n";
    }
  }

  if (defined $command{"\u$answer"}) {
    # if we play around with collections we also select custom-scheme
    # but we do not switch back to originally afterwards, too complicated
    # to be done
    select_scheme("scheme-custom");
    return $command{"\u$answer"}->();
  } else {
    return $command{'self'}->();
  }
}


sub directories_menu
{
  my %command=(
    'self' => \&directories_menu,
    'R' => \&main_menu,
    'Q' => \&quit
      );

  menu_head "Directories customization:";
  if (!TeXLive::TLUtils::texdir_check($vars{'TEXDIR'}, 1)) {
    print "!! The default location as given below is forbidden or
!! can't be written to.
!! Either change the destination directory using <1> or create it
!! outside this script.
";
  }
  my $texmfdir = $vars{'TEXDIR'} .
    ($vars{'TEXDIR'} =~ /\/$/ ? 'texmf-dist' : '/texmf-dist');
  if (!$opt_in_place) {
    print <<"EOF";
 <1> TEXDIR:         $vars{'TEXDIR'}
     main tree:      $texmfdir
EOF
  } else {
    print <<"EOF";
     TEXDIR:         $vars{'TEXDIR'}
     main tree:      $texmfdir
EOF
  }
  if (!$vars{'instopt_portable'}) {
    print <<"EOF";

 <2> TEXMFLOCAL:     $vars{'TEXMFLOCAL'}
 <3> TEXMFSYSVAR:    $vars{'TEXMFSYSVAR'}
 <4> TEXMFSYSCONFIG: $vars{'TEXMFSYSCONFIG'}

 <5> TEXMFVAR:       $vars{'TEXMFVAR'}
 <6> TEXMFCONFIG:    $vars{'TEXMFCONFIG'}
 <7> TEXMFHOME:      $vars{'TEXMFHOME'}

EOF

    if (wndws()) {
      print " Note: ~ will expand to %USERPROFILE%\n";
    } else {
      print " Note: ~ will expand to \$HOME (or to %USERPROFILE% on Windows)\n";
    }
  }

  other_options qw(R Q);
  my $answer = prompt 'Enter command';

  if ("\u$answer" eq '1' and !$opt_in_place) {
    print "New value for TEXDIR [$vars{'TEXDIR'}]: ";
    $answer = &input_dirname ();
    # update free space information
    if ($answer ne $vars{'TEXDIR'}) {
      $vars{'free_size'} = TeXLive::TLUtils::diskfree($answer);
    }
    $vars{'TEXDIR'} = $answer if $answer ne "";
    my $texdirnoslash;
    if ($vars{'TEXDIR'}=~/^(.*)\/$texlive_release$/) {
      $texdirnoslash = $1;
      $vars{'TEXMFLOCAL'}="$texdirnoslash/texmf-local";
      $vars{'TEXMFSYSVAR'}="$texdirnoslash/$texlive_release/texmf-var";
      $vars{'TEXMFSYSCONFIG'}="$texdirnoslash/$texlive_release/texmf-config";
    } elsif ($vars{'TEXDIR'}=~/^(.*)$/) {
      $texdirnoslash = $1;
      $texdirnoslash =~ s!/$!!;
      $vars{'TEXMFLOCAL'}="$texdirnoslash/texmf-local";
      $vars{'TEXMFSYSVAR'}="$texdirnoslash/texmf-var";
      $vars{'TEXMFSYSCONFIG'}="$texdirnoslash/texmf-config";
    }
    return $command{'self'};

  } elsif ("\u$answer" eq '2' and !$vars{'instopt_portable'}) {
    print "New value for TEXMFLOCAL [$vars{'TEXMFLOCAL'}]: ";
    $answer = &input_dirname ();
    $vars{'TEXMFLOCAL'} = $answer if $answer ne "";
    return $command{'self'};

  } elsif ("\u$answer" eq '3' and !$vars{'instopt_portable'}) {
    print "New value for TEXMFSYSVAR [$vars{'TEXMFSYSVAR'}]: ";
    $answer = &input_dirname ();
    $vars{'TEXMFSYSVAR'} = $answer if $answer ne "";
    return $command{'self'};

  } elsif ("\u$answer" eq '4' and !$vars{'instopt_portable'}) {
    print "New value for TEXMFSYSCONFIG [$vars{'TEXMFSYSCONFIG'}]: ";
    $answer = &input_dirname ();
    $vars{'TEXMFSYSCONFIG'} = $answer if $answer ne "";
    return $command{'self'};

  } elsif ("\u$answer" eq '5' and !$vars{'instopt_portable'}) {
    print "New value for TEXMFVAR [$vars{'TEXMFVAR'}]: ";
    $answer = &input_dirname ("noexpansion");
    $vars{'TEXMFVAR'} = $answer if $answer ne "";
    return $command{'self'};

  } elsif ("\u$answer" eq '6' and !$vars{'instopt_portable'}) {
    print "New value for TEXMFCONFIG [$vars{'TEXMFCONFIG'}]: ";
    $answer = &input_dirname ("noexpansion");
    $vars{'TEXMFCONFIG'} = $answer if $answer ne "";
    return $command{'self'};

  } elsif ("\u$answer" eq '7' and !$vars{'instopt_portable'}) {
    print "New value for TEXMFHOME [$vars{'TEXMFHOME'}]: ";
    $answer = &input_dirname ("noexpansion");
    $vars{'TEXMFHOME'} = $answer if $answer ne "";
    return $command{'self'};
  }

  if (defined $command{"\u$answer"}) {
    return $command{"\u$answer"}->();
  } else {
    print "Unknown command: $answer\n\n";
    return $command{'self'}->();
  }
}


# Helper function to read a directory name and clean it up.
# Unless NO_EXPANSION is true, convert to absolute path.
#
sub input_dirname
{
  my $noexpansion = shift;
  chomp (my $answer = <STDIN>);
  return "" if $answer eq "";

  $answer =~ s!\\!/!g if wndws();  # switch to forward slashes

  if (!$noexpansion) {
    $answer = TeXLive::TLUtils::expand_tilde($answer);
  }

  if ($answer !~ m/^~/) {
    # relative paths are unlikely to work in texmf.cnf, et al.,
    # and don't have any apparent practical use.  Convert to absolute.
    if (! File::Spec->file_name_is_absolute($answer)) {
      $answer = TeXLive::TLUtils::tl_abs_path($answer);
      $answer = "" unless defined $answer;
    }
  }
  return $answer;
}


$vars{'page'}=0;

sub html2text {
  my $filename=shift;
  my @text;
  open IN, "$filename";
  @all_lines=<IN>;
  close IN;
  chomp @all_lines;

  my $itemcnt;
  my $ordered_list=0;
  my $h1_indent=25;
  my $h2_indent=3;
  my $h3_indent=6;

  for (@all_lines) {
    next if /DOCTYPE/;
    next if /<!--/;
    next if /<title/i;
    next if /<\/?body/i;
    next if /<\/?html/i;
    next if /<\/?head/i;
    next if /<\/?meta/i;
    next if /^\s*$/; # ignore empty lines

    s/<i>/"/gi;  s/<\/i>/"/gi;  # italics
    s/<tt>/'/gi; s/<\/tt>/'/gi; # typewriter
    s/<p>.*//gi;                # paragraphs
    s/<\/ul>.*//gi;             # unsorted lists
    s/<\/ol>.*//gi;             # ordered lists
    s/&mdash;/--/gi;            # mdash
    s/&lt;/</gi; s/&gt;/>/gi;   # < and >
    if (/<h1>(.*?)<\/h1>/i) {
      push @text, " " x $h1_indent. "$1\n";
      push @text, " " x $h1_indent. "=" x (length $1). "\n";
      push @text, "\n";
    } elsif (/<h2>(.*?)<\/h2>/i) {
      push @text, "\n";
      push @text, " " x $h2_indent. "$1\n";
      push @text, " " x $h2_indent. "~" x (length $1). "\n";
      push @text, "\n";
    } elsif (/<h3>(.*?)<\/h3>/i) {
      push @text, "\n";
      push @text, " " x $h3_indent. "$1\n";
      push @text, " " x $h3_indent. "-" x (length $1). "\n";
      push @text, "\n";
    } elsif (/<ol>/i) {
      $ordered_list=1;
      $itemcnt=1;
    } elsif (/<ul>/i) {
      $ordered_list=0;
    } elsif (/^\s*<li>\s*(.*)/) {
      if ($ordered_list) {
        push @text, "\n";
        push @text, " $itemcnt. $1\n";
        ++$itemcnt;
      } else {
        push @text, "\n";
        push @text, " * $1\n";
      }
    } else {
      push @text, "$_\n";
    }
  }
  return @text;
}


# dumping the html doc to stdout does not seem very helpful,
# and did not work for years with no one noticing, so this
# function is no longer used.
sub help_menu {
  my %command=(
    'self' => \&help_menu,
    'R' => \&main_menu,
    'Q' => \&quit
      );
  my $installer_help = "notused/tlpkg/installer/install-tl.html";

  clear_screen;

  my @text=html2text ($installer_help);
  my $lines=(@text);
  my $overlap=3;
  my $lps=32; # lines per screen - overlap
  my $firstline=$vars{'page'}*$lps;
  my $lastline=$firstline+$lps+$overlap;
  my $line=0;
#  print "<<<$firstline>>> <<<$lastline>>>\n";
  for (@text) {
    print "$_" if ($line>=$firstline and $line<=$lastline);
    ++$line;
  }
  print "\n", hbar,
  "  <T> top  <N> next page  <P> previous page  <R> return"
      . "  <Q> quit         --", $vars{'page'}+1, "--\n";

  my $answer = prompt 'Enter command';

  if ("\u$answer" eq 'T') {
    $vars{'page'}=0;
    return $command{'self'};

  } elsif ("\u$answer" eq 'N') {
    $vars{'page'}+=1 unless $lastline>$lines;
    return $command{'self'};

  } elsif ("\u$answer" eq 'P') {
    $vars{'page'}-=1 if $vars{'page'}>=1;
    return $command{'self'};

  } elsif (defined $command{"\u$answer"}) {
    return $command{"\u$answer"};

  } else {
    print "Unknown command: $answer\n\n";
    return $command{'self'};
  }
}


sub options_menu {
  my $b_path=obutton($vars{'instopt_adjustpath'});
  my $b_doc=obutton($vars{'tlpdbopt_install_docfiles'});
  my $b_src=obutton($vars{'tlpdbopt_install_srcfiles'});
  my $b_fmt=obutton($vars{'tlpdbopt_create_formats'});
  my $b_letter=obutton($vars{'instopt_letter'});
  my $b_adjustrepo=obutton($vars{'instopt_adjustrepo'});
  my $b_deskint=obutton(
    $vars{'tlpdbopt_desktop_integration'}, \@::deskintdesc);
  my $b_admin=obutton($vars{'tlpdbopt_w32_multi_user'});
  my $b_addoneditor=obutton($vars{'collection-texworks'});
  my $b_restricted=obutton($vars{'instopt_write18_restricted'});

  my $sys_bin=$vars{'tlpdbopt_sys_bin'};
  my $sys_man=$vars{'tlpdbopt_sys_man'};
  my $sys_info=$vars{'tlpdbopt_sys_info'};

  my $t_sys_bin=($vars{'instopt_adjustpath'})? $vars{'tlpdbopt_sys_bin'}:'';
  my $t_sys_man=($vars{'instopt_adjustpath'})? $vars{'tlpdbopt_sys_man'}:'';
  my $t_sys_info=($vars{'instopt_adjustpath'})? $vars{'tlpdbopt_sys_info'}:'';

  my %command=(
    'self' => \&options_menu,
    'R' => \&main_menu,
    'Q' => \&quit
      );

  clear_screen;
  menu_head "Options customization:";

  print <<"EOF";
 <P> use letter size instead of A4 by default: $b_letter
 <E> execution of restricted list of programs: $b_restricted
 <F> create all format files:                  $b_fmt
EOF
;
  if ($vars{'doc_splitting_supported'} and !$opt_in_place) {
    print " <D> install font/macro doc tree:              $b_doc\n";
  }
  if ($vars{'src_splitting_supported'} and !$opt_in_place) {
    print " <S> install font/macro source tree:           $b_src\n";
  }
  if (!$vars{'instopt_portable'}) {
    if (unix() || $::opt_all_options) {
      print <<"EOF";
 <L> create symlinks in standard directories:  $b_path
            binaries to: $t_sys_bin
            manpages to: $t_sys_man
                info to: $t_sys_info
EOF
;
    } else {
      print <<"EOF";
 <L> adjust registry entry for path:           $b_path
EOF
;
    }
    if ((wndws() && !$vars{'instopt_portable'}) || $::opt_all_options) {
      print " <M> Start menu shortcuts / launcher:          ".obutton(
          $vars{'tlpdbopt_desktop_integration'}, \@::deskintdesc)."\n";
      print " <N> update file associations:                 ".obutton(
        $vars{'tlpdbopt_file_assocs'}, \@::fileassocdesc)."\n";
      if ($::opt_all_options || TeXLive::TLWinGoo::admin()) {
        # if we are admin we allow normal user installation, too
        print " <U> make installation available to all users: $b_admin\n";
      }
    }
  }
  if (wndws() || $::opt_all_options) {
    print " <W> install TeXworks front end:               $b_addoneditor\n";
  }
  if ($media ne "NET") {
    print " <Y> after install, set CTAN as source for package updates: $b_adjustrepo\n";
  }
  other_options qw(R Q diskspace);
  my $answer = prompt 'Enter command';

  # instopt_adjustpath

  if (unix()) {
    if (("\u$answer" eq 'L') and !$vars{'instopt_portable'}) {
      my $home = TeXLive::TLUtils::get_user_home();
      toggle 'instopt_adjustpath';
      if ($vars{'instopt_adjustpath'}) {
        print "New value for binary directory [$sys_bin]: ";
        chomp($answer=<STDIN>);
        $vars{'tlpdbopt_sys_bin'} =  "$answer" if (length $answer);
        $vars{'tlpdbopt_sys_bin'} =~ s@\\@/@g if (wndws());
        $vars{'tlpdbopt_sys_bin'} =~ s/^~/$home/;
        if ($vars{'tlpdbopt_sys_bin'}=~/^(.*)\/bin$/) {
          $vars{'tlpdbopt_sys_man'}="$1/man";
          $vars{'tlpdbopt_sys_info'}="$1/info";
        }
        print "New value for man directory    [$vars{'tlpdbopt_sys_man'}]: ";
        chomp($answer=<STDIN>);
        $vars{'tlpdbopt_sys_man'}="$answer" if (length $answer);
        $vars{'tlpdbopt_sys_man'} =~ s@\\@/@g if (wndws());
        $vars{'tlpdbopt_sys_man'} =~ s/^~/$home/;

        print "New value for info directory   [$vars{'tlpdbopt_sys_info'}]: ";
        chomp($answer=<STDIN>);
        $vars{'tlpdbopt_sys_info'}="$answer" if (length $answer);
        $vars{'tlpdbopt_sys_info'} =~ s@\\@/@g if (wndws());
        $vars{'tlpdbopt_sys_info'} =~ s/^~/$home/;
      }
      return $command{'self'};
    }
  } else {
    if (("\u$answer" eq 'L') and !$vars{'instopt_portable'}) {
      my $home = TeXLive::TLUtils::get_user_home;
      toggle 'instopt_adjustpath';
      return $command{'self'};
    }
  }

#  # tlpdbopt_desktop_integration, tlpdbopt_file_assocs
#
#  if (wndws() || $::opt_all_options) {
#    if ("\u$answer" eq 'M' and !$vars{'instopt_portable'}) {
#      toggle 'tlpdbopt_desktop_integration';
#      return $command{'self'};
#
#    } elsif ("\u$answer" eq 'N' and !$vars{'instopt_portable'}) {
#      print "New value for file_assocs:\n";
#      print "  0 -- don't tweak the file associations\n";
#      print "  1 -- only add new file associations, don't overwrite old ones\n";
#      print "  2 -- always create file associations to TeX Live programs\n";
#      print "New value for file_assocs [$vars{'tlpdbopt_file_assocs'}]: ";
#      chomp (my $a = <STDIN>);
#      if ($a eq "0" || $a eq "1" || $a eq "2") {
#        $vars{'tlpdbopt_file_assocs'} = $a;
#      }
#      return $command{'self'};
#
#    } elsif ("\u$answer" eq 'U' and !$vars{'instopt_portable'}) {
#      toggle 'tlpdbopt_w32_multi_user';
#      return $command{'self'};
#    }
#  }

  # other options

  if (("\u$answer" eq 'M') && !$vars{'instopt_portable'}) {
    toggle ('tlpdbopt_desktop_integration', \@::deskintdesc);
    return $command{'self'};

  } elsif (("\u$answer" eq 'N') && !$vars{'instopt_portable'}) {
    toggle ('tlpdbopt_file_assocs', \@::fileassocdesc);
    return $command{'self'};

  } elsif ("\u$answer" eq 'P') {
    toggle 'instopt_letter';
    return $command{'self'};

  } elsif ("\u$answer" eq 'F') {
    toggle 'tlpdbopt_create_formats';
    return $command{'self'};

  } elsif ("\u$answer" eq 'E') {
    toggle 'instopt_write18_restricted';
    return $command{'self'};

  } elsif ("\u$answer" eq 'S' and !$opt_in_place) {
    toggle 'tlpdbopt_install_srcfiles';
    return $command{'self'};

  } elsif ("\u$answer" eq 'D' and !$opt_in_place) {
    toggle 'tlpdbopt_install_docfiles';
    return $command{'self'};

  } elsif (defined $command{"\u$answer"}) {
    return $command{"\u$answer"};

  } elsif (("\u$answer" eq 'W') && ($::opt_all_options || wndws()) &&
       !$opt_in_place ) {
    toggle 'collection-texworks';
    return $command{'self'};

  } elsif ("\u$answer" eq 'Y' and $media ne "NET") {
    toggle 'instopt_adjustrepo';
    return $command{'self'};

  } else {
    print "Unknown or unsupported command: $answer\n\n";
    return $command{'self'};
  }
}


sub quit {
  exit 0;
  $RETURN = $MENU_QUIT;
}

sub do_install {
  my $reserve = 100;
  my $doit = 1;
  if ($vars{'free_size'} > 0
      && $vars{'free_size'} + $reserve < $vars{'total_size'}) { 
    print STDERR <<"EOF";
*** WARNING ****************************************************
The installation requires $vars{'total_size'}M of disk space
but only $vars{'free_size'}M is available.

You probably want to either clean up the destination filesystem,
or choose a different installation location,
or reduce what gets installed.

Press Enter to return to the menu, or i to install anyway.
****************************************************************
EOF
    my $ans = readline (*STDIN);
    $doit = 0;
    chomp($ans);
    if ($ans eq "i" or $ans eq "I") {
      $doit = 1;
    }
  }
  if ($doit) {
    # set env variable to make install-tl not trip over
    $ENV{'TEXLIVE_INSTALL_NO_DISKCHECK'} = 1;
    $RETURN = $MENU_INSTALL;
  } else {
    main_menu();
  }
}

sub toggle_portable {
  if ($vars{'instopt_portable'}) {
    $vars{'instopt_portable'} = 0;
    $vars{'tlpdbopt_desktop_integration'} = 0;
    $vars{'instopt_adjustpath'} = 0;
    $vars{'tlpdbopt_file_assocs'} = 0;
    $vars{'tlpdbopt_w32_multi_user'} = 0;
  } else {
    $vars{'instopt_portable'} = 1;
    $vars{'tlpdbopt_desktop_integration'} = 1;
    $vars{'instopt_adjustpath'} = 1;
    $vars{'tlpdbopt_file_assocs'} = 1;
    $vars{'tlpdbopt_w32_multi_user'} = 1;
  }
  $portable_toggled = 1;
  set_texlive_default_dirs(); # this sub tests for portable and in_place
  main_menu;
}

sub callback_save_profile {
  create_profile("texlive.profile");
  print "Installation profile saved to 'texlive.profile', exiting.\n";
  exit(0);
}

sub main_menu {
  my $this_platform=platform_desc($vars{'this_platform'});

  my $b_path=button($vars{'instopt_adjustpath'});
  my $b_doc=button($vars{'tlpdbopt_install_docfiles'});
  my $b_src=button($vars{'tlpdbopt_install_srcfiles'});
  my $b_fmt=button($vars{'tlpdbopt_create_formats'});
  my $b_letter=button($vars{'instopt_letter'});
  my $b_deskint=button($vars{'tlpdbopt_desktop_integration'}, \@::deskintdesc);
  if (wndws()) {
    my $b_fileassoc=button($vars{'tlpdbopt_file_assocs'}, \@::fileassocdesc);
  }
  my $b_admin=button($vars{'tlpdbopt_w32_multi_user'});
  my $b_addoneditor=button($vars{'collection-texworks'});
  my $b_restricted=button($vars{'instopt_write18_restricted'});
  my $b_adjustrepo=button($vars{'instopt_adjustrepo'});

  my $warn_nobin;

  $warn_nobin=set_install_platform;

  $vars{'n_systems_selected'}=0;
  $vars{'n_collections_selected'}=0;
  foreach my $key (keys %vars) {
    if ($key=~/^binary.*/) {
      ++$vars{'n_systems_selected'} if $vars{$key}==1;
    }
    if ($key=~/^collection/) {
      ++$vars{'n_collections_selected'} if $vars{$key}==1;
    }
  }
  calc_depends();

  my %command = (
    'self' => \&main_menu,
    'D' => \&directories_menu,
    'I' => \&do_install,
    'O' => \&options_menu,
    'Q' => \&quit,
    'V' => \&toggle_portable,
    'P' => \&callback_save_profile,
  );
  if (!$opt_in_place) {
    $command{'B'} = \&binary_menu if unix();
    $command{'C'} = \&collection_menu;
    $command{'S'} = \&scheme_menu;
  }

  clear_screen;
  my $freestring = ($vars{'free_size'} >= 0 ? " (free: $vars{'free_size'} MB)" : "");
  print <<"EOF";
======================> TeX Live installation procedure <=====================

======>   Letters/digits in <angle brackets> indicate   <=======
======>   menu items for actions or customizations      <=======
= help>   https://tug.org/texlive/doc/install-tl.html   <=======

 Detected platform: $this_platform
 $warn_nobin
EOF

  if (!$opt_in_place) {
    print <<"EOF";
 <B> set binary platforms: $vars{'n_systems_selected'} out of $vars{'n_systems_available'}

 <S> set installation scheme: $vars{'selected_scheme'}

 <C> set installation collections:
     $vars{'n_collections_selected'} collections out of $vars{'n_collections_available'}, disk space required: $vars{'total_size'} MB$freestring
EOF

  }
    if ($portable_toggled) {
      print $ptoggle_alert;
      $portable_toggled = 0;
    }
    print <<"EOF";

 <D> set directories:
   TEXDIR (the main TeX directory):
EOF

  if (TeXLive::TLUtils::texdir_check($vars{'TEXDIR'}, 1)) {
    print "     $vars{'TEXDIR'}\n";
  } else {
    print "     !! default location: $vars{'TEXDIR'}\n";
    print "     !! is not writable or not allowed, please select a different one!\n";
  }
  print <<"EOF";
   TEXMFLOCAL (directory for site-wide local files):
     $vars{'TEXMFLOCAL'}
   TEXMFSYSVAR (directory for variable and automatically generated data):
     $vars{'TEXMFSYSVAR'}
   TEXMFSYSCONFIG (directory for local config):
     $vars{'TEXMFSYSCONFIG'}
   TEXMFVAR (personal directory for variable and automatically generated data):
     $vars{'TEXMFVAR'}
   TEXMFCONFIG (personal directory for local config):
     $vars{'TEXMFCONFIG'}
   TEXMFHOME (directory for user-specific files):
     $vars{'TEXMFHOME'}

EOF

print <<"EOF";
 <O> options:
   $b_letter use letter size instead of A4 by default
   $b_restricted allow execution of restricted list of programs via \\write18
   $b_fmt create all format files
EOF

  if (!$opt_in_place) {
    if ($vars{'doc_splitting_supported'}) {
      print "   $b_doc install macro/font doc tree\n";
    }
    if ($vars{'src_splitting_supported'}) {
      print "   $b_src install macro/font source tree\n";
    }
  }
  if (wndws()) {
    if (!$vars{'instopt_portable'}) {
      print "   $b_path adjust search path\n";
      print "   $b_deskint add menu items, shortcuts, etc.\n";
      print "   [$vars{'tlpdbopt_file_assocs'}] update file associations\n";
      if (admin()) {
        print "   $b_admin make installation available to all users\n";
      }
    }
    print "   $b_addoneditor install TeXworks front end\n";
  }

  print "   $b_path create symlinks to standard directories\n"
    unless ($vars{'instopt_portable'} || wndws());
  
  print "   $b_adjustrepo after install, set CTAN as source "
          . "for package updates\n"
    unless ($media eq 'NET');

  if ($vars{'instopt_portable'}) {
    print "\n <V> set up for regular installation to hard disk\n";
  } else {
    print "\n <V> set up for portable installation\n";
  }

  other_options qw(I P Q);
  my $answer = prompt 'Enter command';

  if (defined $command{"\u$answer"}) {
    return $command{"\u$answer"};
  } else {
    print "Unknown command: $answer\n\n";
    return $command{'self'};
  }
}
# needs a terminal 1 for require to succeed!
1;

__END__

### Local Variables:
### perl-indent-level: 2
### tab-width: 2
### indent-tabs-mode: nil
### End:
# vim:set tabstop=2 expandtab: #
