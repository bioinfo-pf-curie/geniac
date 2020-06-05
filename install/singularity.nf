#!/usr/bin/env nextflow

// before running, start a local docker registry:
// sudo docker run -d -p 5000:5000 --restart=always --name registry registry:2


/**
 * CUSTOM FUNCTIONS
**/

def addYumAndGitToCondaCh(List condaIt) {
    List<String> gitList = []
    (params.geniac.containers.git[condaIt[0]]?:'')
        .split()
        .each{ gitList.add(it.split('::')) }

    return [
        condaIt[0],
        condaIt[1],
        params.geniac.containers.yum[condaIt[0]],
        gitList
    ]
}

String buildCplmtGit(def gitEntries) {
    String cplmtGit = ''
    for (String[] tab: gitEntries) {
        cplmtGit += """ \\\\
    && mkdir /opt/\$(basename ${tab[0]} .git) && cd /opt/\$(basename ${tab[0]} .git) && git clone ${tab[0]} . && git checkout ${tab[1]}"""
    }

    return cplmtGit

}

String buildCplmtPath(List gitEntries) {
    String cplmtPath = ''
    for (String[] tab: gitEntries) {
        cplmtPath += "/opt/\$(basename ${tab[0]} .git):"
    }

    return cplmtPath
}



/**
 * CHANNELS INIT
**/

condaPackagesCh = Channel.create()
condaFilesCh = Channel.create()
Channel
    .from(params.geniac.tools)
    .flatMap{
        List<String> result = []
        for (Map.Entry<String,String> entry: it.entrySet()) {
            List<String> tab = entry.value.split()

            for (String s: tab) {
                result.add([entry.key, s.split('::')])
            }

            if (tab.size == 0) {
                result.add([entry.key, null])
            }
        }

        return result
    }.choice(condaFilesCh, condaPackagesCh){
        it[1] && it[1][0].endsWith('.yml') ? 0 : 1
    }
condaPackagesCh.into{ condaPackages4SingularityRecipesCh; condaPackages4CondaEnvCh}

Channel
    .fromPath("${baseDir}/recipes/singularity/*.def")
    .map{
        String optionalFile = null
        if (it.simpleName == 'r') {
            optionalFile = "${baseDir}/../preconfs/renv.lock"
        } else if (it.simpleName == 'transIndelAndSamtools') {
            optionalFile = "${baseDir}/conda/transIndel.yml"
        } else if (it.simpleName == 'bcl2fastq') {
            optionalFile = "${baseDir}/tools/bcl2fastq2-v2.20.0.422-Linux-x86_64.rpm"
        } else {
            optionalFile = 'EMPTY'
        }

        return [it.simpleName, it, optionalFile]
    }
    .set{ singularityRecipeCh1 }


/**
 * CONDA RECIPES
**/

Channel
    .fromPath("${baseDir}/recipes/conda/*.yml")
    .set{ condaRecipes }


/**
 * DEPENDENCIES
**/

Channel
    .fromPath("${baseDir}/recipes/dependencies/*")
    .set{ fileDependencies }

/**
 * SOURCE CODE
**/


Channel
    .fromPath("${baseDir}/modules", type: 'dir')
    .set{ sourceCodeDirCh }


Channel
    .fromPath("${baseDir}/modules/*.sh")
    .map{
        return [it.simpleName, it]
    }
    .set{ sourceCodeCh }

/**
 * PROCESSES
**/
// TODO: use worklow.manifest.name for the name field
// TODO: check if it works with pip packages 
// TODO: Add a process in order to test the generated environment.yml (create a venv from it, activate, export and check diffs)
// TODO: Check if order of dependencies can be an issue 
condaChannelFromSpecsCh = Channel.create()
condaDepFromSpecsCh = Channel.create()
condaSpecsCh = condaPackages4CondaEnvCh.separate( condaChannelFromSpecsCh, condaDepFromSpecsCh ) { pTool -> [pTool[1][0], pTool[1][1]] }

process buildCondaEnvFromCondaPackages {
    tag "condaEnvBuild"
    publishDir "${baseDir}/${params.publishDirConda}", overwrite: true, mode: 'copy'

    input:
    val condaDependencies from condaDepFromSpecsCh.unique().collect()
    val condaChannels from condaChannelFromSpecsCh.filter( ~/!(bioconda|conda-forge|defaults)/ ).unique().collect().ifEmpty('NO_CHANNEL')

    output:
    file("environment.yml")

    script:
    def condaChansEnv = condaChannels != 'NO_CHANNEL' ? condaChannels : []
    String condaDepEnv = String.join("\n    - ", condaDependencies)
    String condaChanEnv = String.join("\n    - ", ["bioconda", "conda-forge", "defaults"] + condaChansEnv)
    """
    cat << EOF > environment.yml
    # You can use this file to create a conda environment for this pipeline:
    #   conda env create -f environment.yml
    name: pipeline_env
    channels:
    - ${condaChanEnv} 
    dependencies:
    - which 
    - bc
    - ${condaDepEnv}
    """
}

