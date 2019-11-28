#!/usr/bin/env nextflow

/*
Copyright Institut Curie 2019
This software is a computer program whose purpose is to analyze high-throughput sequencing data.
You can use, modify and/ or redistribute the software under the terms of license (see the LICENSE file for more details).
The software is distributed in the hope that it will be useful, but "AS IS" WITHOUT ANY WARRANTY OF ANY KIND.
Users are therefore encouraged to test the software's suitability as regards their requirements in conditions enabling the security of their systems and/or data.
The fact that you are presently reading this means that you have had knowledge of the license and that you accept its terms.

This script is based on the nf-core guidelines. See https://nf-co.re/ for more information
*/


/*
========================================================================================
                         RNA-seq
========================================================================================
 RNA-seq Analysis Pipeline.
 #### Homepage / Documentation
 https://gitlab.curie.fr/data-analysis/rnaseq
----------------------------------------------------------------------------------------
*/


def helpMessage() {
    if ("${workflow.manifest.version}" =~ /dev/ ){
       dev_mess = file("$baseDir/assets/dev_message.txt")
       log.info dev_mess.text
    }

    log.info """
    rnaseq v${workflow.manifest.version}
    ======================================================================

    Usage:
    nextflow run rnaseq --reads '*_R{1,2}.fastq.gz' --genome hg19 -profile conda
    nextflow run rnaseq --samplePlan sample_plan --genome hg19 -profile conda


    Mandatory arguments:
      --reads 'READS'               Path to input data (must be surrounded with quotes)
      --samplePlan 'SAMPLEPLAN'     Path to sample plan input file (cannot be used with --reads)
      --genome 'BUILD'              Name of genome reference
      -profile PROFILE              Configuration profile to use. test / conda / toolsPath / singularity / cluster (see below)

    Sequencing:
      --singleEnd                   Specifies that the input is single end reads

    Strandness:
      --stranded 'STRANDED'         Library strandness ['auto', 'forward', 'reverse', 'no']. Default: 'auto'

    Mapping:
      --aligner 'MAPPER'            Tool for read alignments ['star', 'hisat2', 'tophat2']. Default: 'star'

    Counts:
      --counts 'COUNTS'             Tool to use to estimate the raw counts per gene ['star', 'featureCounts', 'HTseqCounts']. Default: 'star'

    References:                     If not specified in the configuration file or you wish to overwrite any of the references.
      --star_index 'PATH'           Path to STAR index
      --hisat2_index 'PATH'         Path to HiSAT2 index
      --tophat2_index 'PATH'        Path to TopHat2 index
      --gtf 'GTF'                   Path to GTF file
      --bed12 'BED'                 Path to gene bed12 file
      --saveAlignedIntermediates    Save the intermediate files from the Aligment step  - not done by default

    Other options:
      --metadata 'FILE'             Add metadata file for multiQC report
      --outdir 'PATH'               The output directory where the results will be saved
      -w/--work-dir 'PATH'          The temporary directory where intermediate data will be saved
      --email 'MAIL'                Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      -name 'NAME'                  Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.

    Skip options:
      --skip_qc                     Skip all QC steps apart from MultiQC
      --skip_rrna                   Skip rRNA mapping
      --skip_fastqc                 Skip FastQC
      --skip_genebody_coverage      Skip calculating genebody coverage
      --skip_saturation             Skip Saturation qc
      --skip_dupradar               Skip dupRadar (and Picard MarkDups)
      --skip_readdist               Skip read distribution steps
      --skip_expan                  Skip exploratory analysis
      --skip_multiqc                Skip MultiQC

    =======================================================
    Available Profiles

      -profile test                Set up the test dataset
      -profile conda               Build a new conda environment before running the pipeline
      -profile toolsPath           Use the paths defined in configuration for each tool
      -profile singularity         Use the Singularity images for each process
      -profile cluster             Run the workflow on the cluster, instead of locally

    """.stripIndent()
}

/*
 * SET UP CONFIGURATION VARIABLES
 */


// Show help emssage
if (params.help){
    helpMessage()
    exit 0
}

// Configurable reference genomes
if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
   exit 1, "The provided genome '${params.genome}' is not available in the genomes file. Currently the available genomes are ${params.genomes.keySet().join(", ")}"
}

// Reference index path configuration
// Define these here - after the profiles are loaded with the genomes paths
params.star_index = params.genome ? params.genomes[ params.genome ].star ?: false : false
params.bowtie2_index = params.genome ? params.genomes[ params.genome ].bowtie2 ?: false : false
params.hisat2_index = params.genome ? params.genomes[ params.genome ].hisat2 ?: false : false
params.rrna = params.genome ? params.genomes[ params.genome ].rrna ?: false : false
params.gtf = params.genome ? params.genomes[ params.genome ].gtf ?: false : false
params.bed12 = params.genome ? params.genomes[ params.genome ].bed12 ?: false : false

// Tools option configuration
// Add here the list of options that can change from a reference genome to another
if (params.genome){
  params.star_options = params.genomes[ params.genome ].star_opts ?: params.star_opts
}
// Has the run name been specified by the user?
// this has the bonus effect of catching both -name and --name
custom_runName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  custom_runName = workflow.runName
}

// Stage config files
ch_multiqc_config = Channel.fromPath(params.multiqc_config)
ch_output_docs = Channel.fromPath("$baseDir/docs/output.md")
ch_pca_header = Channel.fromPath("$baseDir/assets/pca_header.txt")
ch_heatmap_header = Channel.fromPath("$baseDir/assets/heatmap_header.txt")

/*
 * CHANNELS
 */

// Validate inputs
if (params.aligner != 'star' && params.aligner != 'hisat2' && params.aligner != 'tophat2'){
    exit 1, "Invalid aligner option: ${params.aligner}. Valid options: 'star', 'hisat2', 'tophat2'"
}
if (params.counts != 'star' && params.counts != 'featureCounts' && params.counts != 'HTseqCounts'){
    exit 1, "Invalid counts option: ${params.counts}. Valid options: 'star', 'featureCounts', 'HTseqCounts'"
}
if (params.counts == 'star' && params.aligner != 'star'){
    exit 1, "Cannot run STAR counts without STAR aligner. Please check the '--aligner' and '--counts' parameters."
}
if (params.stranded != 'auto' && params.stranded != 'reverse' && params.stranded != 'forward' && params.stranded != 'no'){
    exit 1, "Invalid stranded option: ${params.stranded}. Valid options: 'auto', 'reverse', 'forward', 'no'"
}

