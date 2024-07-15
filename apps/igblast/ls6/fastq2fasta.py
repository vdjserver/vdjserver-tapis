
from Bio import SeqIO
import argparse
import re # for search
import os # for rename

parser = argparse.ArgumentParser(description='Process some integers.')
parser.add_argument('-i','--input', required=True, dest='fastq_in', type=str, help='Input FASTA filename')
parser.add_argument('-o','-output', required=True, dest='fasta_out', type=str, help='Output FASQ filename')
args = parser.parse_args()

# open file handles
fastq_fh = open(args.fastq_in, 'r')
fasta_fh = open(args.fasta_out, 'w')

# sniff file
if (re.search('^>', fastq_fh.readline())):
    print("Input file has a FASTQ extension, but the contents appear to be in FASTA format.")
    print("Changing file extension without modifying contents")
    fastq_fh.close()
    fasta_fh.close()
    os.rename(args.fastq_in, args.fasta_out)
else:
    fastq_fh.seek(0)
    # setup fastq iterator
    fastq_iterator = SeqIO.parse(fastq_fh, "fastq")
    
    # output FASTA
    SeqIO.write(fastq_iterator, fasta_fh, "fasta")
    
    # close file handles
    fastq_fh.close()
    fasta_fh.close()
