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
                         @git_repo_name@
========================================================================================
 @git_repo_name@ analysis Pipeline.
 #### Homepage / Documentation
 @git_url@
----------------------------------------------------------------------------------------
*/

// File with text to display when a developement version is used
devMessageFile = file("$baseDir/assets/devMessage.txt")

def helpMessage() {
    if ("${workflow.manifest.version}" =~ /dev/ ){
       log.info devMessageFile.text
    }

    log.info """
    @git_repo_name@ v${workflow.manifest.version}
    ======================================================================

    Usage:
    nextflow run rnaseq --reads '*_R{1,2}.fastq.gz' --genome hg19 -profile conda
    nextflow run rnaseq --samplePlan samplePlan --genome hg19 -profile conda


    Mandatory arguments:
      --reads 'READS'               Path to input data (must be surrounded with quotes)
      --samplePlan 'SAMPLEPLAN'     Path to sample plan input file (cannot be used with --reads)
      --genome 'BUILD'              Name of genome reference
      -profile PROFILE              Configuration profile to use. test / conda / toolsPath / singularity / cluster (see below)

    =======================================================
    Available Profiles

      -profile test                Set up the test dataset
      -profile conda               Build a new conda environment before running the pipeline
      -profile path                Use the paths defined in configuration for each tool
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


// Has the run name been specified by the user?
// this has the bonus effect of catching both -name and --name
customRunName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  customRunName = workflow.runName
}

// Stage config files
multiqcConfigCh = Channel.fromPath(params.multiqcConfig)
OutputDocsCh = Channel.fromPath("$baseDir/docs/output.md")
pcaHeaderCh = Channel.fromPath("$baseDir/assets/pcaHeader.txt")
heatmapHeaderCh = Channel.fromPath("$baseDir/assets/heatmapHeader.txt")

/*
 * CHANNELS
 */

// Validate inputs
if ((params.reads && params.samplePlan) || (params.readPaths && params.samplePlan)){
   exit 1, "Input reads must be defined using either '--reads' or '--samplePlan' parameter. Please choose one way"
}



if ( params.metadata ){
   Channel
       .fromPath( params.metadata )
       .ifEmpty { exit 1, "Metadata file not found: ${params.metadata}" }
       .set { metadataCh }
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
         .set { rawReadsFastqc }
   }else{
      Channel
         .from(file("${params.samplePlan}"))
         .splitCsv(header: false)
         .map{ row -> [ row[0], [file(row[2]), file(row[3])]] }
         .set { rawReadsFastqc }
   }
   params.reads=false
}
else if(params.readPaths){
    if(params.singleEnd){
        Channel
            .from(params.readPaths)
            .map { row -> [ row[0], [file(row[1][0])]] }
            .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
            .set { rawReadsFastqc }
    } else {
        Channel
            .from(params.readPaths)
            .map { row -> [ row[0], [file(row[1][0]), file(row[1][1])]] }
            .ifEmpty { exit 1, "params.readPaths was empty - no input files supplied" }
            .set { rawReadsFastqc }
    }
} else {
    Channel
        .fromFilePairs( params.reads, size: params.singleEnd ? 1 : 2 )
        .ifEmpty { exit 1, "Cannot find any reads matching: ${params.reads}\nNB: Path needs to be enclosed in quotes!\nNB: Path requires at least one * wildcard!\nIf this is single-end data, please specify --singleEnd on the command line." }
        .set { rawReadsFastqc }
}

/*
 * Make sample plan if not available
 */

if (params.samplePlan){
  samplePlanCh = Channel.fromPath(params.samplePlan)
}else if(params.readPaths){
  if (params.singleEnd){
    Channel
       .from(params.readPaths)
       .collectFile() {
         item -> ["samplePlan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + '\n']
        }
       .set{ samplePlanCh }
  }else{
     Channel
       .from(params.readPaths)
       .collectFile() {
         item -> ["samplePlan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + ',' + item[1][1] + '\n']
        }
       .set{ samplePlanCh }
  }
}else{
  if (params.singleEnd){
    Channel
       .fromFilePairs( params.reads, size: 1 )
       .collectFile() {
          item -> ["samplePlan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + '\n']
       }     
       .set { samplePlanCh }
  }else{
    Channel
       .fromFilePairs( params.reads, size: 2 )
       .collectFile() {
          item -> ["samplePlan.csv", item[0] + ',' + item[0] + ',' + item[1][0] + ',' + item[1][1] + '\n']
       }     
       .set { samplePlanCh }
   }
}


// Header log info
if ("${workflow.manifest.version}" =~ /dev/ ){
   log.info devMessageFile.text
}

log.info """=======================================================

 @git_repo_name@ workflow v${workflow.manifest.version}
======================================================="""
def summary = [:]

summary['Max Memory']     = params.maxMemory
summary['Max CPUs']       = params.maxCpus
summary['Max Time']       = params.maxTime
summary['Container Engine'] = workflow.containerEngine
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Output dir']     = params.outputDir
summary['Config Profile'] = workflow.profile

if(params.email) summary['E-mail Address'] = params.email
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="




process workflowSummaryMqc {

  output:
  file 'workflowSummaryMqc.yaml' into workflowSummaryYaml

  exec:
  def yamlFile = task.workDir.resolve('workflowSummaryMqc.yaml')
  yamlFile.text  = """
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


/*
 * Write markdown documentation
 */
process outputDocumentation {
  label 'rmarkdown'
  publishDir "${params.summaryDir}", mode: 'copy'

  input:
  file outputDocs from OutputDocsCh

  output:
  file "resultsDescription.html"

  script:
  """
  markdownToHtml.r $outputDocs resultsDescription.html
  """
}


/*
 * FastQC
 */
process fastqc {
  label 'fastqc'
  label 'smallMem'
  label 'smallCpu'

  tag "${prefix}"
  publishDir "${params.outputDir}/fastqc", mode: 'copy',
      saveAs: {filename -> filename.indexOf(".zip") > 0 ? "zips/$filename" : "$filename"}

  input:
  set val(prefix), file(reads) from rawReadsFastqc

  output:
  file "*_fastqc.{zip,html}" into fastqcResults

  script:
  pbase = reads[0].toString() - ~/(\.fq)?(\.fastq)?(\.gz)?$/
  """
  fastqc ${params.fastqcOpts} $reads
  mv ${pbase}_fastqc.html ${prefix}_fastqc.html
  mv ${pbase}_fastqc.zip ${prefix}_fastqc.zip
  """
}

/*
 * alpine 
 */
// example with local variable
oneToFiveCh = Channel.of(1..5)
process alpine {
  label 'alpine'
  label 'smallMem'
  label 'smallCpu'
  publishDir "${params.outputDir}/alpine", mode: 'copy'

  input:
  val x from oneToFiveCh

  output:
  file "alpine_*"

  script:
  """
  source ${baseDir}/env/alpine.env
  echo "Hello from alpine: \$(date). This is very high here: \${peak_height}!" > alpine_${x}.txt
  """
}


/*
 * helloWord from source code 
 */

process helloWorld {
  label 'helloWorld'
  label 'smallMem'
  label 'smallCpu'
  publishDir "${params.outputDir}/helloWorld", mode: 'copy'

  output:
  file "helloWorld.txt" into helloWorldOutputCh

  script:
  """
  helloWorld > helloWorld.txt
  """
}


/*
 * process with onlyLinux (standard unix command)
 */

process standardUnixCommand {
  label 'onlyLinux'
  label 'smallMem'
  label 'smallCpu'
  publishDir "${params.outputDir}/standardUnixCommand", mode: 'copy'

  input:
  file hello from helloWorldOutputCh

  output:
  file "bonjourMonde.txt"

  script:
  """
  sed -e 's/Hello World/Bonjour Monde/g' ${hello} > bonjourMonde.txt
  """
}

/*
 * process with onlylinux (invoke script from bin/ directory) 
 */

process execBinScript {
  label 'onlyLinux'
  label 'smallMem'
  label 'smallCpu'
  publishDir "${params.outputDir}/execBinScript", mode: 'copy'

  output:
  file "execBinScriptResults_*"

  script:
  """
  apMyscript.sh > execBinScriptResults_1.txt
  someScript.sh > execBinScriptResults_2.txt
  """
}

/*
 * Some process with a software that has to be
 * installed with a custom conda yml file
 */


process trickySoftware {
  label 'trickySoftware'
  label 'smallMem'
  label 'smallCpu'
  publishDir "${params.outputDir}/trickySoftware", mode: 'copy'

  output:
  file "trickySoftwareResults.txt"

  script:
  """
  python ${params.trickySoftwareOpts} > trickySoftwareResults.txt 2>&1
  """
}

workflow.onComplete {

    // pipeline_report.html

    def reportFields = [:]
    reportFields['version'] = workflow.manifest.version
    reportFields['runName'] = customRunName ?: workflow.runName
    reportFields['success'] = workflow.success
    reportFields['dateComplete'] = workflow.complete
    reportFields['duration'] = workflow.duration
    reportFields['exitStatus'] = workflow.exitStatus
    reportFields['errorMessage'] = (workflow.errorMessage ?: 'None')
    reportFields['errorReport'] = (workflow.errorReport ?: 'None')
    reportFields['commandLine'] = workflow.commandLine
    reportFields['projectDir'] = workflow.projectDir
    reportFields['summary'] = summary
    reportFields['summary']['Date Started'] = workflow.start
    reportFields['summary']['Date Completed'] = workflow.complete
    reportFields['summary']['Pipeline script file path'] = workflow.scriptFile
    reportFields['summary']['Pipeline script hash ID'] = workflow.scriptId
    if(workflow.repository) reportFields['summary']['Pipeline repository Git URL'] = workflow.repository
    if(workflow.commitId) reportFields['summary']['Pipeline repository Git Commit'] = workflow.commitId
    if(workflow.revision) reportFields['summary']['Pipeline Git branch/tag'] = workflow.revision


    // Render the TXT template
    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("$baseDir/assets/onCompleteTemplate.txt")
    def txtTemplate = engine.createTemplate(tf).make(reportFields)
    def reportTxt = txtTemplate.toString()
    
    // Render the HTML template
    def hf = new File("$baseDir/assets/onCompleteTemplate.html")
    def htmlTemplate = engine.createTemplate(hf).make(reportFields)
    def reportHtml = htmlTemplate.toString()

    // Write summary e-mail HTML to a file
    def outputSummaryDir = new File( "${params.summaryDir}/" )
    if( !outputSummaryDir.exists() ) {
      outputSummaryDir.mkdirs()
    }
    def outputHtmlFile = new File( outputSummaryDir, "pipelineReport.html" )
    outputHtmlFile.withWriter { w -> w << reportHtml }
    def outputTxtFile = new File( outputSummaryDir, "pipelineReport.txt" )
    outputTxtFile.withWriter { w -> w << reportTxt }

    // onComplete file

    File woc = new File("${params.outputDir}/onComplete.txt")
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

    // final logs

    if(workflow.success){
        log.info "Pipeline Complete"
    }else{
        log.info "FAILED: $workflow.runName"
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