if ((params.reads && params.samplePlan) || (params.readPaths && params.samplePlan)){
   exit 1, "Input reads must be defined using either '--reads' or '--samplePlan' parameter. Please choose one way"
}

if( params.star_index && params.aligner == 'star' ){
    star_index = Channel
        .fromPath(params.star_index)
        .ifEmpty { exit 1, "STAR index not found: ${params.star_index}" }
}
else if ( params.hisat2_index && params.aligner == 'hisat2' ){
    hs2_indices = Channel
        .fromPath("${params.hisat2_index}*")
        .ifEmpty { exit 1, "HISAT2 index not found: ${params.hisat2_index}" }
}
else if ( params.bowtie2_index && params.aligner == 'tophat2' ){
    Channel.fromPath("${params.bowtie2_index}*")
        .ifEmpty { exit 1, "TOPHAT2 index not found: ${params.bowtie2_index}" }
        .set { tophat2_indices}
}
else {
    exit 1, "No reference genome specified!"
}

if( params.gtf ){
    Channel
        .fromPath(params.gtf)
        .ifEmpty { exit 1, "GTF annotation file not found: ${params.gtf}" }
        .into { gtf_star; gtf_dupradar; gtf_featureCounts; gtf_genetype; gtf_HTseqCounts; gtf_tophat; gtf_table; gtf_makeHisatSplicesites }
}else {
    log.warn "No GTF annotation specified - dupRadar, table counts - will be skipped !" 
    Channel
        .empty()
        .into { gtf_star; gtf_dupradar; gtf_featureCounts; gtf_genetype; gtf_HTseqCounts; gtf_tophat; gtf_table; gtf_makeHisatSplicesites }
}

if( params.bed12 ){
    Channel
        .fromPath(params.bed12)
        .ifEmpty { exit 1, "BED12 annotation file not found: ${params.bed12}" }
        .into { bed_rseqc; bed_read_dist; bed_genebody_coverage} 
}else{
    log.warn "No BED gene annotation specified - strandness detection, gene body coverage, read distribution - will be skipped !"
    Channel
       .empty()
       .into { bed_rseqc; bed_read_dist; bed_genebody_coverage}
}

if( params.rrna ){
    Channel
        .fromPath(params.rrna)
        .ifEmpty { exit 1, "rRNA annotation file not found: ${params.rrna}" }
        .set { rrna_annot }
}else{
    log.warn "No rRNA fasta file available - rRNA mapping - will be skipped !"
    rrna_annot = Channel.empty()
}

if ( params.metadata ){
   Channel
       .fromPath( params.metadata )
       .ifEmpty { exit 1, "Metadata file not found: ${params.metadata}" }
       .set { ch_metadata }
}

/*
 * Create a channel for input read files
 */

if(params.samplePlan){
   if(params.singleEnd){
      Channel
         .from(file("${params.samplePlan}"))
         .splitCsv(header: false)
         .map{ row -> [ row[0], [file(row[2])]] }
         .into { raw_reads_fastqc; raw_reads_star; raw_reads_hisat2; raw_reads_tophat2; raw_reads_rna_mapping; raw_reads_prep_rseqc; raw_reads_strandness; save_strandness}
   }else{
      Channel
         .from(file("${params.samplePlan}"))
         .splitCsv(header: false)
         .map{ row -> [ row[0], [file(row[2]), file(row[3])]] }
         .into { raw_reads_fastqc; raw_reads_star; raw_reads_hisat2; raw_reads_tophat2; raw_reads_rna_mapping; raw_reads_prep_rseqc; raw_reads_strandness; save_strandness}
   }
   params.reads=false
}
else if(params.readPaths){
    if(params.singleEnd){
        Channel
            .from(params.readPaths)
            .map { row -> [ row[0], [file(row[1][0])]] }
            .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
            .into { raw_reads_fastqc; raw_reads_star; raw_reads_hisat2; raw_reads_tophat2; raw_reads_rna_mapping; raw_reads_prep_rseqc; raw_reads_strandness; save_strandness}
    } else {
        Channel
            .from(params.readPaths)
            .map { row -> [ row[0], [file(row[1][0]), file(row[1][1])]] }
            .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
            .into { raw_reads_fastqc; raw_reads_star; raw_reads_hisat2; raw_reads_tophat2; raw_reads_rna_mapping; raw_reads_prep_rseqc; raw_reads_strandness; save_strandness}
    }
} else {
    Channel
        .fromFilePairs( params.reads, size: params.singleEnd ? 1 : 2 )
        .ifEmpty { exit 1, "Cannot find any reads matching: ${params.reads}\nNB: Path needs to be enclosed in quotes!\nNB: Path requires at least one * wildcard!\nIf this is single-end data, please specify --singleEnd on the command line." }
        .into { raw_reads_fastqc; raw_reads_star; raw_reads_hisat2; raw_reads_tophat2; raw_reads_rna_mapping; raw_reads_prep_rseqc; raw_reads_strandness; save_strandness}
}

/*
 * Make sample plan if not available
 */

if (params.samplePlan){
  ch_splan = Channel.fromPath(params.samplePlan)
}else if(params.readPaths){
  if (params.singleEnd){
    Channel
       .from(params.readPaths)
       .collectFile() {
         item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + '\n']
        }
       .set{ ch_splan }
  }else{
     Channel
       .from(params.readPaths)
       .collectFile() {
         item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + ',' + item[1][1] + '\n']
        }
       .set{ ch_splan }
  }
}else{
  if (params.singleEnd){
    Channel
       .fromFilePairs( params.reads, size: 1 )
       .collectFile() {
          item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + '\n']
       }     
       .set { ch_splan }
  }else{
    Channel
       .fromFilePairs( params.reads, size: 2 )
       .collectFile() {
          item -> ["sample_plan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + ',' + item[1][1] + '\n']
       }     
       .set { ch_splan }
   }
}


// Header log info
if ("${workflow.manifest.version}" =~ /dev/ ){
   dev_mess = file("$baseDir/assets/dev_message.txt")
   log.info dev_mess.text
}

