try:
    from Bio import SeqIO
except ImportError:
    import subprocess
    import sys
    print("⚠️ Biopython not found. Installing it now...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "biopython"])
    from Bio import SeqIO

from collections import defaultdict

from Bio import SeqIO

genes = defaultdict(list)

for record in SeqIO.parse("imgt_human_constant_regions.fasta", "fasta"):
    header = record.description.split("|")
    gene_name = header[1]  # e.g. IGHA1*01
    region = header[4]     # e.g. CH1, H-CH2, CH3-CHS, M
    genes[gene_name].append((region, str(record.seq)))

# # Sort and merge regions
order = ["CH1","H1","H-CH2","CH2","H2","CH3","H3","CH4","H4","CH3-CHS","CH4-CHS","CHS","M","M1","M2"]
filename = 'human_IG_C.fna'
with open(f"{filename}", "w") as out:
    for gene, parts in genes.items():
        parts.sort(key=lambda x: order.index(x[0]) if x[0] in order else 999)
        merged_seq = "".join(seq for _, seq in parts)
        out.write(f">{gene}\n{merged_seq}\n")

print(f"File merging complete and saved as: {filename}")
