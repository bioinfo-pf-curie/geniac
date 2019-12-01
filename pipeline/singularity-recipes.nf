#!/usr/bin/env nextflow

// before running, start a local docker registry:
// sudo docker run -d -p 5000:5000 --restart=always --name registry registry:2


/**
 * CUSTOM FUNCTIONS
**/

def addYumAndGitToCondaCh(List condaIt) {
    List<String> gitList = []
    (params.containers.git[condaIt[0]]?:'')
        .split()
        .each{ gitList.add(it.split('::')) }

    return [
        condaIt[0],
        condaIt[1],
        params.containers.yum[condaIt[0]],
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
    .from(params.tools)
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

Channel
    .fromPath("${baseDir}/singularity/*.def")
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
 * PROCESSES
**/

process buildDefaultSingularityRecipe {
    publishDir params.containers.singularityRecipes, overwrite: true

    output:
    set val(key), file("${key}.def"), val('EMPTY') into singularityRecipeCh2

    script:
    key = 'notools'

    """
    cat << EOF > ${key}.def
    Bootstrap: docker
    From: conda/miniconda3-centos7

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
    publishDir params.containers.singularityRecipes, overwrite: true

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

process buildSingularityRecipeFromCondaPackages {
    tag "${key}"
    publishDir params.containers.singularityRecipes, overwrite: true

    input:
    set val(key), val(tools), val(yum), val(git) from condaPackagesCh
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

process buildImages {
    maxForks 1
    tag "${key}"
    publishDir params.containers.singularityRecipes, overwrite: true

    when:
    params.buildSingularityImages

    input:
    set val(key), file(singularityRecipe), val(optionalPath) from singularityRecipeCh1.mix(singularityRecipeCh2).mix(singularityRecipeCh3).mix(singularityRecipeCh4)

    output:
    file("${key.toLowerCase()}.simg")

    script:
    String contextDir = optionalPath == 'EMPTY' ? '.' : "\$(dirname \$(realpath ${optionalPath}))"

    """
    singularity build ${key.toLowerCase()}.simg ${singularityRecipe}
    """
}

