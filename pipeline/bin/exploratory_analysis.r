#!/usr/bin/env Rscript

# Command line argument processing
args <- commandArgs(trailingOnly=TRUE)

if (length(args) != 1) {
  stop("Usage: exploratory_analysis.r <raw_counts_table>", call.=FALSE)
}

rawCounts <- args[1]
##tpmCounts <- args[2]

# Load / install required packages
if (!require("DESeq2")){
    source("http://bioconductor.org/biocLite.R")
    biocLite("DESeq2", suppressUpdates=TRUE)
    library("DESeq2")
}
if (!require("edgeR")){
    source("http://bioconductor.org/biocLite.R")
    biocLite("edgeR", suppressUpdates=TRUE)
    library("edgeR")
}
if (!require("gplots")) {
    install.packages("gplots", dependencies=TRUE, repos='http://cloud.r-project.org/')
    library("gplots")
}


## Load a raw count table from a csv file
d <- read.csv(rawCounts, row.names = 1, check.names=FALSE)
d <- as.matrix(d)

## Convert to DESeq2 object
dds <- DESeqDataSetFromMatrix(countData=d, colData=DataFrame(condition=1:ncol(d)), ~ 1)

## Estimate size factors
dds <- estimateSizeFactors(dds)

## Remove lines with only zeros
dds <- dds[ rowSums(counts(dds)) > 0, ]

## Run the VST normalization
rld <- vst(dds, blind=TRUE)

## PCA on 1000 most variant genes
res.pca <- DESeq2::plotPCA(rld, ntop=1000, returnData=TRUE)

# Print PCA coordinates to file
write.csv(res.pca[,c("PC1", "PC2")], 'deseq2_pca_coords_mqc.csv', quote=FALSE, append=FALSE, col.names=FALSE)

# Calculate the euclidean distances between samples
dists <- as.matrix(cor(assay(rld), method = "pearson"))

# Plot a heatmap of correlations
pdf('vst_sample_cor_heatmap.pdf')
hmap <- heatmap.2(dists,
  main="Sample Correlations", key.title="Pearson Cor", trace="none",
  dendrogram="row", margin=c(9, 9)
)
dev.off()

# Write clustered distance values to file
write.csv(hmap$carpet, 'vst_sample_cor_mqc.csv', quote=FALSE, append=FALSE)

file.create("expan.done")

# Printing sessioninfo to standard out
sessionInfo()