log.info """=======================================================

 rnaseq : RNA-Seq workflow v${workflow.manifest.version}
======================================================="""
def summary = [:]
summary['Run Name']     = custom_runName ?: workflow.runName
summary['Command Line'] = workflow.commandLine
summary['Metadata']	= params.metadata
if (params.samplePlan) {
   summary['SamplePlan']   = params.samplePlan
}else{
   summary['Reads']        = params.reads
}
summary['Data Type']    = params.singleEnd ? 'Single-End' : 'Paired-End'
summary['Genome']       = params.genome
summary['Strandedness'] = params.stranded
if(params.aligner == 'star'){
  summary['Aligner'] = "star"
  if(params.star_index) summary['STAR Index'] = params.star_index
} else if(params.aligner == 'tophat2') {
  summary['Aligner'] = "Tophat2"
  if(params.bowtie2_index) summary['Tophat2 Index'] = params.bowtie2_index
} else if(params.aligner == 'hisat2') {
  summary['Aligner'] = "HISAT2"
  if(params.hisat2_index) summary['HISAT2 Index'] = params.hisat2_index
}
summary['Counts'] = params.counts
if(params.gtf)                 summary['GTF Annotation']  = params.gtf
if(params.bed12)               summary['BED Annotation']  = params.bed12
summary['Save Intermeds'] = params.saveAlignedIntermediates ? 'Yes' : 'No'
summary['Max Memory']     = params.max_memory
summary['Max CPUs']       = params.max_cpus
summary['Max Time']       = params.max_time
summary['Container Engine'] = workflow.containerEngine
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Output dir']     = params.outdir
summary['Config Profile'] = workflow.profile

if(params.email) summary['E-mail Address'] = params.email
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="



/*
 * FastQC
 */
process fastqc {
  tag "${prefix}"
  publishDir "${params.outdir}/fastqc", mode: 'copy',
      saveAs: {filename -> filename.indexOf(".zip") > 0 ? "zips/$filename" : "$filename"}

  when:
  !params.skip_qc && !params.skip_fastqc

  input:
  set val(prefix), file(reads) from raw_reads_fastqc

  output:
  file "*_fastqc.{zip,html}" into fastqc_results

  script:
  pbase = reads[0].toString() - ~/(\.fq)?(\.fastq)?(\.gz)?$/
  """
  fastqc -q $reads
  mv ${pbase}_fastqc.html ${prefix}_fastqc.html
  mv ${pbase}_fastqc.zip ${prefix}_fastqc.zip
  """
}


/*
 * rRNA mapping 
 */
process rRNA_mapping {
  tag "${prefix}"
  publishDir "${params.outdir}/rRNA_mapping", mode: 'copy',
      saveAs: {filename ->
	  if (filename.indexOf("fastq.gz") > 0 &&  params.saveAlignedIntermediates) filename
	  else if (filename.indexOf(".log") > 0) "logs/$filename"
          else null
      }

  when:
    !params.skip_rrna && params.rrna

  input:
    set val(prefix), file(reads) from raw_reads_rna_mapping
    file annot from rrna_annot.collect()

  output:
    set val(prefix), file("*fastq.gz") into rrna_mapping_res
    set val(prefix), file("*.sam") into rrna_sam
    file "*.log" into rrna_logs

  script:
  if (params.singleEnd) {
     """
     bowtie ${params.bowtie_opts} \\
     -p ${task.cpus} \\
     --un ${prefix}_norRNA.fastq \\
     --sam ${params.rrna} \\
     ${reads} \\
     ${prefix}.sam  2> ${prefix}.log && \
     gzip -f ${prefix}_norRNA*.fastq 
    """
  } else {
     """
     bowtie ${params.bowtie_opts} \\
     -p ${task.cpus} \\
     --un ${prefix}_norRNA.fastq \\
     --sam ${params.rrna} \\
     -1 ${reads[0]} \\
     -2 ${reads[1]} \\
     ${prefix}.sam  2> ${prefix}.log && \
     gzip -f ${prefix}_norRNA_*.fastq 
     """
  }  
}


/*
 * Strandness
 */
strandness_results = Channel.empty()

if (params.stranded == 'auto' && params.bed12){

  process prep_rseqc {
    tag "${prefix}"
    input:
    set val(prefix), file(reads) from raw_reads_prep_rseqc

    output:
    set val("${prefix}"), file("${prefix}_subsample.bam") into bam_rseqc

    script:
    if (params.singleEnd) {
    """
    bowtie2 --fast --end-to-end --reorder \\
     -p ${task.cpus} \\
     -u ${params.n_check} \\
     -x ${params.bowtie2_index} \\
     -U ${reads} > ${prefix}_subsample.bam 
     """
    } else {
    """
    bowtie2 --fast --end-to-end --reorder \\
     -p ${task.cpus} \\
     -u ${params.n_check} \\
     -x ${params.bowtie2_index} \\
     -1 ${reads[0]} \\
     -2 ${reads[1]} > ${prefix}_subsample.bam
    """
    }
  }

  process rseqc {
    tag "${prefix - '_subsample'}"
    publishDir "${params.outdir}/strandness" , mode: 'copy',
        saveAs: {filename ->
         	  if (filename.indexOf(".txt") > 0) "$filename"
                  else null
        }

    input:
    set val(prefix), file(bam_rseqc) from bam_rseqc
    file bed12 from bed_rseqc.collect()

    output:
    file "*.{txt,pdf,r,xls}" into rseqc_results
    stdout into (stranded_results_featureCounts, stranded_results_genetype, stranded_results_HTseqCounts, stranded_results_dupradar, stranded_results_tophat, stranded_results_hisat, stranded_results_table)

    when:
    params.stranded == 'auto'

    script:
    """
    infer_experiment.py -i $bam_rseqc -r $bed12 > ${prefix}.txt
    parse_rseq_output.sh ${prefix}.txt > ${prefix}_strandness.txt
    cat ${prefix}_strandness.txt
    """  
  }

strandness_results = rseqc_results
}else{

  raw_reads_strandness
    .map { file -> 
        def key = params.stranded 
        return tuple(key)
    }
    .into { stranded_results_featureCounts; stranded_results_genetype; stranded_results_HTseqCounts; stranded_results_dupradar; stranded_results_tophat; stranded_results_hisat; stranded_results_table }

  // save strandness results
  process save_strandness {
  publishDir "${params.outdir}/strandness" , mode: 'copy',
      saveAs: {filename ->
          if (filename.indexOf(".txt") > 0) "$filename"
          else null
      }

  input:
  set val(prefix), file(reads) from save_strandness

  output:
  file "*.txt" into saved_strandness

  script:
  """
  echo ${params.stranded} > ${prefix}_strandness.txt
  """
  }
strandness_results = saved_strandness
}


