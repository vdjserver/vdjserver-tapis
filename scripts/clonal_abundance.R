#!/usr/bin/env Rscript

# Immcantation clonal abundance
# clonal_abundance.R
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Part of the iReceptor+ platform
#
# Author: Scott Christley
# Copyright (C) 2021 The University of Texas Southwestern Medical Center
# Date: June 23, 2021
# 

suppressPackageStartupMessages(library("optparse"))
suppressPackageStartupMessages(library("alakazam"))
suppressPackageStartupMessages(library("shazam"))
suppressPackageStartupMessages(library("airr"))

# Define commmandline arguments
opt_list <- list(make_option(c("-d", "--db"), dest="DB",
                             help="Tabulated data file, in AIRR format (TSV)."),
                 make_option(c("-o", "--output"), dest="OUTFILE",
                             help="output filename prefix"))

# Parse arguments
opt <- parse_args(OptionParser(option_list=opt_list))

# Check input file
if (!("DB" %in% names(opt))) {
    stop("You must provide a database file with the -d option.")
}

# Check output file
if (!("OUTFILE" %in% names(opt))) {
    stop("You must provide an output filename prefix with the -o option.")
}

# Read rearrangement data
db <- airr::read_rearrangement(opt$DB)

clones <- countClones(db, group='repertoire_id', clone='clone_id', copy='duplicate_count')
write.table(clones, row.names=F, sep='\t', file=paste(opt$OUTFILE, '.count.tsv', sep=''))
clones <- estimateAbundance(db, group='repertoire_id', ci=0.95, nboot=200, clone='clone_id', copy='duplicate_count')
write.table(clones@abundance, row.names=F, sep='\t', file=paste(opt$OUTFILE, '.abundance.tsv', sep=''))
