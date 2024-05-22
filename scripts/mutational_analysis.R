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
                 make_option(c("-m", "--model"), dest="MODEL",
                             help="targeting model"),
                 make_option(c("-o", "--output"), dest="OUTFILE",
                             help="output filename prefix"))

# Parse arguments
opt <- parse_args(OptionParser(option_list=opt_list))

# Check input file
if (!("DB" %in% names(opt))) {
    stop("You must provide a database file with the -d option.")
}

# Check targeting model
if (!("MODEL" %in% names(opt))) {
    stop("You must specify targeting model with the -m option.")
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

# selection pressure
if (opt$MODEL == "HH_S5F") {
   tm = HH_S5F
}
if (opt$MODEL == "MK_RS5NF") {
   tm = MK_RS5NF
}

# IMGT_V
clones <- collapseClones(db, cloneColumn="clone_id", sequenceColumn="sequence_alignment", germlineColumn="germline_alignment_d_mask", regionDefinition=IMGT_V, method="thresholdedFreq", minimumFrequency=0.6, includeAmbiguous=FALSE, breakTiesStochastic=FALSE, nproc=1)

observed <- observedMutations(clones, sequenceColumn="clonal_sequence", germlineColumn="clonal_germline", regionDefinition=IMGT_V, nproc=1)
expected <- expectedMutations(observed, sequenceColumn="clonal_sequence", germlineColumn="clonal_germline", targetingModel=tm, regionDefinition=IMGT_V, nproc=1)
baseline <- calcBaseline(expected, testStatistic="focused", regionDefinition=IMGT_V, nproc=1)
group.v <- groupBaseline(baseline, groupBy="repertoire_id")

# IMGT_V_BY_REGIONS
clones <- collapseClones(db, cloneColumn="clone_id", sequenceColumn="sequence_alignment", germlineColumn="germline_alignment_d_mask", regionDefinition=IMGT_V_BY_REGIONS, method="thresholdedFreq", minimumFrequency=0.6, includeAmbiguous=FALSE, breakTiesStochastic=FALSE, nproc=1)

observed <- observedMutations(clones, sequenceColumn="clonal_sequence", germlineColumn="clonal_germline", regionDefinition=IMGT_V_BY_REGIONS, nproc=1)
expected <- expectedMutations(observed, sequenceColumn="clonal_sequence", germlineColumn="clonal_germline", targetingModel=tm, regionDefinition=IMGT_V_BY_REGIONS, nproc=1)
baseline <- calcBaseline(expected, testStatistic="focused", regionDefinition=IMGT_V_BY_REGIONS, nproc=1)
group.a <- groupBaseline(baseline, groupBy="repertoire_id")

group.stats <- rbind(group.v@stats, group.a@stats)
write.table(group.stats, row.names=F, sep='\t', file=paste(opt$OUTFILE, '.selection.tsv', sep=''))