/*
 * Reads mapping
 */

// From nf-core
// Function that checks the alignment rate of the STAR output
// and returns true if the alignment passed and otherwise false
skipped_poor_alignment = []
def check_log(logs) {
  def percent_aligned = 0;
  logs.eachLine { line ->
    if ((matcher = line =~ /Uniquely mapped reads %\s*\|\s*([\d\.]+)%/)) {
      percent_aligned = matcher[0][1]
    }
  }
  logname = logs.getBaseName() - 'Log.final'
  if(percent_aligned.toFloat() <= '2'.toFloat() ){
      log.info "#################### VERY POOR ALIGNMENT RATE! IGNORING FOR FURTHER DOWNSTREAM ANALYSIS! ($logname)    >> ${percent_aligned}% <<"
      skipped_poor_alignment << logname
      return false
  } else {
      log.info "          Passed alignment > star ($logname)   >> ${percent_aligned}% <<"
      return true
  }
}

// Update input channel
star_raw_reads = Channel.empty()
if( params.rrna && !params.skip_rrna){
  star_raw_reads = rrna_mapping_res
}
else {  
  star_raw_reads = raw_reads_star
}


// STAR

if(params.aligner == 'star'){
  hisat_stdout = Channel.from(false)
  process star {
    tag "$prefix"
    publishDir "${params.outdir}/mapping", mode: 'copy',
        saveAs: {filename ->
	    if (filename.indexOf(".bam") == -1) "logs/$filename"
	    else if (params.saveAlignedIntermediates) filename
            else null
        }
    publishDir "${params.outdir}/counts", mode: 'copy',
        saveAs: {filename ->
            if (filename.indexOf("ReadsPerGene.out.tab") > 0) "$filename"
            else null
        }


    input:
    set val(prefix), file(reads) from star_raw_reads
    file index from star_index.collect()
    file gtf from gtf_star.collect().ifEmpty([])

    output:
    set val(prefix), file ("*Log.final.out"), file ('*.bam') into star_sam
    file "*.out" into alignment_logs
    file "*.out.tab" into star_log_counts
    file "*Log.out" into star_log
    file "*ReadsPerGene.out.tab" optional true into star_counts_to_merge, star_counts_to_r

    script:
    def star_count_opt = params.counts == 'star' && params.gtf ? params.star_opts_counts : ''
    def star_gtf_opt = params.gtf ? "--sjdbGTFfile $gtf" : ''
    """
    STAR --genomeDir $index \\
         ${star_gtf_opt} \\
         --readFilesIn $reads  \\
         --runThreadN ${task.cpus} \\
         --runMode alignReads \\
         --outSAMtype BAM Unsorted  \\
         --readFilesCommand zcat \\
         --runDirPerm All_RWX \\
         --outTmpDir /local/scratch/rnaseq_\$(date +%d%s%S%N) \\
         --outFileNamePrefix $prefix  \\
         --outSAMattrRGline ID:$prefix SM:$prefix LB:Illumina PL:Illumina  \\
         ${params.star_options} \\
	 ${star_count_opt}
    """
  }

  process star_sort {
    tag "$prefix"
    publishDir "${params.outdir}/mapping", mode: 'copy'
 
    input:
    set val(prefix), file(Log_final_out), file (star_bam) from star_sam

    output:
    set file("${prefix}Log.final.out"), file ('*.bam') into  star_aligned  
    file "${prefix}Aligned.sortedByCoord.out.bam.bai" into bam_index_star

    script:
    """
    samtools sort  \\
        -@  ${task.cpus}  \\
        -m ${params.sort_max_memory} \\
        -o ${prefix}Aligned.sortedByCoord.out.bam  \\
        ${star_bam}   

    samtools index ${prefix}Aligned.sortedByCoord.out.bam
    """
    }

    // Filter removes all 'aligned' channels that fail the check
    star_aligned
        .filter { logs, bams -> check_log(logs) }
        .flatMap {  logs, bams -> bams }
    .into { bam_count; bam_preseq; bam_markduplicates; bam_featurecounts; bam_genetype; bam_HTseqCounts; bam_read_dist; bam_forSubsamp; bam_skipSubsamp }
}


// HiSat2

hisat2_raw_reads = Channel.empty()
if( params.rrna && !params.skip_rrna ){
    hisat2_raw_reads = rrna_mapping_res
}
else {
    hisat2_raw_reads = raw_reads_hisat2 
}

