#!/usr/bin/env Rscript

# Command line argument processing
args = commandArgs(trailingOnly=TRUE)
if (length(args) < 3) {
  stop("Usage: gene_type_expression.r <counts_tpm_table> <gtf> <output_file> <R-package-location (optional)>", call.=FALSE)
}
countsTPM <- args[1]
gtf <- args[2]
ofile <- args[3]
if (length(args) > 3) { .libPaths( c( args[4], .libPaths() ) ) }

message("TPM count table (Arg 1):", countsTPM)
message("GTF file (Arg 2):", gtf)
message("Output file (Arg 3):", ofile)
message("R package loc. (Arg 4: ", ifelse(length(args) > 3, args[4], "Not specified"))


stopifnot(require(rtracklayer))

counts.tpm <- read.csv(countsTPM, row.names=1, check.names=FALSE)

## count number of expressed genes
idx <- which(rowSums(counts.tpm)>0)
counts.tpm <- counts.tpm[idx,,drop=FALSE]

## gene annotation
d.gtf <- rtracklayer::import(gtf)
my_genes <- d.gtf[d.gtf$type == "gene"]

if (length(my_genes) > 0 && is.element("gene_type", colnames(elementMetadata(my_genes)))){
   mcols(my_genes) <- mcols(my_genes)[c("gene_id", "gene_type","gene_name")]
   n_items <- 5
   d2p <- as.matrix(data.frame(lapply(as.list(counts.tpm), function(x){
          n_ex <- length(which(x>1))
   	  ids <- sapply(strsplit(rownames(counts.tpm)[which(x>1)], "\\|"), "[[", 1)
	  dt <- table(factor(my_genes$gene_type[match(ids, my_genes$gene_id)], levels=unique(sort(my_genes$gene_type))))
	  c(total=n_ex, dt)
	}), check.names=FALSE))
}else{
    n_items <- 1
    d2p <-  as.matrix(data.frame(lapply(as.list(counts.tpm), function(x){
            n_ex <- length(which(x>1))
            c(total=n_ex)
            }), check.names=FALSE))
}

## remove zero values and sort by counts
line2remove <- c(which(rownames(d2p)=="total"), which(rowSums(d2p)==0))
if (length(line2remove) > 0 ){
   d2p <- d2p[-line2remove,,drop=FALSE]
}
d2p <- d2p[order(rowSums(d2p), decreasing=TRUE),,drop=FALSE]

## reduce
if (nrow(d2p) > (n_items + 1)){
   d2p <- rbind(d2p[1:n_items,,drop=FALSE], others=colSums(d2p[(n_items+1):nrow(d2p),,drop=FALSE]))
}

## export
write.csv(t(d2p), file=ofile)
