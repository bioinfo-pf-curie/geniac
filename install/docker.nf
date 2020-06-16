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

Channel
    .fromPath("${baseDir}/recipes/docker/*.Dockerfile")
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
    .set{ dockerRecipeCh1 }


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

process buildDefaultDockerRecipe {
    publishDir "${baseDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

    output:
    set val(key), file("${key}.Dockerfile"), val('EMPTY') into dockerRecipeCh2

    script:
    key = 'onlyLinux'

    """
    cat << EOF > ${key}.Dockerfile
    FROM centos:7

    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    RUN yum install -y which \\\\
    && yum clean all

    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    EOF

    """
}

process buildDockerRecipeFromCondaFile {
    tag "${key}"
    publishDir "${baseDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

    input:
    set val(key), val(condaFile), val(yum), val(git) from condaFilesCh
        .groupTuple()
        .map{ addYumAndGitToCondaCh(it) }
        .map{ [it[0], it[1][0].join(), it[2], it[3]] }

    output:
    set val(key), file("${key}.Dockerfile"), val(condaFile) into dockerRecipeCh3

    script:
    String cplmtGit = buildCplmtGit(git)
    String cplmtPath = buildCplmtPath(git)
    String yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs

    """
    declare env_name=\$(head -1 ${condaFile} | cut -d' ' -f2)

    cat << EOF > ${key}.Dockerfile
    FROM conda/miniconda3-centos7

    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    # real path from baseDir: ${condaFile}
    ADD \$(basename ${condaFile}) /opt/\$(basename ${condaFile})

    RUN yum install -y which ${yumPkgs} ${cplmtGit} \\\\
    && yum clean all \\\\
    && conda env create -f /opt/\$(basename ${condaFile}) \\\\
    && echo "source activate \${env_name}" > ~/.bashrc \\\\
    && conda clean -a


    ENV PATH /usr/local/envs/\${env_name}/bin:${cplmtPath}\\\$PATH

    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    EOF
    """
}

process buildDockerRecipeFromCondaPackages {
    tag "${key}"
    publishDir "${baseDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'


    input:
    set val(key), val(tools), val(yum), val(git) from condaPackagesCh
        .groupTuple()
        .map{ addYumAndGitToCondaCh(it) }

    output:
    set val(key), file("${key}.Dockerfile"), val('EMPTY') into dockerRecipeCh4

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
    cat << EOF > ${key}.Dockerfile
    FROM conda/miniconda3-centos7

    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    RUN yum install -y which ${yumPkgs} ${cplmtGit} \\\\
    && yum clean all \\\\
    && conda create -y -n ${key}_env ${cplmtConda} \\\\
    && echo "source activate ${key}_env" > ~/.bashrc \\\\
    && conda clean -a


    ENV PATH /usr/local/envs/${key}_env/bin:${cplmtPath}\\\$PATH

    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    EOF
    """
}


process buildDockerRecipeFromSourceCode {
    tag "${key}"
    publishDir "${baseDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

    input:
    set val(key), file(installFile) from sourceCodeCh
    
    output:
    set val(key), file("${key}.Dockerfile"), val('EMPTY') into dockerRecipeCh5

    script:
    """
    cat << EOF > ${key}.Dockerfile
    FROM centos:7
    
    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    RUN mkdir -p /opt/modules
 
    ADD modules/${installFile} /opt/modules
    ADD modules/${key}/ /opt/modules/${key}
      
    RUN yum install -y epel-release which gcc gcc-c++ make \\\\
    && cd /opt/modules \\\\
    && bash ${installFile} \\\\
    && rm -r /opt/modules
 
    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    ENV PATH /usr/local/bin:\\\$PATH
    
    EOF
    """
}

onlyCondaRecipeCh = dockerRecipeCh3.mix(dockerRecipeCh4)
dockerAllRecipeCh = dockerRecipeCh1.mix(dockerRecipeCh2).mix(onlyCondaRecipeCh).mix(dockerRecipeCh5).dump(tag:'dockerRecipes')

process buildImages {
    tag "${key}"
    // publishDir "${baseDir}/${params.publishDirDockerImages}", overwrite: true, mode: 'copy'

    when:
    params.buildDockerImages

    input:
    set val(key), file(dockerRecipe), val(optionalPath) from dockerAllRecipeCh
    file condaYml from condaRecipes.collect().ifEmpty([])
    file fileDep from fileDependencies.collect().ifEmpty([])
    file moduleDir from sourceCodeDirCh.collect().ifEmpty([])

    script:
    excludemoduleDir = moduleDir == [] ? "--exclude='modules'" : ""
    """
    tar cvfh contextDir.tar ${excludemoduleDir} *
    mkdir contextDir
    tar xvf contextDir.tar --directory contextDir
    docker build  -f ${dockerRecipe} -t ${key.toLowerCase()} contextDir
    """
}

