import sys
import airr
import json
import re

def get_subgroup(allele_description):
    if allele_description['subgroup_designation']:
        return allele_description['locus'] + allele_description['sequence_type'] + allele_description['subgroup_designation']

def get_gene(allele_description):
    if(allele_description['subgroup_designation'] and allele_description['gene_designation']):
        return allele_description['locus'] + allele_description['sequence_type'] + allele_description['subgroup_designation'] + '-' + allele_description['gene_designation']

def get_allele(allele_description):
    return allele_description['label']

def natural_sort_key(text):
    """Convert a string into a list of mixed integers and strings for sorting."""
    if text is None:
        return (1, "")  # Return tuple that sorts None values last
    return [int(c) if c.isdigit() else c for c in re.split(r'(\d+)', text)]

def main():
    of_interest = ['TRA', 'TRB', 'TRG', 'TRD', 'IGH', 'IGK', 'IGL']
    new_data = {}

    with open(sys.argv[1], 'r', encoding='utf-8') as handle:
        germline = json.load(handle)

    for gs in germline['GermlineSet']:
        if gs['locus'] in of_interest:
            subgroup_v, gene_v, allele_v = [], [], []
            subgroup_j, gene_j, allele_j = [], [], []

            new_data[gs['locus']] = {}

            for allele_description in gs['allele_descriptions']:
                if allele_description['sequence_type'] == 'V':
                    if get_subgroup(allele_description): subgroup_v.append(get_subgroup(allele_description))
                    if get_gene(allele_description): gene_v.append(get_gene(allele_description))
                    if get_allele(allele_description): allele_v.append(get_allele(allele_description))
                if allele_description['sequence_type'] == 'J':
                    if get_subgroup(allele_description): subgroup_j.append(get_subgroup(allele_description))
                    if get_gene(allele_description): gene_j.append(get_gene(allele_description))
                    if get_allele(allele_description): allele_j.append(get_allele(allele_description))
                    
            new_data[gs['locus']] = {
                "V" : {
                    "subgroup" : sorted(list(set(subgroup_v)), key=natural_sort_key),
                    "gene" : sorted(list(set(gene_v)), key=natural_sort_key),
                    "allele" : sorted(list(set(allele_v)), key=natural_sort_key)
                },
                "J" : {
                    "subgroup" : sorted(list(set(subgroup_j)), key=natural_sort_key),
                    "gene" : sorted(list(set(gene_j)), key=natural_sort_key),
                    "allele" : sorted(list(set(allele_j)), key=natural_sort_key)
                }
            }
    json_txt = json.dumps(new_data, indent=4)

    if sys.argv[2]:
        out_file_name = sys.argv[2]
    else:
        out_file_name = "germline-labels.js"
    with open(out_file_name, "w") as file:
        file.write('"use strict";\n')
        file.write('export default ')
        file.write(json_txt)
        file.write(";\n")
    
if __name__ == '__main__':
    main()