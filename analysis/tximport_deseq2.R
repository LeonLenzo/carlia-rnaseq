# kallisto -> tximport -> DESeq2 for the P. nodorum nitrogen-source experiment.
#
# THE FIX: tximport must be called with ignoreTxVersion = FALSE.
#
# The kallisto target IDs come from an NCBI cds_from_genomic FASTA and look like
#   lcl|CP069023.1_cds_QRC90020.1_1
# ignoreTxVersion = TRUE strips everything after the FIRST dot, which on these IDs
# leaves just lcl|CP069023, the chromosome accession. All 17,764 transcripts then
# collapse onto the 23 chromosomes (CP069023..CP069045), which is why tx2gene appeared
# to have "only 23 observations", and why tximport finally reported that none of the
# transcripts in the files were present in tx2gene.
#
# These IDs carry no version suffix to ignore, so the option is simply wrong here.

library(tximport)
library(DESeq2)
library(tidyverse)

# ---- inputs ---------------------------------------------------------------------
# quant_dir must contain one directory per sample, each holding abundance.h5
# Paths assume the layout delivered on the R: drive, where tx2gene.tsv,
# gene_annotation.tsv and samples.tsv sit beside this script. In the git repo the two
# mapping tables live in metadata/ instead.
quant_dir <- "quant_kallisto_0.52.0"
tx2gene   <- read.delim("tx2gene.tsv", stringsAsFactors = FALSE)   # transcript_id, gene_id
colData   <- read.delim("samples.tsv", header = TRUE, stringsAsFactors = FALSE)
rownames(colData) <- colData$sample_id

colData$strain          <- relevel(as.factor(colData$strain), ref = "SN15")
colData$nitrogen_source <- relevel(as.factor(colData$nitrogen_source), ref = "Gln")

files <- file.path(quant_dir, colData$sample_id, "abundance.h5")
names(files) <- colData$sample_id
stopifnot(all(file.exists(files)))

# ---- check the mapping BEFORE importing ------------------------------------------
# Cheap, and it turns a confusing tximport error into an obvious one.
ids <- rhdf5::h5read(files[1], "/aux/ids")
matched <- sum(ids %in% tx2gene$transcript_id)
message(sprintf("tx2gene matches %d of %d kallisto targets", matched, length(ids)))
stopifnot(matched == length(ids))

# ---- import ----------------------------------------------------------------------
txi <- tximport(files,
                type = "kallisto",
                tx2gene = tx2gene,
                countsFromAbundance = "lengthScaledTPM",
                ignoreTxVersion = FALSE)   # <- the fix

# 17,764 CDS collapse onto 17,450 locus tags: ~314 genes have more than one CDS and
# tximport sums them, which is the point of going to gene level.
message(sprintf("gene-level matrix: %d genes x %d samples",
                nrow(txi$counts), ncol(txi$counts)))

# ---- DESeq2 ----------------------------------------------------------------------
dds <- DESeqDataSetFromTximport(txi, colData = colData,
                                design = ~ strain + nitrogen_source)
dds <- DESeq(dds)

res_nitrogen <- results(dds, contrast = c("nitrogen_source", "NO", "Gln"))
res_strain   <- results(dds, contrast = c("strain", "KO41", "SN15"))

summary(res_nitrogen)
summary(res_strain)

# ---- annotate and save -----------------------------------------------------------
annot <- read.delim("gene_annotation.tsv", stringsAsFactors = FALSE)

save_results <- function(res, path) {
  as.data.frame(res) %>%
    rownames_to_column("gene_id") %>%
    left_join(annot, by = "gene_id") %>%
    arrange(padj) %>%
    write.csv(path, row.names = FALSE)
}
save_results(res_nitrogen, "DESeq2_nitrogen_NO_vs_Gln.csv")
save_results(res_strain,   "DESeq2_strain_KO41_vs_SN15.csv")