if(params.aligner == 'hisat2'){
  star_log = Channel.from(false)
  
  process makeHisatSplicesites {
     tag "$gtf"
     publishDir "${params.outdir}/mapping", mode: 'copy',
                saveAs: { filename ->
		   if (params.saveAlignedIntermediates) filename
		   else null
		}
     input:
     file gtf from gtf_makeHisatSplicesites

     output:
     file "${gtf.baseName}.hisat2_splice_sites.txt" into alignment_splicesites

     script:
     """
     hisat2_extract_splice_sites.py $gtf > ${gtf.baseName}.hisat2_splice_sites.txt
     """
  }

  process hisat2Align {
    tag "$prefix"
    publishDir "${params.outdir}/mapping", mode: 'copy',
        saveAs: {filename ->
            if (filename.indexOf(".hisat2_summary.txt") > 0) "logs/$filename"
	    else if (params.saveAlignedIntermediates) filename
            else null
        }

    input:
    set val(prefix), file(reads) from hisat2_raw_reads 
    file hs2_indices from hs2_indices.collect()
    file alignment_splicesites from alignment_splicesites.collect()
    val parse_res from stranded_results_hisat

    output:
    file "${prefix}.bam" into hisat2_bam
    file "${prefix}.hisat2_summary.txt" into alignment_logs

    script:
    index_base = hs2_indices[0].toString() - ~/.\d.ht2/
  
    seqCenter = params.seqCenter ? "--rg-id ${prefix} --rg CN:${params.seqCenter.replaceAll('\\s','_')}" : ''
    def rnastrandness = ''
    if (parse_res=='forward'){
        rnastrandness = params.singleEnd ? '--rna-strandness F' : '--rna-strandness FR'
    } else if (parse_res=='reverse'){
        rnastrandness = params.singleEnd ? '--rna-strandness R' : '--rna-strandness RF'
    }
    if (params.singleEnd) {
    """
    hisat2 -x $index_base \\
           -U $reads \\
           $rnastrandness \\
           --known-splicesite-infile $alignment_splicesites \\
           -p ${task.cpus} \\
           --met-stderr \\
           --new-summary \\
           --summary-file ${prefix}.hisat2_summary.txt $seqCenter \\
           | samtools view -bS -F 4 -F 256 - > ${prefix}.bam
    """
    } else {
    """
    hisat2 -x $index_base \\
           -1 ${reads[0]} \\
           -2 ${reads[1]} \\
           $rnastrandness \\
           --known-splicesite-infile $alignment_splicesites \\
           --no-mixed \\
           --no-discordant \\
           -p ${task.cpus} \\
           --met-stderr \\
           --new-summary \\
           --summary-file ${prefix}.hisat2_summary.txt $seqCenter \\
           | samtools view -bS -F 4 -F 8 -F 256 - > ${prefix}.bam
     """
    }
  }

  process hisat2_sort {
      tag "${hisat2_bam.baseName}"
      publishDir "${params.outdir}/mapping", mode: 'copy'

      input:
      file hisat2_bam

      output:
      file "${hisat2_bam.baseName}.sorted.bam" into bam_count, bam_preseq, bam_markduplicates, bam_featurecounts, bam_genetype, bam_HTseqCounts, bam_read_dist, bam_forSubsamp, bam_skipSubsamp
      file "${hisat2_bam.baseName}.sorted.bam.bai" into bam_index_hisat
 
      script:
      def avail_mem = task.memory ? "-m ${task.memory.toBytes() / task.cpus}" : ''
      """
      samtools sort \\
          $hisat2_bam \\
          -@ ${task.cpus} $avail_mem \\
          -m ${params.sort_max_memory} \\
          -o ${hisat2_bam.baseName}.sorted.bam
      samtools index ${hisat2_bam.baseName}.sorted.bam
      """
  }
}

// Update channel for TopHat2
tophat2_raw_reads = Channel.empty()
if( params.rrna && !params.skip_rrna ){
    tophat2_raw_reads = rrna_mapping_res
}
else {
    tophat2_raw_reads = raw_reads_tophat2
}

if(params.aligner == 'tophat2'){
 process tophat2 {
  tag "${prefix}"
  publishDir "${params.outdir}/mapping", mode: 'copy',
        saveAs: {filename ->
            if (filename.indexOf(".align_summary.txt") > 0) "logs/$filename"
            else filename
        }

  input:
    set val(prefix), file(reads) from tophat2_raw_reads 
    file "tophat2" from tophat2_indices.collect()
    file gtf from gtf_tophat.collect()
    val parse_res from stranded_results_tophat

  output:
    file "${prefix}.bam" into bam_count, bam_preseq, bam_markduplicates, bam_featurecounts, bam_genetype, bam_HTseqCounts, bam_read_dist, bam_forSubsamp, bam_skipSubsamp
    file "${prefix}.align_summary.txt" into alignment_logs
    file "${prefix}.bam.bai" into bam_index_tophat

  script:
    def avail_mem = task.memory ? "-m ${task.memory.toBytes() / task.cpus}" : ''
    def stranded_opt = '--library-type fr-unstranded'
    if (parse_res == 'forward'){
        stranded_opt = '--library-type fr-secondstrand'
    }else if ((parse_res == 'reverse')){
        stranded_opt = '--library-type fr-firststrand'
    }
    def out = './mapping'
    def sample = "--rg-id ${prefix} --rg-sample ${prefix} --rg-library Illumina --rg-platform Illumina --rg-platform-unit ${prefix}"
    """
    mkdir -p ${out}
    tophat2 -p ${task.cpus} \\
    ${sample} \\
    ${params.tophat2_opts} \\
    --GTF $gtf \\
    ${stranded_opt} \\
    -o ${out} \\
    ${params.bowtie2_index} \\
    ${reads} 

    mv ${out}/accepted_hits.bam ${prefix}.bam
    mv ${out}/align_summary.txt ${prefix}.align_summary.txt
    samtools index ${prefix}.bam
    """
  }
}


/*
 * Subsample the BAM files if necessary
 */
bam_forSubsamp
    .filter { it.size() > params.subsampFilesizeThreshold }
    .map { [it, params.subsampFilesizeThreshold / it.size() ] }
    .set{ bam_forSubsampFiltered }
bam_skipSubsamp
    .filter { it.size() <= params.subsampFilesizeThreshold }
    .set{ bam_skipSubsampFiltered }

process bam_subsample {
    tag "${bam.baseName - '.sorted'}"

    input:
    set file(bam), val(fraction) from bam_forSubsampFiltered

    output:
    file "*_subsamp.bam" into bam_subsampled

    script:
    """
    samtools view -s $fraction -b $bam | samtools sort -o ${bam.baseName}_subsamp.bam
    """
}

/*
 * Rseqc genebody_coverage
 */
process genebody_coverage {
    tag "${bam.baseName - '.sorted'}"
       publishDir "${params.outdir}/genecov" , mode: 'copy',
        saveAs: {filename ->
            if (filename.indexOf("geneBodyCoverage.curves.pdf") > 0)       "geneBodyCoverage/$filename"
            else if (filename.indexOf("geneBodyCoverage.r") > 0)           "geneBodyCoverage/rscripts/$filename"
            else if (filename.indexOf("geneBodyCoverage.txt") > 0)         "geneBodyCoverage/data/$filename"
            else if (filename.indexOf("log.txt") > -1) false
            else filename
        }

    when:
    !params.skip_qc && !params.skip_genebody_coverage

    input:
    file bam from bam_subsampled.concat(bam_skipSubsampFiltered)
    file bed12 from bed_genebody_coverage.collect()

    output:
    file "*.{txt,pdf,r}" into genebody_coverage_results

    script:
    """
    samtools index $bam
    geneBody_coverage.py \\
        -i $bam \\
        -o ${bam.baseName}.rseqc \\
        -r $bed12
    mv log.txt ${bam.baseName}.rseqc.log.txt
    """
}

