#!/usr/bin/perl
# Phrack epub generator
# Author:   albino <albinowax@eml.cc>, http://skeletonscribe.blogspot.com
# License:  Apache License (http://www.apache.org/licenses/LICENSE-2.0)
# Created: 2012

# What this code does:
# For every issue of phrack
#     Generate a table of contents
#     If it isn't already in /localcontent, download & extact it to there
# 
#     For each line of each article:
#         Preprocess to convert to xhtml (see filter())
#         Guess whether the line was broken because it was too long, or for formatting reasons (see formatn) #This is where things go Wrong
# Zip the result into an epub

#use LWP::Simple;
use Archive::Extract;
use strict;
use utf8;

my $issueno = 1;
my $out = "";
my $i;
my $next; 
my $cur; 
my $file;
my $title;
my $rootdir = ".";
my $localcontent = "$rootdir/localcontent";
my $bookdir = "$rootdir/ebookcontents";
my $epubTOC = '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="Phrack Magazine"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
  </head>
  <docTitle>
    <text>Phrack Magazine</text>
  </docTitle>
<navMap>';
my $navID = 0;
my $toc = '<?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" 
    "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Phrack Magazine</title>
  </head>
<body><table><tr>';
while (1) { #for every issue
    $i=0;

    #read in and parse the issue's Table of Contents
    my $contents;
    #unless(-e "$localcontent/toc-$issueno"){
    #    my $rc = getstore("https://phrack.org/issues/$issueno/1", "$localcontent/toc-$issueno");
    #    if (is_error($rc)) {
    #        die "getstore of <$issueno> failed with $rc";
    #    }
    #}

    {
        local $/;
        open (my $TABLEOFCONTENTS, "$localcontent/toc-$issueno");
        $contents = <$TABLEOFCONTENTS>;
    }
    $contents =~ m/<table.*?class="tissue"(.*?)<\/table>/s;
    my @titles = ($1 =~ m/^.*?article">(.*?)<.*?$/msg);
    print "xxx";
    print join(", ",@titles);
    my @authors = ($contents =~ m/^.*?align="right">(.*?)<.*?$/msg);
    last unless @titles;

    #Update/generate the new table of contents
    $toc .= "<td><a href='#p$issueno\'>$issueno</a></td>";
    $epubTOC .= "\n".'<navPoint id="navPoint-'.$navID.'" playOrder="'.$navID.'"><navLabel><text>'.$issueno.'</text></navLabel><content src="phrack.html#p'.$issueno.'"/>';
    unless ($issueno % 10) { $toc .= '</tr><tr>';}
    $out .= "<h1 id='p$issueno\'>$issueno</h1><ul>";
    foreach $title (@titles){
	$i++;
        $navID++;
	$out .= "<li><a href='#i$issueno".'p'.$i."'>$title</a> by "
                .@authors[$i-1]."</li>";
        $epubTOC .= "\n\t".'<navPoint id="navPoint-'.$navID.'" playOrder="'.$navID.'"><navLabel><text>'.$title.'</text></navLabel><content src="phrack.html#i'.$issueno.'p'.$i.'"/></navPoint>';
    }
    $epubTOC .= "</navPoint>";
    $out .= "</ul>";

    $i=0;
    foreach $title (@titles){ #for every article in the issue

        $i++;

        #get the full article text
        $file = getArticle($issueno, $i, $localcontent); 
        open(ARTICLE, $file) or die "Couldn't obtain issue $issueno article $i";
        $cur = <ARTICLE>;
        $out .= "<h2 class='chapter' id='i".$issueno."p".$i."'>$title</h2>\n";
	$next = "";
	my $tgz = 0;
        my $maxlen = 30;
        
	while (<ARTICLE>){ #for each line of the article
            $next = $_;
            if (length($next) > $maxlen){
                $maxlen = length($next);
                if($maxlen > 80){
                    $maxlen = 80;
                }
            }
            
            #skip if it looks like tgz
	    if ($tgz) {
		$tgz = not $next =~ m/^`$/;
		next;
	    }
	    $tgz = $next =~ m/^M'XL|^UEsDBA|^M1TE&|^M\("`\@/;
          
	    #decide whether it's code or not & format accordingly
            my $altlen = altlength($cur, $next);
            if (formatn($cur, $next, $maxlen)){   
                $cur = filter($cur);
		$cur =~ s/\n$/ /; 	#strip newline
		$cur =~ s/&#8209; $//; 	#remove forced hyphens
	    }
	    else{
                $cur = filter($cur);
		$cur =~ s/(\s)*\n//; 	#strip trailing whitespace
		$cur.= "<br\/>\n";
	    }
	    $cur =~ s/^(\s)*//;         #strip leading whitespace
	    $out .= '<!--'.$altlen.'|'.($maxlen-15)."-->".$cur;
	    $cur = $next;
	}
    $out .= "<br\/>\n";
    }

    $issueno++;
    $navID++;
}
$out = $toc ."</tr></table><div>" . $out. "</div></body></html>";
open(my $outfile, ">$bookdir/phrack.html") or die $_;
print $outfile $out;
$epubTOC .= "</navMap></ncx>";
open(my $outfile, ">$bookdir/toc.ncx") or die $_;
print $outfile $epubTOC;
print `zip -Xr9D $rootdir/phrack.epub mimetype $bookdir/* -x .DS_Store`;
print 'Done';



sub getArticle{
    my($issueno, $i, $localcontent) = @_;
    #unless(-e "$localcontent/phrack$issueno.tar.gz"){
    #getstore("https://archives.phrack.org/tgz/phrack$issueno.tar.gz", "$localcontent/phrack$issueno.tar.gz");
        print "Downloading $issueno\n";
        #my $ae = Archive::Extract->new( archive => "$localcontent/phrack$issueno.tar.gz" );
        #my $ok = $ae->extract(to=>"$localcontent/");
        #if($issueno eq 66) {`mv $localcontent/phrack66 $localcontent/66`;}
        #}
    $file = sprintf("%s/%s/%s.txt",$localcontent, $issueno, $i);
    #($file) = glob $file."*";

    print $file;
    return $file;
}


sub formatn{
    my($cur, $next, $maxlen) = @_;#count whitespace in line
    if($cur =~ /^}|\/\/|\/\*|\*\/|[^a-zA-Z0-9]{30,}/){ #if it looks like code
        return $next =~ /^$/;
    }
    if($cur =~ /^$/ and $next =~ /^$/){
        return 1;
    }
    if($next =~ /^$/ or $cur =~ /^$/ or $next =~ /[^a-zA-Z0-9]{30,}/){
        return 0;
    }
#     my $lead = $cur =~ m/^(\s*)/ && length($1); #count leading whitespace
#     my $nextlead = $next =~ m/^(\s*)/ && length($1); #count leading whitespace
#     if ($nextlead > 5 && $lead - 3 > $nextlead){ 	#try to detect headings in indented sections
#         return $next =~ /^$/;
#     }
#     if ($next < 5 && $nextlead > 5){ 	#probably a paragraph/indented section!
#         return $next =~ /^$/;
#     }
    my $len = altlength($cur, $next);
    return ($len>$maxlen-15) | $cur =~ /^$/;#5
}


sub altlength{
my($cur, $next) = @_;
$cur =~ s/[\s]+$//;                          #strip trailing chars
$next =~ m/([\s]*[^\s&\n]*)/;                #grab first word of next line
return length($cur) + length($1);
}


sub filter{ 
$_ = shift;
#s/^(\s)*//;				  #strip leading whitespace
s/([^a-zA-Z0-9]{40})[^a-zA-Z0-9]{1,}/\1/; #reduces probable seperators to 40 chars
s/&/&amp;/g;
s/-/&#8209;/g;				  #stops hyphens causing linebreaks (whose idea was it to overload hyphens anyway?)
s/</&lt;/g;
s/>/&gt;/g;
s/([^[:ascii:]])/'&#' . ord($1) . ';'/ge;
s/[^\x0D\x0A\x20-\x7F]//g;
#s/^$/<br\/>/;
return $_
}
