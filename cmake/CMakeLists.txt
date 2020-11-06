#######################################################################################
# This file is part of geniac.
# 
# Copyright Institut Curie 2020.
# 
# This software is a computer program whose purpose is to perform
# Automatic Configuration GENerator and Installer for nextflow pipeline.
# 
# You can use, modify and/ or redistribute the software under the terms
# of license (see the LICENSE file for more details).
# 
# The software is distributed in the hope that it will be useful,
# but "AS IS" WITHOUT ANY WARRANTY OF ANY KIND.
# Users are therefore encouraged to test the software's suitability as regards
# their requirements in conditions enabling the security of their systems and/or data.
# 
# The fact that you are presently reading this means that you have had knowledge
# of the license and that you accept its terms.
#######################################################################################


# ##############################################################################
# Include some functions
# ##############################################################################
include("functionColorMessage.cmake")

# ##############################################################################
# STEP 1
# ##############################################################################
# Check that all the prerequisites are met
# ##############################################################################
include("stepFindPackages.cmake")

# ##############################################################################
# STEP 2
# ##############################################################################
# Check that all the options are consistent
# ##############################################################################
include("stepCheckOptions.cmake")

# ##############################################################################
# STEP 3
# ##############################################################################
# Extract git information
# ##############################################################################
include("stepGitInfo.cmake")

# ##############################################################################
# STEP 4
# ##############################################################################
# Main core script to generate config files, recipes and containers, and
# installed them
# ##############################################################################
include("stepMainCoreScript.cmake")

# ##############################################################################
# STEP 5
# ##############################################################################
# Add custom targets for tests
# ##############################################################################
include("stepAddTestTargets.cmake")
