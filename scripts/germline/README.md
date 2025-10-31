# Building the IG germline database
Run the docker command and then use run the **build_human_IG_germline_db.sh** file to generate the database.

```
docker run -it -v $(pwd):/data:z immcantation/suite:4.5.0 bash
./build_human_IG_germline_db.sh
```
This will create and save the database archive as: **db.2025.10.31.tgz**
---
---
# Now for the detailed and long version of getting the constant region and merging it is below.

# Building and Integrating Human IG Constant-Region (C-Gene) Database for IgBLAST

This document describes how to curate *Homo sapiens* immunoglobulin constant-region (C-gene) sequences from the IMGT/GENE-DB database, process them into a single merged FASTA file, and integrate the resulting database into **IgBLAST** for C-gene annotation.

## Step 1: Retrieve Constant Region Sequences from IMGT
1. Go to the [IMGT/GENE-DB](https://www.imgt.org/genedb/) website.  
2. Under the **IDENTIFICATION** section, configure the following:
   - **Species:** *Homo sapiens*  
   - **Gene type:** *Constant*  
   - **Functionality:** *Functional*  
   - **Molecular component:** *IG*
3. Click **Submit**.  

IMGT will display:
- **Number of resulting genes:** 17  
- **Number of resulting alleles:** 129  

4. From the **List of resulting genes**, click **Select All**.  
5. Under **IMGT/GENE-DB allele reference sequences in FASTA format**, select:
   - **F + ORF + in-frame P nucleotide sequences**  
6. Click **Submit** to view the output.  

You should now see about **598 FASTA sequences**.  
Copy all sequences into a file named:

imgt_human_constant_regions.fasta


## Step 2: Merge and Clean the C-Gene FASTA

IMGT provides separate fragments (regions) for each allele — for example, **CH1**, **H-CH2**, **CH3-CHS**, **M**, etc.  
These fragments must be merged to form a complete C-gene entry for each allele.

Use the provided Python script to merge fragments per gene:

```
python merge_c_genes.py
```

This script will:

* Group sequences by allele name
* Sort regions in the correct order
* Concatenate sequences to form one complete gene

The output file will be:

```
human_IG_C.fna
```

Each entry in this `.fna` file now represents a **complete constant region** for one allele.

## Step 3: Build a BLAST Database for IgBLAST

Move the merged FASTA/fna file into your IgBLAST database directory (e.g., `germline/human/ReferenceDirectorySet/` where your other germline files are stored).

To build the database, use the **Immcantation Docker environment**:

```
docker run -it -v $(pwd):/data:z immcantation/suite:4.5.0 bash
```

Then inside the container, create a BLAST database: (e.g. for C genes)

```
makeblastdb -parse_seqids -dbtype nucl -in human_IG_C.fna -out human_IG_C
```

This will generate all the necessary `.nhr`, `.nin`, and `.nsq` etc. files that IgBLAST uses.


## Step 4: Run IgBLAST with the Custom C-Gene Database

To enable C-gene annotation, include the additional parameter:

```
-c_region_db human_IG_C
```

Here’s the full example command:

```
igblastn \
    -germline_db_V human_IG_V \
    -germline_db_D human_IG_D \
    -germline_db_J human_IG_J \
    -c_region_db human_IG_C \
    -auxiliary_data human_IG.aux \
    -custom_internal_data human_IG.ndm \
    -domain_system imgt \
    -num_threads 6 \
    -query HD13M.fasta \
    -out HD13M.fmt7
```



## Notes and Recommendations

* The `-c_region_db` parameter is required for IgBLAST to annotate **constant-region genes**.
* You do **not** need a separate `.aux` or `.ndm` file for the C-gene database — those are only used for V(D)J domain mappings.
* Ensure all database files (V, D, J, C) are in the same directory for IgBLAST to locate them easily.
* If you modify or update your FASTA file later, remember to rerun `makeblastdb`.

---

## Expected Output

When configured correctly, IgBLAST will now report **C-gene assignments** (e.g., IGHA1, IGHG2, IGHM, etc.) in your results, alongside the standard V, D, and J gene annotations.

