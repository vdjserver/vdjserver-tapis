#!/usr/bin/perl

use Getopt::Std;
use IO::File;

if ($#ARGV < 1) {

	print STDOUT "splitfasta.pl -s query -f myfasta.fa -o directory/ -r 1000", "\n";
	print STDOUT "  -f: input FASTA\n"; 
	print STDOUT "  -o: output directory\n"; 
	print STDOUT "  -s: output prefix\n";
	print STDOUT "  -r: number of records\n";
	exit 1;
}

my %opts = ();
getopts ('s:f:o:r:', \%opts);
my $stem   = $opts{'s'} || 'query';
my $fasta  = $opts{'f'};
my $outdir = $opts{'o'} || '.';
my $number = $opts{'r'} || 1000;

print STDOUT "splitfasta.pl -f $fasta -o $outdir -n $number\n";

# Redfine the record separator to > for reading FASTA file
# This is 20x faster than Bio::SeqIO, though probably less
# fault-tolerant. However, FASTA that come from
# automated sources like sequencers are all very clean
# and standards-compliant. I forsee no problem, and if there
# is, its better to make a transformation on the 
# source file than in this code.

# mkdir
mkdir($outdir) unless(-d $outdir);

my $old_input_rec_sep = $/;
$/ = ">";

open (FASTA, $fasta) or die("Couldn't find $fasta");
my $count_rec = 0;
my $file_count = 0;
my $fname = $stem . "." . $file_count . ".fasta";
#open (FOUT, ">$outdir/$fname");

while (my $rec = <FASTA>) {
	
	unless ($rec =~ /^>$/) {
		chomp($rec);
		
		my $seqout = ">" . $rec;
		
		if ($count_rec == 0) {
			my $fname = $stem . "." . $file_count . ".fasta";
			open (FOUT, ">$outdir/$fname");
		}

		print FOUT $seqout;

		$count_rec++;
		if ($count_rec >= $number) {
			close FOUT;
			
			$file_count++;
			#print STDOUT "Opening new query file $file_count ($count_rec)\n";
			$count_rec=0;
		}
	
	}

}
close FOUT;

$/ = $old_input_rec_sep;

print STDOUT "splitfasta DONE\n";