process buildDefaultSingularityRecipe {
    publishDir "${baseDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

    output:
    set val(key), file("${key}.def"), val('EMPTY') into singularityRecipeCh2

    script:
    key = 'onlyLinux'

    """
    cat << EOF > ${key}.def
    Bootstrap: docker
    From: centos:7

    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %post
        yum install -y which \\\\
        && yum clean all

    %environment
        LC_ALL=en_US.utf-8
        LANG=en_US.utf-8
    EOF
    """
}

process buildSingularityRecipeFromCondaFile {
    tag "${key}"
    publishDir "${baseDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

    input:
    set val(key), val(condaFile), val(yum), val(git) from condaFilesCh
        .groupTuple()
        .map{ addYumAndGitToCondaCh(it) }
        .map{ [it[0], it[1][0].join(), it[2], it[3]] }

    output:
    set val(key), file("${key}.def"), val(condaFile) into singularityRecipeCh3

    script:
    String cplmtGit = buildCplmtGit(git)
    String cplmtPath = buildCplmtPath(git)
    String yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs

    """
    declare env_name=\$(head -1 ${condaFile} | cut -d' ' -f2)

    cat << EOF > ${key}.def
    Bootstrap: docker
    From: conda/miniconda3-centos7
    
    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %environment
        PATH=/usr/local/envs/\${env_name}/bin:${cplmtPath}\\\$PATH
        LC_ALL=en_US.utf-8
        LANG=en_US.utf-8

    # real path from baseDir: ${condaFile}
    %files
        \$(basename ${condaFile}) /opt/\$(basename ${condaFile})
    
    %post
        yum install -y which ${yumPkgs} ${cplmtGit} \\\\
        && yum clean all \\\\
        && conda env create -f /opt/\$(basename ${condaFile}) \\\\
        && echo "source activate \${env_name}" > ~/.bashrc \\\\
        && conda clean -a

    EOF
    """
}

/** 
 * Build Singularity recipe from conda specifications in params.geniac.tools
**/
process buildSingularityRecipeFromCondaPackages {
    tag "${key}"
    publishDir "${baseDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'


    input:
    set val(key), val(tools), val(yum), val(git) from condaPackages4SingularityRecipesCh
        .groupTuple()
        .map{ addYumAndGitToCondaCh(it) }

    output:
    set val(key), file("${key}.def"), val('EMPTY') into singularityRecipeCh4

    script:
    String cplmtGit = buildCplmtGit(git)
    String cplmtPath = buildCplmtPath(git)
    String yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs

    String cplmtConda = ''
    for (String[] tab: tools) {
        cplmtConda += """ \\\\
    && conda install -y -c ${tab[0]} -n ${key}_env ${tab[1]}"""
    }

    """
    cat << EOF > ${key}.def
    Bootstrap: docker
    From: conda/miniconda3-centos7
    
    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %environment
        PATH=/usr/local/envs/${key}_env/bin:${cplmtPath}\\\$PATH
        LC_ALL=en_US.utf-8
        LANG=en_US.utf-8

    %post
        yum install -y which ${yumPkgs} ${cplmtGit} \\\\
        && yum clean all \\\\
        && conda create -y -n ${key}_env ${cplmtConda} \\\\
        && echo "source activate ${key}_env" > ~/.bashrc \\\\
        && conda clean -a

    EOF
    """
}


process buildSingularityRecipeFromSourceCode {
    tag "${key}"
    publishDir "${baseDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

    input:
    set val(key), file(installFile) from sourceCodeCh
    
    output:
    set val(key), file("${key}.def"), val('EMPTY') into singularityRecipeCh5

    script:
    """
    cat << EOF > ${key}.def
    Bootstrap: docker
    From: centos:7
    Stage: devel
   
    %setup
        mkdir -p \\\${SINGULARITY_ROOTFS}/opt/modules
 
    %files
        modules/${installFile} /opt/modules
        modules/${key}/ /opt/modules
      
    %post
        yum install -y epel-release which gcc gcc-c++ make \\\\
        && cd /opt/modules \\\\
        && bash ${installFile} \\\\
    
    Bootstrap: docker
    From: centos:7
    Stage: final
    
    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %files from devel
        /usr/local/bin /usr/local/bin
    

    %environment
        LC_ALL=en_US.utf-8
        LANG=en_US.utf-8
        PATH=/usr/local/bin:\\\$PATH
    
    EOF
    """
}

