#
# fix germline issues for human
# Subgroup designation and gene designation had issues.
# https://vdjserver.org
#
# Author: Tanzira Najnin
# Copyright (C)  The University of Texas Southwestern Medical Center
# Date: Jun 17, 2026
#


import pandas as pd
import json
import glob
import sys

def getSubgroup(allele_description):
    if allele_description['locus'] is None:
        print('ERROR: locus is None')
        print(allele_description)
    if allele_description['sequence_type'] is None:
        print('ERROR: sequence_type is None')
        print(allele_description)
    if allele_description['subgroup_designation'] is None:
        return allele_description['locus'] + allele_description['sequence_type']
    else:
        return allele_description['locus'] + allele_description['sequence_type'] + allele_description['subgroup_designation']

def getGene(allele_description):
    n = getSubgroup(allele_description)
    if allele_description['gene_designation'] is None:
        return n
    else:
        if allele_descriptions['functional'] == False:
            return n + '/' + allele_description['gene_designation']
        else:
            return n + '-' + allele_description['gene_designation']

def getAllele(allele_description):
    n = getGene(allele_description)
    if allele_description['allele_designation'] is None:
        print('ERROR: allele_designation is None')
        print(allele_description)
    return n + '*' + allele_description['allele_designation']


file_path = 'db.2019.01.23/germline/human/'

json_files = glob.glob(f"{file_path}/*_germline.airr.json")
print(f"{json_files}")
if not json_files:
    print("No germline JSON files found to merge — skipping.")
    sys.exit(0)

for f in sorted(json_files):
    total_false = 0
    total_true = 0
    total_TR_true = 0
    total_TR_false = 0
    i = 0
    with open(f) as fh:
        print(f)
        data = json.load(fh)
        for germline_set in data.get("GermlineSet", []):
            for allele_descriptions in germline_set.get("allele_descriptions", []):
                i+=1
                locus = allele_descriptions.get('locus', None)
                gene_designation = allele_descriptions.get('gene_designation', None)
                sequence_type = allele_descriptions.get('sequence_type', None)
                subgroup_designation = allele_descriptions.get('subgroup_designation', None)
                allele_designation = allele_descriptions.get('allele_designation', None)
                label = allele_descriptions.get('label', None)
                
                if locus and "IG" in locus:
                    if sequence_type == 'V':
                        if subgroup_designation and gene_designation:
                            if "-" in gene_designation:
                                left, right = gene_designation.split("-", 1)
                                allele_descriptions['gene_designation'] = right
                                # if left.endswith("D"):
                                #     subgroup_designation += "D"
                                #     allele_descriptions['subgroup_designation'] = subgroup_designation
                                    
                            if "/" in gene_designation:
                                left, right = gene_designation.split("/", 1)
                                allele_descriptions['functional'] = False
                                allele_descriptions['gene_designation'] = right
                                
                    if sequence_type == 'D' or sequence_type == 'J':
                        if subgroup_designation is None:
                            allele_descriptions['subgroup_designation'] = gene_designation
                            allele_descriptions['gene_designation'] = None
                            
                        if subgroup_designation and gene_designation:
                            if "-" in gene_designation:
                                left, right = gene_designation.split("-", 1)
                                
                                allele_descriptions['gene_designation'] = right
                            if "/" in gene_designation:
                                left, right = gene_designation.split("/", 1)
                                allele_descriptions['gene_designation'] = right
                                allele_descriptions['functional'] = False
    
                    allele = getAllele(allele_descriptions)
                    if label != allele:
                        total_false += 1
                        # print(label, allele, label == allele)
                    else:
                        total_true += 1
                
                elif locus and "TR" in locus:
                    
                    if sequence_type == 'V':
                        if subgroup_designation and gene_designation:
                            if subgroup_designation == gene_designation:
                                allele_descriptions['gene_designation'] = None
                                
                            if "-" in gene_designation:
                                left, right = gene_designation.split("-", 1)
                                allele_descriptions['gene_designation'] = right

                            if "/" in gene_designation:
                                left, right = gene_designation.split("/", 1)
                                allele_descriptions['functional'] = False
                                allele_descriptions['gene_designation'] = right
                                    
                    if sequence_type == 'D' or sequence_type == 'J':
                        if subgroup_designation is None:
                            if "-" in gene_designation:
                                left, right = gene_designation.split("-", 1)
                                
                                allele_descriptions['gene_designation'] = right
                                allele_descriptions['subgroup_designation'] = left
                            else:
                                allele_descriptions['subgroup_designation'] = gene_designation
                                allele_descriptions['gene_designation'] = None
                            
                        if subgroup_designation and gene_designation:
                            if subgroup_designation == gene_designation:
                                allele_descriptions['gene_designation'] = None
                                
                            if "-" in gene_designation:
                                left, right = gene_designation.split("-", 1)
                                allele_descriptions['gene_designation'] = right
                                
                            if "/" in gene_designation:
                                left, right = gene_designation.split("/", 1)
                                allele_descriptions['gene_designation'] = right
                                allele_descriptions['functional'] = False

                    if label == 'TRAV38-2/DV8*01':
                        allele_descriptions['gene_designation'] = '2/DV8'
                        allele_descriptions['functional'] = True
                        
                    allele = getAllele(allele_descriptions)
                    if label != allele:
                        total_TR_false += 1
                        print(label, allele, label == allele)
                    else:
                        total_TR_true += 1
                        
        print("Total IG false: ", total_false)
        print("Total IG true: ", total_true)
        
        print("total_TR false: ", total_TR_false)
        print("total_TR true: ", total_TR_true)
        print("total number of allele descriptions: ", i)

        out_file = f.replace("_germline.airr.json", "_updated_germline.airr.json")
        with open(out_file, "w") as out_fh:
            json.dump(data, out_fh, indent=2)

                
