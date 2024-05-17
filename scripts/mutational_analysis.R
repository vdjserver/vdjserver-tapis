#!/usr/bin/env Rscript

# Alakazam mutational analysis
# mutational_analysis.R
#
# VDJServer Analysis Portal
# VDJServer Tapis applications
# https://vdjserver.org
#
# Part of the iReceptor+ platform
#
# Author: Scott Christley
# Copyright (C) 2021 The University of Texas Southwestern Medical Center
# Date: Dec 23, 2020
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

db.om <- observedMutations(db, sequenceColumn='sequence_alignment', germlineColumn='germline_alignment_d_mask', regionDefinition=IMGT_V_BY_SEGMENTS, frequency=FALSE, nproc=1)
airr::write_rearrangement(db.om, file=paste(opt$OUTFILE, '.summary.mutations.airr.tsv', sep=''))
db.fom <- observedMutations(db, sequenceColumn='sequence_alignment', germlineColumn='germline_alignment_d_mask', regionDefinition=IMGT_V_BY_SEGMENTS, frequency=TRUE, nproc=1)
db.fom2 <- observedMutations(db.fom, sequenceColumn='sequence_alignment', germlineColumn='germline_alignment_d_mask', regionDefinition=IMGT_V_BY_REGIONS, frequency=TRUE, nproc=1)
airr::write_rearrangement(db.fom2, file=paste(opt$OUTFILE, '.frequency.summary.mutations.airr.tsv', sep=''))

db.om2 <- observedMutations(db.om, sequenceColumn='sequence_alignment', germlineColumn='germline_alignment_d_mask', regionDefinition=IMGT_V_BY_CODONS, frequency=FALSE, nproc=1)
airr::write_rearrangement(db.om2, file=paste(opt$OUTFILE, '.mutations.airr.tsv', sep=''))
