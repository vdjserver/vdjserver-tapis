#!/usr/bin/env Rscript

# Alakazam AA properties
#
# Author: Scott Christley
# Date: Sep 3, 2020
# 

# based upon this script for parsing args with optparse
# https://bitbucket.org/kleinstein/immcantation/src/master/pipelines/shazam-threshold.R

suppressPackageStartupMessages(library("optparse"))
suppressPackageStartupMessages(library("alakazam"))
suppressPackageStartupMessages(library("airr"))

# Define commmandline arguments
opt_list <- list(make_option(c("-d", "--db"), dest="DB",
                             help="Tabulated data file, in AIRR format (TSV)."),
                 make_option(c("-o", "--output"), dest="OUTPUT",
                             help=paste("Output file to save data.")))

# Parse arguments
opt <- parse_args(OptionParser(option_list=opt_list))

# Check input file
if (!("DB" %in% names(opt))) {
    stop("You must provide a database file with the -d option.")
}

# Check output file
if (!("OUTPUT" %in% names(opt))) {
    stop("You must provide an output file with the -o option.")
}

# Read rearrangement data
db <- airr::read_rearrangement(opt$DB)

db_props <- aminoAcidProperties(db, seq='junction', trim=TRUE, label='cdr3')

airr::write_rearrangement(db_props, opt$OUTPUT)