onlyCondaRecipeCh = singularityRecipeCh3.mix(singularityRecipeCh4)
onlyCondaRecipeCh.into { onlyCondaRecipe4buildCondaCh ; onlyCondaRecipe4buildMulticondaCh ; onlyCondaRecipe4buildImagesCh }

singularityAllRecipeCh = singularityRecipeCh1.mix(singularityRecipeCh2).mix(onlyCondaRecipe4buildImagesCh).mix(singularityRecipeCh5)
singularityAllRecipeCh.into { singularityAllRecipe4buildImagesCh ; singularityAllRecipe4buildSingularityCh ; singularityAllRecipe4buildDockerCh ; singularityAllRecipe4buildPathCh}

process buildImages {
    tag "${key}"
    publishDir "${baseDir}/${params.publishDirSingularityImages}", overwrite: true, mode: 'copy'

    when:
    params.buildSingularityImages

    input:
    set val(key), file(singularityRecipe), val(optionalPath) from singularityAllRecipe4buildImagesCh 
    file condaYml from condaRecipes.collect().ifEmpty([])
    file fileDep from fileDependencies.collect().ifEmpty([])
    file moduleDir from sourceCodeDirCh.collect().ifEmpty([])

    output:
    file("${key.toLowerCase()}.simg")

    script:

    """
    singularity build ${key.toLowerCase()}.simg ${singularityRecipe}
    """
}


/**
 * Generate singularity.config
**/

process buildSingularityConfig {
    tag "${key}"

    when:
    params.buildConfigFiles

    input:
    set val(key), file(singularityRecipe), val(optionalPath) from singularityAllRecipe4buildSingularityCh 

    output:
    file("${key}SingularityConfig.txt") into mergeSingularityConfigCh

    script:

    """
    cat << EOF > "${key}SingularityConfig.txt"
        withLabel:${key} { container = "\\\${params.geniac.containers.singularityImagePath}/${key.toLowerCase()}.simg" }
    EOF
    """
}

process mergeSingularityConfig {
    tag "mergeSingularityConfig"
    publishDir "${baseDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

    when:
    params.buildConfigFiles

    input:
    file key from mergeSingularityConfigCh.collect() 

    output:
    file("singularity.config") into finalSingularityConfigCh

    script:
    """
    cat << EOF > "singularity.config"
    includeConfig 'process.config'
    
    singularity {
        enabled = true
        autoMounts = true
        runOptions = "\\\${params.geniac.containers.singularityRunOptions}"
    }

    process {
    EOF
    for keyFile in ${key}
    do
        cat \${keyFile} >> singularity.config
    done
    echo "}"  >> singularity.config
    """
}

/**
 * Generate docker.config
**/

process buildDockerConfig {
    tag "${key}"

    when:
    params.buildConfigFiles

    input:
    set val(key), file(singularityRecipe), val(optionalPath) from singularityAllRecipe4buildDockerCh 

    output:
    file("${key}DockerConfig.txt") into mergeDockerConfigCh

    script:

    """
    cat << EOF > "${key}DockerConfig.txt"
        withLabel:${key} { container = "${key.toLowerCase()}" }
    EOF
    """
}

process mergeDockerConfig {
    tag "mergeDockerConfig"
    publishDir "${baseDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

    when:
    params.buildConfigFiles

    input:
    file key from mergeDockerConfigCh.collect() 

    output:
    file("docker.config") into finalDockerConfigCh

    script:
    """
    cat << EOF > "docker.config"
    includeConfig 'process.config'
    
    docker {
        enabled = true
        runOptions = "\\\${params.geniac.containers.dockerRunOptions}"
    }

    process {
    EOF
    for keyFile in ${key}
    do
        cat \${keyFile} >> docker.config
    done
    echo "}"  >> docker.config
    """
}
/**
 * Generate conda.config
**/

process buildCondaConfig {
    tag "${key}"

    when:
    params.buildConfigFiles

    input:
    set val(key), file(singularityRecipe), val(optionalPath) from onlyCondaRecipe4buildCondaCh

    output:
    file("${key}CondaConfig.txt") into mergeCondaConfigCh

    script:

    """
    cat << EOF > "${key}CondaConfig.txt"
        withLabel:${key} { conda = "\\\${baseDir}/environment.yml" }
    EOF
    """
}

