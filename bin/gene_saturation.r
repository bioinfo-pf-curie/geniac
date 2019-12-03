#!/usr/bin/env Rscript

# Command line argument processing
args = commandArgs(trailingOnly=TRUE)
if (length(args) < 1) {
  stop("Usage: gene_saturation.r <counts_table> <R-package-location (optional)>", call.=FALSE)
}
rawCounts <- args[1]
if (length(args) > 1) { .libPaths( c( args[2], .libPaths() ) ) }

message("Raw count table (Arg 1):", rawCounts)
message("R package loc. (Arg 2: ", ifelse(length(args) > 2, args[2], "Not specified"))

## estimate_saturation
## Estimate saturation of genes based on rarefaction of reads
## counts : a matrix of counts
## max_reads : maximum number of reads to downsample
## ndepths : resampling levels
## nreps : number of times the subsampling is performed to calculate a variance
## mincounts : minimum counts level to consider a gene as expressed. If NA, the threshold is fixed to 1 CPM
## extend.lines : If TRUE, the max number of detected genes is returned when the maximum number of reads is reached.
estimate_saturation <- function(counts, max_reads=Inf, ndepths=6, nreps=1, mincounts=NA, extend.lines=FALSE){
  stopifnot(require(S4Vectors))
  
  counts <- as.matrix(counts)
  readsums <- colSums(counts)
  max_reads <- min(max(readsums), max_reads)
  if (max_reads > 10e6){
    depths <- c(seq(from=0, to=10e6, length.out=6),
                seq(from=10e6, to=max_reads, length.out=ndepths+1)[-1])
  }else{
    depths <- round(seq(from=0, to=max_reads, length.out=ndepths+1))
  }
  
  saturation <- lapply(1:ncol(counts), function(k){
    message("Processing sample ", colnames(counts)[k], "...")
    x <- counts[,k]
    nreads <- sum(x)
    
    ## minimum expression levels
    if (is.na(mincounts)){
      mincounts <- nreads / 1e6
    }
    ## max number of detected genes
    ngenes_detected <- length(which(x>=mincounts))
    
    probs <- x / nreads ## calculate gene probabilities for the library
    probs <- probs[probs > 0] ## zero counts add nothing but computational time!
    ngenes <- length(probs)

    res <- lapply(depths, function(dp, nreps=1, ...){
        rsim <- c(NA, NA)
        if (extend.lines)
            rsim <- c(ngenes_detected, NA)
        if (dp <= nreads){
            estim <- lapply(1:nreps, function(i, ngenes, dp, probs, mincounts){
                csim <- sample(x=ngenes, size=dp, replace=TRUE, prob=probs)
                length(which(runLength(Rle(sort(csim)))>=mincounts))
            }, ngenes=ngenes, dp=dp, probs=probs, mincounts=mincounts)
            rsim <- c(mean(unlist(estim)), var(unlist(estim)))
        }
        return(rsim)
    }, nreps=nreps, nreads=nreads,  ngenes=ngenes, probs=probs, mincounts=mincounts)
    
    data.frame(depths=depths,
               sat.estimates=sapply(res, "[[", 1),
               sat.var.estimates=sapply(res, "[[", 2))
  })
  names(saturation) <- colnames(counts)
  return(saturation)
}##estimate_saturation

counts <- read.csv(rawCounts, row.names=1, check.names=FALSE)
sat <- estimate_saturation(counts=counts, ndepths=10, nreps=1, extend.lines=TRUE)

## save - one file per sample
for (sname in names(sat)){
    d2w <- sat[[sname]][,c(1,2)]
    ## Reads per Millions
    d2w[,1] <- round(d2w[,1]/1000000,2)
    write.table(d2w, file=paste0(sname,"_gcurve.txt"),
                quote=FALSE, sep="\t", col.names=FALSE, row.names=FALSE)
}