/*
 * Saturation Curves
 */
process preseq {
  tag "${bam_preseq}"
  publishDir "${params.outdir}/preseq", mode: 'copy'

  when:
  !params.skip_qc && !params.skip_saturation

  input:
  file bam_preseq

  output:
  file "*ccurve.txt" into preseq_results

  script:
  prefix = bam_preseq.toString() - ~/(.bam)?$/
  """
  preseq lc_extrap -v -B $bam_preseq -o ${prefix}.extrap_ccurve.txt -e 200e+06
  """
}

/*
 * Duplicates
 */
process markDuplicates {
  tag "${bam}"
  publishDir "${params.outdir}/markDuplicates", mode: 'copy',
      saveAs: {filename -> 
      	      if (filename.indexOf("_metrics.txt") > 0) "metrics/$filename" 
	      else if (params.saveAlignedIntermediates) filename
	      }

  when:
  !params.skip_qc && !params.skip_dupradar

  input:
  file bam from bam_markduplicates

  output:
  file "${bam.baseName}.markDups.bam" into bam_md
  file "${bam.baseName}.markDups_metrics.txt" into picard_results
  file "${bam.baseName}.markDups.bam.bai"

  script:
  if( !task.memory ){
    log.info "[Picard MarkDuplicates] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this."
    avail_mem = 3
  } else {
    avail_mem = task.memory.toGiga()
  }

  markdup_java_options = task.memory.toGiga() > 8 ? params.markdup_java_options : "\"-Xms" +  (task.memory.toGiga() / 2).trunc() + "g -Xmx" + (task.memory.toGiga() - 1) + "g\""
  
  """
  picard ${markdup_java_options} -Djava.io.tmpdir=/local/scratch MarkDuplicates \\
      MAX_RECORDS_IN_RAM=50000 \\
      INPUT=$bam \\
      OUTPUT=${bam.baseName}.markDups.bam \\
      METRICS_FILE=${bam.baseName}.markDups_metrics.txt \\
      REMOVE_DUPLICATES=false \\
      ASSUME_SORTED=true \\
      PROGRAM_RECORD_ID='null' \\
      VALIDATION_STRINGENCY=LENIENT
  samtools index ${bam.baseName}.markDups.bam
  """
}

process dupradar {
  tag "${bam_md}"
  publishDir "${params.outdir}/dupradar", mode: 'copy',
      saveAs: {filename ->
          if (filename.indexOf("_duprateExpDens.pdf") > 0) "scatter_plots/$filename"
          else if (filename.indexOf("_duprateExpBoxplot.pdf") > 0) "box_plots/$filename"
          else if (filename.indexOf("_expressionHist.pdf") > 0) "histograms/$filename"
          else if (filename.indexOf("_dupMatrix.txt") > 0) "gene_data/$filename"
          else if (filename.indexOf("_duprateExpDensCurve.txt") > 0) "scatter_curve_data/$filename"
          else if (filename.indexOf("_intercept_slope.txt") > 0) "intercepts_slopes/$filename"
          else "$filename"
      }

  when:
    !params.skip_qc && !params.skip_dupradar

  input:
  file bam_md
  file gtf from gtf_dupradar.collect()
  val parse_res from stranded_results_dupradar

  output:
  file "*.{pdf,txt}" into dupradar_results

  script: 
  def dupradar_direction = 0
  if (parse_res == 'forward'){
      dupradar_direction = 1
  } else if ((parse_res == 'reverse')){
      dupradar_direction = 2
  }
  def paired = params.singleEnd ? 'single' :  'paired'
  """
  dupRadar.r $bam_md $gtf $dupradar_direction $paired ${task.cpus}
  """
}

/*
 * Counts
 */

process featureCounts {
  tag "${bam_featurecounts.baseName - 'Aligned.sortedByCoord.out'}"
  publishDir "${params.outdir}/counts", mode: 'copy',
      saveAs: {filename ->
          if (filename.indexOf("_counts.csv.summary") > 0) "gene_count_summaries/$filename"
          else if (filename.indexOf("_counts.csv") > 0) "gene_counts/$filename"
          else "$filename"
      }

  when:
  params.counts == 'featureCounts'

  input:
  file bam_featurecounts
  file gtf from gtf_featureCounts.collect()
  val parse_res from stranded_results_featureCounts

  output:
  file "${bam_featurecounts.baseName}_counts.csv" into featureCounts_counts_to_merge, featureCounts_counts_to_r
  file "${bam_featurecounts.baseName}_counts.csv.summary" into featureCounts_logs

  script:
  def featureCounts_direction = 0
  if (parse_res == 'forward'){
      featureCounts_direction = 1
  } else if ((parse_res == 'reverse')){
      featureCounts_direction = 2
  }
  """
  featureCounts ${params.featurecounts_opts} -T ${task.cpus} -a $gtf -o ${bam_featurecounts.baseName}_counts.csv -p -s $featureCounts_direction $bam_featurecounts
  """
}

process HTseqCounts {
  tag "${bam_HTseqCounts}"
  publishDir "${params.outdir}/counts", mode: 'copy',
      saveAs: {filename ->
          if (filename.indexOf("_gene.HTseqCounts.txt.summary") > 0) "gene_count_summaries/$filename"
          else if (filename.indexOf("_gene.HTseqCounts.txt") > 0) "gene_counts/$filename"
          else "$filename"
      }
  when:
  params.counts == 'HTseqCounts'

  input:
  file bam_HTseqCounts
  file gtf from gtf_HTseqCounts.collect()
  val parse_res from  stranded_results_HTseqCounts

  output: 
  file "*_counts.csv" into htseq_counts_to_merge, htseq_counts_to_r, HTSeqCounts_logs

  script:
  def stranded_opt = '-s no' 
  if (parse_res == 'forward'){
      stranded_opt= '-s yes'
  } else if ((parse_res == 'reverse')){
      stranded_opt= '-s reverse'
  }
  """
  htseq-count ${params.htseq_opts} $stranded_opt $bam_HTseqCounts $gtf > ${bam_HTseqCounts.baseName}_counts.csv
  """
}