process mergeCondaConfig {
    tag "mergeCondaConfig"
    publishDir "${baseDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

    when:
    params.buildConfigFiles

    input:
    file key from mergeCondaConfigCh.collect() 

    output:
    file("conda.config") into finalCondaConfigCh

    script:
    """
    echo -e "includeConfig 'process.config'\n" > conda.config
    echo -e "conda { cacheDir = \\\"\\\${params.condaCacheDir}\\\" }\n" >> conda.config
    echo "process {"  >> conda.config
    for keyFile in ${key}
    do
        cat \${keyFile} >> conda.config
    done
    echo "}"  >> conda.config
    """
}

/**
 * Generate multiconda.config
**/

process buildMulticondaConfig {
    tag "${key}"
    //publishDir "${baseDir}/${params.publishDirNextflowConf}", overwrite: true, mode: 'copy'

    when:
    params.buildConfigFiles

    input:
    set val(key), file(singularityRecipe), val(optionalPath) from onlyCondaRecipe4buildMulticondaCh

    output:
    file("${key}MulticondaConfig.txt") into mergeMulticondaConfigCh

    script:

    """
    cat << EOF > "${key}MulticondaConfig.txt"
        withLabel:${key} { conda = "\\\${params.geniac.tools.${key}}" }
    EOF
    """
}

process mergeMulticondaConfig {
    tag "mergeMulticondaConfig"
    publishDir "${baseDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

    when:
    params.buildConfigFiles

    input:
    file key from mergeMulticondaConfigCh.collect() 

    output:
    file("multiconda.config") into finalMulticondaConfigCh

    script:
    """
    echo -e "includeConfig 'process.config'\n" > multiconda.config
    echo -e "conda { cacheDir = \\\"\\\${params.condaCacheDir}\\\" }\n" >> multiconda.config
    echo "process {"  >> multiconda.config
    for keyFile in ${key}
    do
        cat \${keyFile} >> multiconda.config
    done
    echo "}"  >> multiconda.config
    """
}

/**
 * Generate path.config
**/

process buildPathConfig {
    tag "${key}"
    //publishDir "${baseDir}/${params.publishDirNextflowConf}", overwrite: true, mode: 'copy'

    when:
    params.buildConfigFiles

    input:
    set val(key), file(singularityRecipe), val(optionalPath) from singularityAllRecipe4buildPathCh

    output:
    file("${key}PathConfig.txt") into mergePathConfigCh
    file("${key}PathLink.txt") into mergePathLinkCh

    script:

    """
    cat << EOF > "${key}PathConfig.txt"
        withLabel:${key} { beforeScript = "export PATH=\\\${baseDir}/../path/${key}/bin:\\\$PATH" } 
    EOF
    cat << EOF > "${key}PathLink.txt"
    ${key}/bin
    EOF
    """
}

process mergePathConfig {
    tag "mergePathConfig"
    publishDir "${baseDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

    when:
    params.buildConfigFiles

    input:
    file key from mergePathConfigCh.collect() 

    output:
    file("path.config") into finalPathConfigCh

    script:
    """
    echo -e "includeConfig 'process.config'\n" >> path.config
    echo "singularity {" >> path.config
    echo "  enable = false" >> path.config
    echo -e "}\n" >> path.config
    echo "docker {" >> path.config
    echo "  enable = false" >> path.config
    echo -e "}\n" >> path.config
    echo "process {"  >> path.config
    for keyFile in ${key}
    do
        cat \${keyFile} >> path.config
    done
    echo "}"  >> path.config
    grep -v onlyLinux path.config > path.config.tmp
    mv path.config.tmp path.config
    """
}

process mergePathLink {
    tag "mergePathLink"
    publishDir "${baseDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

    when:
    params.buildConfigFiles

    input:
    file key from mergePathLinkCh.collect()

    output:
    file("pathLink.txt") into finalPathLinkCh

    script:
    """
    for keyFile in ${key}
    do
        cat \${keyFile} >> pathLink.txt
    done
    grep -v onlyLinux pathLink.txt > pathLink.txt.tmp
    mv pathLink.txt.tmp pathLink.txt
    """
}

process clusterConfig {
    tag "clusterConfig"
    publishDir "${baseDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

    output:
    file("cluster.config")

    script:
    """
    cat << EOF > "cluster.config"
    /*
     * -------------------------------------------------
     *  Config the cluster profile and your scheduler
     * -------------------------------------------------
     */
    
    process {
        executor = '${params.clusterExecutor}'
        queue = params.queue ?: null
    }
    """
}
