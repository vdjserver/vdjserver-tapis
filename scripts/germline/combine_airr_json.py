# --- Combine germline JSON files ---
import json
import glob
import os
import sys
import argparse
from Bio import SeqIO

import re



def check_c_gene_fasta(base_dir):
    VALID_NT = re.compile("^[ACGTURYSWKMBDHVN]+$", re.I)
    problems = []
    filename = f'{base_dir}/human_IGH_C.fasta'
    for rec in SeqIO.parse(filename, "fasta"):
        if "." in rec.seq or "-" in rec.seq:
            problems.append((rec.id, "contains gaps"))
        if not VALID_NT.match(str(rec.seq)):
            problems.append((rec.id, "invalid characters"))
        if len(rec.seq) < 200:
            problems.append((rec.id, "sequence too short for C gene"))
        print("C gene problems: ", problems)
    return problems

def mergeAirrJson(species_short, base_dir):
    # Look for germline JSON files (modify path if needed)
    json_files = glob.glob(f"{base_dir}/vdjserver_*_germline.airr.json")
    if not json_files:
        print("No germline JSON files found to merge — skipping.")
        sys.exit(0)

    combined = {"Info": None, "GermlineSet": []}

    for f in sorted(json_files):
        with open(f) as fh:
            data = json.load(fh)
            if combined["Info"] is None:
                combined["Info"] = data.get("Info", {})
            combined["GermlineSet"].extend(data.get("GermlineSet", []))

    out_json = f"{base_dir}/vdjserver_{species_short}_germline.airr.json"

    with open(out_json, "w") as out:
        json.dump(combined, out, indent=2)

    print(f"Combined {len(json_files)} germline JSON files into: {out_json}")
    
    
def geneExistence(base_dir):
    
    genes_ig_vdj = set()
    igvdj_file = f'{base_dir}/ReferenceDirectorySet/IG_VDJ.fna'
    
    for record in SeqIO.parse(f'{igvdj_file}', "fasta"):
        gene = record.id
        genes_ig_vdj.add(gene)
    
    genes_airr_json = set()
    
    with open(f"{base_dir}/vdjserver_germline.airr.json") as f:
        data = json.load(f)
        
    for germline_set in data.get("GermlineSet", []):
        for allele in germline_set.get("allele_descriptions", []):
            genes_airr_json.add(allele["label"])
    
    print(f"Total unique number of alleles in IG_VDJ.fna file {len(genes_ig_vdj)}")   
    print(f"Total unique number of alleles in GermlineSet file {len(genes_airr_json)}")
    
    only_in_fna = genes_ig_vdj - genes_airr_json
    only_in_json = genes_airr_json - genes_ig_vdj
    
    print("Only in FNA:", len(only_in_fna), '\n', sorted(only_in_fna))
    print("Only in JSON:", sorted(only_in_json))


def updateAirrAlleleLabels(base_dir):
    
    igvdj_file = f'{base_dir}/ReferenceDirectorySet/IG_VDJ.fna'
    json_file = f'{base_dir}/vdjserver_germline.airr.json'
    fna_genes = {}
    
    for record in SeqIO.parse(igvdj_file, "fasta"):
        fna_id = record.id
        json_id = fna_id
        if json_id.endswith("*00"):
            json_id = json_id[:-3]
        
        for locus in ["IGHV", "IGHD", "IGHJ", "IGKV", "IGKJ", "IGLV", "IGLJ"]:
            if json_id.startswith(locus + "0"):
                json_id = locus + json_id[len(locus) + 1:]
                break
    
        fna_genes[json_id] = fna_id
        
    with open(json_file) as f:
        data = json.load(f)
        
    updated = 0
    unmatched = []
    for germline_set in data.get("GermlineSet", []):
        for allele in germline_set.get("allele_descriptions", []):
            
            old_label = allele.get("label")
            if old_label in fna_genes:
                new_label = fna_genes[old_label]
                allele["label"] = new_label
                updated += 1
            else:
                unmatched.append(old_label)
                
    # Write updated JSON
    with open(json_file, "w") as f:
        json.dump(data, f, indent=2)
    
    print(f"Updated {updated} allele records.")
    
    if unmatched:
        print(f"WARNING: {len(unmatched)} JSON alleles could not be matched.")
        print("Unmatched:")
        for gene in sorted(set(unmatched)):
            print(f"  {gene}")
    
# # Remove Alleles that has _SC in them
# def removeSCGgenes(base_dir):
#     kept = 0
#     removed = 0
#     input_fna = f'{base_dir}/IG_VDJ.fna'
#     output_fna = f'{base_dir}/IG_VDJ_updated.fna'
#     with open(output_fna, "w") as out_handle:
#         for record in SeqIO.parse(input_fna, "fasta"):
#             gene = record.id
#             if gene.endswith("_SC"):
#                 removed += 1
#                 continue
#             SeqIO.write(record, out_handle, "fasta")
#             kept += 1

#     print(f"Kept records: {kept}")
#     print(f"Removed _SC records: {removed}")
    
    
    
# Remove Alleles that has _SC in them
def removeSCGgenes(species_short, base_dir):
    kept = 0
    removed = 0
    input_fna = f'{base_dir}/{species_short}_IGH_C.fasta'
    output_fna = f'{base_dir}/{species_short}_IGH_C_updated.fasta'
    with open(output_fna, "w") as out_handle:
        for record in SeqIO.parse(input_fna, "fasta"):
            gene = record.id
            if gene.endswith("_SC"):
                removed += 1
                continue
            SeqIO.write(record, out_handle, "fasta")
            kept += 1

    print(f"Kept records: {kept}")
    print(f"Removed _SC records: {removed}")
    
    
if (__name__=="__main__"):
    
    parser = argparse.ArgumentParser(description='Functions for merging and checking the airr json files.')
    parser.add_argument('--mergeAirrJson', help='Merge Airr Json Files', nargs=2, metavar=('species_short', 'base_dir'))
    parser.add_argument('--geneExistence', help='Check if genes exists in both IG_VDJ and airr json files', nargs=1, metavar=('base_dir'))
    parser.add_argument('--removeSCGgenes', help='Remove _SC genes from the file', nargs=2, metavar=('species_short', 'base_dir'))
    parser.add_argument('--CheckCGene', help='Check C genes in human', nargs=1, metavar=('base_dir'))
    parser.add_argument('--updateAirrAlleleLabels', help='Update AIRR allele labels', nargs=1, metavar=('base_dir'))

    args = parser.parse_args()

    if args.mergeAirrJson:
        metadata = mergeAirrJson(args.mergeAirrJson[0], args.mergeAirrJson[1])
    if args.geneExistence:
        metadata = geneExistence(args.geneExistence[0])
    if args.removeSCGgenes:
        metadata = removeSCGgenes(args.removeSCGgenes[0], args.removeSCGgenes[1])
    if args.CheckCGene:
        metadata = check_c_gene_fasta(args.CheckCGene[0])
    if args.updateAirrAlleleLabels:
        updateAirrAlleleLabels(args.updateAirrAlleleLabels[0])
        