counts_to_merge = Channel.empty()
counts_to_r = Channel.empty()
if( params.counts == 'featureCounts' ){
    counts_to_merge = featureCounts_counts_to_merge
    counts_to_r = featureCounts_counts_to_r
} else if (params.counts == 'HTseqCounts'){
    counts_to_merge = htseq_counts_to_merge
    counts_to_r = htseq_counts_to_r	
}else if (params.counts == 'star'){
    counts_to_merge = star_counts_to_merge
    counts_to_r = star_counts_to_r
}

process merge_counts {
  publishDir "${params.outdir}/counts", mode: 'copy'

  input:
  file input_counts from counts_to_merge.collect()
  file gtf from gtf_table.collect()
  val parse_res from stranded_results_table.collect()

  output:
  file 'tablecounts_raw.csv' into raw_counts, counts_saturation
  file 'tablecounts_tpm.csv' into tpm_counts, tpm_genetype
  file 'tableannot.csv' into genes_annot

  script:
  """
  echo -e ${input_counts} | tr " " "\n" > listofcounts.tsv
  echo -n "${parse_res}" | sed -e "s/\\[//" -e "s/\\]//" -e "s/,//g" | tr " " "\n" > listofstrandness.tsv
  makeCountTable.r listofcounts.tsv ${gtf} ${params.counts} listofstrandness.tsv
  """
}

counts_logs = Channel.empty()
if( params.counts == 'featureCounts' ){
    counts_logs = featureCounts_logs
} else if (params.counts == 'HTseqCounts'){
    counts_logs = HTSeqCounts_logs
}else if (params.counts == 'star'){
    counts_logs = star_log_counts
}


/*
 * Gene-based saturation
 */

process geneSaturation {
  publishDir "${params.outdir}/gene_saturation" , mode: 'copy'

  when:
  !params.skip_qc && !params.skip_saturation

  input:
  file input_counts from counts_saturation.collect()

  output:
  file "*gcurve.txt" into genesat_results

  script:
  """
  gene_saturation.r $input_counts counts.gcurve.txt
  """
}


/*
 * Reads distribution
 */

process read_distribution {
  tag "${bam_read_dist}"
  publishDir "${params.outdir}/read_distribution" , mode: 'copy'

  when:
  !params.skip_readdist

  input:
  file bam_read_dist
  file bed12 from bed_read_dist.collect()

  output:
  file "*.txt" into read_dist_results

  script:
  """
  read_distribution.py -i ${bam_read_dist} -r ${bed12} > ${bam_read_dist.baseName}.read_distribution.txt
  """
}


process getCountsPerGeneType {
  publishDir "${params.outdir}/read_distribution", mode: 'copy'

  when:
  !params.skip_readdist

  input:
  file tpm_genetype
  file gtf from gtf_genetype.collect()
 
  output:
  file "*genetype.txt" into counts_per_genetype

  script:
  """
  gene_type_expression.r ${tpm_genetype} ${gtf} counts_genetype.txt 
  """
}


/*
 * Exploratory analysis
 */

process exploratory_analysis {
  publishDir "${params.outdir}/exploratory_analysis", mode: 'copy'

  when:
  !params.skip_expan

  input:
  file table_raw from raw_counts.collect()
  file table_tpm from tpm_counts.collect()
  val num_sample from counts_to_r.count()
  file pca_header from ch_pca_header
  file heatmap_header from ch_heatmap_header

  output:
  file "*.{txt,pdf,csv}" into exploratory_analysis_results

  when:
  num_sample > 2

  script:
  """
  exploratory_analysis.r ${table_raw}
  cat $pca_header deseq2_pca_coords_mqc.csv >> tmp_file
  mv tmp_file deseq2_pca_coords_mqc.csv 
  cat $heatmap_header vst_sample_cor_mqc.csv >> tmp_file
  mv tmp_file vst_sample_cor_mqc.csv
  """
}

/*
 * MultiQC
 */

process get_software_versions {
  output:
  file 'software_versions_mqc.yaml' into software_versions_yaml

  script:
  """
  echo $workflow.manifest.version &> v_rnaseq.txt
  echo $workflow.nextflow.version &> v_nextflow.txt
  fastqc --version &> v_fastqc.txt
  STAR --version &> v_star.txt
  tophat2 --version &> v_tophat2.txt
  hisat2 --version &> v_hisat2.txt
  preseq &> v_preseq.txt
  infer_experiment.py --version &> v_rseqc.txt
  read_duplication.py --version &> v_read_duplication.txt
  featureCounts -v &> v_featurecounts.txt
  htseq-count -h | grep version  &> v_htseq.txt
  picard MarkDuplicates --version &> v_markduplicates.txt || true
  samtools --version &> v_samtools.txt
  multiqc --version &> v_multiqc.txt
  scrape_software_versions.py &> software_versions_mqc.yaml
  """
}

process workflow_summary_mqc {
  when:
  !params.skip_multiqc

  output:
  file 'workflow_summary_mqc.yaml' into workflow_summary_yaml

  exec:
  def yaml_file = task.workDir.resolve('workflow_summary_mqc.yaml')
  yaml_file.text  = """
  id: 'summary'
  description: " - this information is collected when the pipeline is started."
  section_name: 'Workflow Summary'
  section_href: 'https://gitlab.curie.fr/rnaseq'
  plot_type: 'html'
  data: |
      <dl class=\"dl-horizontal\">
${summary.collect { k,v -> "            <dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }.join("\n")}
      </dl>
  """.stripIndent()
}

