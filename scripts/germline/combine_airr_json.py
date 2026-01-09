# --- Combine germline JSON files ---
import json
import glob
import os
import sys
import argparse
from Bio import SeqIO


species_short = sys.argv[1]
base_dir = sys.argv[2]


def mergeAirrJson(species_short, base_dir):
    # Look for germline JSON files (modify path if needed)
    json_files = glob.glob(f"{base_dir}/ReferenceDirectorySet/*_germline.airr.json")
    print(f"{base_dir}/ReferenceDirectorySet/")
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
    out_json1 = f"{base_dir}/vdjserver_{species_short}_germline.airr.json"
    out_json2 = f"{base_dir}/vdjserver_germline.airr.json"
    
    with open(out_json1, "w") as out:
        json.dump(combined, out, indent=2)
    with open(out_json2, "w") as out:
        json.dump(combined, out, indent=2)
    print(f"Combined {len(json_files)} germline JSON files into: {out_json1} and {out_json2}")
    
    
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

    
# Remove Alleles that has _SC in them
def removeSCGgenes(base_dir):
    kept = 0
    removed = 0
    input_fna = f'{base_dir}/IG_VDJ.fna'
    output_fna = f'{base_dir}/IG_VDJ_updated.fna'
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
    parser.add_argument('--removeSCGgenes', help='Remove _SC genes from IG_VDJ file', nargs=1, metavar=('base_dir'))

    args = parser.parse_args()

    if (args):
        if args.mergeAirrJson:
            metadata = mergeAirrJson(args.mergeAirrJson[0], args.mergeAirrJson[1])
        if args.geneExistence:
            metadata = geneExistence(args.geneExistence[0])
        if args.removeSCGgenes:
            metadata = removeSCGgenes(args.removeSCGgenes[0])