process multiqc {
    publishDir "${params.outdir}/MultiQC", mode: 'copy'

    when:
    !params.skip_multiqc

    input:
    file splan from ch_splan.collect()
    file metadata from ch_metadata.ifEmpty([])
    file multiqc_config from ch_multiqc_config    
    file (fastqc:'fastqc/*') from fastqc_results.collect().ifEmpty([])
    file ('rrna/*') from rrna_logs.collect().ifEmpty([])
    file ('alignment/*') from alignment_logs.collect()
    file ('strandness/*') from strandness_results.collect().ifEmpty([])
    file ('rseqc/*') from read_dist_results.collect().ifEmpty([])
    file ('rseqc/*') from genebody_coverage_results.collect().ifEmpty([])
    file ('preseq/*') from preseq_results.collect().ifEmpty([])
    file ('genesat/*') from genesat_results.collect().ifEmpty([])
    file ('dupradar/*') from dupradar_results.collect().ifEmpty([])
    file ('picard/*') from picard_results.collect().ifEmpty([])	
    file ('counts/*') from counts_logs.collect()
    file ('genetype/*') from counts_per_genetype.collect().ifEmpty([])
    file ('exploratory_analysis_results/*') from exploratory_analysis_results.collect().ifEmpty([]) // If the Edge-R is not run create an Empty array
    file ('software_versions/*') from software_versions_yaml.collect()
    file ('workflow_summary/*') from workflow_summary_yaml.collect()

    output:
    file splan
    file "*multiqc_report.html" into multiqc_report
    file "*_data"

    script:
    rtitle = custom_runName ? "--title \"$custom_runName\"" : ''
    rfilename = custom_runName ? "--filename " + custom_runName + "_multiqc_report" : ''
    metadata_opts = params.metadata ? "--metadata ${metadata}" : ""
    splan_opts = params.samplePlan ? "--splan ${params.samplePlan}" : ""
    isPE = params.singleEnd ? 0 : 1
    
    modules_list = "-m custom_content -m preseq -m rseqc -m bowtie1 -m hisat2 -m star -m tophat -m cutadapt -m fastqc"
    modules_list = params.counts == 'featureCounts' ? "${modules_list} -m featureCounts" : "${modules_list}"  
    modules_list = params.counts == 'HTseqCounts' ? "${modules_list} -m htseq" : "${modules_list}"  
 
    """
    stats2multiqc.sh ${splan} ${params.aligner} ${isPE}
    ##max_read_nb="\$(awk -F, 'BEGIN{a=0}(\$1>a){a=\$3}END{print a}' mq.stats)"
    median_read_nb="\$(sort -t, -k3,3n mq.stats | awk -F, '{a[i++]=\$3;} END{x=int((i+1)/2); if (x<(i+1)/2) print(a[x-1]+a[x])/2; else print a[x-1];}')"
    mqc_header.py --name "RNA-seq" --version ${workflow.manifest.version} ${metadata_opts} ${splan_opts} --nbreads \${median_read_nb} > multiqc-config-header.yaml
    multiqc . -f $rtitle $rfilename -c $multiqc_config -c multiqc-config-header.yaml $modules_list
    """    
}


/*
 * Sub-routine
 */
process output_documentation {
    publishDir "${params.outdir}/pipeline_info", mode: 'copy'

    input:
    file output_docs from ch_output_docs

    output:
    file "results_description.html"

    script:
    """
    markdown_to_html.r $output_docs results_description.html
    """
}

workflow.onComplete {

    /*pipeline_report.html*/

    def report_fields = [:]
    report_fields['version'] = workflow.manifest.version
    report_fields['runName'] = custom_runName ?: workflow.runName
    report_fields['success'] = workflow.success
    report_fields['dateComplete'] = workflow.complete
    report_fields['duration'] = workflow.duration
    report_fields['exitStatus'] = workflow.exitStatus
    report_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
    report_fields['errorReport'] = (workflow.errorReport ?: 'None')
    report_fields['commandLine'] = workflow.commandLine
    report_fields['projectDir'] = workflow.projectDir
    report_fields['summary'] = summary
    report_fields['summary']['Date Started'] = workflow.start
    report_fields['summary']['Date Completed'] = workflow.complete
    report_fields['summary']['Pipeline script file path'] = workflow.scriptFile
    report_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
    if(workflow.repository) report_fields['summary']['Pipeline repository Git URL'] = workflow.repository
    if(workflow.commitId) report_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
    if(workflow.revision) report_fields['summary']['Pipeline Git branch/tag'] = workflow.revision

    report_fields['skipped_poor_alignment'] = skipped_poor_alignment

    // Render the TXT template
    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("$baseDir/assets/oncomplete_template.txt")
    def txt_template = engine.createTemplate(tf).make(report_fields)
    def report_txt = txt_template.toString()
    
    // Render the HTML template
    def hf = new File("$baseDir/assets/oncomplete_template.html")
    def html_template = engine.createTemplate(hf).make(report_fields)
    def report_html = html_template.toString()

    // Write summary e-mail HTML to a file
    def output_d = new File( "${params.outdir}/pipeline_info/" )
    if( !output_d.exists() ) {
      output_d.mkdirs()
    }
    def output_hf = new File( output_d, "pipeline_report.html" )
    output_hf.withWriter { w -> w << report_html }
    def output_tf = new File( output_d, "pipeline_report.txt" )
    output_tf.withWriter { w -> w << report_txt }

    /*oncomplete file*/

    File woc = new File("${params.outdir}/workflow.oncomplete.txt")
    Map endSummary = [:]
    endSummary['Completed on'] = workflow.complete
    endSummary['Duration']     = workflow.duration
    endSummary['Success']      = workflow.success
    endSummary['exit status']  = workflow.exitStatus
    endSummary['Error report'] = workflow.errorReport ?: '-'
    String endWfSummary = endSummary.collect { k,v -> "${k.padRight(30, '.')}: $v" }.join("\n")
    println endWfSummary
    String execInfo = "${fullSum}\nExecution summary\n${logSep}\n${endWfSummary}\n${logSep}\n"
    woc.write(execInfo)

    /*final logs*/

    if(skipped_poor_alignment.size() > 0){
        log.info "[rnaseq] WARNING - ${skipped_poor_alignment.size()} samples skipped due to poor alignment scores!"
    }

    if(workflow.success){
        log.info "[rnaseq] Pipeline Complete"
    }else{
        log.info "[rnaseq] FAILED: $workflow.runName"
        if( workflow.profile == 'test'){
            log.error "====================================================\n" +
                    "  WARNING! You are running with the profile 'test' only\n" +
                    "  pipeline config profile, which runs on the head node\n" +
                    "  and assumes all software is on the PATH.\n" +
                    "  This is probably why everything broke.\n" +
                    "  Please use `-profile test,conda` or `-profile test,singularity` to run on local.\n" +
                    "  Please use `-profile test,conda,cluster` or `-profile test,singularity,cluster` to run on your cluster.\n" +
                    "============================================================"
        }
    }
 
}
